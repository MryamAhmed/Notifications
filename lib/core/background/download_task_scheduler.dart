import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:workmanager/workmanager.dart';

import 'download_progress_store.dart';
import 'download_task_handler.dart';
import 'download_trace.dart';
import '../constants/app_error_codes.dart';
import '../error/app_error.dart';

/// UI-isolate wrapper around WorkManager, mirroring the role the
/// `BackgroundDownloadService` played for the Foreground Service branch.
///
/// Note how much disappeared. There is no `isRunning()` to race against, no
/// ready handshake, no ping loop and no timeout, because enqueueing does not
/// start anything: it writes a row into WorkManager's Room database and
/// returns. Android decides when the worker actually runs.
@lazySingleton
class DownloadTaskScheduler {
  DownloadTaskScheduler(this._progressStore);

  final DownloadProgressStore _progressStore;

  /// Registers the Dart entry point so Android can find it later.
  ///
  /// This only stores a callback handle natively. It does not schedule work and
  /// does not spawn an isolate.
  Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher);
    fgsTrace('UI', 'WorkManager initialized - callback handle registered');
  }

  /// Enqueues the download and returns as soon as WorkManager accepts it.
  ///
  /// Success here means "Android has durably recorded the request", not
  /// "the download started". That distinction is the whole difference from
  /// `startForegroundService()`.
  Future<Either<AppError, Unit>> enqueueDownload({
    required String url,
    required String fileName,

    /// Requests the expedited fast lane instead of ordinary deferred work.
    ///
    /// Left off by default on purpose. On API 30 and below WorkManager runs
    /// expedited work as a foreground service and requires the worker to
    /// implement `getForegroundInfo()`; workmanager_android 0.9.0+2 does not,
    /// so enabling this throws IllegalStateException on older devices. Safe to
    /// turn on when testing exclusively on Android 12+.
    bool expedited = false,
  }) async {
    try {
      // Seeded before enqueueing so the UI can render "Queued" during the gap
      // between the tap and the worker actually starting.
      await _progressStore.write(
        const DownloadProgressSnapshot(status: DownloadTaskStatus.enqueued),
      );

      await Workmanager().registerOneOffTask(
        kDownloadTaskUniqueName,
        kDownloadTaskName,
        inputData: {
          kTaskInputUrl: url,
          kTaskInputFileName: fileName,
        },
        // A precondition, and therefore an explicit licence for Android to
        // wait. With no connection the work simply sits in the queue.
        constraints: Constraints(networkType: NetworkType.connected),
        // A second tap supersedes the previous request rather than queueing a
        // duplicate download onto the same notification id.
        existingWorkPolicy: ExistingWorkPolicy.replace,
        // Applied only when the worker returns false (Result.retry).
        backoffPolicy: BackoffPolicy.exponential,
        backoffPolicyDelay: const Duration(seconds: 30),
        outOfQuotaPolicy: expedited
            ? OutOfQuotaPolicy.runAsNonExpeditedWorkRequest
            : null,
      );

      fgsTrace('UI', 'one-off task enqueued', fileName);
      return const Right(unit);
    } catch (error) {
      await _progressStore.write(
        DownloadProgressSnapshot(
          status: DownloadTaskStatus.failed,
          errorMessage: error.toString(),
        ),
      );
      return Left(
        AppError.local(
          AppErrorCodes.pdfDownloadFailed,
          message: error.toString(),
        ),
      );
    }
  }

  /// Polled view of the worker's progress. See [DownloadProgressStore.watch]
  /// for why polling is the only option here.
  Stream<DownloadProgressSnapshot> watchProgress() => _progressStore.watch();

  /// One-shot read used to restore the UI after the process was recreated.
  Future<DownloadProgressSnapshot> currentProgress() => _progressStore.read();

  /// Marks a finished result as consumed so a later app launch starts clean.
  Future<void> clearProgress() => _progressStore.clear();

  Future<void> cancel() async {
    await Workmanager().cancelByUniqueName(kDownloadTaskUniqueName);
    await _progressStore.clear();
  }
}
