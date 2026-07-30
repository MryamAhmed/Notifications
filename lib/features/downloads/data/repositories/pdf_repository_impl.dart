import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/repositories/pdf_repository.dart';

class PdfRepositoryImpl implements PdfRepository {
  PdfRepositoryImpl({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<String> fetchPreviewPdf({
    required String url,
    required String fileName,
  }) async {
    final cacheDir = await getTemporaryDirectory();
    final savePath = p.join(cacheDir.path, fileName);
    await _dio.download(url, savePath);
    return savePath;
  }

  @override
  Future<String> downloadPdf({
    required String url,
    required String fileName,
    required void Function(int progress) onProgress,
  }) async {
    final docsDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(p.join(docsDir.path, 'downloads'));
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final savePath = p.join(downloadsDir.path, fileName);

    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total <= 0) return;
        final progress = ((received / total) * 100).round().clamp(0, 100);
        onProgress(progress);
      },
    );

    onProgress(100);
    return savePath;
  }
}
