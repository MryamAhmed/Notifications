import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/constants/api_parameter_constant.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/features/downloads/domain/entities/pdf_file_entity.dart';
import 'package:notifecation/features/downloads/domain/repositories/pdf_repository.dart';

@injectable
class LoadPdfPreviewUseCase {
  LoadPdfPreviewUseCase(this._repository);

  final PdfRepository _repository;

  Future<Either<AppError, PdfFileEntity>> call({
    String fileName = ApiParameterConstant.previewPdfFileName,
  }) {
    return _repository.fetchPreviewPdf(fileName: fileName);
  }
}
