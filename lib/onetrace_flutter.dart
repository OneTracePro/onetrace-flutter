/// OneTrace.pro for Flutter: events, screens and identities of app users, installations for mobile push, in-app
/// messages and the message feed — through the native OneTrace SDKs for Android and iOS.
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

/// How a feed card is drawn.
enum FeedCardLayout {
  /// The image on the left of the text.
  classic,

  /// The image above the text.
  captioned,

  /// The image only; [OneTraceFeedCard.title] describes it.
  banner,
}

/// A card of the message feed: an offer, news, a reminder or a promo code that stays in the app until it expires or the
/// user removes it (unlike in-app messages, which are shown once). Get the cards with [OneTrace.fetchFeed].
@immutable
class OneTraceFeedCard {
  const OneTraceFeedCard({
    required this.token,
    this.layout = FeedCardLayout.classic,
    this.title = '',
    this.body,
    this.imageUrl,
    this.buttonText,
    this.buttonUrl,
    this.pinned = false,
    this.read = false,
    this.createdAt,
    this.expiresAt,
    this.opensOnTap = false,
  });

  /// A card as the native SDK passes it over the channel; dates are milliseconds since the epoch.
  factory OneTraceFeedCard.fromMap(Map<Object?, Object?> map) => OneTraceFeedCard(
    token: map['token'] as String? ?? '',
    layout: FeedCardLayout.values.asNameMap()[map['layout']] ?? FeedCardLayout.classic,
    title: map['title'] as String? ?? '',
    body: map['body'] as String?,
    imageUrl: map['imageUrl'] as String?,
    buttonText: map['buttonText'] as String?,
    buttonUrl: map['buttonUrl'] as String?,
    pinned: map['pinned'] == true,
    read: map['read'] == true,
    createdAt: _date(map['createdAt']),
    expiresAt: _date(map['expiresAt']),
    opensOnTap: map['opensOnTap'] == true,
  );

  /// Identifies the card in the reports to OneTrace.
  final String token;

  final FeedCardLayout layout;

  /// Shown in bold; for the [FeedCardLayout.banner] layout the description of the image.
  final String title;

  final String? body;

  /// A web address of the image.
  final String? imageUrl;

  /// The button label; null when the whole card is the link.
  final String? buttonText;

  /// A web page or a deep link of the app.
  final String? buttonUrl;

  /// Shown above the other cards.
  final bool pinned;

  /// Already shown to the user: not counted as unread.
  final bool read;

  /// In UTC.
  final DateTime? createdAt;

  /// The card leaves the feed after it; in UTC.
  final DateTime? expiresAt;

  /// A tap anywhere on the card opens [buttonUrl]: a card without a button label, or a banner.
  final bool opensOnTap;

  static DateTime? _date(Object? value) =>
      value is int ? DateTime.fromMillisecondsSinceEpoch(value, isUtc: true) : null;
}

/// The OneTrace SDK. Call [init] once, as early as possible (before `runApp`); every other call does nothing before it.
abstract final class OneTrace {
  /// Version of this package, reported with every event.
  static const String version = '1.2.0';

  @visibleForTesting
  static const MethodChannel channel = MethodChannel('pro.onetrace/sdk');

  /// The unread count of the message feed; see [feedUnread].
  @visibleForTesting
  static const EventChannel feedUnreadChannel = EventChannel('pro.onetrace/feed_unread');

  static Stream<int>? _feedUnread;

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

  /// Loads the message feed of this user: pinned cards first, then the newest, up to 50. Without a network the cards
  /// loaded before; before [init] an empty list.
  static Future<List<OneTraceFeedCard>> fetchFeed() async =>
      _cards(await channel.invokeMethod<List<Object?>>('fetchFeed'));

  /// The feed as last loaded, with the shows and removals since then; no request.
  static Future<List<OneTraceFeedCard>> get feedCards async =>
      _cards(await channel.invokeMethod<List<Object?>>('feedCards'));

  /// Cards of the last loaded feed the user has not seen yet.
  static Future<int> get feedUnreadCount async => await channel.invokeMethod<int>('feedUnreadCount') ?? 0;

  /// The number of feed cards the user has not seen yet, for a badge: the count now and on every change. Listening
  /// starts the native observer (and loads the feed if needed), cancelling the last subscription stops it. Listen after
  /// [init].
  static Stream<int> get feedUnread =>
      _feedUnread ??= feedUnreadChannel.receiveBroadcastStream().map((count) => count as int);

  /// For your own feed UI: at least half of the card is visible. Reported once; the card becomes read, the message
  /// delivered and opened.
  static Future<void> feedCardShown(OneTraceFeedCard card) =>
      channel.invokeMethod('feedCardShown', {'token': card.token});

  /// For your own feed UI: a tap on the button, or on the card when [OneTraceFeedCard.opensOnTap]. Reports the click and
  /// opens [OneTraceFeedCard.buttonUrl] as push links are opened; with `openPushLinks: false` it only reports.
  static Future<void> feedCardClicked(OneTraceFeedCard card) =>
      channel.invokeMethod('feedCardClicked', {'token': card.token});

  /// For your own feed UI: the user removed the card; it does not come back.
  static Future<void> feedCardDismissed(OneTraceFeedCard card) =>
      channel.invokeMethod('feedCardDismissed', {'token': card.token});

  /// Opens the ready-made feed screen of the native SDK: the cards in their layouts, pinned first, a remove button,
  /// pull to refresh, shows and clicks reported. [language] (`de`, `pt-BR`…) chooses the labels on iOS; on Android they
  /// follow the app language.
  static Future<void> openFeed({String? language}) => channel.invokeMethod('openFeed', {'language': language});

  static Future<String?> get anonymousId => channel.invokeMethod<String>('anonymousId');

  static Future<String?> get userId => channel.invokeMethod<String>('userId');

  /// The installation id: the `mobile_push` identity of the profile while push can be sent.
  static Future<String?> get installationId => channel.invokeMethod<String>('installationId');

  static List<OneTraceFeedCard> _cards(List<Object?>? cards) => [
    for (final card in cards ?? const <Object?>[])
      if (card is Map) OneTraceFeedCard.fromMap(card),
  ];

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
