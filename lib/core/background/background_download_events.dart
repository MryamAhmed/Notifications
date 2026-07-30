/// Event names used to talk between:
/// - the UI isolate (Flutter app / Cubit)
/// - the background isolate (Foreground Service)
///
/// flutter_background_service uses string event names + Map payloads.
class BackgroundDownloadEvents {
  BackgroundDownloadEvents._();

  /// UI → background: asks whether the isolate has attached its listeners.
  static const String ping = 'downloadPing';

  /// background → UI: confirms that commands can now be received.
  static const String ready = 'downloadReady';

  /// UI → background: "please start downloading this file"
  static const String startDownload = 'startDownload';

  /// background → UI: progress percentage update
  static const String progress = 'progress';

  /// background → UI: download finished successfully
  static const String complete = 'complete';

  /// background → UI: download failed
  static const String failed = 'failed';

  /// UI → background: "what is happening right now?"
  ///
  /// The progress stream is a broadcast controller with no replay, so a UI that
  /// was recreated while the service kept running hears nothing until the next
  /// update — and nothing at all if the download already finished. This gives a
  /// newly built Cubit a starting point.
  static const String queryState = 'queryDownloadState';

  /// background → UI: one-shot answer to [queryState].
  static const String stateSnapshot = 'downloadStateSnapshot';

  /// UI → background: stop the service
  static const String stopService = 'stopService';
}

/// Point-in-time answer to [BackgroundDownloadEvents.queryState].
class DownloadStateSnapshot {
  const DownloadStateSnapshot({
    required this.isDownloading,
    required this.progress,
    this.savedPath,
    this.errorMessage,
  });

  final bool isDownloading;
  final int progress;
  final String? savedPath;
  final String? errorMessage;
}

/// Typed events the Cubit can listen to (cleaner than raw Maps).
sealed class BackgroundDownloadEvent {
  const BackgroundDownloadEvent();
}

class DownloadProgressEvent extends BackgroundDownloadEvent {
  const DownloadProgressEvent(this.progress);
  final int progress;
}

class DownloadCompletedEvent extends BackgroundDownloadEvent {
  const DownloadCompletedEvent(this.path);
  final String path;
}

class DownloadFailedEvent extends BackgroundDownloadEvent {
  const DownloadFailedEvent(this.message);
  final String message;
}
