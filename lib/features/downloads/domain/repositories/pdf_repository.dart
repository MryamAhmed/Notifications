import 'package:fpdart/fpdart.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/features/downloads/domain/entities/pdf_file_entity.dart';

abstract class PdfRepository {
  Future<Either<AppError, PdfFileEntity>> fetchPreviewPdf({
    required String fileName,
  });

  Future<Either<AppError, PdfFileEntity>> downloadPdf({
    required String fileName,
    required void Function(int progress) onProgress,
  });
}
