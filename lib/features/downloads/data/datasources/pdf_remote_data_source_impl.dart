import 'dart:io';

import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'package:notifecation/core/constants/app_endpoints.dart';
import 'package:notifecation/core/constants/app_error_codes.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/core/network/api_call_helpers.dart';
import 'package:notifecation/core/network/dio_client_service.dart';
import 'package:notifecation/features/downloads/data/datasources/pdf_remote_data_source.dart';
import 'package:notifecation/features/downloads/data/models/pdf_file_response.dart';

@LazySingleton(as: PdfRemoteDataSource)
class PdfRemoteDataSourceImpl implements PdfRemoteDataSource {
  PdfRemoteDataSourceImpl(this._client);

  final DioClientService _client;

  @override
  Future<Either<AppError, PdfFileResponse>> fetchPreviewPdf({
    required String fileName,
  }) {
    return callDownload<PdfFileResponse>(
      failureCode: AppErrorCodes.pdfPreviewFailed,
      request: () async {
        final cacheDir = await getTemporaryDirectory();
        final savePath = p.join(cacheDir.path, fileName);
        await _client.dio.download(AppEndpoints.samplePdf, savePath);
        return PdfFileResponse(path: savePath, fileName: fileName);
      },
    );
  }

  @override
  Future<Either<AppError, PdfFileResponse>> downloadPdf({
    required String fileName,
    required void Function(int progress) onProgress,
  }) {
    return callDownload<PdfFileResponse>(
      failureCode: AppErrorCodes.pdfDownloadFailed,
      request: () async {
        final docsDir = await getApplicationDocumentsDirectory();
        final downloadsDir = Directory(p.join(docsDir.path, 'downloads'));
        if (!await downloadsDir.exists()) {
          await downloadsDir.create(recursive: true);
        }

        final savePath = p.join(downloadsDir.path, fileName);
        await _client.dio.download(
          AppEndpoints.samplePdf,
          savePath,
          onReceiveProgress: (received, total) {
            if (total <= 0) return;
            final progress = ((received / total) * 100).round().clamp(0, 100);
            onProgress(progress);
          },
        );
        onProgress(100);
        return PdfFileResponse(path: savePath, fileName: fileName);
      },
    );
  }
}
