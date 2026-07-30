import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:notifecation/core/error/app_error.dart';

part 'downloads_state.freezed.dart';

@freezed
abstract class DownloadsState with _$DownloadsState {
  const factory DownloadsState({
    @Default(false) bool isLoadingPreview,
    @Default(false) bool isDownloading,
    @Default(0) int progress,
    String? previewPath,
    String? savedPath,
    AppError? error,
    @Default(true) bool permissionGranted,
  }) = _DownloadsState;
}
