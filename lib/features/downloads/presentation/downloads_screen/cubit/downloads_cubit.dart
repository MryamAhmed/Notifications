import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/background/download_progress_store.dart';
import 'package:notifecation/core/constants/app_error_codes.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/features/downloads/domain/usecases/download_pdf_usecase.dart';
import 'package:notifecation/features/downloads/domain/usecases/load_pdf_preview_usecase.dart';
import 'package:notifecation/features/downloads/domain/usecases/request_notification_permission_usecase.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_state.dart';

/// UI-side controller for the WorkManager download branch.
///
/// Difference from the Foreground Service branch worth noting: restoring an
/// in-flight download needs no request/response handshake with a service. The
/// worker's progress lives in a file, so a freshly created Cubit simply reads
/// it. What was a multi-step debugging problem there is one `await` here.
@injectable
class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit(
    this._requestPermissionUseCase,
    this._loadPdfPreviewUseCase,
    this._downloadPdfUseCase,
    this._observeDownloadProgressUseCase,
    this._getDownloadProgressUseCase,
  ) : super(const DownloadsState()) {
    _restoreLastKnownProgress();
    _listenToWorker();
    bootstrap();
  }

  final RequestNotificationPermissionUseCase _requestPermissionUseCase;
  final LoadPdfPreviewUseCase _loadPdfPreviewUseCase;
  final DownloadPdfUseCase _downloadPdfUseCase;
  final ObserveDownloadProgressUseCase _observeDownloadProgressUseCase;
  final GetDownloadProgressUseCase _getDownloadProgressUseCase;

  StreamSubscription<DownloadProgressSnapshot>? _progressSub;

  // Held as fields because the subscription outlives a single downloadPdf()
  // call and cannot capture them in a closure.
  VoidCallback? _onSuccess;
  void Function(AppError error)? _onError;

  /// Adopts whatever the worker was doing before this Cubit existed.
  Future<void> _restoreLastKnownProgress() async {
    final snapshot = await _getDownloadProgressUseCase();
    if (isClosed || snapshot.status == DownloadTaskStatus.idle) return;
    _applySnapshot(snapshot, notifyCallbacks: false);
  }

  void _listenToWorker() {
    _progressSub = _observeDownloadProgressUseCase().listen((snapshot) {
      if (isClosed) return;
      _applySnapshot(snapshot, notifyCallbacks: true);
    });
  }

  /// Translates a worker snapshot into UI state.
  ///
  /// [notifyCallbacks] is false when restoring on startup, so reopening the app
  /// after a finished download does not replay a success or error toast.
  void _applySnapshot(
    DownloadProgressSnapshot snapshot, {
    required bool notifyCallbacks,
  }) {
    switch (snapshot.status) {
      case DownloadTaskStatus.idle:
        return;

      // Accepted by WorkManager but not started. Progress stays at 0 for as
      // long as Android decides to defer the work.
      case DownloadTaskStatus.enqueued:
      case DownloadTaskStatus.running:
        emit(
          state.copyWith(
            isDownloading: true,
            progress: snapshot.progress,
            savedPath: null,
            error: null,
          ),
        );

      case DownloadTaskStatus.success:
        emit(
          state.copyWith(
            isDownloading: false,
            progress: 100,
            savedPath: snapshot.filePath,
            error: null,
          ),
        );
        if (notifyCallbacks) {
          _onSuccess?.call();
          _clearCallbacks();
        }

      case DownloadTaskStatus.failed:
        final error = AppError.local(
          AppErrorCodes.pdfDownloadFailed,
          message: snapshot.errorMessage,
        );
        emit(
          state.copyWith(
            isDownloading: false,
            error: error,
          ),
        );
        if (notifyCallbacks) {
          _onError?.call(error);
          _clearCallbacks();
        }
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

  /// Queues the download with WorkManager.
  ///
  /// This returns as soon as Android records the request. Unlike the Foreground
  /// Service branch, a successful return is no promise that bytes are moving:
  /// the work may sit in the queue while the device is dozing or offline.
  Future<void> downloadPdf({
    VoidCallback? onSuccess,
    void Function(AppError error)? onError,
  }) async {
    if (state.isDownloading) return;

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

    final enqueueResult = await _downloadPdfUseCase();
    if (isClosed) return;

    enqueueResult.match(
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
        // Queued. Progress arrives through the polled snapshot stream.
      },
    );
  }

  bool get canDownload =>
      !state.isDownloading &&
      !state.isLoadingPreview &&
      state.previewPath != null;

  @override
  Future<void> close() async {
    await _progressSub?.cancel();
    return super.close();
  }
}
