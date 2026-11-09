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
