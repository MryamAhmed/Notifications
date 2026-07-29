import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const AndroidNotificationChannel progressChannel = AndroidNotificationChannel(
  'progress_notifications',
  'Progress notifications',
  description: 'Shows local notification progress for the background spike.',
  importance: Importance.high,
);

const int progressNotificationId = 1001;

final FlutterLocalNotificationsPlugin localNotifications =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeNotifications();
  runApp(const MyApp());
}

Future<void> _initializeNotifications() async {
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    iOS: DarwinInitializationSettings(),
    macOS: DarwinInitializationSettings(),
  );

  await localNotifications.initialize(settings: initializationSettings);

  final androidPlugin =
      localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.createNotificationChannel(progressChannel);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Spike',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const NotificationSpikePage(),
    );
  }
}

class NotificationSpikePage extends StatefulWidget {
  const NotificationSpikePage({super.key});

  @override
  State<NotificationSpikePage> createState() => _NotificationSpikePageState();
}

class _NotificationSpikePageState extends State<NotificationSpikePage> {
  Timer? _progressTimer;
  int _progress = 0;
  String _status = 'Create a notification channel and request permission.';

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _requestPermission() async {
    final androidPlugin =
        localNotifications.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    final iosPlugin = localNotifications.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final macOsPlugin =
        localNotifications.resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>();

    final androidGranted =
        await androidPlugin?.requestNotificationsPermission();
    final iosGranted = await iosPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );
    final macOsGranted = await macOsPlugin?.requestPermissions(
      alert: true,
      badge: true,
      sound: true,
    );

    setState(() {
      final granted = androidGranted ?? iosGranted ?? macOsGranted;
      _status = granted == false
          ? 'Notification permission was denied.'
          : 'Notification permission is ready.';
    });
  }

  Future<void> _showNotification() async {
    await localNotifications.show(
      id: progressNotificationId,
      title: 'Local notification ready',
      body: 'This notification uses the "${progressChannel.name}" channel.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          progressChannel.id,
          progressChannel.name,
          channelDescription: progressChannel.description,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
    );

    setState(() {
      _status = 'Displayed a local notification.';
    });
  }

  Future<void> _showProgressNotification(int progress) async {
    await localNotifications.show(
      id: progressNotificationId,
      title: 'Download progress',
      body: progress >= 100 ? 'Download complete.' : 'Downloaded $progress%',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          progressChannel.id,
          progressChannel.name,
          channelDescription: progressChannel.description,
          importance: Importance.high,
          priority: Priority.high,
          onlyAlertOnce: true,
          showProgress: progress < 100,
          maxProgress: 100,
          progress: progress,
          ongoing: progress < 100,
        ),
        iOS: const DarwinNotificationDetails(),
        macOS: const DarwinNotificationDetails(),
      ),
    );
  }

  void _startProgressDemo() {
    _progressTimer?.cancel();
    _progress = 0;

    _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      _progress += 20;
      if (_progress >= 100) {
        _progress = 100;
        timer.cancel();
      }

      await _showProgressNotification(_progress);

      if (mounted) {
        setState(() {
          _status = _progress >= 100
              ? 'Updated notification to completion.'
              : 'Updated notification progress to $_progress%.';
        });
      }
    });
  }

  Future<void> _cancelNotification() async {
    _progressTimer?.cancel();
    await localNotifications.cancel(id: progressNotificationId);

    setState(() {
      _progress = 0;
      _status = 'Notification cancelled.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Notification Spike'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Phase 1: Local Notifications',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              'Channel: ${progressChannel.id}\n'
              'Notification ID: $progressNotificationId',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _requestPermission,
              icon: const Icon(Icons.verified_user_outlined),
              label: const Text('Request notification permission'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _showNotification,
              icon: const Icon(Icons.notifications_outlined),
              label: const Text('Show notification'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _startProgressDemo,
              icon: const Icon(Icons.update),
              label: const Text('Update notification with progress'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _cancelNotification,
              icon: const Icon(Icons.clear),
              label: const Text('Cancel notification'),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
