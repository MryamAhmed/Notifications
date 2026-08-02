# Spike Report: Background Downloads and Progress Notifications

## Executive summary

This spike evaluates two Flutter/Android approaches for downloading a file while
the app UI is closed:

1. Android Foreground Service using `flutter_background_service`
2. Android WorkManager using `workmanager`

Both implementations run download code in a separate Dart isolate, save the
file to app-specific storage, and update a local notification with live
progress.

The Foreground Service is the recommended approach for this use case. A
user-initiated download is immediate, long-running, and visible to the user.
WorkManager is better suited to deferrable work that Android may execute later,
such as synchronization, cleanup, and retry jobs.

The Foreground Service implementation met the core acceptance criteria on the
tested physical Android device when the app was backgrounded and removed from
Recents.

## Scope

- Configure local notification channels.
- Request Android 13+ notification permission.
- Open the app when a notification is tapped.
- Run Dart code from a background isolate.
- Download a real file with Dio.
- Show live progress in an Android notification.
- Show completion and failure notifications.
- Compare WorkManager with an Android Foreground Service.
- Test behavior with the app backgrounded, removed from Recents, in Doze, and
  under battery optimization.

The spike was timeboxed to 3–4 days.

## Repository branches

- `dev`: Foreground Service implementation
- `workmanger`: WorkManager implementation

There is currently no branch named `forgroundservice`; the completed Foreground
Service implementation is on `dev`.

## Architecture

The project follows this high-level flow:

```text
Downloads screen
    ↓
DownloadsCubit
    ↓
Download use cases
    ↓
Background execution wrapper
    ↓
Background Dart isolate
    ├── Dio download
    ├── File persistence
    └── Local notification updates
```

The UI isolate and background isolate do not share memory. `BuildContext`,
widgets, Cubits, and UI navigation are unavailable inside the worker.
Communication therefore uses plugin messages or persisted files.

Every background entry point:

- Is a top-level function.
- Is marked with `@pragma('vm:entry-point')`.
- Calls `DartPluginRegistrant.ensureInitialized()`.
- Creates its own Dio and notification objects instead of using UI-isolate
  dependency injection instances.

## Notification implementation

The app uses `flutter_local_notifications`.

### Notification channel

The `downloads` channel is created before starting background work. A Dart
`AndroidNotificationChannel` only describes the channel;
`createNotificationChannel()` creates it in Android.

### Runtime permission

Android 13+ requires `POST_NOTIFICATIONS` in the manifest and runtime permission
from the user.

### Progress updates

Dio reports the received and total byte counts. The percentage is calculated
and posted using:

```dart
showProgress: true,
maxProgress: 100,
progress: currentProgress,
ongoing: true,
onlyAlertOnce: true,
```

The same notification ID is reused so Android updates one notification instead
of creating a new notification for every percentage.

Updates are serialized and limited to approximately one update every 500 ms.
This avoids out-of-order percentages and Android
`NotificationManagerService` rate limiting.

The endpoint must expose a valid content length to calculate a percentage.
Otherwise, an indeterminate progress indicator is required.

## Foreground Service implementation

Package: `flutter_background_service`

### Execution flow

1. The user taps Download.
2. The UI starts an Android Foreground Service.
3. A background Flutter engine and Dart isolate are created.
4. A ping/ready handshake confirms that the isolate is listening.
5. The UI sends the URL and filename to the isolate.
6. Dio downloads the file in the background.
7. The isolate updates the ongoing notification and sends progress events to
   the UI when it is available.
8. A separate completion or failure notification is displayed.
9. The Foreground Service stops after the work finishes.

### Android configuration

The manifest declares:

- `INTERNET`
- `POST_NOTIFICATIONS`
- `FOREGROUND_SERVICE`
- `FOREGROUND_SERVICE_DATA_SYNC`
- `WAKE_LOCK`

The service is declared with:

```xml
android:foregroundServiceType="dataSync"
android:exported="false"
android:stopWithTask="false"
```

The matching `dataSync` service type is also supplied to
`flutter_background_service`. This handles the typed Foreground Service
requirement on Android 14+.

### Process recovery

The active job is written to `pending_download.json` before network work starts.
If the process is killed and the service is recreated, the new isolate can read
the job and restart it.

Recovery is limited to three attempts to avoid an endless restart loop.

This is job recovery, not byte-level resume. The current test endpoint does not
support HTTP range requests, so an interrupted download restarts from 0%.

### UI restoration

When the app is reopened, a new Cubit subscribes to service events and requests
a state snapshot. This restores the current progress without depending on the
old UI process.

## WorkManager implementation

Package: `workmanager`

### Execution flow

1. The callback dispatcher is registered at app startup.
2. The user request is stored in WorkManager's persistent database.
3. Android starts the worker when constraints and system policy allow.
4. The plugin creates a headless Flutter engine and background isolate.
5. The isolate downloads the file and updates the notification.
6. The worker returns success or retry.

Enqueue success means that Android recorded the request. It does not guarantee
that the download started immediately.

### Scheduling configuration

- One-off unique work
- Connected-network constraint
- Replace policy for duplicate requests
- Exponential retry backoff starting at 30 seconds

The code requests a delayed retry for temporary failures. HTTP 4xx responses
are considered permanent and are not retried. However, automatic retry was not
observed during the final physical-device test, so it is not treated as verified
behavior in this report.

### Progress communication

The tested Flutter WorkManager plugin does not expose the native
`setProgressAsync` and `WorkInfo` observation APIs.

The worker therefore writes an atomic `download_progress.json` snapshot. The UI
polls this file every 500 ms. This also lets a recreated UI restore the latest
known state.

The implementation tracks an internal `enqueued` state, although the current UI
may still display generic downloading text before the worker starts.

### Limitations

- Start time is controlled by Android.
- Work can be delayed by Doze, battery policies, and app standby.
- The notification is not protected by a Foreground Service lifecycle.
- The plugin version used by this spike cannot promote the worker with
  `setForegroundAsync`.
- Long downloads may exceed WorkManager's normal worker execution window.
- UI progress requires file polling instead of push events.

## Comparison

| Decision factor | Foreground Service | WorkManager |
| --- | --- | --- |
| Start time | Immediate | Not guaranteed |
| User-visible long work | Designed for it | Scheduler controlled |
| Ongoing notification | Required | Optional ordinary notification |
| Live progress to UI | Plugin event channel | File polling in this spike |
| Best use case | Active downloads, tracking, media | Sync, cleanup, periodic work |

## Physical-device test results

These results describe the recorded test run. Android behavior can vary by OS
version, OEM, device settings, and the exact application build.

| Scenario | Foreground Service | WorkManager observation |
| --- | --- | --- |
| User starts download | Passed; started immediately | Passed in recorded run |
| App sent to background | Continued with progress | Continued with progress |
| App removed from Recents | Continued with progress | Stopped; reopening restarted at 0% |
| Doze / screen off | Continued with progress | Stopped on tested device |
| Battery optimization | Continued with progress | Stopped when combined with removing the app from Recents |
| Progress notification | Passed | Passed while worker remained active |
| Completion notification | Passed | Passed |
| Notification tap | Opened the app | Opened the app |
| Failure handling | Failure notification; no automatic restart when internet returned | Failure notification; no automatic restart observed when internet returned |

## Failure handling

The failure test was performed by disconnecting the internet while a download
was active. Both APKs showed the same visible behavior:

1. Dio reported a network error and the active download stopped.
2. The progress notification changed to a failure notification.
3. If the application screen was open, the UI also showed an error snackbar.
4. If the application was closed, only the notification could be shown because
   there was no active Flutter screen on which to display a snackbar.
5. Restoring the internet connection did not continue the existing download.
6. Starting the download again began at 0%.

The download is **stopped**, not paused. Neither implementation stores the
partially downloaded byte position or sends an HTTP range request, so it cannot
continue from the previous percentage.

### Foreground Service behavior

When Dio throws a network error, the background isolate:

- Clears the saved pending job.
- Sends a failure event to the UI when the UI is available.
- Shows a failure notification.
- Stops the Foreground Service.

The current Foreground Service implementation does not schedule an automatic
network retry. The user must start a new download after connectivity returns.

### WorkManager behavior

When Dio throws a network error, the worker:

- Writes a failed progress snapshot for the UI.
- Shows a failure notification.
- Requests a delayed retry for errors classified as temporary.

WorkManager decides when a requested retry may run; it is not guaranteed to
restart immediately when the internet returns. In the tested APK and device, no
automatic restart was observed. Therefore, the verified result is the same as
the Foreground Service: the user starts another download, and it begins at 0%.

## Meaning of “app closed”

Android distinguishes several states:

- **Home/background:** the Activity is hidden and the process may remain alive.
- **Removed from Recents:** the task is removed, but the package is not
  necessarily force-stopped.
- **Low-memory process kill:** in-memory Dart isolates and UI state disappear.
- **Doze/battery saver:** background network and scheduling are restricted.
- **Force stop from Android settings:** the package enters a stopped state.
  Neither implementation should be expected to continue until the user
  relaunches it.
- **Device reboot:** WorkManager can restore persisted work. The Foreground
  Service implementation has `autoStartOnBoot: false`.

For accurate reporting, the demonstrated acceptance case should be described as
“the app was removed from Recents,” not “the app was force-stopped.”

## Key lessons

1. A Foreground Service is required when the user expects immediate,
   user-visible work to continue.
2. WorkManager guarantees eventual scheduling, not immediate continuous
   execution.
3. Background isolates cannot access UI objects or UI-isolate memory.
4. State required after process death must be persisted.
5. Foreground Service recovery does not automatically provide partial-file
   resume.
6. Notification updates must be throttled.
7. Android permissions and Foreground Service types must match the actual work.
8. Device and OEM testing is essential; code inspection alone cannot prove
   behavior under Doze or process killing.

## Recommendation

Use the Foreground Service for the active, user-initiated download and live
progress notification.

Use WorkManager for deferrable synchronization, cleanup, retry, periodic work,
or as a durable recovery mechanism after an interrupted foreground operation.

For a production implementation, a hybrid design is appropriate:

- Foreground Service for the active download.
- WorkManager for deferred retry or recovery.
- HTTP range requests for real byte-level resume.

Android `DownloadManager` should also be considered when the requirement is a
standard file download and system-managed notifications and retry behavior are
acceptable.

## Remaining production work

- Re-test the final WorkManager APK on the target device.
- Test additional OEM devices and Android versions.
- Add HTTP range-based resumable downloads.
- Add user cancellation and retry controls.
- Persist stable work/download identifiers.
- Improve permanent versus transient error classification.
- Add integration tests for background, swipe-away, Doze, and process recovery.

## Running the project

Foreground Service implementation:

```powershell
git switch dev
.\.fvm\flutter_sdk\bin\flutter run
```

WorkManager implementation:

```powershell
git switch workmanger
.\.fvm\flutter_sdk\bin\flutter run
```

Use a physical Android device for background-execution verification.
