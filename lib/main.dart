import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// App core
import 'package:bujafasta_app/services/app_connectivity.dart';
import 'package:bujafasta_app/deep_link_handler.dart';

// Pages
import 'package:bujafasta_app/screens/splash/splash_page.dart';
import 'package:bujafasta_app/pages/home_page.dart';
import 'package:bujafasta_app/pages/add_item_page.dart';
import 'package:bujafasta_app/pages/my_shop.dart';
import 'package:bujafasta_app/pages/profile_page.dart';
import 'package:bujafasta_app/pages/messages/chat_room_page.dart';

// Auth & shop flow
import 'package:bujafasta_app/screens/auth/login_page.dart' as auth_login;
import 'package:bujafasta_app/screens/auth/complete_profile_page.dart';
import 'package:bujafasta_app/screens/shop/create_shop_page.dart';
import 'package:bujafasta_app/screens/shop/create_shop_type_page.dart';
import 'package:bujafasta_app/screens/shop/create_shop_address_page.dart';
import 'package:bujafasta_app/screens/shop/shop_setup_loading.dart';
import 'package:bujafasta_app/screens/shop/create_shop_final_page.dart';
import 'package:bujafasta_app/screens/shop/create_shop_online_province_page.dart';

// Models
import 'package:bujafasta_app/models/product.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // App-wide connectivity listener (safe on web)
  AppConnectivity().initialize();

  // Supabase init (works on web)
  await Supabase.initialize(
    url: 'https://apcdtfczrkshvjggbjnh.supabase.co',
    anonKey: 'sb_publishable_3ccugtJmagtCBuJps_eSTQ_q1Jkm9XP',
  );

  runApp(const BujaFastaApp());
}

class BujaFastaApp extends StatefulWidget {
  const BujaFastaApp({super.key});

  @override
  State<BujaFastaApp> createState() => _BujaFastaAppState();
}

class _BujaFastaAppState extends State<BujaFastaApp> {
  late final DeepLinkHandler _deepLinkHandler;

  @override
  void initState() {
    super.initState();

    // Deep links (works on web + mobile)
    _deepLinkHandler = DeepLinkHandler(navigatorKey: navigatorKey);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _deepLinkHandler.init();
    });

    // Supabase auth listener (safe on web)
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      debugPrint('🔐 Auth event: ${data.event}');
    });
  }

  @override
  void dispose() {
    _deepLinkHandler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Buja Fasta',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),

      home: const SplashPage(),

      routes: {
        '/login': (_) => auth_login.LoginPage(),
        '/home': (_) => const MainNavigation(),
        '/complete-profile': (_) => const CompleteProfilePage(),

        '/create-shop': (_) => const CreateShopPage(),
        '/create-shop-type': (_) => const CreateShopTypePage(),
        '/create-shop-address': (_) => const CreateShopAddressPage(),
        '/shop-setup-loading': (_) => const ShopSetupLoading(),
        '/create-shop-final': (_) => const CreateShopFinalPage(),
        '/create-shop-online-province': (_) =>
            const CreateShopOnlineProvincePage(),
      },

      onGenerateRoute: (settings) {
        if (settings.name == '/chat_room') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => ChatRoomPage(
              chatId: args['chatId'],
              isCustomerCare: true,
            ),
          );
        }
        return null;
      },

      onUnknownRoute: (_) =>
          MaterialPageRoute(builder: (_) => const MainNavigation()),
    );
  }
}

// ================= MAIN NAVIGATION =================

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  bool _isSeller = false;
  bool _checkingRole = true;

  int _selectedIndex = 0;
  final List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _loadUserShop();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map && args['openShop'] == true) {
      setState(() => _selectedIndex = 2);
    }
  }

  Future<void> _loadUserShop() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      setState(() {
        _isSeller = false;
        _checkingRole = false;
      });
      return;
    }

    final shop = await client
        .from('shops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    setState(() {
      _isSeller = shop != null;
      _checkingRole = false;
    });
  }

  void _onItemTapped(int index) {
    if (index == 2 && !_isSeller) {
      ProfilePage.openFavoritesFromAnywhere(context);
      return;
    }
    setState(() => _selectedIndex = index);
  }

  void _addProduct(Product p) {
    setState(() => _products.insert(0, p));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Product posted')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      HomePage(products: _products),
      AddItemPage(onPost: _addProduct),
      _isSeller ? const MyShopPage() : const SizedBox(),
      const ProfilePage(),
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: const Color(0xFFFFAA07),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            activeIcon: Icon(Icons.add_box),
            label: 'Add Item',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              _isSeller ? Icons.storefront_outlined : Icons.favorite_border,
            ),
            activeIcon:
                Icon(_isSeller ? Icons.storefront : Icons.favorite),
            label: _isSeller ? 'My Shop' : 'Favorites',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
