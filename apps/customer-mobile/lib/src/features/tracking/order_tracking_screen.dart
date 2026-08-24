import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

class OrderTrackingScreen extends ConsumerStatefulWidget {
  const OrderTrackingScreen({super.key, required this.orderId});

  final String orderId;

  @override
  ConsumerState<OrderTrackingScreen> createState() =>
      _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends ConsumerState<OrderTrackingScreen> {
  Timer? _fallbackPoll;
  StompClient? _stomp;
  bool _stompConnected = false;
  Map<String, dynamic>? _state;
  String? _error;

  static const _terminalStatuses = {
    'COMPLETED',
    'COLLECTED',
    'CANCELLED',
    'VENDOR_REJECTED',
    'EXPIRED',
    'PAYMENT_FAILED',
    'DELIVERY_FAILED',
    'CUSTOMER_NO_SHOW',
    'REFUNDED',
  };

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _fetchOnce();
    await _connectStomp();
    _fallbackPoll = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_stompConnected) _fetchOnce();
    });
  }

  @override
  void dispose() {
    _fallbackPoll?.cancel();
    _stomp?.deactivate();
    super.dispose();
  }

  Future<void> _fetchOnce() async {
    try {
      final res = await ref
          .read(trackingClientProvider)
          .dio
          .get('/api/v1/tracking/orders/${widget.orderId}');
      if (!mounted) return;
      setState(() {
        _state = res.data as Map<String, dynamic>;
        _error = null;
      });
      _stopLiveUpdatesIfTerminal(_state?['status']?.toString());
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No tracking updates yet.');
    }
  }

  Future<void> _connectStomp() async {
    final token = await ref.read(tokenStorageProvider).readAccess();
    if (token == null || token.isEmpty) return;
    final base = ref.read(appConfigProvider).trackingBaseUrl;
    final wsUrl = '${base.replaceFirst('http', 'ws')}/ws-tracking?access_token='
        '${Uri.encodeQueryComponent(token)}';

    _stomp = StompClient(
      config: StompConfig(
        url: wsUrl,
        stompConnectHeaders: {'Authorization': 'Bearer $token'},
        webSocketConnectHeaders: {'Authorization': 'Bearer $token'},
        onConnect: (frame) {
          setState(() => _stompConnected = true);
          _stomp!.subscribe(
            destination: '/topic/orders/${widget.orderId}',
            callback: (StompFrame f) {
              if (f.body == null || !mounted) return;
              try {
                final payload = jsonDecode(f.body!) as Map<String, dynamic>;
                setState(() {
                  _state = payload;
                  _error = null;
                });
                _stopLiveUpdatesIfTerminal(payload['status']?.toString());
              } catch (_) {}
            },
          );
        },
        onDisconnect: (_) => setState(() => _stompConnected = false),
        onWebSocketError: (_) => setState(() => _stompConnected = false),
        onStompError: (_) => setState(() => _stompConnected = false),
        reconnectDelay: const Duration(seconds: 5),
      ),
    );
    _stomp!.activate();
  }

  void _stopLiveUpdatesIfTerminal(String? status) {
    if (status == null || !_terminalStatuses.contains(status)) return;
    _fallbackPoll?.cancel();
    _fallbackPoll = null;
    _stomp?.deactivate();
    _stomp = null;
    if (mounted && _stompConnected) setState(() => _stompConnected = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    final status = state?['status']?.toString() ?? 'PENDING';
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track order'),
        centerTitle: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(child: _LiveChip(live: _stompConnected)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchOnce,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            const PlayfulBanner(
              title: 'ON THE WAY',
              subtitle: 'Your food is making its campus rounds.',
              icon: Icons.delivery_dining_rounded,
              color: BhookColors.mint,
              margin: EdgeInsets.zero,
            ),
            const SizedBox(height: 20),
            _StatusHeadline(status: status),
            const SizedBox(height: 20),
            _Timeline(current: status),
            const SizedBox(height: 20),
            _MetaCard(
              partner: state?['partnerId']?.toString(),
              updated: _formatUpdatedAt(state?['updatedAt']?.toString()),
              lastLocation: state?['lastLocation'] as Map<String, dynamic>?,
            ),
            if (_error != null && state == null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                ),
                child: Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFFDC2626))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LiveChip extends StatelessWidget {
  const _LiveChip({required this.live});
  final bool live;
  @override
  Widget build(BuildContext context) {
    final color = live ? const Color(0xFF16A34A) : const Color(0xFF6B6C74);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 6),
        Text(live ? 'LIVE' : 'POLLING',
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 11,
                letterSpacing: 0.8)),
      ]),
    );
  }
}

class _StatusHeadline extends StatelessWidget {
  const _StatusHeadline({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (title, subtitle) = _describe(status);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEDEF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BhookColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.delivery_dining_rounded,
              color: BhookColors.primary, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: Color(0xFF191A1F))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        color: Color(0xFF6B6C74), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static (String, String) _describe(String status) {
    switch (status) {
      case 'PAYMENT_PENDING':
        return ('Awaiting payment', 'Complete payment to confirm your order');
      case 'PAID':
        return ('Payment received', 'Waiting for vendor confirmation');
      case 'VENDOR_ACCEPTED':
        return ('Order confirmed', 'Vendor will start preparing shortly');
      case 'PREPARING':
        return ('Preparing your order', 'Your food is being made fresh');
      case 'READY_FOR_PICKUP':
        return ('Ready for pickup', 'Waiting for delivery partner');
      case 'DELIVERY_ASSIGNED':
        return ('Partner assigned', 'On the way to collect your order');
      case 'PICKED_UP':
        return ('Picked up', 'Partner is heading to you');
      case 'OUT_FOR_DELIVERY':
        return ('Out for delivery', 'Almost at your pickup point');
      case 'COMPLETED':
        return ('Delivered', 'Enjoy your meal!');
      case 'CANCELLED':
        return ('Cancelled', 'This order was cancelled');
      default:
        return (status, '');
    }
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.current});
  final String current;

  @override
  Widget build(BuildContext context) {
    const steps = [
      ('Order placed', 'PAID'),
      ('Vendor accepted', 'VENDOR_ACCEPTED'),
      ('Preparing', 'PREPARING'),
      ('Ready for pickup', 'READY_FOR_PICKUP'),
      ('Out for delivery', 'OUT_FOR_DELIVERY'),
      ('Delivered', 'COMPLETED'),
    ];
    final order = [
      'PAYMENT_PENDING',
      'PAID',
      'VENDOR_ACCEPTED',
      'PREPARING',
      'READY_FOR_PICKUP',
      'DELIVERY_ASSIGNED',
      'PICKED_UP',
      'OUT_FOR_DELIVERY',
      'COMPLETED'
    ];
    final currentIndex = order.indexOf(current);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Progress',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2)),
          const SizedBox(height: 12),
          for (int i = 0; i < steps.length; i++)
            _TimelineRow(
              label: steps[i].$1,
              done: currentIndex >= order.indexOf(steps[i].$2),
              active: currentIndex >= 0 &&
                  order.indexOf(steps[i].$2) <= currentIndex &&
                  (i + 1 == steps.length ||
                      order.indexOf(steps[i + 1].$2) > currentIndex),
              isLast: i == steps.length - 1,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow(
      {required this.label,
      required this.done,
      required this.active,
      required this.isLast});
  final String label;
  final bool done;
  final bool active;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    const primary = BhookColors.primary;
    const success = Color(0xFF16A34A);
    final color = active ? primary : (done ? success : BhookColors.divider);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: (done || active) ? color : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done && !active
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                      width: 2, color: done ? success : BhookColors.divider),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 1, bottom: isLast ? 0 : 16),
              child: Text(
                label,
                style: TextStyle(
                  color: (done || active)
                      ? const Color(0xFF191A1F)
                      : const Color(0xFF9A9BA3),
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String? _formatUpdatedAt(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    final local = DateTime.parse(value).toLocal();
    return DateFormat('MMM d, yyyy · h:mm a').format(local);
  } catch (_) {
    return value;
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard(
      {required this.partner,
      required this.updated,
      required this.lastLocation});
  final String? partner;
  final String? updated;
  final Map<String, dynamic>? lastLocation;

  @override
  Widget build(BuildContext context) {
    if (partner == null && updated == null && lastLocation == null)
      return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Delivery details',
              style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: -0.2)),
          const SizedBox(height: 12),
          if (partner != null) _row(Icons.person_outline, 'Partner', partner!),
          if (updated != null) _row(Icons.access_time, 'Last update', updated!),
          if (lastLocation != null)
            _row(Icons.location_on_outlined, 'Location',
                '${lastLocation!['latitude']}, ${lastLocation!['longitude']}'),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Icon(icon, size: 16, color: const Color(0xFF6B6C74)),
          const SizedBox(width: 10),
          SizedBox(
              width: 100,
              child: Text(label,
                  style:
                      const TextStyle(color: Color(0xFF6B6C74), fontSize: 13))),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      color: Color(0xFF191A1F),
                      fontWeight: FontWeight.w600,
                      fontSize: 13))),
        ]),
      );
}
