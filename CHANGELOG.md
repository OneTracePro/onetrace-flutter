# Changelog

## Unreleased

- Stage 105, forwarding the new native calls: `OneTrace.remoteConfig` (`getString`, `getBool`, `getInt`, `getDouble`, `getJson`, `fetch`, `changes`); `enableGeofences`, `disableGeofences`, `requestLocationPermission` and `GeofenceStatus`; `notificationOpened(data, actionId: …)`; `handlePush(data)` and `OneTraceConfig.richPush` (Android rich push); `OneTraceConfig.remoteConfigMinFetchInterval`.
- Native code comes from the `stage-105` branches until their release (a commit on JitPack on Android, mavenLocal with `onetrace.mavenLocal=true`; a pinned commit on iOS); see the README.
- Geofences are connected separately: Android with `onetrace.geofences=true` in `gradle.properties`, iOS with the `OneTraceLocation` product and `OneTraceLocation.register()`; without them the app gets no location permissions or purpose strings and `enableGeofences()` returns `unavailable`. The native Android SDK is an `api` dependency, so the app's `Application` can start it for geofences in the background.
- `handlePush` takes the silent check (`cdp_kind` without a token); the README passes data from `onMessage` too.

## 1.2.0 — 2026-11-09

- Message feed: `fetchFeed()` and `feedCards` return `OneTraceFeedCard`s with every field (token, layout, title, body, image and button, pinned, read, created and expiry dates, `opensOnTap`); `feedUnread` — the unread count as a stream for a badge (listening starts the native observer, cancelling stops it), `feedUnreadCount`; `feedCardShown`, `feedCardClicked` (opens the link like push links) and `feedCardDismissed` reports for your own feed UI.
- `openFeed({language})` opens the ready-made feed screen of the native SDK: classic, captioned and banner cards, pinned first, remove button, pull to refresh, labels in 10 languages, light and dark.
- Native SDKs 1.2.0.

## 1.1.0 — 2026-11-02

- Signed user ids: `identify(userId, traits, userHash)` and `alias(userId, userHash)` pass the signature from your server to the native SDKs, which send it with every event and the installation registration. Required when the project turns on the user id signature.
- Native SDKs 1.1.0.

## 1.0.0 — 2026-10-31

- Events, screens, identify, alias and reset through the native OneTrace SDKs for Android and iOS; dates in properties become ISO 8601 strings.
- `OneTraceNavigatorObserver`: a screen for every named page route.
- Mobile push with firebase_messaging or your own setup: tokens, permission changes, delivery receipts and taps (reported once, links opened).
- In-app messages drawn by the native SDKs over the Flutter UI; pause and fetch on demand.
