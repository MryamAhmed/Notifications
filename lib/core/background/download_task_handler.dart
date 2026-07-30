import 'dart:io';
import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:workmanager/workmanager.dart';

import 'download_progress_store.dart';
import 'download_trace.dart';
import '../notifications/notification_service.dart';

/// Identifies the work in WorkManager's database. Reusing one unique name lets
/// [ExistingWorkPolicy] collapse duplicate taps into a single download.
const String kDownloadTaskUniqueName = 'pdf-download-work';

/// The value handed back to [Workmanager.executeTask] so one dispatcher can
/// serve several task types.
const String kDownloadTaskName = 'downloadPdfTask';

const String kTaskInputUrl = 'url';
const String kTaskInputFileName = 'fileName';

String _formatBytes(int bytes) {
  const mb = 1024 * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).toStringAsFixed(0)} KB';
}

/// ============================================================================
/// WORKMANAGER BACKGROUND ISOLATE ENTRY POINT
/// ============================================================================
/// How Android reaches this function:
///
/// 1. `Workmanager().initialize(callbackDispatcher)` resolves this function to
///    a raw callback handle and persists that integer natively.
/// 2. `registerOneOffTask` enqueues a OneTimeWorkRequest into WorkManager's own
///    Room database on disk — outside this process entirely.
/// 3. When constraints are met, WorkManager (via JobScheduler) starts the app
///    process if needed and runs the plugin's BackgroundWorker.
/// 4. That worker reads the stored handle, spins up a brand new headless
///    FlutterEngine with no Activity, and invokes this function in a fresh
///    isolate.
///
/// Consequences, identical to the Foreground Service branch:
/// - GetIt from the UI isolate does not exist here.
/// - Cubits do not exist here.
/// - Dio and NotificationService are constructed locally.
///
/// @pragma('vm:entry-point') stops tree-shaking from removing a function that
/// nothing in the widget tree references.
@pragma('vm:entry-point')
void callbackDispatcher() {
  // The headless engine registers plugins natively, but calling this makes the
  // isolate's plugin registry explicit and is safe to repeat.
  DartPluginRegistrant.ensureInitialized();

  Workmanager().executeTask((taskName, inputData) async {
    fgsTrace('WM', 'worker isolate started', taskName);

    if (taskName != kDownloadTaskName) {
      // Unknown work should not be retried forever.
      return true;
    }

    return _runDownload(inputData);
  });
}

/// Returns whether WorkManager should consider the work finished.
///
/// `true`  -> Result.success(), the work is removed from the queue.
/// `false` -> Result.retry(), WorkManager reschedules using the backoff policy.
Future<bool> _runDownload(Map<String, dynamic>? inputData) async {
  final url = inputData?[kTaskInputUrl] as String?;
  final fileName = inputData?[kTaskInputFileName] as String?;

  final store = DownloadProgressStore();

  // Genuine reuse: NotificationService holds nothing but a plugin instance, so
  // the worker isolate can build its own and call the same public methods the
  // UI does. Channels are created idempotently inside initialize().
  final notifications = NotificationService();
  await notifications.initialize();

  if (url == null || fileName == null) {
    // Missing input is a programming error; retrying cannot fix it.
    await store.write(
      const DownloadProgressSnapshot(
        status: DownloadTaskStatus.failed,
        errorMessage: 'Missing url or fileName in task input data.',
      ),
    );
    await notifications.showDownloadFinishedNotification(
      success: false,
      body: 'Missing download parameters.',
    );
    return true;
  }

  await store.write(
    const DownloadProgressSnapshot(status: DownloadTaskStatus.running),
  );
  await notifications.showDownloadNotification(
    title: 'Downloading file',
    body: 'Starting download...',
  );

  try {
    // App-specific storage needs no legacy WRITE_EXTERNAL_STORAGE permission.
    final docsDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(p.join(docsDir.path, 'downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }
    final savePath = p.join(downloadsDir.path, fileName);

    // Dio's progress callback is synchronous, so awaiting inside it directly
    // would let 43% overtake 42%. Chaining onto one future serialises them.
    var lastProgress = -1;
    var lastNotifiedAt = DateTime.fromMillisecondsSinceEpoch(0);
    Future<void> pending = Future<void>.value();

    void reportProgress(int progress, {int received = 0, int total = 0}) {
      if (progress <= lastProgress) return;
      lastProgress = progress;

      // NotificationManagerService sheds updates once a package exceeds
      // max_package_enqueue_rate (5/sec), logging "Package enqueue rate is N".
      // A 25 MB file emits 15-30 updates/sec, so without this the bar looks
      // frozen. Completed progress is exempt from shedding, so 100% always
      // gets through.
      const minInterval = Duration(milliseconds: 500);
      final now = DateTime.now();
      if (progress < 100 && now.difference(lastNotifiedAt) < minInterval) {
        return;
      }
      lastNotifiedAt = now;

      pending = pending.then((_) async {
        await notifications.updateDownloadNotification(
          progress: progress,
          title: 'Downloading $fileName',
          body: total > 0
              ? '${_formatBytes(received)} of ${_formatBytes(total)}'
              : '$progress% complete',
        );
        // The UI isolate has no other way to learn this number.
        await store.write(
          DownloadProgressSnapshot(
            status: DownloadTaskStatus.running,
            progress: progress,
          ),
        );
      });
    }

    reportProgress(0);
    await pending;

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
        // A chunked response with no Content-Length reports -1 here, which
        // means no percentage can be computed at all.
        if (total <= 0) return;
        final progress = ((received / total) * 100).round().clamp(0, 100);
        reportProgress(progress, received: received, total: total);
      },
    );

    reportProgress(100);
    await pending;

    final savedBytes = await File(savePath).length();

    await notifications.showDownloadFinishedNotification(
      success: true,
      body: '$fileName (${_formatBytes(savedBytes)})',
    );
    await store.write(
      DownloadProgressSnapshot(
        status: DownloadTaskStatus.success,
        progress: 100,
        filePath: savePath,
      ),
    );

    fgsTrace('WM', 'download finished', savePath);
    return true;
  } catch (error) {
    // WorkManager's built-in backoff replaces the retry logic the Foreground
    // Service branch had to hand-roll. A 4xx will fail identically next time,
    // so only transient errors are worth rescheduling.
    final isPermanent = error is DioException &&
        (error.response?.statusCode ?? 0) >= 400 &&
        (error.response?.statusCode ?? 0) < 500;

    await notifications.showDownloadFinishedNotification(
      success: false,
      body: isPermanent
          ? error.toString()
          : 'Network problem. Android will retry automatically.',
    );
    await store.write(
      DownloadProgressSnapshot(
        status: DownloadTaskStatus.failed,
        errorMessage: error.toString(),
      ),
    );

    fgsTrace('WM', 'download failed', 'permanent=$isPermanent $error');
    return isPermanent;
  }
}
