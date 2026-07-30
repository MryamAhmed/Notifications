import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/background/background_download_events.dart';
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
  ) : super(const DownloadsState()) {
    // STEP: ask permission + load preview as soon as screen Cubit is created.
    bootstrap();
  }

  final RequestNotificationPermissionUseCase _requestPermissionUseCase;
  final LoadPdfPreviewUseCase _loadPdfPreviewUseCase;
  final DownloadPdfUseCase _downloadPdfUseCase;
  final ObserveForegroundDownloadUseCase _observeForegroundDownloadUseCase;

  StreamSubscription<BackgroundDownloadEvent>? _downloadEventsSub;

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

    emit(
      state.copyWith(
        isDownloading: true,
        progress: 0,
        error: null,
        savedPath: null,
      ),
    );

    // STEP 1: Listen to FGS isolate events BEFORE starting the download.
    await _downloadEventsSub?.cancel();
    _downloadEventsSub = _observeForegroundDownloadUseCase().listen((event) {
      if (isClosed) return;

      switch (event) {
        case DownloadProgressEvent(:final progress):
          if (progress == state.progress) return;
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
          onSuccess?.call();
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
          onError?.call(error);
      }
    });

    // STEP 2: Ask use case to start the Foreground Service + send startDownload.
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
