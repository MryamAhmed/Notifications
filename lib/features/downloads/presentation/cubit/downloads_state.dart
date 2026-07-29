import 'package:equatable/equatable.dart';

class DownloadsState extends Equatable {
  const DownloadsState({
    this.progress = 0,
    this.status = 'Ready to test local notifications.',
    this.permissionGranted,
  });

  final int progress;
  final String status;

  /// null = still requesting, true/false = result from Android 13+ dialog.
  final bool? permissionGranted;

  DownloadsState copyWith({
    int? progress,
    String? status,
    bool? permissionGranted,
  }) {
    return DownloadsState(
      progress: progress ?? this.progress,
      status: status ?? this.status,
      permissionGranted: permissionGranted ?? this.permissionGranted,
    );
  }

  @override
  List<Object?> get props => [progress, status, permissionGranted];
}
