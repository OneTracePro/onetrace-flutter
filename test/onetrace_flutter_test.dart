import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetrace_flutter/onetrace_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  final feed = [
    {
      'token': 'f1.sig',
      'layout': 'captioned',
      'title': 'Spring sale',
      'body': '−20 % on shoes',
      'imageUrl': 'https://cdn.example.com/sale.jpg',
      'buttonText': 'Shop now',
      'buttonUrl': 'shopapp://sale',
      'pinned': true,
      'read': false,
      'createdAt': 1794218400000,
      'expiresAt': null,
      'opensOnTap': false,
    },
    {'token': 'f2.sig', 'layout': 'mosaic', 'title': 'News', 'read': true},
  ];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(OneTrace.channel, (
      call,
    ) async {
      calls.add(call);

      return switch (call.method) {
        'anonymousId' => 'anon-1',
        'fetchFeed' || 'feedCards' => feed,
        'feedUnreadCount' => 1,
        'handlePush' => true,
        _ => null,
      };
    });
  });

  test('starts the native SDK with the settings and the wrapper version', () async {
    await OneTrace.init(
      const OneTraceConfig(
        writeKey: 'cdp_wk_test',
        host: 'https://crm.example.com',
        flushInterval: Duration(minutes: 1),
        debug: true,
      ),
    );

    expect(calls.single.method, 'init');
    expect(calls.single.arguments, {
      'writeKey': 'cdp_wk_test',
      'host': 'https://crm.example.com',
      'flushAt': 20,
      'flushIntervalSeconds': 60,
      'maxQueueSize': 1000,
      'trackLifecycle': true,
      'openPushLinks': true,
      'debug': true,
      'wrapper': 'flutter',
      'wrapperVersion': OneTrace.version,
    });
  });

  test('turns dates and other objects into values the channel can carry', () async {
    await OneTrace.track('order_completed', {
      'amount': 1250.5,
      'items': [
        {'product_id': 'SKU-1', 'quantity': 1},
      ],
      'paid_at': DateTime.utc(2026, 10, 30, 12),
      'status': Uri.parse('https://shop.example.com/orders/1'),
      'coupon': null,
    });

    expect(calls.single.arguments, {
      'event': 'order_completed',
      'properties': {
        'amount': 1250.5,
        'items': [
          {'product_id': 'SKU-1', 'quantity': 1},
        ],
        'paid_at': '2026-10-30T12:00:00.000Z',
        'status': 'https://shop.example.com/orders/1',
        'coupon': null,
      },
    });
  });

  test('passes on only OneTrace notifications', () async {
    expect(await OneTrace.notificationOpened({'google.message_id': '1'}), isFalse);
    await OneTrace.notificationReceived({'title': 'Not ours'});
    expect(calls, isEmpty);

    expect(
      await OneTrace.notificationOpened({
        'cdp_token': 'abc.def',
        'cdp_url': 'shopapp://sale',
        'badge': 2,
        'empty': null,
      }),
      isTrue,
    );
    expect(calls.single.method, 'notificationOpened');
    expect(calls.single.arguments, {
      'data': {'cdp_token': 'abc.def', 'cdp_url': 'shopapp://sale', 'badge': '2'},
    });
  });

  test('passes the rich push flag and the Remote Config interval to the native SDK only when they are set', () async {
    await OneTrace.init(
      const OneTraceConfig(
        writeKey: 'cdp_wk_test',
        host: 'https://crm.example.com',
        richPush: true,
        remoteConfigMinFetchInterval: Duration(minutes: 10),
      ),
    );

    expect(calls.single.arguments['richPush'], isTrue);
    expect(calls.single.arguments['remoteConfigMinFetchIntervalSeconds'], 600);

    calls.clear();
    await OneTrace.init(const OneTraceConfig(writeKey: 'cdp_wk_test', host: 'https://crm.example.com'));

    expect((calls.single.arguments as Map).containsKey('richPush'), isFalse);
    expect((calls.single.arguments as Map).containsKey('remoteConfigMinFetchIntervalSeconds'), isFalse);
  });

  test('passes the tapped button to the native SDK', () async {
    await OneTrace.notificationOpened({'cdp_token': 'abc.def'}, actionId: 'snooze');

    expect(calls.single.method, 'notificationOpened');
    expect(calls.single.arguments, {
      'data': {'cdp_token': 'abc.def'},
      'actionId': 'snooze',
    });
  });

  test('hands push data to the native SDK to draw and tells whether it was OneTrace push', () async {
    expect(await OneTrace.handlePush({'title': 'Not ours'}), isFalse);
    expect(calls, isEmpty);

    expect(await OneTrace.handlePush({'cdp_token': 'abc.def', 'cdp_kind': 'carousel', 'n': 3}), isTrue);
    expect(calls.single.method, 'handlePush');
    expect(calls.single.arguments, {
      'data': {'cdp_token': 'abc.def', 'cdp_kind': 'carousel', 'n': '3'},
    });
  });

  test('Remote Config methods call the native ones with the same arguments', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(OneTrace.channel, (
      call,
    ) async {
      calls.add(call);

      return switch (call.method) {
        'remoteConfigGetString' => 'blue',
        'remoteConfigGetBool' => true,
        'remoteConfigGetInt' => 7,
        'remoteConfigGetDouble' => 1.5,
        'remoteConfigGetJson' => '{"a":1}',
        'remoteConfigFetch' => true,
        _ => null,
      };
    });

    expect(await OneTrace.remoteConfig.getString('theme', 'red'), 'blue');
    expect(await OneTrace.remoteConfig.getBool('promo', false), isTrue);
    expect(await OneTrace.remoteConfig.getInt('limit', 1), 7);
    expect(await OneTrace.remoteConfig.getDouble('ratio', 0.5), 1.5);
    expect(await OneTrace.remoteConfig.getJson('menu', null), '{"a":1}');
    expect(await OneTrace.remoteConfig.fetch(), isTrue);

    expect(
      [for (final call in calls) call.method],
      [
        'remoteConfigGetString',
        'remoteConfigGetBool',
        'remoteConfigGetInt',
        'remoteConfigGetDouble',
        'remoteConfigGetJson',
        'remoteConfigFetch',
      ],
    );
    expect(calls[0].arguments, {'key': 'theme', 'default': 'red'});
    expect(calls[1].arguments, {'key': 'promo', 'default': false});
    expect(calls[2].arguments, {'key': 'limit', 'default': 1});
    expect(calls[3].arguments, {'key': 'ratio', 'default': 0.5});
    expect(calls[4].arguments, {'key': 'menu', 'default': null});
  });

  test('the Remote Config change stream starts the native listener and cancelling stops it', () async {
    final events = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      OneTrace.remoteConfigChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          events.add('listen');
          sink.success(['theme', 'promo']);
        },
        onCancel: (arguments) => events.add('cancel'),
      ),
    );

    final changes = <Set<String>>[];
    final subscription = OneTrace.remoteConfig.changes.listen(changes.add);
    await pumpEventQueue();
    expect(changes, [
      {'theme', 'promo'},
    ]);

    await subscription.cancel();
    await pumpEventQueue();
    expect(events, ['listen', 'cancel']);
  });

  test('geofence methods call the native ones and map the status', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(OneTrace.channel, (
      call,
    ) async {
      calls.add(call);

      return switch (call.method) {
        'enableGeofences' => 'backgroundPermissionMissing',
        'requestLocationPermission' => true,
        _ => null,
      };
    });

    expect(await OneTrace.enableGeofences(), GeofenceStatus.backgroundPermissionMissing);
    expect(await OneTrace.requestLocationPermission(), isTrue);
    await OneTrace.disableGeofences();

    expect(
      [for (final call in calls) call.method],
      ['enableGeofences', 'requestLocationPermission', 'disableGeofences'],
    );
  });

  test('sends identities, push tokens and reads ids', () async {
    await OneTrace.identify('u-42', {'email': 'anna@example.com'});
    await OneTrace.identify('u-42', {}, 'a1b2');
    await OneTrace.alias('u-43', 'c3d4');
    await OneTrace.setPushToken('apns-token', provider: PushProvider.apns);

    expect(calls.map((call) => call.arguments), [
      {
        'userId': 'u-42',
        'traits': {'email': 'anna@example.com'},
        'userHash': null,
      },
      {'userId': 'u-42', 'traits': {}, 'userHash': 'a1b2'},
      {'userId': 'u-43', 'userHash': 'c3d4'},
      {'token': 'apns-token', 'provider': 'apns'},
    ]);
    expect(await OneTrace.anonymousId, 'anon-1');
  });

  test('loads the message feed with every card field', () async {
    final cards = await OneTrace.fetchFeed();

    expect(calls.single.method, 'fetchFeed');
    expect(cards, hasLength(2));
    final sale = cards.first;
    expect(sale.token, 'f1.sig');
    expect(sale.layout, FeedCardLayout.captioned);
    expect(sale.title, 'Spring sale');
    expect(sale.body, '−20 % on shoes');
    expect(sale.imageUrl, 'https://cdn.example.com/sale.jpg');
    expect(sale.buttonText, 'Shop now');
    expect(sale.buttonUrl, 'shopapp://sale');
    expect(sale.pinned, isTrue);
    expect(sale.read, isFalse);
    expect(sale.createdAt, DateTime.utc(2026, 11, 9, 10));
    expect(sale.expiresAt, isNull);
    expect(sale.opensOnTap, isFalse);

    final news = cards.last;
    expect(news.layout, FeedCardLayout.classic, reason: 'an unknown layout falls back to classic');
    expect((news.body, news.buttonUrl, news.pinned, news.read), (null, null, false, true));

    expect((await OneTrace.feedCards).map((card) => card.token), ['f1.sig', 'f2.sig']);
    expect(await OneTrace.feedUnreadCount, 1);
  });

  test('reports shows, clicks and removals by card token and opens the ready-made feed screen', () async {
    const card = OneTraceFeedCard(token: 'f1.sig', title: 'Spring sale');
    await OneTrace.feedCardShown(card);
    await OneTrace.feedCardClicked(card);
    await OneTrace.feedCardDismissed(card);
    await OneTrace.openFeed(language: 'de');
    await OneTrace.openFeed();

    expect(calls.map((call) => call.method), [
      'feedCardShown',
      'feedCardClicked',
      'feedCardDismissed',
      'openFeed',
      'openFeed',
    ]);
    expect(calls.map((call) => call.arguments), [
      {'token': 'f1.sig'},
      {'token': 'f1.sig'},
      {'token': 'f1.sig'},
      {'language': 'de'},
      {'language': null},
    ]);
  });

  test('the unread count stream starts the native observer and cancelling stops it', () async {
    final events = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockStreamHandler(
      OneTrace.feedUnreadChannel,
      MockStreamHandler.inline(
        onListen: (arguments, sink) {
          events.add('listen');
          sink
            ..success(3)
            ..success(2);
        },
        onCancel: (arguments) => events.add('cancel'),
      ),
    );

    final counts = <int>[];
    final subscription = OneTrace.feedUnread.listen(counts.add);
    await pumpEventQueue();
    expect(counts, [3, 2]);

    await subscription.cancel();
    await pumpEventQueue();
    expect(events, ['listen', 'cancel']);
  });

  testWidgets('the navigator observer sends a screen for every named page route, not for dialogs', (tester) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [OneTraceNavigatorObserver()],
        routes: {'/': (_) => const Text('Home'), '/product': (_) => const Text('Product')},
      ),
    );

    navigator.currentState!.pushNamed('/product');
    await tester.pumpAndSettle();
    showDialog<void>(context: navigator.currentContext!, builder: (_) => const Text('Dialog'));
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    expect(calls.where((call) => call.method == 'screen').map((call) => call.arguments['name']), [
      '/',
      '/product',
      '/',
    ]);
  });
}
