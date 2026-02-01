import 'package:supabase_flutter/supabase_flutter.dart';

class GlobalMessageListener {
  static RealtimeChannel? _channel;

  static void start() {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return;

    // 🔥 LISTEN TO ALL MESSAGES FOR THIS USER (ANY CHAT)
    _channel = supabase
        .channel('global_messages_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (payload) async {
            final m = payload.newRecord;

            // Ignore my own messages
            if (m['recipient_id'] != user.id) return;

            // Only mark SENT → DELIVERED
            if (m['status'] == 'sent') {
              await supabase
                  .from('messages')
                  .update({'status': 'delivered'})
                  .eq('id', m['id'])
                  .eq('status', 'sent'); // 🔒 safe update
            }
          },
        )
        .subscribe();
  }

  static void stop() {
    _channel?.unsubscribe();
    _channel = null;
  }
}
