import 'package:intl/intl.dart';

class TimeUtils {
  /// Convert UTC time from Supabase to local device time
  static DateTime toLocal(DateTime utcTime) {
    return utcTime.toLocal();
  }

  /// Format UTC time nicely for UI
  static String format(
    DateTime utcTime, {
    String pattern = 'dd MMM yyyy, HH:mm',
  }) {
    final local = utcTime.toLocal();
    return DateFormat(pattern).format(local);
  }

  /// Short time (for chat, orders, etc.)
  static String timeOnly(DateTime utcTime) {
    return DateFormat('HH:mm').format(utcTime.toLocal());
  }

  /// Date only
  static String dateOnly(DateTime utcTime) {
    return DateFormat('dd MMM yyyy').format(utcTime.toLocal());
  }
}
