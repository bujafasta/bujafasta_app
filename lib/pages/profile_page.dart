import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/services/shop_navigation.dart';
import 'package:bujafasta_app/pages/admin/admin_page.dart';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:bujafasta_app/pages/wallet/wallet_page.dart';
import 'package:bujafasta_app/pages/buyer/my_orders_page.dart';
import 'package:bujafasta_app/services/device_service.dart';
import 'package:bujafasta_app/widgets/complete_profile_banner.dart';
import 'package:bujafasta_app/state/profile_completion_state.dart';
import 'package:bujafasta_app/state/seller_pending_order_state.dart';
import 'package:bujafasta_app/pages/product/product_details_page.dart';
import 'package:bujafasta_app/state/auth_state.dart';
import 'package:bujafasta_app/pages/settings/password_pin_management_page.dart';
import 'package:bujafasta_app/pages/settings/personal_account_info_page.dart';
import 'package:bujafasta_app/services/pin_cache_service.dart';
import 'package:bujafasta_app/pages/wallet/pin_verify_screen.dart';
import 'package:bujafasta_app/screens/auth/complete_profile_page.dart';
import 'package:bujafasta_app/pages/wallet/pin_setup_screen.dart';
import 'package:bujafasta_app/services/shop_cache_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:bujafasta_app/models/product.dart';

class ProfilePage extends StatefulWidget {
  // =========================================================
  // 🔓 OPEN FAVORITES FROM ANYWHERE (BOTTOM NAV, PROFILE, ETC)
  // =========================================================
  static void openFavoritesFromAnywhere(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ProfileFavoritesSheet(),
    );
  }

  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // ================= FEEDBACK STATE =================
  bool _showFeedback = false;
  bool _sendingFeedback = false;
  final TextEditingController _feedbackController = TextEditingController();
  // ================= HELP STATE =================
  bool _showHelp = false;

  bool _hasWalletPin = false;
  bool _pinChecked = false;

  void _openSettingsPage() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: const Text(
                "Settings",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              centerTitle: true,
            ),
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _settingsItem(
                    icon: Icons.person_outline,
                    title: "Personal info & account details",
                    subtitle: "View and manage your personal information",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PersonalAccountInfoPage(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  _settingsItem(
                    icon: Icons.lock_outline,
                    title: "Password & PIN management",
                    subtitle: "Password and wallet PIN settings",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PasswordPinManagementPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool get _isLoggedIn => Supabase.instance.client.auth.currentUser != null;
  bool _isLoggingOut = false;

  void _openFavoritesSheet() {
    ProfilePage.openFavoritesFromAnywhere(context);
  }

  Future<void> _loadCachedPinStatus() async {
    // 1️⃣ Try local cache first (FAST)
    final cached = await PinCacheService.getPinSet();

    if (cached != null) {
      setState(() {
        _hasWalletPin = cached;
        _pinChecked = true;
      });
      return;
    }

    // 2️⃣ Fallback: check DB once (FIRST INSTALL ONLY)
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final profile = await Supabase.instance.client
        .from('profiles')
        .select('pin_set')
        .eq('id', user.id)
        .maybeSingle();

    final bool pinSet = profile?['pin_set'] == true;

    // 3️⃣ Cache it forever
    await PinCacheService.setPinSet(pinSet);

    setState(() {
      _hasWalletPin = pinSet;
      _pinChecked = true;
    });
  }

  bool _profileComplete = true;
  bool _checkingProfile = true;

  final ValueNotifier<int> _bannerNudge = ValueNotifier(0);

  static const Color kAccent = Color(0xFFFFAA07);

  String _fullName = "Loading...";
  bool _isAdmin = false;

  String? _avatarUrl;
  Uint8List? _avatarBytes;
  String _avatarCacheKey = '';
  bool _isUploadingAvatar = false;
  bool _avatarUploadFailed = false;
  String? _avatarErrorMessage;

  @override
  void initState() {
    super.initState();
    _loadCachedPinStatus(); // 👈 ADD THIS (VERY IMPORTANT)

    _loadUserName();
    _checkIfAdmin();
    _checkProfileCompletion();

    // 🔔 LISTEN TO GLOBAL PROFILE STATE
    profileCompleteNotifier.addListener(_onProfileCompletionChanged);

    // 🔔 LISTEN TO BANNER NUDGE (ONLY ONCE)
    _bannerNudge.addListener(() {
      _refreshProfile();
    });
  }

  void _onProfileCompletionChanged() {
    if (!mounted) return;

    setState(() {
      _profileComplete = profileCompleteNotifier.value;
      _checkingProfile = false;
    });

    // also reload visible data if profile just completed
    if (_profileComplete) {
      _loadUserName();
    }
  }

  void _requireCompleteProfile(VoidCallback action) {
    if (_checkingProfile) return;

    if (_profileComplete) {
      action(); // ✅ allow navigation
    } else {
      // ❌ block + trigger angry banner
      _bannerNudge.value++;
    }
  }

  Future<void> _refreshProfile() async {
    // 1️⃣ re-check completion
    await _checkProfileCompletion();

    // 2️⃣ reload profile info (name + avatar)
    await _loadUserName();
  }

  Future<void> _checkProfileCompletion() async {
    final client = Supabase.instance.client;

    try {
      final bool isComplete = await client.rpc<bool>('is_profile_complete');

      if (!mounted) return;

      setState(() {
        _profileComplete = isComplete;
        _checkingProfile = false;
      });

      // 🔔 TELL THE WHOLE APP
      profileCompleteNotifier.value = isComplete;
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _profileComplete = true; // fail-safe
        _checkingProfile = false;
      });

      // 🔔 fail-safe also updates app state
      profileCompleteNotifier.value = true;
    }
  }

  Future<void> _checkIfAdmin() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    final data = await client
        .from('user_roles')
        .select('is_admin')
        .eq('user_id', user.id)
        .maybeSingle();

    if (data != null && data['is_admin'] == true) {
      setState(() => _isAdmin = true);
    }
  }

  Future<void> _loadUserName() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      setState(() => _fullName = "Log in");
      return;
    }

    final data = await client
        .from('profiles')
        .select('first_name, last_name, avatar_url')
        .eq('id', user.id)
        .maybeSingle();

    if (data == null) {
      setState(() => _fullName = "Complete your profile");
      return;
    }

    final first = data['first_name'] ?? "";
    final last = data['last_name'] ?? "";

    setState(() {
      _fullName = "$first $last".trim().isEmpty
          ? "Complete your profile"
          : "$first $last".trim();

      _avatarUrl = data['avatar_url'];
    });
  }

  Widget _menuItem({
    required String label,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 26, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _settingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, size: 26),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Profile',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // 🔽 MAIN SCROLLABLE CONTENT
          _showFeedback
              ? _feedbackView()
              : _showHelp
              ? _helpView()
              : RefreshIndicator(
                  color: const Color(0xFFFFAA07),
                  onRefresh: () async {
                    // 👇 force avatar reload
                    setState(() {
                      _avatarCacheKey = DateTime.now().millisecondsSinceEpoch
                          .toString();
                    });

                    await _refreshProfile();
                  },
                  child: SingleChildScrollView(
                    physics:
                        const AlwaysScrollableScrollPhysics(), // 👈 REQUIRED
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                    child: Column(
                      children: [
                        Column(
                          children: [
                            GestureDetector(
                              onTap: _showAvatarOptions,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // 🔄 LOADING / ERROR RING
                                  if (_isUploadingAvatar || _avatarUploadFailed)
                                    SizedBox(
                                      width: 98,
                                      height: 98,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 3,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              _avatarUploadFailed
                                                  ? Colors.red
                                                  : const Color(0xFFFFAA07),
                                            ),
                                      ),
                                    ),

                                  // 🖼️ AVATAR WITH TINY BORDER
                                  Container(
                                    padding: const EdgeInsets.all(
                                      1,
                                    ), // tiny separator
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                        width: 1,
                                      ),
                                    ),
                                    child: CircleAvatar(
                                      radius: 45,
                                      backgroundColor: Colors.grey.shade300,
                                      child: _avatarBytes != null
                                          ? ClipOval(
                                              child: Image.memory(
                                                _avatarBytes!,
                                                width: 90,
                                                height: 90,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                          : (_avatarUrl != null &&
                                                _avatarUrl!.isNotEmpty)
                                          ? ClipOval(
                                              child: CachedNetworkImage(
                                                imageUrl:
                                                    '$_avatarUrl?cache=$_avatarCacheKey',
                                                width: 90,
                                                height: 90,
                                                fit: BoxFit.cover,

                                                // 👇 shows while loading
                                                placeholder: (context, url) =>
                                                    Shimmer.fromColors(
                                                      baseColor:
                                                          Colors.grey.shade300,
                                                      highlightColor:
                                                          Colors.grey.shade100,
                                                      child: Container(
                                                        width: 90,
                                                        height: 90,
                                                        decoration:
                                                            BoxDecoration(
                                                              color:
                                                                  Colors.grey,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                      ),
                                                    ),

                                                // 👇 shows when offline / error
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(
                                                          Icons.person,
                                                          size: 50,
                                                          color: Colors.white,
                                                        ),
                                              ),
                                            )
                                          : const Icon(
                                              Icons.person,
                                              size: 50,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),

                                  // ❌ ERROR TEXT
                                  if (_avatarErrorMessage != null)
                                    Positioned(
                                      bottom: -18,
                                      child: Text(
                                        _avatarErrorMessage!,
                                        style: const TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: !_isLoggedIn
                                  ? () {
                                      // 👉 Not logged in → Login page
                                      Navigator.pushNamed(context, '/login');
                                    }
                                  : (!_profileComplete
                                        ? () {
                                            // 👉 Logged in but profile incomplete → Complete profile
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    const CompleteProfilePage(),
                                              ),
                                            );
                                          }
                                        : null),
                              child: Text(
                                _fullName,
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: (!_isLoggedIn || !_profileComplete)
                                      ? kAccent // ✅ deep orange
                                      : Colors.black,
                                ),
                              ),
                            ),

                            const SizedBox(height: 25),
                          ],
                        ),

                        _menuItem(
                          label: "My Shop",
                          icon: Icons.storefront_outlined,
                          onTap: () => _requireCompleteProfile(
                            () => openMyShop(context),
                          ),
                        ),

                        const SizedBox(height: 15),

                        _menuItem(
                          label: "My Wallet",
                          icon: Icons.account_balance_wallet_outlined,
                          onTap: () {
                            _requireCompleteProfile(() async {
                              // 1️⃣ Must be logged in
                              if (!_isLoggedIn) {
                                Navigator.pushNamed(context, '/login');
                                return;
                              }

                              // 2️⃣ Wait until pin status is known
                              if (!_pinChecked) return;

                              // 3️⃣ PIN already set → VERIFY
                              if (_hasWalletPin) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PinVerifyScreen(
                                      onPinVerified: () {
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const WalletPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              } else {
                                // 4️⃣ PIN not set → SET PIN ONCE
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PinSetupScreen(
                                      onPinSet: () async {
                                        // 1️⃣ Cache pin (already correct)
                                        await PinCacheService.setPinSet(true);

                                        // 2️⃣ Update local state
                                        setState(() {
                                          _hasWalletPin = true;
                                        });

                                        // 3️⃣ GO STRAIGHT TO WALLET ✅
                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const WalletPage(),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                );
                              }
                            });
                          },
                        ),

                        const SizedBox(height: 15),

                        _menuItem(
                          label: "My Orders",
                          icon: Icons.shopping_bag_outlined,
                          onTap: () => _requireCompleteProfile(() {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MyOrdersPage(),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 15),

                        _menuItem(
                          label: "Favorites",
                          icon: Icons.favorite_border,
                          onTap: () =>
                              _requireCompleteProfile(_openFavoritesSheet),
                        ),

                        const SizedBox(height: 15),

                        _menuItem(
                          label: "Settings",
                          icon: Icons.settings_outlined,
                          onTap: _openSettingsPage,
                        ),

                        const SizedBox(height: 15),

                        _menuItem(
                          label: "Feedback",
                          icon: Icons.feedback_outlined,
                          onTap: () {
                            setState(() {
                              _showFeedback = true;
                            });
                          },
                        ),

                        const SizedBox(height: 15),

                        _menuItem(
                          label: "Help",
                          icon: Icons.help_outline,
                          onTap: () {
                            setState(() {
                              _showHelp = true;
                            });
                          },
                        ),

                        if (_isAdmin) ...[
                          const SizedBox(height: 15),
                          _menuItem(
                            label: "Admin Panel",
                            icon: Icons.admin_panel_settings_outlined,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const AdminPage(),
                                ),
                              );
                            },
                          ),
                        ],

                        const SizedBox(height: 30),

                        // 🔐 AUTH ACTION BUTTON (LOGIN / LOGOUT)
                        InkWell(
                          onTap: _isLoggingOut
                              ? null
                              : () {
                                  if (_isLoggedIn) {
                                    _confirmAndLogout();
                                  } else {
                                    Navigator.pushNamed(context, '/login');
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: _isLoggedIn
                                  ? kAccent.withValues(alpha: 0.15)
                                  : kAccent,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: _isLoggingOut
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.grey,
                                      ),
                                    )
                                  : Text(
                                      _isLoggedIn ? "LOG OUT" : "LOG IN",
                                      style: TextStyle(
                                        color: _isLoggedIn
                                            ? Colors.red.shade600
                                            : Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
          // 🔔 FIXED COMPLETE PROFILE BANNER (NOT SCROLLABLE)
          if (!_checkingProfile && !_profileComplete)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: CompleteProfileBanner(nudge: _bannerNudge),
            ),
        ],
      ),
    );
  }

  Widget _feedbackView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔙 BACK
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showFeedback = false;
                });
              },
            ),

            const SizedBox(height: 10),

            // 📝 TITLE
            const Text(
              "We can’t wait to hear your feedback 💛",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 16),

            const Text(
              "Your opinion helps us improve Buja Fasta for everyone.",
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),

            const SizedBox(height: 20),

            // ✍️ INPUT CARD
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _feedbackController,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: "Tell us what you think...",
                  border: InputBorder.none,
                ),
              ),
            ),

            const SizedBox(height: 24),

            // 📤 SUBMIT BUTTON
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _sendingFeedback ? null : _submitFeedback,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: kAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _sendingFeedback
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Submit feedback",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpView() {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔙 BACK
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                setState(() {
                  _showHelp = false;
                });
              },
            ),

            const SizedBox(height: 10),

            // 🆘 TITLE
            const Text(
              "Help & Support",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 20),

            // 📧 CONTACT CARD
            _helpCard(
              icon: Icons.email_outlined,
              title: "General Support",
              content: "contact@bujafasta.com",
            ),

            const SizedBox(height: 16),

            // 🚨 EMERGENCY CARD
            _helpCard(
              icon: Icons.warning_amber_rounded,
              title: "Emergency Support",
              content: "bujafasta@gmail.com",
            ),

            const SizedBox(height: 20),

            // ℹ️ INFO BOX
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                "You can also use the live assistance inside the app. "
                "Our support team will try to help you as soon as possible.\n\n"
                "Please note: some issues may take up to 24 hours to be reviewed "
                "before the team starts handling them.",
                style: TextStyle(fontSize: 14, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _helpCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: kAccent, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _submitFeedback() async {
    final message = _feedbackController.text.trim();

    // ❌ Empty message guard
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please write something before submitting"),
        ),
      );
      return;
    }

    setState(() {
      _sendingFeedback = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;

      await Supabase.instance.client.from('user_feedback').insert({
        'user_id': user?.id,
        'message': message,
      });

      // clear input
      _feedbackController.clear();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Thank you for your feedback 💛")),
      );

      // go back to profile
      setState(() {
        _showFeedback = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Something went wrong. Please try again."),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _sendingFeedback = false;
        });
      }
    }
  }

  // ================= AVATAR OPTIONS =================

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text("Preview profile"),
                onTap: () {
                  Navigator.pop(context);
                  _previewAvatar();
                },
              ),
              ListTile(
                leading: const Icon(Icons.image),
                title: const Text("Change image"),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadAvatar();
                },
              ),
              if (_avatarUrl != null)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text(
                    "Remove profile image",
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _confirmRemoveAvatar();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _previewAvatar() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: AspectRatio(
          aspectRatio: 1,
          child: _avatarUrl != null
              ? Image.network(_avatarUrl!, fit: BoxFit.cover)
              : const Icon(Icons.person, size: 100, color: Colors.white),
        ),
      ),
    );
  }

  void _confirmRemoveAvatar() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Remove profile image"),
        content: const Text(
          "Are you sure you want to remove your profile image?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await Supabase.instance.client
                  .from('profiles')
                  .update({'avatar_url': null})
                  .eq('id', Supabase.instance.client.auth.currentUser!.id);

              setState(() {
                _avatarUrl = null;
                _avatarBytes = null;
                _avatarCacheKey = '';
              });
            },
            child: const Text("Remove", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickAndUploadAvatar() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.single.bytes == null) return;

    final bytes = result.files.single.bytes!;

    // 👉 Show preview immediately
    setState(() {
      _avatarBytes = bytes;
      _isUploadingAvatar = true;
      _avatarUploadFailed = false;
      _avatarErrorMessage = null;
    });

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final path = '${user.id}/avatar_$timestamp.png';

    try {
      await Supabase.instance.client.storage
          .from('user_avatars')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              upsert: true,
              contentType: 'image/png',
            ),
          );

      final publicUrl = Supabase.instance.client.storage
          .from('user_avatars')
          .getPublicUrl(path);

      await Supabase.instance.client
          .from('profiles')
          .update({'avatar_url': publicUrl})
          .eq('id', user.id);

      setState(() {
        _avatarUrl = publicUrl;
        _avatarCacheKey = timestamp.toString();
        _avatarBytes = null;
        _isUploadingAvatar = false;
      });
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
        _avatarUploadFailed = true;
        _avatarErrorMessage = 'Upload failed';
      });
    }
  }

  Future<void> _confirmAndLogout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    // User pressed NO or closed dialog
    if (shouldLogout != true) return;

    // ✅ NOW user really confirmed logout
    setState(() {
      _isLoggingOut = true;
    });

    // ✅ USER CONFIRMED LOGOUT
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user != null) {
      // 1️⃣ Get device ID
      final deviceId = await getDeviceId();

      // 2️⃣ Detach this device from the user
      await client
          .from('user_devices')
          .delete()
          .eq('device_id', deviceId)
          .eq('user_id', user.id);
    }

    // 3️⃣ STOP SELLER ORDER WATCHER (GLOBAL CLEANUP)
    await stopSellerPendingOrderWatcher();

    // 4️⃣ CLEAR LOCAL CACHES (VERY IMPORTANT)
    await PinCacheService.clear(); // wallet / pin state
    await ShopCacheService.clear(); // seller / shop state

    // 5️⃣ Sign out from Supabase
    await Supabase.instance.client.auth.signOut();

    // 🔔 TELL THE WHOLE APP: USER IS LOGGED OUT
    isLoggedInNotifier.value = false;

    // 4️⃣ Go to login
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  void dispose() {
    profileCompleteNotifier.removeListener(_onProfileCompletionChanged);
    _bannerNudge.dispose();
    super.dispose();
  }
}

// =========================================================
// ❤️ FAVORITES BOTTOM SHEET (REUSED EVERYWHERE)
// =========================================================

class _ProfileFavoritesSheet extends StatefulWidget {
  const _ProfileFavoritesSheet({super.key});

  @override
  State<_ProfileFavoritesSheet> createState() => _ProfileFavoritesSheetState();
}

class _ProfileFavoritesSheetState extends State<_ProfileFavoritesSheet> {
  List<Map<String, dynamic>> _favorites = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      setState(() {
        _favorites = [];
        _loading = false;
      });
      return;
    }

    final res = await client
        .from('favorites')
        .select('''
      product_id,
      products!inner (
        id,
        name,
        price,
        image_urls,
        is_hidden,
        is_deleted,     
        status,
        owner_id,
        shop_id
      )
    ''')
        .eq('user_id', user.id)
        .eq('products.is_hidden', false)
        .eq('products.is_deleted', false) // 👈 ADD THIS
        .eq('products.status', 'approved')
        .order('created_at', ascending: false);

    final rawFavorites = List<Map<String, dynamic>>.from(res);

    final filteredFavorites = rawFavorites.where((f) {
      final product = f['products'];
      if (product == null) return false;

      return product['is_hidden'] != true &&
          product['is_deleted'] != true &&
          product['status'] == 'approved';
    }).toList();

    setState(() {
      _favorites = filteredFavorites;
      _loading = false;
    });

    // 🔔 SHOW MESSAGE ONLY IF SOME WERE REMOVED
    if (mounted && rawFavorites.length > filteredFavorites.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Some favorites were removed because they are no longer available',
          ),
        ),
      );
    }
  }

  Future<void> _removeFavorite(int productId) async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    await client
        .from('favorites')
        .delete()
        .eq('user_id', user.id)
        .eq('product_id', productId);

    setState(() {
      _favorites.removeWhere((f) => f['product_id'] == productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          "Your Favorites",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  const Text(
                    "Favorites may be removed if no longer available.",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: _loading
                    ? const Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.grey,
                            ),
                          ),
                        ),
                      )
                    : _favorites.isEmpty
                    ? const Center(child: Text("No favorites yet ❤️"))
                    : ListView.separated(
                        itemCount: _favorites.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final product = _favorites[index]['products'];
                          final productId = _favorites[index]['product_id'];

                          final images = (product['image_urls'] as List?) ?? [];

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),

                            leading: images.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      images.first,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : const Icon(
                                    Icons.image_not_supported,
                                    size: 40,
                                    color: Colors.grey,
                                  ),

                            title: Text(
                              product['name'],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13, // 👈 small
                                fontWeight:
                                    FontWeight.w600, // 👈 strong but not loud
                                color: Colors.black87,
                              ),
                            ),

                            subtitle: Text(
                              "${product['price']} BIF",
                              style: const TextStyle(
                                fontSize: 11, // 👈 very small
                                color: Colors.grey, // 👈 low attention
                                fontWeight: FontWeight.w400,
                              ),
                            ),

                            trailing: IconButton(
                              icon: const Icon(
                                Icons.close, // 👈 quieter than delete
                                size: 18,
                                color: Colors.grey, // 👈 low attention
                              ),

                              onPressed: () async {
                                await _removeFavorite(productId);
                              },
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailsPage(
                                    product: Product.fromMap(product),
                                    shopId: product['shop_id'],
                                    sellerId: product['owner_id'],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
