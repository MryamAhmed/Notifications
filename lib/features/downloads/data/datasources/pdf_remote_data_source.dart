import 'package:fpdart/fpdart.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/features/downloads/data/models/pdf_file_response.dart';

abstract class PdfRemoteDataSource {
  Future<Either<AppError, PdfFileResponse>> fetchPreviewPdf({
    required String fileName,
  });

  Future<Either<AppError, PdfFileResponse>> downloadPdf({
    required String fileName,
    required void Function(int progress) onProgress,
  });
}
