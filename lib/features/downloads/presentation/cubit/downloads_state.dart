import 'package:equatable/equatable.dart';

enum DownloadsStatus {
  initial,
  loadingPreview,
  previewReady,
  downloading,
  downloaded,
  failure,
}

class DownloadsState extends Equatable {
  const DownloadsState({
    this.status = DownloadsStatus.initial,
    this.progress = 0,
    this.message = 'Opening downloads...',
    this.permissionGranted,
    this.previewPath,
    this.savedPath,
  });

  final DownloadsStatus status;
  final int progress;
  final String message;
  final bool? permissionGranted;
  final String? previewPath;
  final String? savedPath;

  bool get isDownloading => status == DownloadsStatus.downloading;
  bool get canDownload =>
      status == DownloadsStatus.previewReady ||
      status == DownloadsStatus.downloaded ||
      status == DownloadsStatus.failure;

  DownloadsState copyWith({
    DownloadsStatus? status,
    int? progress,
    String? message,
    bool? permissionGranted,
    String? previewPath,
    String? savedPath,
  }) {
    return DownloadsState(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      permissionGranted: permissionGranted ?? this.permissionGranted,
      previewPath: previewPath ?? this.previewPath,
      savedPath: savedPath ?? this.savedPath,
    );
  }

  @override
  List<Object?> get props => [
        status,
        progress,
        message,
        permissionGranted,
        previewPath,
        savedPath,
      ];
}
