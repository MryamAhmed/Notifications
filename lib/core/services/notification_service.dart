import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// App-wide notification helper.
///
/// In clean architecture terms this belongs in `core` because notifications are
/// a platform capability that multiple features can reuse.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const int downloadNotificationId = 1001;

  /// Android notification channels group notifications by behavior.
  ///
  /// Android 8+ requires every notification to be posted through a channel.
  static const AndroidNotificationChannel downloadsChannel =
      AndroidNotificationChannel(
    'downloads',
    'Downloads',
    description: 'Shows download status and progress notifications.',
    importance: Importance.high,
  );

  /// Initializes the local notifications plugin before the app starts.
  Future<void> initialize() async {
    // Android needs a small icon resource for notifications.
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    // iOS/macOS settings are included so the service stays platform-friendly.
    const darwinSettings = DarwinInitializationSettings();

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    // v19 uses a positional InitializationSettings argument.
    await _plugin.initialize(settings);

    // Create the Downloads channel once. Android keeps this channel after that.
    await _createDownloadsChannel();
  }

  Future<void> _createDownloadsChannel() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.createNotificationChannel(downloadsChannel);
  }

  /// Requests notification permission on Android 13+.
  ///
  /// Older Android versions grant notification permission at install time, so
  /// the plugin returns null there. We treat null as allowed for this spike.
  Future<bool> requestNotificationPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    final granted = await androidPlugin?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Shows the initial Downloads notification.
  Future<void> showDownloadNotification({
    String title = 'Download started',
    String body = 'Preparing your file...',
  }) async {
    // v19 show(...) uses positional args: id, title, body, details.
    await _plugin.show(
      downloadNotificationId,
      title,
      body,
      _notificationDetails(),
    );
  }

  /// Updates the same notification by reusing the same notification id.
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

  /// Shows a final success/failure notification for the download.
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

  /// Cancels the Downloads notification shown by this spike.
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
