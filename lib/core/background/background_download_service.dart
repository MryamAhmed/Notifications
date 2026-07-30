import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';
import 'package:notifecation/core/background/background_download_events.dart';
import 'package:notifecation/core/background/background_download_handler.dart';
import 'package:notifecation/core/background/download_trace.dart';
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

        // Dedicated id for the native FGS notification. It intentionally
        // differs from the final local-notification id (see NotificationService).
        foregroundServiceNotificationId:
            NotificationService.foregroundServiceNotificationId,

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

      // 1) Start the native Foreground Service unconditionally.
      //
      // isRunning() walks ActivityManager.getRunningServices(), which tracks the
      // Android Service lifecycle, not the Flutter engine lifecycle. Right after
      // stopSelf() the service is still listed while onDestroy has already
      // nulled its method channel, so gating on it meant skipping the start and
      // then pinging a dead engine until the handshake timed out.
      //
      // Starting again is safe: onStartCommand -> runService() early-returns
      // while the engine is alive, and it revives a half-destroyed service.
      if (!await service.startService()) {
        return left(
          AppError.local(
            AppErrorCodes.foregroundServiceFailed,
            message: 'Android could not start the Foreground Service.',
          ),
        );
      }

      // 2) Wait for a real ready acknowledgement.
      //
      // A fixed delay is a race: slower devices may need more time to create
      // the Flutter engine and attach the background isolate listeners.
      try {
        await _waitUntilBackgroundIsolateIsReady(service);
      } on TimeoutException {
        // An engine that was tearing down during the first attempt is gone by
        // now, so a second start creates a fresh one.
        if (!await service.startService()) rethrow;
        await _waitUntilBackgroundIsolateIsReady(service);
      }

      // 3) Only send the command after the isolate confirms it is listening.
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

  /// STEP B2: One-shot snapshot of what the service is doing right now.
  ///
  /// Returns null when nothing is running, or when the isolate does not answer
  /// in time — in both cases the UI simply keeps its default state.
  Future<DownloadStateSnapshot?> currentState() async {
    final service = FlutterBackgroundService();

    // STEP 3: the query begins.
    fgsTrace('UI', 'STEP 3 currentState() called');

    // A false positive here only costs the timeout below, so the stale-value
    // problem that made this check wrong in startDownload does not apply.
    final running = await service.isRunning();
    fgsTrace('UI', 'STEP 3a isRunning()', running);
    if (!running) {
      // A false here while the notification is still counting up means the
      // query never even got a chance to be sent.
      fgsTrace('UI', 'STEP 3b ABORT - service reported not running');
      return null;
    }

    final completer = Completer<DownloadStateSnapshot?>();
    late final StreamSubscription<Map<String, dynamic>?> subscription;

    subscription =
        service.on(BackgroundDownloadEvents.stateSnapshot).listen((event) {
      // STEP 6: the reply came back across the pipe.
      fgsTrace('UI', 'STEP 6 stateSnapshot received', event);
      if (completer.isCompleted || event == null) return;
      try {
        completer.complete(
          DownloadStateSnapshot(
            isDownloading: event['isDownloading'] as bool? ?? false,
            progress: (event['progress'] as num?)?.toInt() ?? 0,
            savedPath: event['path'] as String?,
            errorMessage: event['message'] as String?,
          ),
        );
      } catch (error) {
        // A cast failure here would otherwise be swallowed by the stream and
        // look identical to "no reply arrived".
        fgsTrace('UI', 'STEP 6a PARSE FAILED', error);
        completer.complete(null);
      }
    });

    fgsTrace('UI', 'STEP 3c sending queryState');
    service.invoke(BackgroundDownloadEvents.queryState);

    try {
      final snapshot = await completer.future.timeout(
        const Duration(seconds: 2),
        onTimeout: () {
          fgsTrace('UI', 'STEP 3d TIMEOUT - no stateSnapshot within 2s');
          return null;
        },
      );
      return snapshot;
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _waitUntilBackgroundIsolateIsReady(
    FlutterBackgroundService service,
  ) async {
    final completer = Completer<void>();

    late final StreamSubscription<Map<String, dynamic>?> readySubscription;
    Timer? pingTimer;

    readySubscription =
        service.on(BackgroundDownloadEvents.ready).listen((event) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });

    // Ping immediately and repeatedly. This also works when the service was
    // already running and its one-time startup "ready" event was missed.
    void ping() => service.invoke(BackgroundDownloadEvents.ping);
    ping();
    pingTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) => ping());

    try {
      await completer.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw TimeoutException(
          'Foreground Service isolate did not become ready.',
        ),
      );
    } finally {
      pingTimer.cancel();
      await readySubscription.cancel();
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
