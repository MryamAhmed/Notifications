import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'background_download_events.dart';
import '../notifications/notification_service.dart';

/// ============================================================================
/// PENDING JOB PERSISTENCE
/// ============================================================================
/// The `startDownload` command only ever exists in the UI isolate's memory.
/// When an OEM kills the process on swipe, the plugin's WatchdogReceiver
/// respawns the service with a brand new isolate that has nothing to do — it
/// posts "Preparing download..." and waits forever for a command whose only
/// sender just died.
///
/// Writing the job to disk lets the respawned isolate pick it back up. A file
/// is used instead of SharedPreferences so no new dependency is needed.

/// Guard against an endlessly failing URL respawning the service forever.
const int _maxResumeAttempts = 3;

String _formatBytes(int bytes) {
  const mb = 1024 * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

Future<File> _pendingJobFile() async {
  final docsDir = await getApplicationDocumentsDirectory();
  return File(p.join(docsDir.path, 'pending_download.json'));
}

Future<void> _savePendingJob({
  required String url,
  required String fileName,
  required int attempt,
}) async {
  final file = await _pendingJobFile();
  await file.writeAsString(
    jsonEncode({'url': url, 'fileName': fileName, 'attempt': attempt}),
  );
}

Future<Map<String, dynamic>?> _readPendingJob() async {
  try {
    final file = await _pendingJobFile();
    if (!await file.exists()) return null;
    final decoded = jsonDecode(await file.readAsString());
    return decoded is Map<String, dynamic> ? decoded : null;
  } catch (_) {
    // A corrupt file must never block a new download.
    return null;
  }
}

Future<void> _clearPendingJob() async {
  try {
    final file = await _pendingJobFile();
    if (await file.exists()) await file.delete();
  } catch (_) {}
}

/// ============================================================================
/// BACKGROUND ISOLATE ENTRY POINT (Foreground Service worker)
/// ============================================================================
/// IMPORTANT CONCEPT:
/// When Android runs a Foreground Service through flutter_background_service,
/// your download code does NOT run in the same isolate as the UI.
/// It runs in a SEPARATE Dart isolate.
///
/// That means:
/// - GetIt from the UI isolate is NOT available here
/// - Cubits are NOT available here
/// - We create Dio + Notifications locally inside this isolate
///
/// @pragma('vm:entry-point') tells Flutter: "keep this function even if the
/// UI tree doesn't reference it" — required for background entry points.
@pragma('vm:entry-point')
Future<void> backgroundDownloadOnStart(ServiceInstance service) async {
  // ---------------------------------------------------------------------------
  // STEP 1: Initialize Flutter plugins inside THIS isolate
  // ---------------------------------------------------------------------------
  // Without this, path_provider / notifications / dio plugins may fail with
  // "Unable to establish connection on channel".
  DartPluginRegistrant.ensureInitialized();

  // ---------------------------------------------------------------------------
  // STEP 2: Promote this Android service to a Foreground Service (FGS)
  // ---------------------------------------------------------------------------
  // A Foreground Service shows a persistent notification and is much harder
  // for the OS to kill than a normal background task.
  if (service is AndroidServiceInstance) {
    // Optional: allow UI to force foreground/background mode later.
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    // Start as foreground immediately so Android allows long network work.
    await service.setAsForegroundService();
  }

  // ---------------------------------------------------------------------------
  // STEP 3: Create a local notifications plugin in THIS isolate
  // ---------------------------------------------------------------------------
  // We reuse the Downloads channel, but the running FGS and final result use
  // different notification ids so stopping the FGS cannot remove the result.
  final notifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    const InitializationSettings(android: androidSettings),
  );

  const channel = NotificationService.downloadsChannel;

  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // ---------------------------------------------------------------------------
  // STEP 4: Ready handshake
  // ---------------------------------------------------------------------------
  // The UI pings until this isolate answers. This replaces the unreliable
  // "wait 700 ms and hope the listener exists" approach.
  service.on(BackgroundDownloadEvents.ping).listen((event) {
    service.invoke(BackgroundDownloadEvents.ready);
  });
  service.invoke(BackgroundDownloadEvents.ready);

  var downloadRunning = false;

  // ---------------------------------------------------------------------------
  // STEP 5: The download itself
  // ---------------------------------------------------------------------------
  // Extracted into a function because two callers need it: a fresh command
  // from the UI, and a resume after the process was killed mid-download.
  Future<void> runDownload({
    required String url,
    required String fileName,
    required int attempt,
  }) async {
    // Prevent two downloads from sharing one service/notification at once.
    if (downloadRunning) return;
    downloadRunning = true;

    try {
      // Persist BEFORE any network work, so a kill at any point is recoverable.
      await _savePendingJob(url: url, fileName: fileName, attempt: attempt);

      // -----------------------------------------------------------------
      // STEP 6: Resolve a writable save path inside app documents
      // -----------------------------------------------------------------
      // App-specific storage does NOT need legacy WRITE_EXTERNAL_STORAGE.
      final docsDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(docsDir.path, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final savePath = p.join(downloadsDir.path, fileName);

      // -----------------------------------------------------------------
      // STEP 7: Update progress in a controlled order
      // -----------------------------------------------------------------
      // Dio's progress callback is synchronous; async calls made directly in it
      // can overlap and make 42% appear after 43%. This queue serializes updates.
      var lastProgress = -1;
      var lastNotifiedAt = DateTime.fromMillisecondsSinceEpoch(0);
      Future<void> notificationQueue = Future<void>.value();

      void reportProgress(int progress, {int received = 0, int total = 0}) {
        // Update only when the percentage actually increases.
        if (progress <= lastProgress) return;
        lastProgress = progress;

        // The UI isolate may be gone after the app is swiped away; invoking is
        // still safe, and a reopened UI can subscribe to future events.
        service.invoke(BackgroundDownloadEvents.progress, {
          'progress': progress,
        });

        // NotificationManagerService drops updates to an existing notification
        // once the package exceeds max_package_enqueue_rate (5/sec by default),
        // logging "Package enqueue rate is N. Shedding <key>". A 25 MB file
        // produces 15-30 updates/sec, so nearly all of them were being thrown
        // away and the bar looked frozen. Notifications with completed progress
        // are exempt from shedding, so 100% must always be posted.
        const minInterval = Duration(milliseconds: 500);
        final now = DateTime.now();
        if (progress < 100 && now.difference(lastNotifiedAt) < minInterval) {
          return;
        }
        lastNotifiedAt = now;

        // Update the SAME notification id used by startForeground().
        //
        // These are the exact Android progress-bar properties requested by
        // the spike:
        // - showProgress: true  → render the bar
        // - maxProgress: 100    → percentage scale
        // - progress            → current percentage
        notificationQueue = notificationQueue.then((_) async {
          await notifications.show(
            NotificationService.foregroundServiceNotificationId,
            'Downloading $fileName',
            total > 0
                ? '${_formatBytes(received)} of ${_formatBytes(total)}'
                : 'Starting download...',
            NotificationDetails(
              android: AndroidNotificationDetails(
                channel.id,
                channel.name,
                channelDescription: channel.description,
                importance: Importance.high,
                priority: Priority.high,
                onlyAlertOnce: true,
                showProgress: true,
                maxProgress: 100,
                progress: progress,
                ongoing: true,
                autoCancel: false,
                // Android draws the bar but never a percentage, and several OEM
                // skins (One UI, MIUI) drop the content-text line when a bar is
                // present. subText renders in the header row next to the app
                // name, which survives on every skin.
                subText: '$progress%',
              ),
            ),
          );
        });
      }

      reportProgress(0);
      await notificationQueue;

      // -----------------------------------------------------------------
      // STEP 8: Perform the actual HTTP download with Dio in this isolate
      // -----------------------------------------------------------------
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      await dio.download(
        url,
        savePath,
        onReceiveProgress: (received, total) {
          if (total <= 0) return;
          final progress = ((received / total) * 100).round().clamp(0, 100);
          reportProgress(progress, received: received, total: total);
        },
      );

      reportProgress(100);
      await notificationQueue;

      final savedBytes = await File(savePath).length();

      // -----------------------------------------------------------------
      // STEP 9: Mark complete, tell UI, then stop the service
      // -----------------------------------------------------------------
      // This uses notification id 1001. The FGS uses id 1002, so stopSelf()
      // removes only the sticky FGS notification and leaves this result visible.
      await notifications.show(
        NotificationService.downloadNotificationId,
        'Download complete',
        fileName,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            onlyAlertOnce: true,
            ongoing: false,
            subText: _formatBytes(savedBytes),
          ),
        ),
      );

      service.invoke(BackgroundDownloadEvents.complete, {
        'path': savePath,
      });

      // The job is done, so a later respawn must not download it again.
      await _clearPendingJob();
      downloadRunning = false;

      // Stop FGS when work is done (saves battery + removes sticky notif lifecycle).
      await service.stopSelf();
    } catch (error) {
      // A real error (404, no network) is not something a respawn can fix.
      await _clearPendingJob();
      downloadRunning = false;

      service.invoke(BackgroundDownloadEvents.failed, {
        'message': error.toString(),
      });

      await notifications.show(
        NotificationService.downloadNotificationId,
        'Download failed',
        error.toString(),
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            ongoing: false,
          ),
        ),
      );

      await service.stopSelf();
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 10: Listen for "startDownload" commands from the UI isolate
  // ---------------------------------------------------------------------------
  // UI calls: FlutterBackgroundService().invoke('startDownload', {...})
  // This isolate receives that event here.
  service.on(BackgroundDownloadEvents.startDownload).listen((event) async {
    if (event == null) return;

    final url = event['url'] as String?;
    final fileName = event['fileName'] as String?;
    if (url == null || fileName == null) {
      service.invoke(BackgroundDownloadEvents.failed, {
        'message': 'Missing url or fileName in startDownload event',
      });
      return;
    }

    await runDownload(url: url, fileName: fileName, attempt: 1);
  });

  // ---------------------------------------------------------------------------
  // STEP 11: Allow UI to stop the service manually
  // ---------------------------------------------------------------------------
  service.on(BackgroundDownloadEvents.stopService).listen((event) async {
    await _clearPendingJob();
    await service.stopSelf();
  });

  // ---------------------------------------------------------------------------
  // STEP 12: Resume a job that a process kill interrupted
  // ---------------------------------------------------------------------------
  // Reaching here with a job still on disk means the previous isolate died
  // before finishing — swiped away on an aggressive OEM, or low-memory killed —
  // and WatchdogReceiver respawned the service. Without this the respawned
  // service would sit on "Preparing download..." forever.
  final pendingJob = await _readPendingJob();
  if (pendingJob != null) {
    final url = pendingJob['url'] as String?;
    final fileName = pendingJob['fileName'] as String?;
    final attempt = (pendingJob['attempt'] as num?)?.toInt() ?? 1;

    if (url == null || fileName == null || attempt >= _maxResumeAttempts) {
      await _clearPendingJob();
    } else {
      // The server sends no Accept-Ranges, so this restarts from byte 0.
      await runDownload(url: url, fileName: fileName, attempt: attempt + 1);
    }
  }
}
