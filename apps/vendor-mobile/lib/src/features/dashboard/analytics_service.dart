import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

enum AnalyticsRange { today, sevenDays, thirtyDays, ninetyDays }

extension AnalyticsRangeX on AnalyticsRange {
  String get label => switch (this) {
        AnalyticsRange.today => 'Today',
        AnalyticsRange.sevenDays => '7 days',
        AnalyticsRange.thirtyDays => '30 days',
        AnalyticsRange.ninetyDays => '90 days',
      };

  Duration get window => switch (this) {
        AnalyticsRange.today => const Duration(days: 1),
        AnalyticsRange.sevenDays => const Duration(days: 7),
        AnalyticsRange.thirtyDays => const Duration(days: 30),
        AnalyticsRange.ninetyDays => const Duration(days: 90),
      };
}

class ItemStat {
  ItemStat({
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.revenueMinor,
    required this.orders,
  });

  final String itemId;
  final String itemName;
  final int quantity;
  final int revenueMinor;
  final int orders;

  factory ItemStat.fromJson(Map<String, dynamic> j) => ItemStat(
        itemId: j['itemId']?.toString() ?? '',
        itemName: j['itemName']?.toString() ?? 'Item',
        quantity: (j['quantity'] as num?)?.toInt() ?? 0,
        revenueMinor: (j['revenueMinor'] as num?)?.toInt() ?? 0,
        orders: (j['orders'] as num?)?.toInt() ?? 0,
      );
}

class DailyPoint {
  DailyPoint({required this.date, required this.orders, required this.revenueMinor});
  final String date;
  final int orders;
  final int revenueMinor;

  factory DailyPoint.fromJson(Map<String, dynamic> j) => DailyPoint(
        date: j['date']?.toString() ?? '',
        orders: (j['orders'] as num?)?.toInt() ?? 0,
        revenueMinor: (j['revenueMinor'] as num?)?.toInt() ?? 0,
      );
}

class VendorAnalytics {
  VendorAnalytics({
    required this.currency,
    required this.totalOrders,
    required this.grossRevenueMinor,
    required this.netRevenueMinor,
    required this.avgOrderValueMinor,
    required this.itemsSold,
    required this.ordersByStatus,
    required this.daily,
    required this.topItems,
  });

  final String currency;
  final int totalOrders;
  final int grossRevenueMinor;
  final int netRevenueMinor;
  final int avgOrderValueMinor;
  final int itemsSold;
  final Map<String, int> ordersByStatus;
  final List<DailyPoint> daily;
  final List<ItemStat> topItems;

  factory VendorAnalytics.fromJson(Map<String, dynamic> j) => VendorAnalytics(
        currency: j['currency']?.toString() ?? 'INR',
        totalOrders: (j['totalOrders'] as num?)?.toInt() ?? 0,
        grossRevenueMinor: (j['grossRevenueMinor'] as num?)?.toInt() ?? 0,
        netRevenueMinor: (j['netRevenueMinor'] as num?)?.toInt() ?? 0,
        avgOrderValueMinor: (j['avgOrderValueMinor'] as num?)?.toInt() ?? 0,
        itemsSold: (j['itemsSold'] as num?)?.toInt() ?? 0,
        ordersByStatus: ((j['ordersByStatus'] as Map?) ?? const {})
            .map((k, v) => MapEntry(k.toString(), (v as num?)?.toInt() ?? 0)),
        daily: ((j['daily'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(DailyPoint.fromJson)
            .toList(),
        topItems: ((j['topItems'] as List?) ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(ItemStat.fromJson)
            .toList(),
      );
}

typedef AnalyticsArgs = ({String vendorId, AnalyticsRange range});

final vendorAnalyticsProvider =
    FutureProvider.family.autoDispose<VendorAnalytics, AnalyticsArgs>((ref, args) async {
  final to = DateTime.now().toUtc();
  final from = to.subtract(args.range.window);
  final res = await ref.read(orderClientProvider).dio.get(
    '/api/v1/vendor/orders/analytics',
    queryParameters: {
      'vendorId': args.vendorId,
      'from': from.toIso8601String(),
      'to': to.toIso8601String(),
    },
  );
  return VendorAnalytics.fromJson(res.data as Map<String, dynamic>);
});
