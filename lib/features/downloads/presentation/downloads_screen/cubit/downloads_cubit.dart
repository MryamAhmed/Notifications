import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/features/downloads/domain/usecases/download_pdf_usecase.dart';
import 'package:notifecation/features/downloads/domain/usecases/load_pdf_preview_usecase.dart';
import 'package:notifecation/features/downloads/domain/usecases/request_notification_permission_usecase.dart';
import 'package:notifecation/features/downloads/presentation/downloads_screen/cubit/downloads_state.dart';

@injectable
class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit(
    this._requestPermissionUseCase,
    this._loadPdfPreviewUseCase,
    this._downloadPdfUseCase,
  ) : super(const DownloadsState()) {
    bootstrap();
  }

  final RequestNotificationPermissionUseCase _requestPermissionUseCase;
  final LoadPdfPreviewUseCase _loadPdfPreviewUseCase;
  final DownloadPdfUseCase _downloadPdfUseCase;

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
      ),
    );

    final result = await _downloadPdfUseCase(
      onProgress: (progress) {
        if (isClosed || progress == state.progress) return;
        emit(
          state.copyWith(
            progress: progress,
            isDownloading: true,
          ),
        );
      },
    );

    if (isClosed) return;

    result.match(
      (error) {
        emit(
          state.copyWith(
            isDownloading: false,
            error: error,
          ),
        );
        onError?.call(error);
      },
      (file) {
        emit(
          state.copyWith(
            isDownloading: false,
            progress: 100,
            savedPath: file.path,
            error: null,
          ),
        );
        onSuccess?.call();
      },
    );
  }

  bool get canDownload =>
      !state.isDownloading &&
      !state.isLoadingPreview &&
      state.previewPath != null;
}
