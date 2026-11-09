import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onetrace_flutter/onetrace_flutter.dart';

/// Run with your project's write key and address:
/// `flutter run --dart-define=ONETRACE_WRITE_KEY=cdp_wk_… --dart-define=ONETRACE_HOST=https://crm.example.com`
const writeKey = String.fromEnvironment('ONETRACE_WRITE_KEY');
const host = String.fromEnvironment('ONETRACE_HOST');

/// A local OneTrace from the Android emulator (10.0.2.2 is the computer) or the iOS simulator.
String get defaultHost =>
    defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:8180' : 'http://localhost:8180';

const products = [
  (id: 'SKU-1', name: 'Running shoes', price: 89.9),
  (id: 'SKU-2', name: 'Trail jacket', price: 149.0),
  (id: 'SKU-3', name: 'Water bottle', price: 12.5),
];

Future<void> main() async {
  if (writeKey.isNotEmpty) {
    await OneTrace.init(
      OneTraceConfig(writeKey: writeKey, host: host.isEmpty ? defaultHost : host, flushAt: 1, debug: true),
    );
  }

  runApp(const ShopApp());
}

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OneTrace demo shop',
      theme: ThemeData(colorSchemeSeed: const Color(0xFF4F46E5)),
      navigatorObservers: [OneTraceNavigatorObserver()],
      routes: {'/': (_) => const HomeScreen()},
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) =>
            ProductScreen(product: products.firstWhere((product) => '/product/${product.id}' == settings.name)),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? userId;
  String? anonymousId;
  String? installationId;

  @override
  void initState() {
    super.initState();
    refreshIds();
  }

  Future<void> refreshIds() async {
    final ids = await Future.wait([OneTrace.userId, OneTrace.anonymousId, OneTrace.installationId]);
    setState(() {
      userId = ids[0];
      anonymousId = ids[1];
      installationId = ids[2];
    });
  }

  Future<void> signIn() async {
    await OneTrace.identify('demo-anna', {'email': 'anna@example.com', 'first_name': 'Anna'});
    await OneTrace.track('signed_in');
    await refreshIds();
  }

  Future<void> signOut() async {
    await OneTrace.reset();
    await refreshIds();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('OneTrace demo shop'),
        actions: [
          // The message feed: the native screen, with the unread count as a badge.
          StreamBuilder<int>(
            stream: OneTrace.feedUnread,
            builder: (context, unread) => IconButton(
              tooltip: 'Updates',
              onPressed: OneTrace.openFeed,
              icon: Badge(
                isLabelVisible: (unread.data ?? 0) > 0,
                label: Text('${unread.data ?? 0}'),
                child: const Icon(Icons.notifications_outlined),
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (writeKey.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('Start the app with --dart-define=ONETRACE_WRITE_KEY=cdp_wk_… to send events.'),
              ),
            ),
          for (final product in products)
            ListTile(
              title: Text(product.name),
              subtitle: Text('${product.price}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).pushNamed('/product/${product.id}'),
            ),
          const Divider(),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              userId == null
                  ? FilledButton(onPressed: signIn, child: const Text('Sign in as Anna'))
                  : OutlinedButton(onPressed: signOut, child: const Text('Sign out')),
              OutlinedButton(onPressed: OneTrace.fetchInAppMessages, child: const Text('Check in-app messages')),
              OutlinedButton(onPressed: OneTrace.flush, child: const Text('Send events now')),
            ],
          ),
          const SizedBox(height: 16),
          SelectableText(
            'User: ${userId ?? '—'}\nAnonymous id: ${anonymousId ?? '—'}\nInstallation: ${installationId ?? '—'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ProductScreen extends StatefulWidget {
  const ProductScreen({super.key, required this.product});

  final ({String id, String name, double price}) product;

  @override
  State<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends State<ProductScreen> {
  @override
  void initState() {
    super.initState();
    OneTrace.track('product_viewed', {'product_id': widget.product.id, 'price': widget.product.price});
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;

    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${product.price}', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('Add to cart'),
              onPressed: () {
                OneTrace.track('add_to_cart', {'product_id': product.id, 'price': product.price, 'quantity': 1});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart')));
              },
            ),
          ],
        ),
      ),
    );
  }
}
