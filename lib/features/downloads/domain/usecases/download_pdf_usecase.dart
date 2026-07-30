import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/background/download_progress_store.dart';
import 'package:notifecation/core/background/download_task_scheduler.dart';
import 'package:notifecation/core/constants/api_parameter_constant.dart';
import 'package:notifecation/core/constants/app_endpoints.dart';
import 'package:notifecation/core/error/app_error.dart';

/// STEP (domain): Hand a PDF download to Android's WorkManager.
///
/// The signature is deliberately unchanged from the Foreground Service branch
/// so the Cubit's call site stays the same. Only the meaning of a successful
/// result changed: it now confirms the work was *queued*, not that it started.
@injectable
class DownloadPdfUseCase {
  DownloadPdfUseCase(this._scheduler);

  final DownloadTaskScheduler _scheduler;

  Future<Either<AppError, Unit>> call({
    String fileName = ApiParameterConstant.downloadPdfFileName,
  }) {
    return _scheduler.enqueueDownload(
      url: AppEndpoints.downloadPdf,
      fileName: fileName,
    );
  }
}

/// STEP (domain): Observe progress written to disk by the worker isolate.
///
/// The Foreground Service version streamed real push events over a plugin
/// pipe. WorkManager exposes no such channel to Dart, so this stream is a
/// polling loop over a shared file.
@injectable
class ObserveDownloadProgressUseCase {
  ObserveDownloadProgressUseCase(this._scheduler);

  final DownloadTaskScheduler _scheduler;

  Stream<DownloadProgressSnapshot> call() => _scheduler.watchProgress();
}

/// STEP (domain): Read the last known progress once, to restore a UI that was
/// recreated while work was still queued or running.
@injectable
class GetDownloadProgressUseCase {
  GetDownloadProgressUseCase(this._scheduler);

  final DownloadTaskScheduler _scheduler;

  Future<DownloadProgressSnapshot> call() => _scheduler.currentProgress();
}
