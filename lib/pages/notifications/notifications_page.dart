import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bujafasta_app/utils/time_utils.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> notifications = [];
  bool loading = true;

  bool selectionMode = false;
  Set<int> selected = {};

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final data = await supabase
        .from('notifications')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    setState(() {
      notifications = List<Map<String, dynamic>>.from(data as List<dynamic>);
      loading = false;
    });
  }

  void toggleSelect(int id) {
    setState(() {
      if (selected.contains(id)) {
        selected.remove(id);
      } else {
        selected.add(id);
      }
      selectionMode = selected.isNotEmpty;
    });
  }

  Future<void> _deleteOne(int id) async {
    await supabase.from('notifications').delete().eq('id', id);
  }

  Future<void> _deleteSelected() async {
    if (selected.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete notifications?"),
        content: Text(
          "Are you sure you want to delete ${selected.length} items?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok != true) return;

    await supabase
        .from('notifications')
        .delete()
        .inFilter('id', selected.toList());

    setState(() {
      notifications.removeWhere((n) => selected.contains(n['id']));
      selected.clear();
      selectionMode = false;
    });
  }

  void _openLightbox(String? image, String name, String msg) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (image != null && image.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    image,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(msg, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Close"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatar(String? image, bool selected, {bool isError = false}) {
    return Stack(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundImage: (image != null && image.isNotEmpty)
              ? NetworkImage(image)
              : null,
          backgroundColor: isError ? Colors.red.shade50 : Colors.grey[200],
          child: (image == null || image.isEmpty)
              ? Icon(
                  isError ? Icons.error_outline : Icons.notifications_outlined,
                  color: isError ? Colors.red : Colors.grey[700],
                  size: 28,
                )
              : null,
        ),

        if (selected)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 26),
            ),
          ),
      ],
    );
  }

  Widget _buildTile(Map<String, dynamic> n) {
    final meta = n['metadata'] ?? {};

    final title = n['title']?.toString() ?? 'Notification';
    final message = n['message']?.toString() ?? '';

    final image = meta['product_image']?.toString();

    final type = n['type']?.toString(); // success, error, info
    final createdAt = n['created_at'];
    final id = n['id'];
    final isSelected = selected.contains(id);

    return Dismissible(
      key: ValueKey(id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      confirmDismiss: (_) async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Delete?"),
            content: const Text("Delete this notification?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Delete"),
              ),
            ],
          ),
        );
        return ok == true;
      },
      onDismissed: (_) async {
        await _deleteOne(id);
        setState(() {
          notifications.removeWhere((n) => n['id'] == id);
        });
      },
      child: Container(
        decoration: BoxDecoration(
          color: type == 'error'
              ? Colors.red.withValues(alpha: 0.10) // 👈 10% red
              : Colors.transparent,
        ),
        child: InkWell(
          onLongPress: () => toggleSelect(id),
          onTap: () async {
            if (selectionMode) {
              toggleSelect(id);
              return;
            }

            // mark as read
            await supabase
                .from('notifications')
                .update({'is_read': true})
                .eq('id', id);

            _openLightbox(image, title, message);
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _avatar(image, isSelected, isError: type == 'error'),

                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: type == 'error' ? Colors.red : Colors.black,
                        ),
                      ),

                      const SizedBox(height: 4),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: type == 'error' ? Colors.red : Colors.black87,
                        ),
                      ),

                      const SizedBox(height: 6),
                      Text(
                        TimeUtils.format(
                          DateTime.parse(createdAt),
                          pattern: 'dd MMM yyyy, HH:mm',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: type == 'error'
                              ? Colors.red.withValues(alpha: 0.7)
                              : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          selectionMode ? "${selected.length} selected" : "Notifications",
        ),
        actions: [
          if (selectionMode)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteSelected,
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _loadNotifications(),
        child: ListView.builder(
          itemCount: notifications.length,
          itemBuilder: (_, i) => _buildTile(notifications[i]),
        ),
      ),
    );
  }
}
