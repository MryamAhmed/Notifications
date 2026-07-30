import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/background/background_download_events.dart';
import 'package:notifecation/core/background/background_download_service.dart';
import 'package:notifecation/core/constants/api_parameter_constant.dart';
import 'package:notifecation/core/constants/app_endpoints.dart';
import 'package:notifecation/core/error/app_error.dart';

/// STEP (domain): Start a PDF download inside the Android Foreground Service.
///
/// Why a use case?
/// PR guidelines say Cubits inject use cases only — not repositories/services
/// directly for feature actions. This use case is the Cubit's entry point.
@injectable
class DownloadPdfUseCase {
  DownloadPdfUseCase(this._backgroundDownloadService);

  final BackgroundDownloadService _backgroundDownloadService;

  Future<Either<AppError, Unit>> call({
    String fileName = ApiParameterConstant.samplePdfFileName,
  }) {
    // Hand off to the UI-isolate wrapper, which starts FGS + invoke(startDownload).
    return _backgroundDownloadService.startDownload(
      url: AppEndpoints.samplePdf,
      fileName: fileName,
    );
  }
}

/// STEP (domain): Observe progress/complete/failed events from the FGS isolate.
@injectable
class ObserveForegroundDownloadUseCase {
  ObserveForegroundDownloadUseCase(this._backgroundDownloadService);

  final BackgroundDownloadService _backgroundDownloadService;

  Stream<BackgroundDownloadEvent> call() => _backgroundDownloadService.events;
}
