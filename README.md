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

## WorkManager vs flutter_background_service

Do not implement both together yet. For the next learning step, read them
separately:

- `workmanager` is best for deferrable background work that should eventually
  run, such as syncing data, cleanup, retrying uploads, or periodic refresh. The
  OS decides the exact execution time, especially under Doze mode and battery
  optimization. It is not for continuous live progress.
- `flutter_background_service` is best when you need an Android foreground
  service with an ongoing notification, such as tracking, long-running work, or
  live progress while the app is not visible. It needs careful permission and
  battery testing, and Android can still restrict behavior depending on version
  and OEM.

For this project, Phase 1 only uses local notifications. Later phases should add
WorkManager and foreground-service demos separately before combining them with a
download-progress flow.
