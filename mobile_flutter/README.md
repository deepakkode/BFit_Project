# BFit for Flutter

This is the parallel Flutter mobile client for the existing BFit API. It keeps the Expo app in `../mobile/` intact. The trained activity model and account data remain on the existing backend; the Flutter client does not copy or retrain that model.

## Requirements and first run

- Flutter stable with Dart 3.5 or newer (`flutter --version`)
- Android Studio/Android SDK for Android; Xcode and CocoaPods for iOS
- A physical phone for meaningful step-counter, motion-sensor, notification, and battery-policy checks

From this directory:

```sh
flutter pub get
flutter run
```

The Android Gradle app configuration and sensor/notification manifest are included. If the local Flutter installation needs regenerated native runner support files (Gradle wrapper/Xcode project), run Flutter's platform scaffolder from this directory before building:

```sh
flutter create --platforms=android,ios --org=com.deepakkode --project-name=bfit .
```

Then re-check the platform permissions below; generated platform files should not replace the BFit-specific permission declarations.

## API configuration

The build default is the deployed backend:

```text
https://bfit-api.onrender.com/api/v1
```

Override it at build/run time with a Dart define:

```sh
flutter run --dart-define=BFIT_API_BASE_URL=https://your-api.example/api/v1
flutter build apk --dart-define=BFIT_API_BASE_URL=https://your-api.example/api/v1
flutter build ios --dart-define=BFIT_API_BASE_URL=https://your-api.example/api/v1
```

All authenticated requests use a bearer token held in platform secure storage. Tokens expire 30 days after sign-in by default on the backend; an existing token keeps its current expiry, and a `401` returns to sign in. The client uses the existing `/api/v1` auth, profile, activity, steps, analytics, and goals routes. Absolute daily step totals use the server's idempotent `/steps/update` upsert.

## Features

- Startup session restore, register/sign-in/sign-out, secure bearer token, profile completion and editing (age, height, weight, optional gender).
- Five native destinations: Home, History, Insights, Goals, and Profile.
- Home step-goal arc, server-recognized activity (Sitting and Standing grouped as Rest), activity mix, estimated distance/energy, and a daily coaching note.
- Native pedometer totals independent from activity classification. On Android, a health-type foreground service keeps the hardware step counter active while the app UI is backgrounded or its Flutter process is restarted. It shows an ongoing notification, uses additional battery, and journals its daily counter locally; the Flutter tracker reconciles updates with its own persisted cursor and syncs absolute UTC-day totals to the backend when BFit next runs. Sign-out stops the service.
- Local step totals and older pending UTC-day totals are journaled locally and retried as absolute totals. Server baselines are merged once; queued totals are persisted as absolute values before the idempotent upsert so a restart can retry safely.
- Weekly/monthly summaries and step history, editable goals, and the existing profile-adjusted gradual goal recommendation (at least three positive history days in the last seven; rounded to 100 and clamped to 3,000–12,000 steps).
- Optional local daily reminder in the phone's local time zone. A time-zone change is reconciled when BFit next opens or resumes. Android uses an inexact schedule; battery management, Doze, or notification settings may delay or prevent delivery, so the selected time is not an exact-minute promise.
- Persisted light/dark palettes; empty, loading, retry, and partial-data states.

## Permissions and physical-device validation

Android declares `ACTIVITY_RECOGNITION`, `POST_NOTIFICATIONS`, the Android health foreground-service permissions, internet access, and boot rescheduling for local reminders. When an authenticated user opens BFit, it requests activity-recognition and notification permission before starting background step tracking. If either permission is unavailable or the device has no step-counter sensor, BFit reports the limitation and only the in-app pedometer fallback may work while the UI is open. iOS declares `NSMotionUsageDescription` and asks for notification access only when the user enables a reminder.

The native step counter reports new observations, not a complete recoverable history. In particular, BFit cannot reconstruct Android steps from before its first sensor observation or reliably divide a counter gap that spans a UTC midnight; those ambiguous steps are not assigned to the new day. Older phone-health history may therefore differ from BFit. The server baseline and locally journaled totals are reconciled to avoid re-adding a previously synced absolute total. Android background tracking is not guaranteed after the user force-stops BFit, disables permissions, reboots the phone (open BFit again to restart tracking), or encounters OEM battery restrictions; those restrictions may also stop or delay the service.

Editing age, height, weight, or gender saves the profile first, then recalculates and persists a profile-adjusted daily goal through the existing `/goals` endpoint while carrying the current weekly-run and monthly-distance values forward. Suggestions use profile factors and recent step history when available, round to the nearest 100 steps, and stay between 3,000 and 12,000. If goals cannot be read or saved, the profile screen explicitly reports that the daily goal may be stale. If recent history is unavailable, BFit saves a profile-based starting goal and says that history was omitted.

On a physical device, verify:

1. Register or sign in; complete the profile; sign out and confirm a fresh launch restores no signed-out session.
2. Allow physical-activity and notification access, verify the ongoing BFit tracking notification, lock the phone or switch to another app, walk, and compare BFit with the device's native step counter. Confirm the total persists after reopening BFit and eventually syncs after reconnecting.
3. Count steps offline, swipe BFit away from Recents before UTC midnight (do not force-stop it), reopen on the next UTC day, and reconnect. Verify yesterday's pending absolute total is recovered and retried once without being added to today's total. The server uses UTC dates; phone display time is local. Steps from counter gaps spanning midnight are inherently ambiguous and are not reconstructed.
4. Allow for a few seconds to collect a full 200-sample window; confirm a prediction arrives from the backend and appears in Home/History. Sensor orientation and phone placement can affect recognition.
5. Enable a reminder, choose a local time, change the phone's time zone, reopen BFit, then test with the device's notification and battery settings. Delivery may be delayed or prevented; exact timing is not guaranteed.
6. Deny notification access and confirm the reminder remains off with an explanatory message; also test revoking access in system settings.
7. Review activity permission denial, airplane mode, expired-token, empty-history, and unavailable-model states.

Step totals are counted independently of classification. Distance and calories are estimates, not clinical measurements. Activity detection depends on the installed backend model and real-phone validation; this source does not assert that the deployed service or classifier is currently healthy.

## Tests and builds

These are required validation commands, not a claim that a build or test has passed. Run them on a Flutter-enabled workstation or CI runner, then complete the physical-device checklist before release.

```sh
flutter test
flutter analyze
flutter build apk
flutter build ios
```

The build configuration keeps Android application ID `com.deepakkode.bfit` for continuity only. **An APK can update an already installed Expo app only if it is signed with the same Android signing key.** This repository does not contain the Expo/EAS signing keystore, and the included Flutter Gradle release fallback uses the local debug key. Therefore, do not treat a locally signed Flutter APK as an in-place upgrade; use the original signing credentials or install it separately after choosing a different application ID. No signing credentials are included.
