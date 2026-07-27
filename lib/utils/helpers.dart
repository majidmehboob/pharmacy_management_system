import 'package:intl/intl.dart';

class Helpers {
  static String formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  static String formatDate(String isoDateString) {
    try {
      final date = DateTime.parse(isoDateString);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return isoDateString;
    }
  }

  static String formatDateTime(String isoDateString) {
    try {
      final date = DateTime.parse(isoDateString);
      return DateFormat('yyyy-MM-dd hh:mm a').format(date);
    } catch (_) {
      return isoDateString;
    }
  }
}
