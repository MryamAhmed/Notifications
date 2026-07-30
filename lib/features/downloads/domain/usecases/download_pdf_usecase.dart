import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/constants/api_parameter_constant.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/core/notifications/notification_service.dart';
import 'package:notifecation/features/downloads/domain/entities/pdf_file_entity.dart';
import 'package:notifecation/features/downloads/domain/repositories/pdf_repository.dart';

@injectable
class DownloadPdfUseCase {
  DownloadPdfUseCase(
    this._repository,
    this._notificationService,
  );

  final PdfRepository _repository;
  final NotificationService _notificationService;

  Future<Either<AppError, PdfFileEntity>> call({
    String fileName = ApiParameterConstant.samplePdfFileName,
    required void Function(int progress) onProgress,
  }) async {
    await _notificationService.showDownloadNotification(
      title: 'Downloading PDF',
      body: 'Starting download...',
    );

    final result = await _repository.downloadPdf(
      fileName: fileName,
      onProgress: (progress) {
        onProgress(progress);
        _notificationService.updateDownloadNotification(
          progress: progress,
          title: 'Downloading PDF',
        );
      },
    );

    await result.match(
      (error) async {
        await _notificationService.showDownloadFinishedNotification(
          success: false,
          body: error.message,
        );
      },
      (file) async {
        await _notificationService.showDownloadFinishedNotification(
          success: true,
          body: 'Saved to ${file.path}',
        );
      },
    );

    return result;
  }
}
