import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/features/downloads/data/datasources/pdf_remote_data_source.dart';
import 'package:notifecation/features/downloads/domain/entities/pdf_file_entity.dart';
import 'package:notifecation/features/downloads/domain/repositories/pdf_repository.dart';

@LazySingleton(as: PdfRepository)
class PdfRepositoryImpl implements PdfRepository {
  PdfRepositoryImpl(this._remoteDataSource);

  final PdfRemoteDataSource _remoteDataSource;

  @override
  Future<Either<AppError, PdfFileEntity>> fetchPreviewPdf({
    required String fileName,
  }) async {
    final result = await _remoteDataSource.fetchPreviewPdf(fileName: fileName);
    return result.map((response) => response.toDomain());
  }

  @override
  Future<Either<AppError, PdfFileEntity>> downloadPdf({
    required String fileName,
    required void Function(int progress) onProgress,
  }) async {
    final result = await _remoteDataSource.downloadPdf(
      fileName: fileName,
      onProgress: onProgress,
    );
    return result.map((response) => response.toDomain());
  }
}
