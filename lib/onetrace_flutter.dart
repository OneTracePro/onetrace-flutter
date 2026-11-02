/// OneTrace.pro for Flutter: events, screens and identities of app users, installations for mobile push and in-app
/// messages — through the native OneTrace SDKs for Android and iOS.
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// SDK settings.
@immutable
class OneTraceConfig {
  const OneTraceConfig({
    required this.writeKey,
    required this.host,
    this.flushAt = 20,
    this.flushInterval = const Duration(seconds: 30),
    this.maxQueueSize = 1000,
    this.trackLifecycle = true,
    this.openPushLinks = true,
    this.debug = false,
  });

  /// The project write key (`cdp_wk_…`) from the OneTrace admin panel.
  final String writeKey;

  /// The address you open OneTrace at, for example `https://crm.example.com`; `/api/v1` is added automatically.
  final String host;

  /// Send the queue once it has this many events.
  final int flushAt;

  /// Send the queue at least this often while the app is running.
  final Duration flushInterval;

  /// Events kept on disk while offline; the oldest are dropped beyond it.
  final int maxQueueSize;

  /// Send `app_installed`, `app_updated`, `app_opened` and `app_backgrounded`.
  final bool trackLifecycle;

  /// Open the link of a tapped push notification (`cdp_url`) automatically.
  final bool openPushLinks;

  /// Log what the SDK does (Logcat, Xcode console).
  final bool debug;

  Map<String, Object?> toMap() => {
    'writeKey': writeKey,
    'host': host,
    'flushAt': flushAt,
    'flushIntervalSeconds': flushInterval.inSeconds,
    'maxQueueSize': maxQueueSize,
    'trackLifecycle': trackLifecycle,
    'openPushLinks': openPushLinks,
    'debug': debug,
  };
}

/// Push provider of the token passed to [OneTrace.setPushToken].
enum PushProvider { fcm, apns }

/// The OneTrace SDK. Call [init] once, as early as possible (before `runApp`); every other call does nothing before it.
abstract final class OneTrace {
  /// Version of this package, reported with every event.
  static const String version = '1.0.0';

  @visibleForTesting
  static const MethodChannel channel = MethodChannel('pro.onetrace/sdk');

  static Future<void> init(OneTraceConfig config) {
    WidgetsFlutterBinding.ensureInitialized();

    return channel.invokeMethod('init', {...config.toMap(), 'wrapper': 'flutter', 'wrapperVersion': version});
  }

  /// Your own event, for example `track('order_completed', {'order_id': '1001', 'amount': 1250.5})`.
  static Future<void> track(String event, [Map<String, Object?> properties = const {}]) =>
      channel.invokeMethod('track', {'event': event, 'properties': _values(properties)});

  /// A screen of the app: the `$screen` event with the screen name. [OneTraceNavigatorObserver] sends it for you.
  static Future<void> screen(String name, [Map<String, Object?> properties = const {}]) =>
      channel.invokeMethod('screen', {'name': name, 'properties': _values(properties)});

  /// The user signed in or updated their data. Pass null as the user id to update traits of the current visitor.
  ///
  /// [userHash] is the signature of the user id: HMAC-SHA256 of [userId] with the project's signing key, in hex. Your
  /// server computes it after sign-in and returns it to the app; never put the signing key into the app. When the
  /// project requires the signature, a user id without it is ignored. The SDK keeps it with the user id and sends it
  /// with every event and the installation; a later `identify` of the same user without it keeps the stored one.
  static Future<void> identify(String? userId, [Map<String, Object?> traits = const {}, String? userHash]) =>
      channel.invokeMethod('identify', {'userId': userId, 'traits': _values(traits), 'userHash': userHash});

  /// Links the current anonymous visitor to a new user id; [userHash] is its signature, as in [identify].
  static Future<void> alias(String userId, [String? userHash]) =>
      channel.invokeMethod('alias', {'userId': userId, 'userHash': userHash});

  /// The user signed out: a new anonymous id, and the installation leaves the previous user's profile.
  static Future<void> reset() => channel.invokeMethod('reset');

  /// Sends queued events now instead of waiting for the next batch.
  static Future<void> flush() => channel.invokeMethod('flush');

  /// The push token of this installation, for example `await FirebaseMessaging.instance.getToken()`. Null removes it.
  static Future<void> setPushToken(String? token, {PushProvider provider = PushProvider.fcm}) =>
      channel.invokeMethod('setPushToken', {'token': token, 'provider': provider.name});

  /// Call after the user answered the notification permission prompt: the platform learns whether push can be sent.
  static Future<void> notificationPermissionChanged() => channel.invokeMethod('notificationPermissionChanged');

  /// True when the data of a push message came from OneTrace.
  static bool isOneTraceNotification(Map<String, Object?> data) => data['cdp_token'] is String;

  /// A OneTrace notification reached the app, for example in `FirebaseMessaging.onMessage`: it becomes delivered.
  static Future<void> notificationReceived(Map<String, Object?> data) async {
    if (isOneTraceNotification(data)) {
      await channel.invokeMethod('notificationReceived', {'data': _strings(data)});
    }
  }

  /// A OneTrace notification was tapped, for example in `FirebaseMessaging.onMessageOpenedApp`: the open is reported
  /// once and its link opened. Returns false when the data is not from OneTrace.
  static Future<bool> notificationOpened(Map<String, Object?> data) async {
    if (!isOneTraceNotification(data)) {
      return false;
    }

    await channel.invokeMethod('notificationOpened', {'data': _strings(data)});

    return true;
  }

  /// Holds in-app messages back while true, for example during checkout; they are shown after it is set back to false
  /// and the app opens again or tracks their trigger event.
  static Future<void> pauseInAppMessages(bool paused) => channel.invokeMethod('pauseInAppMessages', {'paused': paused});

  /// Asks OneTrace for in-app messages now; the SDK also does it when the app opens and after sending events.
  static Future<void> fetchInAppMessages() => channel.invokeMethod('fetchInAppMessages');

  static Future<String?> get anonymousId => channel.invokeMethod<String>('anonymousId');

  static Future<String?> get userId => channel.invokeMethod<String>('userId');

  /// The installation id: the `mobile_push` identity of the profile while push can be sent.
  static Future<String?> get installationId => channel.invokeMethod<String>('installationId');

  /// Values the platform channel can carry: dates become ISO 8601 strings in UTC, other objects their `toString()`.
  static Object? _value(Object? value) => switch (value) {
    null || String() || bool() || int() || double() => value,
    DateTime() => value.toUtc().toIso8601String(),
    Map() => {for (final entry in value.entries) entry.key.toString(): _value(entry.value)},
    Iterable() => [for (final item in value) _value(item)],
    _ => value.toString(),
  };

  static Map<String, Object?> _values(Map<String, Object?> map) => {
    for (final entry in map.entries) entry.key: _value(entry.value),
  };

  static Map<String, String> _strings(Map<String, Object?> data) => {
    for (final entry in data.entries)
      if (entry.value != null) entry.key: entry.value.toString(),
  };
}

/// Sends a screen for every named route: add it to `MaterialApp(navigatorObservers: [OneTraceNavigatorObserver()])`.
class OneTraceNavigatorObserver extends NavigatorObserver {
  OneTraceNavigatorObserver({this.screenName = _routeName});

  /// The screen name of a route; null skips the route. By default the name of a page route (`RouteSettings.name`).
  final String? Function(Route<dynamic> route) screenName;

  static String? _routeName(Route<dynamic> route) => route is PageRoute ? route.settings.name : null;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _send(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (newRoute != null) {
      _send(newRoute);
    }
  }

  /// Back to the previous screen; closing a dialog or a bottom sheet is not a new screen.
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (previousRoute != null && screenName(route) != null) {
      _send(previousRoute);
    }
  }

  void _send(Route<dynamic> route) {
    final name = screenName(route);

    if (name != null && name.isNotEmpty) {
      OneTrace.screen(name);
    }
  }
}
