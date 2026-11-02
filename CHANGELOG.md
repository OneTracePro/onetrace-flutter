# Changelog

## 1.1.0 — unreleased

- Signed user ids: `identify(userId, traits, userHash)` and `alias(userId, userHash)` pass the signature from your server to the native SDKs, which send it with every event and the installation registration. Required when the project turns on the user id signature.
- Native SDKs 1.1.0.

## 1.0.0 — 2026-10-31

- Events, screens, identify, alias and reset through the native OneTrace SDKs for Android and iOS; dates in properties become ISO 8601 strings.
- `OneTraceNavigatorObserver`: a screen for every named page route.
- Mobile push with firebase_messaging or your own setup: tokens, permission changes, delivery receipts and taps (reported once, links opened).
- In-app messages drawn by the native SDKs over the Flutter UI; pause and fetch on demand.
