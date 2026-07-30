import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'background_download_events.dart';

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
  // We reuse the same channel id + notification id as the UI NotificationService.
  // Updating the SAME id gives us a live progress bar on one notification.
  final notifications = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifications.initialize(
    const InitializationSettings(android: androidSettings),
  );

  const channel = AndroidNotificationChannel(
    'downloads',
    'Downloads',
    description: 'Shows download status and progress notifications.',
    importance: Importance.high,
  );

  await notifications
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);

  // ---------------------------------------------------------------------------
  // STEP 4: Listen for "startDownload" commands from the UI isolate
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

    try {
      // -----------------------------------------------------------------
      // STEP 5: Resolve a writable save path inside app documents
      // -----------------------------------------------------------------
      // App-specific storage does NOT need legacy WRITE_EXTERNAL_STORAGE.
      final docsDir = await getApplicationDocumentsDirectory();
      final downloadsDir = Directory(p.join(docsDir.path, 'downloads'));
      if (!await downloadsDir.exists()) {
        await downloadsDir.create(recursive: true);
      }
      final savePath = p.join(downloadsDir.path, fileName);

      // -----------------------------------------------------------------
      // STEP 6: Show/update the FGS notification with a real progress bar
      // -----------------------------------------------------------------
      Future<void> showProgress(int progress) async {
        await notifications.show(
          1001,
          'Downloading PDF',
          '$progress% complete',
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
              ongoing: progress < 100,
            ),
          ),
        );

        // Also notify the UI isolate so the Cubit can update the progress bar.
        service.invoke(BackgroundDownloadEvents.progress, {
          'progress': progress,
        });
      }

      await showProgress(0);

      // -----------------------------------------------------------------
      // STEP 7: Perform the actual HTTP download with Dio in this isolate
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
        onReceiveProgress: (received, total) async {
          if (total <= 0) return;
          final progress = ((received / total) * 100).round().clamp(0, 100);
          await showProgress(progress);
        },
      );

      // -----------------------------------------------------------------
      // STEP 8: Mark complete, tell UI, then stop the service
      // -----------------------------------------------------------------
      await notifications.show(
        1001,
        'Download complete',
        'Saved to $savePath',
        NotificationDetails(
          android: AndroidNotificationDetails(
            channel.id,
            channel.name,
            channelDescription: channel.description,
            importance: Importance.high,
            priority: Priority.high,
            onlyAlertOnce: true,
            ongoing: false,
          ),
        ),
      );

      service.invoke(BackgroundDownloadEvents.complete, {
        'path': savePath,
      });

      // Stop FGS when work is done (saves battery + removes sticky notif lifecycle).
      await service.stopSelf();
    } catch (error) {
      service.invoke(BackgroundDownloadEvents.failed, {
        'message': error.toString(),
      });

      await notifications.show(
        1001,
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
  });

  // ---------------------------------------------------------------------------
  // STEP 9: Allow UI to stop the service manually
  // ---------------------------------------------------------------------------
  service.on(BackgroundDownloadEvents.stopService).listen((event) async {
    await service.stopSelf();
  });
}
