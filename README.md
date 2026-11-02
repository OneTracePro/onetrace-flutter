# OneTrace.pro for Flutter

[![CI](https://github.com/OneTracePro/onetrace-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/OneTracePro/onetrace-flutter/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

The Flutter plugin of [OneTrace.pro](https://onetrace.pro), the customer data platform: events and screens of your app users in the same profiles as your website, CRM and stores — for segments, journeys, predictions and analytics — plus mobile push notifications and in-app messages.

The plugin is a thin layer over the native SDKs, [OneTrace for Android](https://github.com/OneTracePro/onetrace-android) and [OneTrace for iOS](https://github.com/OneTracePro/onetrace-ios): events are queued on disk and sent in batches by native code, and in-app messages are drawn natively over your Flutter UI.

- Android 5.0+ (API 21), iOS 13+.
- iOS uses Swift Package Manager, the default since Flutter 3.44. With CocoaPods turned on (`enable-swift-package-manager: false`) the plugin cannot be built.

## Installation

```yaml
dependencies:
  onetrace_flutter:
    git:
      url: https://github.com/OneTracePro/onetrace-flutter.git
      ref: v1.0.0
```

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

## In-app messages

Messages of the **In-app messages** channel (journeys and campaigns) are fetched when the app opens and after events are sent, and shown over the app as a modal, a banner or a full screen — right away or after their trigger event. Hold them back during checkout with `OneTrace.pauseInAppMessages(true)`, ask for them now with `OneTrace.fetchInAppMessages()`.

## Example

[`example/`](example) is a small shop: products, sign-in and sign-out, add to cart, in-app messages.

Clone the repository into a directory named `onetrace_flutter` to build the example for iOS — Xcode rejects the plugin's Swift package otherwise ([flutter/flutter#186881](https://github.com/flutter/flutter/issues/186881)); apps that depend on the plugin are not affected.

```bash
cd example
flutter run --dart-define=ONETRACE_WRITE_KEY=cdp_wk_… --dart-define=ONETRACE_HOST=https://crm.example.com
```

## License

MIT
