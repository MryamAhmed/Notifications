import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/notification_service.dart';
import '../../data/repositories/pdf_repository_impl.dart';
import '../../domain/repositories/pdf_repository.dart';
import 'downloads_state.dart';

/// Sample PDF endpoint used for this spike.
const kSamplePdfUrl =
    'https://mozilla.github.io/pdf.js/web/compressed.tracemonkey-pldi-09.pdf';

const kSamplePdfFileName = 'sample.pdf';

class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit({
    NotificationService? notificationService,
    PdfRepository? pdfRepository,
  })  : _notifications = notificationService ?? NotificationService.instance,
        _pdfRepository = pdfRepository ?? PdfRepositoryImpl(),
        super(const DownloadsState()) {
    _bootstrap();
  }

  final NotificationService _notifications;
  final PdfRepository _pdfRepository;

  /// Permission first, then load the remote PDF into the viewer.
  Future<void> _bootstrap() async {
    final granted = await _notifications.requestNotificationPermission();

    emit(
      state.copyWith(
        permissionGranted: granted,
        message: granted
            ? 'Loading PDF preview...'
            : 'Notification permission denied. Loading PDF preview...',
        status: DownloadsStatus.loadingPreview,
      ),
    );

    await loadPreview();
  }

  Future<void> loadPreview() async {
    emit(
      state.copyWith(
        status: DownloadsStatus.loadingPreview,
        message: 'Loading PDF preview...',
      ),
    );

    try {
      final path = await _pdfRepository.fetchPreviewPdf(
        url: kSamplePdfUrl,
        fileName: kSamplePdfFileName,
      );

      emit(
        state.copyWith(
          status: DownloadsStatus.previewReady,
          previewPath: path,
          message: 'PDF ready. Press Download to save it with live progress.',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: DownloadsStatus.failure,
          message: 'Failed to load PDF preview: $error',
        ),
      );
    }
  }

  /// Starts a real download and auto-updates the notification progress.
  Future<void> downloadPdf() async {
    if (state.isDownloading) return;

    emit(
      state.copyWith(
        status: DownloadsStatus.downloading,
        progress: 0,
        message: 'Downloading PDF...',
      ),
    );

    await _notifications.showDownloadNotification(
      title: 'Downloading PDF',
      body: 'Starting download...',
    );

    try {
      final savedPath = await _pdfRepository.downloadPdf(
        url: kSamplePdfUrl,
        fileName: kSamplePdfFileName,
        onProgress: (progress) {
          // Ignore emits after close, and skip duplicate percentages.
          if (isClosed || progress == state.progress) return;

          emit(
            state.copyWith(
              progress: progress,
              message: 'Downloading PDF... $progress%',
            ),
          );

          // Same notification id → Android updates the existing notification.
          _notifications.updateDownloadNotification(
            progress: progress,
            title: 'Downloading PDF',
          );
        },
      );

      await _notifications.showDownloadFinishedNotification(
        success: true,
        body: 'Saved to $savedPath',
      );

      emit(
        state.copyWith(
          status: DownloadsStatus.downloaded,
          progress: 100,
          savedPath: savedPath,
          message: 'Download complete.\nSaved to: $savedPath',
        ),
      );
    } catch (error) {
      await _notifications.showDownloadFinishedNotification(
        success: false,
        body: error.toString(),
      );

      emit(
        state.copyWith(
          status: DownloadsStatus.failure,
          message: 'Download failed: $error',
        ),
      );
    }
  }
}
