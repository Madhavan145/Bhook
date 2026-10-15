import 'dart:convert';

import 'package:dio/dio.dart';

class Money {
  static String format(int minor, {String currency = 'INR'}) {
    final rupees = minor / 100.0;
    return '${_symbol(currency)}${rupees.toStringAsFixed(2)}';
  }

  static String _symbol(String c) {
    switch (c) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return '$c ';
    }
  }
}

String? extractApiError(Object err) {
  if (err is DioException) {
    final data = err.response?.data;
    if (data is Map) {
      final message = data['message']?.toString();
      if (message != null && message.isNotEmpty) return message;
    }
  }
  final s = err.toString();
  final start = s.indexOf('{');
  final end = s.lastIndexOf('}');
  if (start >= 0 && end > start) {
    try {
      final json =
          jsonDecode(s.substring(start, end + 1)) as Map<String, dynamic>;
      final msg = json['message'] as String?;
      if (msg != null && msg.isNotEmpty) return msg;
    } catch (_) {}
  }
  return null;
}
