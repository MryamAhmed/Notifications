import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/services/notification_service.dart';
import 'downloads_state.dart';

/// Manages Phase 1 notification demo UI state.
///
/// Permission is requested as soon as this Cubit is created (app open),
/// not from a button press.
class DownloadsCubit extends Cubit<DownloadsState> {
  DownloadsCubit({
    NotificationService? notificationService,
  })  : _notifications = notificationService ?? NotificationService.instance,
        super(const DownloadsState()) {
    // Ask for notification permission right when the feature starts.
    requestPermissionOnOpen();
  }

  final NotificationService _notifications;

  Future<void> requestPermissionOnOpen() async {
    final granted = await _notifications.requestNotificationPermission();

    emit(
      state.copyWith(
        permissionGranted: granted,
        status: granted
            ? 'Notification permission is available.'
            : 'Notification permission was denied.',
      ),
    );
  }

  Future<void> showNotification() async {
    await _notifications.showDownloadNotification();

    emit(
      state.copyWith(
        progress: 0,
        status: 'Initial download notification shown.',
      ),
    );
  }

  Future<void> updateNotificationProgress() async {
    final nextProgress = (state.progress + 25).clamp(0, 100);

    await _notifications.updateDownloadNotification(progress: nextProgress);

    emit(
      state.copyWith(
        progress: nextProgress,
        status: 'Download notification updated to $nextProgress%.',
      ),
    );
  }

  Future<void> cancelNotification() async {
    await _notifications.cancelDownloadNotification();

    emit(state.copyWith(status: 'Download notification cancelled.'));
  }
}
