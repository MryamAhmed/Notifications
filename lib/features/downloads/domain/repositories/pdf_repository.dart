/// Contract for loading and saving PDF files.
///
/// Lives in domain so the Cubit depends on an abstraction, not Dio.
abstract class PdfRepository {
  /// Downloads the remote PDF into a local preview/cache file.
  Future<String> fetchPreviewPdf({
    required String url,
    required String fileName,
  });

  /// Downloads the remote PDF into app documents and reports progress 0–100.
  Future<String> downloadPdf({
    required String url,
    required String fileName,
    required void Function(int progress) onProgress,
  });
}
