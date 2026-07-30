# Notification Background Service Spike

This Flutter sample is the first slice of the background-service spike. The
current implementation focuses on local notifications only.

## Phase 1: Local Notifications

Completed in this project:

- Created a Flutter project.
- Added `flutter_local_notifications`.
- Created an Android notification channel named `progress_notifications`.
- Added Android 13+ `POST_NOTIFICATIONS` permission to the manifest.
- Requested notification permission from the app.
- Displayed a local notification.
- Updated the same notification ID with progress so Android treats it as one
  live notification instead of many separate notifications.

Run it with:

```bash
.\.fvm\flutter_sdk\bin\flutter run
```

Tap the buttons in order:

1. Request notification permission.
2. Show notification.
3. Update notification with progress.
4. Cancel notification.

## Notification Channels And Permissions

Android 8+ requires notification channels. A channel groups notifications and
lets the user control importance, sound, vibration, and visibility from system
settings. After a channel is created, Android does not let the app freely change
some channel settings, so choose channel IDs and importance carefully.

Android 13+ also requires the runtime `POST_NOTIFICATIONS` permission. The app
declares it in `android/app/src/main/AndroidManifest.xml` and requests it from
Flutter before showing notifications.

## Phase 5: WorkManager (branch `workmanger`)

This branch re-implements the exact same download spike on top of Android's
`WorkManager` so the two approaches can be compared directly. It is a learning
branch: the Foreground Service implementation still lives on its own branch and
is not replaced.

### How Android reaches Dart

1. `Workmanager().initialize(callbackDispatcher)` resolves the top-level
   `callbackDispatcher` to a raw callback handle and persists that integer
   natively. Nothing is scheduled and no isolate is spawned.
2. `registerOneOffTask(...)` writes a `OneTimeWorkRequest` into WorkManager's
   own Room database (`androidx.work.workdb`) — on disk, outside the process.
3. When constraints are satisfied, WorkManager (through `JobScheduler`) starts
   the app process if needed and runs the plugin's `BackgroundWorker`.
4. That worker reads the stored handle, creates a **new headless
   `FlutterEngine`** with no Activity, and invokes `callbackDispatcher` in a
   fresh isolate.
5. The `bool` returned from `executeTask` becomes `Result.success()` (`true`) or
   `Result.retry()` (`false`).

Because the job description lives in a system-managed database rather than in
app memory, durability across process death and reboot is free. That is the
entire trade being made.

### Architecture map

| Concern | Foreground Service branch | WorkManager branch |
| --- | --- | --- |
| Background entry point | `background_download_handler.dart` | `download_task_handler.dart` |
| UI-side wrapper | `background_download_service.dart` | `download_task_scheduler.dart` |
| Worker to UI channel | `background_download_events.dart` (plugin pipe) | `download_progress_store.dart` (file polling) |
| Notifications | `NotificationService` | `NotificationService` (unchanged, reused as-is) |
| Manifest | `<service>` + 3 FGS permissions | nothing; `androidx.work` merges its own |

### Behaviour comparison

| | Foreground Service | WorkManager |
| --- | --- | --- |
| Starts | Immediately on tap | When the scheduler allows (Doze, standby bucket, constraints) |
| Runtime limit | Until finished; Android 15 caps `dataSync` at 6h/24h | ~10 min, then `onStopped()` |
| Survives reboot | No | Yes, re-enqueued from disk |
| Survives process kill | Only via a watchdog + hand-rolled JSON resume | Yes, natively |
| Live progress to UI | Yes, bidirectional pipe | **No channel exists**; must go through disk |
| Retry and backoff | Hand-rolled | Built in (`BackoffPolicy`) |
| Notification | Owned and protected by the service | Ordinary notification, unprotected |
| Network constraint | Manual | Declarative (`Constraints`) |
| User-visible guarantee | Strong | Weak |

### What disappeared from the code

Removing the Foreground Service deleted an entire class of problems, all of
which were bugs actually hit during the FGS phase:

- The ready handshake, the 250 ms ping loop, and its 10-second timeout.
- The `service.isRunning()` race, where `ActivityManager.getRunningServices()`
  reported a service as alive while its Flutter engine was already dead.
- `pending_download.json` and the manual resume-after-kill logic, replaced by
  WorkManager's own persistence.
- The `queryState` / `stateSnapshot` request-response handshake used to restore
  the UI. Because progress now lives in a file, a recreated Cubit just reads it.
- Two notification IDs. Only one is needed now that no service teardown can
  remove the result notification.

### What it costs

- **No push channel to the UI.** Native Android has `setProgressAsync` paired
  with `getWorkInfoByIdLiveData`; the Flutter plugin exposes neither. The UI
  polls `download_progress.json` every 500 ms instead. Writes go through a temp
  file plus `rename` so a poll can never read a half-written snapshot.
- **No foreground promotion.** `workmanager_android 0.9.0+2` contains no
  `setForegroundAsync` and no `ForegroundInfo`, so the worker can never become a
  foreground service. This is the single biggest limitation.
- **Expedited work is API 31+ in practice.** `setExpedited` is supported, but on
  API 30 and below WorkManager runs expedited work as a foreground service and
  requires `getForegroundInfo()`, which the plugin does not implement. The
  `expedited` flag on `enqueueDownload` is therefore off by default.
- **A visible queued state.** The UI shows "Queued. Waiting for Android to start
  the work..." between the tap and the first byte. That gap has no equivalent in
  the FGS branch and is the most instructive thing to observe when testing.

### Verdict

For this spike's requirement — a user-initiated download with live progress —
the Foreground Service is the correct choice, and WorkManager is the wrong tool
used well. This matches Google's own split:

- **WorkManager**: deferrable work that must eventually happen. Sync, cleanup,
  retrying uploads, periodic refresh.
- **Foreground Service**: user-visible work that must happen *now* and keep
  running. Downloads with progress, location tracking, media playback.
- **`DownloadManager`**: plain file downloads with no custom logic, where the
  system handles notification and retry for you.

The honest hybrid, if this were production: start a foreground service for the
active download, and use WorkManager purely as a durable retry net for work
interrupted by process death or reboot.

### Running this branch

```bash
.\.fvm\flutter_sdk\bin\flutter run
```

Things worth observing:

1. Tap Download and watch for the "Queued" state before progress starts.
2. Swipe the app away mid-download; the notification keeps updating.
3. Reopen the app; the UI restores from the snapshot file with no handshake.
4. Turn off Wi-Fi before tapping. The work stays queued and only starts once the
   `NetworkType.connected` constraint is satisfied.
5. Reboot mid-download to see WorkManager re-enqueue the job by itself.
