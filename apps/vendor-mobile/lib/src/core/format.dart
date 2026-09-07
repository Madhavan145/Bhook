import 'dart:convert';

class Money {
  static String format(int minor, {String currency = 'INR'}) {
    final rupees = minor / 100.0;
    final sym = switch (currency) {
      'INR' => '₹',
      'USD' => '\$',
      _ => '$currency ',
    };
    return '$sym${rupees.toStringAsFixed(2)}';
  }
}

String? extractApiError(Object error) {
  final text = error.toString();
  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  try {
    final data = jsonDecode(text.substring(start, end + 1)) as Map<String, dynamic>;
    final message = data['message']?.toString();
    return message == null || message.isEmpty ? null : message;
  } catch (_) {
    return null;
  }
}
