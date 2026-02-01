import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../wallet/pin_setup_screen.dart';
import '../wallet/pin_verify_screen.dart';
import 'package:bujafasta_app/services/pin_cache_service.dart';

enum PasswordPinView { main, changePassword, walletPin }

class PasswordPinManagementPage extends StatefulWidget {
  const PasswordPinManagementPage({super.key});

  @override
  State<PasswordPinManagementPage> createState() =>
      _PasswordPinManagementPageState();
}

class _PasswordPinManagementPageState extends State<PasswordPinManagementPage> {
  bool _isLoadingPinStatus = true;
  bool _pinSet = false;
  bool _profileCompletionSnackShown = false;

  Future<void> _checkProfileCompletedAndPromptPin() async {
    if (_profileCompletionSnackShown) return;

    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await supabase
          .from('profiles')
          .select('is_complete, pin_set')
          .eq('id', user.id)
          .single();

      final bool isComplete = profile['is_complete'] == true;
      final bool pinSet = profile['pin_set'] == true;

      if (isComplete && !pinSet) {
        _profileCompletionSnackShown = true;

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile completed! Set your PIN now'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      // fail silently
    }
  }

  Future<void> _loadPinStatus() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      setState(() {
        _pinSet = false;
        _isLoadingPinStatus = false;
      });
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('pin_set')
          .eq('id', user.id)
          .single();

      setState(() {
        _pinSet = profile['pin_set'] == true;
        _isLoadingPinStatus = false;
      });
    } catch (_) {
      setState(() {
        _pinSet = false;
        _isLoadingPinStatus = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // runs when user comes back from complete-profile page
    _checkProfileCompletedAndPromptPin();
  }

  @override
  void initState() {
    super.initState();
    _loadPinStatus();
  }

  PasswordPinView _currentView = PasswordPinView.main;
  Future<void> _handleCreateWalletPin(BuildContext context) async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please log in first')));
      return;
    }

    try {
      final profile = await supabase
          .from('profiles')
          .select('is_complete, pin_set')
          .eq('id', user.id)
          .single();

      final bool isProfileComplete = profile['is_complete'] == true;
      final bool pinSet = profile['pin_set'] == true;

      if (!isProfileComplete) {
        showModalBottomSheet(
          context: context,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (_) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100, // 🩶 soft grey
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.deepOrange.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.info_outline,
                            color: Colors.deepOrange,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'Profile required',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black, // ⚫ strong title
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    const Text(
                      'To protect your wallet, you must complete your profile before creating a PIN.',
                      style: TextStyle(
                        fontSize: 12, // 👈 very small text
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange, // 🟠 action color
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pushNamed(context, '/complete-profile');
                        },
                        child: const Text(
                          'Complete profile',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
        return;
      }

      if (pinSet) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You already have a wallet PIN set')),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinSetupScreen(
            onPinSet: () async {
              Navigator.pop(context);

              await PinCacheService.setPinSet(true);

              setState(() {
                _pinSet = true;
              });

              showModalBottomSheet(
                context: context,
                isDismissible: false,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: const BoxDecoration(
                            color: Colors.deepOrange,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'PIN Set Successfully',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your wallet PIN has been set.\nYou’ll need to add money to start shopping.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.deepOrange,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context); // close success sheet

                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/home', // 👈 your HOME route
                                (route) => false,
                              );
                            },

                            child: const Text(
                              "Let's go shopping",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      );
    } catch (_) {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.deepOrange.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: Colors.deepOrange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Profile required',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'To protect your wallet, you must complete your profile before creating a PIN.',
                    style: TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepOrange,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(context, '/complete-profile');
                      },
                      child: const Text(
                        'Complete profile',
                        style: TextStyle(
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
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _currentView == PasswordPinView.main
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _currentView = PasswordPinView.main;
                  });
                },
              ),
        title: Text(
          _currentView == PasswordPinView.main
              ? "Password & PIN"
              : _currentView == PasswordPinView.changePassword
              ? "Change Password"
              : "Wallet PIN",
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _buildCurrentView(),
      ),
    );
  }

  /// 🔁 SWITCH BETWEEN STATES
  Widget _buildCurrentView() {
    switch (_currentView) {
      case PasswordPinView.changePassword:
        return _changePasswordView();

      case PasswordPinView.walletPin:
        return _walletPinView();

      case PasswordPinView.main:
      default:
        return _mainMenuView();
    }
  }

  /// 🔹 MAIN MENU
  Widget _mainMenuView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _optionItem(
          icon: Icons.lock_outline,
          title: "Account password",
          subtitle: "Update your login password",
          onTap: () {
            setState(() {
              _currentView = PasswordPinView.changePassword;
            });
          },
        ),
        const SizedBox(height: 12),
        _optionItem(
          icon: Icons.pin_outlined,
          title: "Wallet PIN",
          subtitle: "Secure your wallet with a PIN",
          onTap: () {
            setState(() {
              _currentView = PasswordPinView.walletPin;
            });
          },
        ),
      ],
    );
  }

  /// 🔐 CHANGE PASSWORD VIEW
  Widget _changePasswordView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          "Change account password",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 12),
        Text(
          "This feature is under construction, You’ll soon be able to change your password here.In the meantime, use Forgot Password to reset your password.",
          style: TextStyle(color: Colors.grey),
        ),
        SizedBox(height: 24),

        // 🔜 Password fields will go here later
        // Old password
        // New password
        // Confirm password
      ],
    );
  }

  /// 🔢 WALLET PIN VIEW
  Widget _walletPinView() {
    if (_isLoadingPinStatus) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 👉 CREATE PIN (only if not set)
        if (!_pinSet)
          _optionItem(
            icon: Icons.add_circle_outline,
            title: "Create wallet PIN",
            subtitle: "Set a new PIN for your wallet",
            onTap: () => _handleCreateWalletPin(context),
          ),

        // 👉 CHANGE PIN (only if already set)
        if (_pinSet) ...[
          _optionItem(
            icon: Icons.edit_outlined,
            title: "Change wallet PIN",
            subtitle: "Update your existing wallet PIN",
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                builder: (_) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange.withOpacity(0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.construction_outlined,
                                  color: Colors.deepOrange,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Expanded(
                                child: Text(
                                  'Change PIN coming soon',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          const Text(
                            'Changing your wallet PIN using your current PIN is not available yet.\n\n'
                            'To change your PIN, use the “Forgot PIN” option. '
                            'You will be asked for your account password, then you can set a new PIN.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],

        // 👉 SAFETY MESSAGE (optional UX polish)
        if (!_pinSet)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Text(
              "You don’t have a wallet PIN yet. Please create one first.",
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
      ],
    );
  }

  /// 🔧 REUSABLE ITEM
  Widget _optionItem({
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
}
