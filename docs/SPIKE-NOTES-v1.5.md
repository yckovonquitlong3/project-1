# V1.5 Phase 0 Spike Notes

**Date:** 2026-11-06
**Device:** Vivo VHEM, Android 12 (API 31), Asia/Manila
**Build:** debug, installed with `adb install -r`

## Notification spike

| Check | Result |
|---|---|
| Schedule a notification 2 minutes ahead | Passed; AlarmManager registered it |
| App backgrounded (Home) | Passed; notification posted |
| App process killed (`adb shell am kill`) | Passed; notification posted with a new ID after the process was gone |
| Notification tap | Opened `MainActivity` |
| Inexact timing | Scheduled 03:05, observed by ~03:07–03:08; expect a few minutes of delay |
| Reboot rescheduling | Pending manual check |
| Force-stop | Expected to cancel alarms; not tested (documented Android behavior) |
| Android 13 runtime permission | Not testable on this Android 12 device |
| Uninstall | Cancels every alarm and wipes app data |

The first test appeared to fail because the app package had been **uninstalled**, not merely
removed from Recents. Uninstalling cancels all alarms and deletes the database. After reinstalling,
the background and killed-process tests passed.

**Decision:** keep inexact local reminders. They may arrive a few minutes late; that is acceptable
for a 24-hour warning and a billing-day alert. Revisit exact alarms only if the delay becomes a
usability problem. The boot receiver is configured; reboot verification remains.

## Android setup added

- `POST_NOTIFICATIONS` and `RECEIVE_BOOT_COMPLETED`.
- `ScheduledNotificationReceiver` and `ScheduledNotificationBootReceiver`.
- Core library desugaring in `android/app/build.gradle.kts`.
- `flutter_local_notifications` 22.3.3, `timezone` 0.11.2, `flutter_timezone` 5.1.1.

## Temporary spike code

- `lib/core/notifications/notification_spike.dart`
- Debug-only bell action on the Dashboard (`kDebugMode` only)

Both are temporary and will be replaced by the real `NotificationScheduler` in Phase 3.
