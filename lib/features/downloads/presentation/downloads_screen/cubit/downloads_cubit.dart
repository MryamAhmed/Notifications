import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/background/background_download_events.dart';
import 'package:notifecation/core/background/download_trace.dart';
import 'package:notifecation/core/constants/app_error_codes.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/features/downloads/domain/usecases/download_pdf_usecase.dart';
import 'package:notifecation/features/downloads/domain/usecases/load_pdf_preview_usecase.dart';
import 'package:notifecation/features/downloads/domain/usecases/request_notification_permission_usecase.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_state.dart';

/// UI-side controller for Phase 1 + Foreground Service download.
///
/// Important:
/// - Preview still loads in the UI isolate (fast, for displaying PDF).
/// - The actual "Download" button starts an Android Foreground Service.
/// - Progress comes back through ObserveForegroundDownloadUseCase events.
@injectable
class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit(
    this._requestPermissionUseCase,
    this._loadPdfPreviewUseCase,
    this._downloadPdfUseCase,
    this._observeForegroundDownloadUseCase,
    this._getForegroundDownloadStateUseCase,
  ) : super(const DownloadsState()) {
    // STEP 1: a new Cubit exists, so whatever state the old one held is gone.
    fgsTrace('UI', 'STEP 1 DownloadsCubit created');

    // Listening must start here, not in downloadPdf(). This Cubit is a factory,
    // so after the process is killed and the app reopened a brand new instance
    // is built while the service is still downloading — if it only subscribed
    // on button press it would never hear that download at all.
    _listenToService();
    syncWithRunningService();

    // STEP: ask permission + load preview as soon as screen Cubit is created.
    bootstrap();
  }

  final RequestNotificationPermissionUseCase _requestPermissionUseCase;
  final LoadPdfPreviewUseCase _loadPdfPreviewUseCase;
  final DownloadPdfUseCase _downloadPdfUseCase;
  final ObserveForegroundDownloadUseCase _observeForegroundDownloadUseCase;
  final GetForegroundDownloadStateUseCase _getForegroundDownloadStateUseCase;

  StreamSubscription<BackgroundDownloadEvent>? _downloadEventsSub;

  // Held as fields because the subscription now outlives a single downloadPdf()
  // call, so the callbacks can no longer be captured in its closure.
  VoidCallback? _onSuccess;
  void Function(AppError error)? _onError;

  void _listenToService() {
    fgsTrace('UI', 'STEP 1a subscribing to service events');
    _downloadEventsSub = _observeForegroundDownloadUseCase().listen((event) {
      if (isClosed) return;

      switch (event) {
        case DownloadProgressEvent(:final progress):
          // If these never appear while the notification is counting up, the
          // service-to-UI pipe is dead and the snapshot query cannot work
          // either — the bug would be in the plugin wiring, not the snapshot.
          if (progress % 10 == 0) {
            fgsTrace('UI', 'progress event received', progress);
          }
          if (progress == state.progress && state.isDownloading) return;
          emit(
            state.copyWith(
              isDownloading: true,
              progress: progress,
            ),
          );
        case DownloadCompletedEvent(:final path):
          emit(
            state.copyWith(
              isDownloading: false,
              progress: 100,
              savedPath: path,
              error: null,
            ),
          );
          _onSuccess?.call();
          _clearCallbacks();
        case DownloadFailedEvent(:final message):
          final error = AppError.local(
            AppErrorCodes.pdfDownloadFailed,
            message: message,
          );
          emit(
            state.copyWith(
              isDownloading: false,
              error: error,
            ),
          );
          _onError?.call(error);
          _clearCallbacks();
      }
    });
  }

  /// Adopts a download that is already running in the Foreground Service.
  ///
  /// The progress stream has no replay, so subscribing alone leaves a gap: the
  /// UI would show 0% until the next update, and would never recover at all if
  /// the download had already finished. This asks the service directly.
  Future<void> syncWithRunningService() async {
    // STEP 2: the restore attempt starts.
    fgsTrace('UI', 'STEP 2 syncWithRunningService() called');

    final snapshot = await _getForegroundDownloadStateUseCase();

    fgsTrace(
      'UI',
      'STEP 2a snapshot resolved',
      snapshot == null
          ? 'null (nothing to restore)'
          : 'isDownloading=${snapshot.isDownloading} '
              'progress=${snapshot.progress} savedPath=${snapshot.savedPath}',
    );

    if (isClosed) {
      fgsTrace('UI', 'STEP 2b ABORT - cubit already closed');
      return;
    }
    if (snapshot == null) return;

    if (snapshot.isDownloading) {
      emit(
        state.copyWith(
          isDownloading: true,
          progress: snapshot.progress,
          savedPath: null,
          error: null,
        ),
      );
      // STEP 7: the restored state is now in the Cubit.
      fgsTrace(
        'UI',
        'STEP 7 emitted restored state',
        'isDownloading=${state.isDownloading} progress=${state.progress}',
      );
    } else if (snapshot.savedPath != null) {
      emit(
        state.copyWith(
          isDownloading: false,
          progress: 100,
          savedPath: snapshot.savedPath,
        ),
      );
      fgsTrace('UI', 'STEP 7 emitted completed state', state.savedPath);
    } else {
      fgsTrace('UI', 'STEP 7 SKIPPED - snapshot says idle, nothing to restore');
    }
  }

  void _clearCallbacks() {
    _onSuccess = null;
    _onError = null;
  }

  Future<void> bootstrap() async {
    await _requestPermissionUseCase().then((result) {
      result.match(
        (_) {
          if (isClosed) return;
          emit(state.copyWith(permissionGranted: false));
        },
        (granted) {
          if (isClosed) return;
          emit(state.copyWith(permissionGranted: granted));
        },
      );
    });

    await loadPreview();
  }

  Future<void> loadPreview({
    VoidCallback? onSuccess,
    void Function(AppError error)? onError,
  }) async {
    emit(
      state.copyWith(
        isLoadingPreview: true,
        error: null,
      ),
    );

    final result = await _loadPdfPreviewUseCase();
    if (isClosed) return;

    result.match(
      (error) {
        emit(
          state.copyWith(
            isLoadingPreview: false,
            error: error,
          ),
        );
        onError?.call(error);
      },
      (file) {
        emit(
          state.copyWith(
            isLoadingPreview: false,
            previewPath: file.path,
            error: null,
          ),
        );
        onSuccess?.call();
      },
    );
  }

  /// Starts download inside an Android Foreground Service.
  ///
  /// Why FGS?
  /// Android can kill normal background network work when the app is closed.
  /// A Foreground Service shows a sticky notification and is allowed to keep
  /// running long enough to finish the download + emit progress updates.
  Future<void> downloadPdf({
    VoidCallback? onSuccess,
    void Function(AppError error)? onError,
  }) async {
    if (state.isDownloading) return;

    // The subscription is created in the constructor and lives for the whole
    // Cubit, so only the one-shot UI callbacks are wired up here.
    _onSuccess = onSuccess;
    _onError = onError;

    emit(
      state.copyWith(
        isDownloading: true,
        progress: 0,
        error: null,
        savedPath: null,
      ),
    );

    // Ask use case to start the Foreground Service + send startDownload.
    final startResult = await _downloadPdfUseCase();
    if (isClosed) return;

    startResult.match(
      (error) {
        emit(
          state.copyWith(
            isDownloading: false,
            error: error,
          ),
        );
        onError?.call(error);
        _clearCallbacks();
      },
      (_) {
        // Service started. Progress will arrive through the event stream.
      },
    );
  }

  bool get canDownload =>
      !state.isDownloading &&
      !state.isLoadingPreview &&
      state.previewPath != null;

  @override
  Future<void> close() async {
    await _downloadEventsSub?.cancel();
    return super.close();
  }
}
