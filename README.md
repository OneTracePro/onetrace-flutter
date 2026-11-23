# OneTrace.pro for Flutter

[![CI](https://github.com/OneTracePro/onetrace-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/OneTracePro/onetrace-flutter/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

The Flutter plugin of [OneTrace.pro](https://onetrace.pro), the customer data platform: events and screens of your app users in the same profiles as your website, CRM and stores — for segments, journeys, predictions and analytics — plus mobile push notifications, in-app messages and the message feed.

The plugin is a thin layer over the native SDKs, [OneTrace for Android](https://github.com/OneTracePro/onetrace-android) and [OneTrace for iOS](https://github.com/OneTracePro/onetrace-ios): events are queued on disk and sent in batches by native code, and in-app messages and the feed screen are drawn natively over your Flutter UI.

- Android 5.0+ (API 21), iOS 13+.
- iOS uses Swift Package Manager, the default since Flutter 3.44. With CocoaPods turned on (`enable-swift-package-manager: false`) the plugin cannot be built.

## Installation

```yaml
dependencies:
  onetrace_flutter:
    git:
      url: https://github.com/OneTracePro/onetrace-flutter.git
      ref: v1.2.0
```

## Native code before the release (stage 105)

The features above (rich push, Remote Config, geofences) are in the `stage-105` branches of the native SDKs, which are not released yet:

- Android: in `onetrace-android` (branch `stage-105`) run `./gradlew :onetrace:publishReleasePublicationToMavenLocal :onetrace-fcm:publishReleasePublicationToMavenLocal :onetrace-location:publishReleasePublicationToMavenLocal`; the plugin resolves `com.github.OneTracePro.onetrace-android:onetrace` and `onetrace-location` from `mavenLocal()` first. The plugin now depends on the `onetrace-location` module (Google Play services location).
- iOS: `ios/onetrace_flutter/Package.swift` pins `onetrace-ios` to a commit of the `stage-105` branch (`revision:`); for local work replace it with `.package(path: "../../../onetrace-ios")`.

After the native SDKs are released these lines switch back to the version.

## Quick start

```dart
import 'package:onetrace_flutter/onetrace_flutter.dart';

Future<void> main() async {
  await OneTrace.init(const OneTraceConfig(
    writeKey: 'cdp_wk_…',              // Settings → API keys: a write key
    host: 'https://crm.example.com',   // the address you open OneTrace at
  ));

  runApp(MaterialApp(
    navigatorObservers: [OneTraceNavigatorObserver()],  // a screen for every named route
    // …
  ));
}
```

Then, anywhere:

```dart
OneTrace.track('add_to_cart', {'product_id': 'SKU-1', 'price': 49.9});
OneTrace.identify('u-42', {'email': 'anna@example.com'});  // after sign-in
OneTrace.reset();                                          // after sign-out
```

Use the same event names and `product_id` values as on your website — then recommendations, abandoned cart journeys and the reports work across the website and the app. See the [e-commerce events](https://onetrace.pro/en/docs/api).

The SDK sends `app_installed`, `app_updated`, `app_opened` and `app_backgrounded` itself, with the app version, device model, OS version, language and time zone in the context of every event. Dates in properties become ISO 8601 strings in UTC.

`OneTraceNavigatorObserver` sends a screen with the route name (`RouteSettings.name`) for every page route; dialogs and bottom sheets are not screens. Pass `screenName` to name routes yourself, or call `OneTrace.screen('Cart')`.

## Signed user ids

The write key ships inside the app, so anyone could call `identify` with someone else's user id and receive that customer's in-app messages and push. Sign the user id on your server to prove it belongs to the signed-in user. When the project requires the signature (**Website → Connection → Server**), a user id without a valid one is ignored: events stay with the anonymous id, and the installation is not registered for that user.

1. Create the signing key on the **Website → Connection → Server** tab and keep it on your server only — never put it into the app.
2. After sign-in, your server returns the signature with the session: HMAC-SHA256 of the user id with the signing key, in hex.

   ```php
   $userHash = hash_hmac('sha256', $userId, getenv('CDP_IDENTITY_KEY'));
   ```

   ```js
   const userHash = crypto.createHmac('sha256', process.env.CDP_IDENTITY_KEY).update(userId).digest('hex');
   ```

3. Pass it to `identify` (and to `alias`):

   ```dart
   OneTrace.identify(session.userId, {'email': session.email}, session.userHash);
   ```

The SDK keeps the signature with the user id and sends it as `userHash` with every event and the installation registration. A later `identify` of the same user without a signature keeps the stored one; another user id or `reset()` clears it. After the key is changed, the previous one is accepted for another 24 hours: return signatures with the new key from your server before then.

## Push notifications

The plugin does not receive push messages itself — use [firebase_messaging](https://pub.dev/packages/firebase_messaging) (or your own setup) and pass the token and the messages on:

```dart
final messaging = FirebaseMessaging.instance;
await messaging.requestPermission();
await OneTrace.notificationPermissionChanged();
await OneTrace.setPushToken(await messaging.getToken());          // FCM, Android and iOS
messaging.onTokenRefresh.listen(OneTrace.setPushToken);

FirebaseMessaging.onMessage.listen((message) => OneTrace.notificationReceived(message.data));
FirebaseMessaging.onMessageOpenedApp.listen((message) => OneTrace.notificationOpened(message.data));
final initial = await messaging.getInitialMessage();
if (initial != null) {
  await OneTrace.notificationOpened(initial.data);
}
```

A tap is reported once and its link (`cdp_url`, `myapp://…` or `https://…`) is opened — set `openPushLinks: false` to handle it yourself. On iOS without Firebase pass the APNs token: `OneTrace.setPushToken(token, provider: PushProvider.apns)`.

In OneTrace add the **Mobile push** integration with your package name and bundle id: the Firebase service account for FCM and, for APNs tokens, the APNs key.

### Rich push, buttons and the tapped button (stage 105, unreleased)

Android: the native SDK draws OneTrace push (carousel, timer, buttons, snooze). Set `richPush: true` in `OneTraceConfig` and pass the data of every message to `OneTrace.handlePush(data)` from your background handler (it returns false for other messages); only then the installation reports `rich` and `silent` and the server sends data-only messages. Without the flag the server sends the plain notification, as before.

```dart
@pragma('vm:entry-point')
Future<void> onBackgroundMessage(RemoteMessage message) => OneTrace.handlePush(message.data);

await OneTrace.init(const OneTraceConfig(writeKey: '…', host: '…', richPush: true));
FirebaseMessaging.onBackgroundMessage(onBackgroundMessage);
```

iOS draws rich push in a Notification Service Extension and Notification Content Extension of the native SDK (see its README); `richPush` and `handlePush` do nothing there. A tap on a button is passed with its id: `OneTrace.notificationOpened(message.data, actionId: id)`. The same tap passed twice (the native delegate and your code) is reported once.

## Remote Config

App settings of OneTrace (**Apps → Remote Config**), read from the device:

```dart
final theme = await OneTrace.remoteConfig.getString('theme', 'light');
final enabled = await OneTrace.remoteConfig.getBool('new_checkout', false);   // also getInt, getDouble, getJson (a JSON string)
await OneTrace.remoteConfig.fetch();                                            // fresh values now, true when fetched
OneTrace.remoteConfig.changes.listen((keys) => reload(keys));                   // keys that changed after a fetch
```

`OneTraceConfig.remoteConfigMinFetchInterval` sets how often the SDK asks by itself (one hour by default).

## Geofences

Zones of **Apps → Geofences** produce `geofence_entered`, `geofence_dwelled` and `geofence_exited` events. The native SDK watches the nearest zones; the location permission is yours to ask for:

```dart
await OneTrace.requestLocationPermission();     // Android: call again after the answer for «Allow all the time»
final status = await OneTrace.enableGeofences(); // GeofenceStatus.enabled, or the reason it is not
await OneTrace.disableGeofences();
```

Android needs `ACCESS_FINE_LOCATION` (and `ACCESS_BACKGROUND_LOCATION`) in the app manifest; iOS needs the `NSLocationWhenInUseUsageDescription` and `NSLocationAlwaysAndWhenInUseUsageDescription` strings. Call `enableGeofences()` at app start too: iOS starts the app in the background for a zone event.

## Live Activities (iOS)

Not wrapped: they use ActivityKit types. Call `OneTrace.liveActivities` of the native iOS SDK directly from your Swift code in the app target (see the native SDK README).

## In-app messages

Messages of the **In-app messages** channel (journeys and campaigns) are fetched when the app opens and after events are sent, and shown over the app as a modal, a banner or a full screen — right away or after their trigger event. Hold them back during checkout with `OneTrace.pauseInAppMessages(true)`, ask for them now with `OneTrace.fetchInAppMessages()`.

## Message feed

Personal cards — an offer, news, a reminder, a promo code — that stay in the app until they expire or the user removes them, with an unread count for a badge. Unlike in-app messages, a card is not shown once and gone: it waits in the feed (the same cards are shown in the feed widget of your website). Cards are sent by journeys and campaigns through the **Message feed** channel, a feature of the OneTrace plan; without it the feed is empty.

**Ready-made screen.** The native SDK draws it: the cards in their layouts (image on the left, image on top, image only), pinned ones first, a remove button on each, pull to refresh and an empty state. A card at least half visible is reported as shown (read; the message delivered and opened), a tap on the button — or on a card without a button — reports the click and opens the link like push links.

```dart
OneTrace.openFeed();                  // a modal screen on iOS, an activity on Android
OneTrace.openFeed(language: 'de');    // iOS: the labels language; Android follows the app language
```

The labels follow the device language (English, Russian, German, Uzbek, Turkish, Spanish, French, Italian, Portuguese or Chinese), the colors the light or dark appearance.

**Unread badge.** Listening starts the native observer — the count now and on every change — and cancelling the subscription stops it. Listen after `init`.

```dart
StreamBuilder<int>(
  stream: OneTrace.feedUnread,
  builder: (context, unread) => IconButton(
    onPressed: OneTrace.openFeed,
    icon: Badge(
      isLabelVisible: (unread.data ?? 0) > 0,
      label: Text('${unread.data ?? 0}'),
      child: const Icon(Icons.notifications_outlined),
    ),
  ),
)
```

While the count is observed, the SDK refreshes the feed when the app opens. `await OneTrace.feedUnreadCount` reads the last count.

**Your own UI.** Load the cards, draw them with your widgets, and report what the user sees and does:

```dart
final cards = await OneTrace.fetchFeed();   // OneTraceFeedCard: token, layout, title, body, imageUrl, buttonText,
                                            // buttonUrl, pinned, read, createdAt, expiresAt, opensOnTap

OneTrace.feedCardShown(card);               // at least half of the card is on screen; reported once, the card becomes read
OneTrace.feedCardClicked(card);             // the button, or the card if card.opensOnTap: reports and opens buttonUrl
OneTrace.feedCardDismissed(card);           // removed: it does not come back
```

`fetchFeed()` returns pinned cards first, then the newest, up to 50; without a network the cards loaded before. `OneTrace.feedCards` is the last loaded feed with the shows and removals since then, without a request — reload it after a report to redraw the list. A show that has not reached OneTrace yet still counts as read for the rest of the session, and a removed card does not come back on a refresh. With `openPushLinks: false` `feedCardClicked` only reports the click: open `card.buttonUrl` yourself, for example with your router.

## Example

[`example/`](example) is a small shop: products, sign-in and sign-out, add to cart, in-app messages, the message feed with an unread badge.

Clone the repository into a directory named `onetrace_flutter` to build the example for iOS — Xcode rejects the plugin's Swift package otherwise ([flutter/flutter#186881](https://github.com/flutter/flutter/issues/186881)); apps that depend on the plugin are not affected.

```bash
cd example
flutter run --dart-define=ONETRACE_WRITE_KEY=cdp_wk_… --dart-define=ONETRACE_HOST=https://crm.example.com
```

## License

MIT
