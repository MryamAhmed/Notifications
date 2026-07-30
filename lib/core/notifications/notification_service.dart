import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:injectable/injectable.dart';

/// Platform notification capability registered via DI.
@lazySingleton
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int downloadNotificationId = 1001;

  static const AndroidNotificationChannel downloadsChannel =
      AndroidNotificationChannel(
    'downloads',
    'Downloads',
    description: 'Shows download status and progress notifications.',
    importance: Importance.high,
  );

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    await _plugin.initialize(settings);
    await _createDownloadsChannel();
  }

  Future<void> _createDownloadsChannel() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(downloadsChannel);
  }

  Future<bool> requestNotificationPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? true;
  }

  Future<void> showDownloadNotification({
    String title = 'Download started',
    String body = 'Preparing your file...',
  }) async {
    await _plugin.show(
      downloadNotificationId,
      title,
      body,
      _notificationDetails(),
    );
  }

  Future<void> updateDownloadNotification({
    required int progress,
    String title = 'Downloading file',
  }) async {
    final safeProgress = progress.clamp(0, 100);
    await _plugin.show(
      downloadNotificationId,
      title,
      '$safeProgress% complete',
      _notificationDetails(
        progress: safeProgress,
        ongoing: safeProgress < 100,
      ),
    );
  }

  Future<void> showDownloadFinishedNotification({
    required bool success,
    String? body,
  }) async {
    await _plugin.show(
      downloadNotificationId,
      success ? 'Download complete' : 'Download failed',
      body ??
          (success
              ? 'Your PDF was saved successfully.'
              : 'Something went wrong while downloading.'),
      _notificationDetails(ongoing: false),
    );
  }

  Future<void> cancelDownloadNotification() async {
    await _plugin.cancel(downloadNotificationId);
  }

  NotificationDetails _notificationDetails({
    int? progress,
    bool ongoing = false,
  }) {
    final androidDetails = AndroidNotificationDetails(
      downloadsChannel.id,
      downloadsChannel.name,
      channelDescription: downloadsChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      onlyAlertOnce: true,
      showProgress: progress != null,
      maxProgress: 100,
      progress: progress ?? 0,
      ongoing: ongoing,
    );

    return NotificationDetails(android: androidDetails);
  }
}
