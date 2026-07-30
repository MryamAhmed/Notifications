import 'package:notifecation/features/downloads/domain/entities/pdf_file_entity.dart';

class PdfFileResponse {
  const PdfFileResponse({
    required this.path,
    required this.fileName,
  });

  final String path;
  final String fileName;

  factory PdfFileResponse.fromJson(Map<String, dynamic> json) {
    return PdfFileResponse(
      path: json['path'] as String? ?? '',
      fileName: json['fileName'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'fileName': fileName,
      };

  PdfFileEntity toDomain() => PdfFileEntity(
        path: path,
        fileName: fileName,
      );
}
