import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/background/background_download_events.dart';
import 'package:notifecation/core/background/background_download_handler.dart';
import 'package:notifecation/core/constants/app_error_codes.dart';
import 'package:notifecation/core/error/app_error.dart';
import 'package:notifecation/core/notifications/notification_service.dart';

/// UI-isolate side of the Foreground Service download.
///
/// Responsibilities:
/// 1) configure flutter_background_service once at app start
/// 2) start the Android Foreground Service when user taps Download
/// 3) expose a typed event stream so Cubit/UI can show live progress
@lazySingleton
class BackgroundDownloadService {
  /// STEP A: Configure the plugin (call this from mainCommon before runApp).
  ///
  /// This does NOT start the service yet. It only registers:
  /// - the background entry point (`backgroundDownloadOnStart`)
  /// - foreground-mode defaults
  /// - the notification channel/id used by the FGS sticky notification
  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    // STEP A1: Channel must already exist before configure() on Android.
    // We create it in NotificationService.initialize() (called first in mainCommon).

    await service.configure(
      // Android: real Foreground Service with sticky notification.
      androidConfiguration: AndroidConfiguration(
        // Entry point that runs in the BACKGROUND isolate.
        onStart: backgroundDownloadOnStart,

        // We start manually when user presses Download.
        autoStart: false,

        // Do not restart this download service after device reboot.
        autoStartOnBoot: false,

        // true = startForeground(...) under the hood (FGS mode).
        isForegroundMode: true,

        // Must match NotificationService.downloadsChannel.id
        notificationChannelId: NotificationService.downloadsChannel.id,

        // Initial sticky notification text (before progress updates).
        initialNotificationTitle: 'Download Service',
        initialNotificationContent: 'Preparing download...',

        // Must match NotificationService.downloadNotificationId so progress
        // updates replace the same notification instead of creating another.
        foregroundServiceNotificationId:
            NotificationService.downloadNotificationId,

        // Android 14+: declare why this FGS is allowed to run.
        // dataSync = network transfer / file sync style work (our PDF download).
        foregroundServiceTypes: const [AndroidForegroundType.dataSync],
      ),

      // iOS support is limited for this spike; we still provide a config.
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: backgroundDownloadOnStart,
      ),
    );
  }

  /// STEP B: Start FGS (if needed) and send the download command.
  Future<Either<AppError, Unit>> startDownload({
    required String url,
    required String fileName,
  }) async {
    try {
      final service = FlutterBackgroundService();

      // 1) Start the native Foreground Service if it is not already running.
      final alreadyRunning = await service.isRunning();
      if (!alreadyRunning) {
        await service.startService();

        // Tiny delay so the background isolate can attach its `.on(...)` listeners
        // before we invoke startDownload.
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }

      // 2) Send command + payload to the background isolate.
      service.invoke(BackgroundDownloadEvents.startDownload, {
        'url': url,
        'fileName': fileName,
      });

      return right(unit);
    } catch (error) {
      return left(
        AppError.local(
          AppErrorCodes.foregroundServiceFailed,
          message: error.toString(),
        ),
      );
    }
  }

  /// STEP C: Typed stream of progress/complete/failed events from the service.
  Stream<BackgroundDownloadEvent> get events {
    final service = FlutterBackgroundService();

    // Merge the 3 plugin event streams into one typed stream for the Cubit.
    return Stream<BackgroundDownloadEvent>.multi((controller) {
      final subs = <StreamSubscription>[
        service.on(BackgroundDownloadEvents.progress).listen((event) {
          final progress = event?['progress'];
          if (progress is int) {
            controller.add(DownloadProgressEvent(progress));
          } else if (progress is num) {
            controller.add(DownloadProgressEvent(progress.round()));
          }
        }),
        service.on(BackgroundDownloadEvents.complete).listen((event) {
          final path = event?['path'] as String?;
          if (path != null) {
            controller.add(DownloadCompletedEvent(path));
          }
        }),
        service.on(BackgroundDownloadEvents.failed).listen((event) {
          final message = event?['message'] as String? ?? 'Download failed';
          controller.add(DownloadFailedEvent(message));
        }),
      ];

      controller.onCancel = () async {
        for (final sub in subs) {
          await sub.cancel();
        }
      };
    });
  }

  Future<void> stop() async {
    final service = FlutterBackgroundService();
    service.invoke(BackgroundDownloadEvents.stopService);
  }
}
