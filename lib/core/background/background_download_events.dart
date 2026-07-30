/// Event names used to talk between:
/// - the UI isolate (Flutter app / Cubit)
/// - the background isolate (Foreground Service)
///
/// flutter_background_service uses string event names + Map payloads.
class BackgroundDownloadEvents {
  BackgroundDownloadEvents._();

  /// UI → background: "please start downloading this file"
  static const String startDownload = 'startDownload';

  /// background → UI: progress percentage update
  static const String progress = 'progress';

  /// background → UI: download finished successfully
  static const String complete = 'complete';

  /// background → UI: download failed
  static const String failed = 'failed';

  /// UI → background: stop the service
  static const String stopService = 'stopService';
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
