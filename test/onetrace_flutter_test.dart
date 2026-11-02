import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:onetrace_flutter/onetrace_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(OneTrace.channel, (
      call,
    ) async {
      calls.add(call);

      return call.method == 'anonymousId' ? 'anon-1' : null;
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
