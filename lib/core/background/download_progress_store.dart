import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:injectable/injectable.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Lifecycle of a download as seen from outside the worker isolate.
enum DownloadTaskStatus {
  /// Nothing has ever been scheduled, or the last result was consumed.
  idle,

  /// Handed to WorkManager, but Android has not started the worker yet.
  ///
  /// This state has no equivalent in the Foreground Service version, where
  /// work began the moment the service started. Here it can last anywhere
  /// from milliseconds to minutes depending on Doze and the standby bucket.
  enqueued,

  /// The worker isolate is alive and bytes are moving.
  running,
  success,
  failed,
}

/// A point-in-time view of the download, safe to move across isolates.
class DownloadProgressSnapshot {
  const DownloadProgressSnapshot({
    required this.status,
    this.progress = 0,
    this.filePath,
    this.errorMessage,
  });

  const DownloadProgressSnapshot.idle() : this(status: DownloadTaskStatus.idle);

  final DownloadTaskStatus status;
  final int progress;
  final String? filePath;
  final String? errorMessage;

  bool get isActive =>
      status == DownloadTaskStatus.enqueued ||
      status == DownloadTaskStatus.running;

  bool get isFinished =>
      status == DownloadTaskStatus.success ||
      status == DownloadTaskStatus.failed;

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'progress': progress,
        'filePath': filePath,
        'errorMessage': errorMessage,
      };

  factory DownloadProgressSnapshot.fromJson(Map<String, dynamic> json) {
    return DownloadProgressSnapshot(
      status: DownloadTaskStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => DownloadTaskStatus.idle,
      ),
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      filePath: json['filePath'] as String?,
      errorMessage: json['errorMessage'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DownloadProgressSnapshot &&
      other.status == status &&
      other.progress == progress &&
      other.filePath == filePath &&
      other.errorMessage == errorMessage;

  @override
  int get hashCode => Object.hash(status, progress, filePath, errorMessage);
}

/// The only channel between the WorkManager worker isolate and the UI isolate.
///
/// A [ListenableWorker] started by WorkManager runs in a fresh FlutterEngine
/// with no port, no `SendPort`, and no plugin equivalent of the
/// `setProgressAsync` / `getWorkInfoByIdLiveData` pair that native Android
/// offers. The two isolates therefore share nothing but the filesystem.
///
/// Writing through a temp file and renaming keeps reads atomic: `rename` on the
/// same filesystem either fully succeeds or does not happen, so a UI poll can
/// never observe a partially serialised snapshot.
@lazySingleton
class DownloadProgressStore {
  static const String _fileName = 'download_progress.json';

  Future<File> _snapshotFile() async {
    final docsDir = await getApplicationDocumentsDirectory();
    return File(p.join(docsDir.path, _fileName));
  }

  Future<void> write(DownloadProgressSnapshot snapshot) async {
    try {
      final target = await _snapshotFile();
      final temp = File('${target.path}.tmp');
      await temp.writeAsString(jsonEncode(snapshot.toJson()), flush: true);
      await temp.rename(target.path);
    } catch (_) {
      // Losing one progress sample must never abort the download itself.
    }
  }

  Future<DownloadProgressSnapshot> read() async {
    try {
      final file = await _snapshotFile();
      if (!await file.exists()) return const DownloadProgressSnapshot.idle();

      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return const DownloadProgressSnapshot.idle();
      }
      return DownloadProgressSnapshot.fromJson(decoded);
    } catch (_) {
      return const DownloadProgressSnapshot.idle();
    }
  }

  Future<void> clear() async {
    try {
      final file = await _snapshotFile();
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  /// Polls [read] and emits only when the snapshot actually changes.
  ///
  /// Polling is the cost of having no push channel. 500 ms matches the
  /// notification throttle in the worker, so the UI and the notification stay
  /// roughly in step without either doing redundant work.
  Stream<DownloadProgressSnapshot> watch({
    Duration interval = const Duration(milliseconds: 500),
  }) async* {
    DownloadProgressSnapshot? previous;

    while (true) {
      final current = await read();
      if (current != previous) {
        previous = current;
        yield current;
      }
      await Future<void>.delayed(interval);
    }
  }
}
