import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// ============================================
/// USER MODERATION PAGE
/// ============================================
/// CLIENT-SIDE: Only handles UI and calls server RPCs
/// SERVER-SIDE: All data fetching, permission checks, and actions
///
/// WHY:
/// - User counts must be accurate (can't trust client)
/// - Search on large datasets (performance)
/// - Suspend/unsuspend are critical admin actions (security)
/// ============================================

class UserModerationPage extends StatefulWidget {
  const UserModerationPage({super.key});

  @override
  State<UserModerationPage> createState() => _UserModerationPageState();
}

class _UserModerationPageState extends State<UserModerationPage>
    with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final TextEditingController _searchController = TextEditingController();

  late TabController _tabController;
  String _searchQuery = '';
  int _totalUsers = 0;
  int _suspendedUsers = 0;
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUserStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================
  // LOAD USER STATS (SERVER-SIDE RPC)
  // ============================================

  Future<void> _loadUserStats() async {
    setState(() {
      _isLoadingStats = true;
    });

    try {
      final result = await supabase.rpc('get_user_moderation_stats').single();

      setState(() {
        _totalUsers = result['total_users'] as int;
        _suspendedUsers = result['suspended_users'] as int;
        _isLoadingStats = false;
      });
    } catch (e) {
      debugPrint('Error loading user stats:  $e');
      setState(() {
        _isLoadingStats = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading stats: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================
  // FETCH USERS (SERVER-SIDE RPC)
  // ============================================

  Future<List<Map<String, dynamic>>> _fetchUsers(bool suspended) async {
    try {
      final result = await supabase.rpc(
        'search_users',
        params: {'search_term': _searchQuery, 'is_suspended_filter': suspended},
      );

      return List<Map<String, dynamic>>.from(result);
    } catch (e) {
      debugPrint('Error fetching users: $e');
      return [];
    }
  }

  // ============================================
  // SUSPEND USER (SERVER-SIDE RPC)
  // ============================================

  Future<void> _suspendUser(Map<String, dynamic> user) async {
    final controller = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Suspend User',
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'User:  ${user['first_name']} ${user['last_name']}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Suspension Reason',
                hintText: 'e.g., Violating community guidelines',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final reason = controller.text.trim();
    if (reason.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please provide a suspension reason'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      // Call server-side RPC
      final result = await supabase.rpc(
        'suspend_user_action',
        params: {
          'target_user_id': user['id'],
          'suspension_reason_text': reason,
        },
      );

      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Suspended:  ${user['first_name']} ${user['last_name']}',
            ),
            backgroundColor: Colors.red,
          ),
        );
        _loadUserStats();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error suspending user:  $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed:  ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================
  // UNSUSPEND USER (SERVER-SIDE RPC)
  // ============================================

  Future<void> _unsuspendUser(Map<String, dynamic> user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unsuspend User'),
        content: Text(
          'Are you sure you want to unsuspend ${user['first_name']} ${user['last_name']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unsuspend'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Call server-side RPC
      final result = await supabase.rpc(
        'unsuspend_user_action',
        params: {'target_user_id': user['id']},
      );

      if (mounted && result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Unsuspended: ${user['first_name']} ${user['last_name']}',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadUserStats();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error unsuspending user: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================
  // MESSAGE USER (Placeholder)
  // ============================================

  void _messageUser(Map<String, dynamic> user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Message feature coming soon for ${user['first_name']}'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  // ============================================
  // BUILD USER CARD (CLIENT-SIDE UI)
  // ============================================

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isSuspended = user['is_suspended'] == true;
    final name = '${user['first_name'] ?? ''} ${user['last_name'] ?? ''}'
        .trim();
    final phone = user['phone'] ?? 'No phone';
    final avatarUrl = user['avatar_url'];

    return Card(
      margin: const EdgeInsets.only(bottom: 6), // ⬅ smaller gap

      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        dense: true, // 🔥 very important
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),

        leading: CircleAvatar(
          radius: 22,

          backgroundColor: Colors.grey.shade200,
          backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
              ? NetworkImage(avatarUrl)
              : null,
          child: avatarUrl == null || avatarUrl.isEmpty
              ? Icon(Icons.person, size: 22, color: Colors.grey.shade600)
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name.isEmpty ? 'User' : name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (isSuspended)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'SUSPENDED',
                  style: TextStyle(
                    fontSize: 9,

                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('📱 $phone', style: const TextStyle(fontSize: 12)),

            if (isSuspended && user['suspension_reason'] != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '⚠️ ${user['suspension_reason']}',
                  style: const TextStyle(
                    fontSize: 11,

                    color: Colors.red,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case 'suspend':
                _suspendUser(user);
                break;
              case 'unsuspend':
                _unsuspendUser(user);
                break;
              case 'message':
                _messageUser(user);
                break;
            }
          },
          itemBuilder: (context) => [
            if (!isSuspended)
              const PopupMenuItem(
                value: 'suspend',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text('Suspend User'),
                  ],
                ),
              ),
            if (isSuspended)
              const PopupMenuItem(
                value: 'unsuspend',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 20),
                    SizedBox(width: 8),
                    Text('Unsuspend User'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'message',
              child: Row(
                children: [
                  Icon(Icons.message, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('Send Message'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // BUILD USER TAB (CLIENT-SIDE UI)
  // ============================================

  Widget _buildUserTab(bool suspended) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: SizedBox(
            height: 38,
            child: TextField(
              controller: _searchController,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Search user…',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
        ),

        // User List
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchUsers(suspended),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text('Error:  ${snapshot.error}'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => setState(() {}),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                );
              }

              final users = snapshot.data!;

              if (users.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        suspended ? 'No suspended users' : 'No users found',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  await _loadUserStats();
                  setState(() {});
                },
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: users.length,
                  itemBuilder: (_, i) => _buildUserCard(users[i]),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Stats Header
        // 🔢 SMALL STATS BAR (COMPACT)
        Container(
          margin: const EdgeInsets.only(top: 6, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: _isLoadingStats
              ? const SizedBox(
                  height: 24,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 👤 TOTAL USERS
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_totalUsers',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Users',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),

                    // 🔴 SUSPENDED USERS
                    Row(
                      children: [
                        const Icon(Icons.block, size: 18, color: Colors.red),
                        const SizedBox(width: 6),
                        Text(
                          '$_suspendedUsers',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Suspended',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      ],
                    ),
                  ],
                ),
        ),

        // Tabs
        SizedBox(
          height: 36, // 🔥 FORCE HEIGHT
          child: TabBar(
            controller: _tabController,
            padding: EdgeInsets.zero,
            labelPadding: const EdgeInsets.symmetric(horizontal: 6),
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
            tabs: const [
              Tab(icon: Icon(Icons.people, size: 14), text: 'Active'),
              Tab(icon: Icon(Icons.block, size: 14), text: 'Suspended'),
            ],
          ),
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildUserTab(false), // Active users
              _buildUserTab(true), // Suspended users
            ],
          ),
        ),
      ],
    );
  }
}
