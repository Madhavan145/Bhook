import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

final _myTicketsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref.read(operationsClientProvider).dio.get(
        '/api/v1/support/tickets',
      );
  return ((response.data as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
});

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  final _subject = TextEditingController();
  final _details = TextEditingController();
  String _category = 'ORDER';
  bool _submitting = false;
  String? _error;

  static const _categories = <String, String>{
    'ORDER': 'Order issue',
    'PAYMENT': 'Payment issue',
    'ACCOUNT': 'Account help',
    'VENDOR': 'Vendor or dish',
    'OTHER': 'Something else',
  };

  @override
  void dispose() {
    _subject.dispose();
    _details.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_subject.text.trim().isEmpty || _details.text.trim().isEmpty) {
      setState(() => _error = 'Add a short subject and tell us what happened.');
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(operationsClientProvider).dio.post(
        '/api/v1/support/tickets',
        data: {
          'category': _category,
          'subject': _subject.text.trim(),
          'body': _details.text.trim(),
        },
      );
      _subject.clear();
      _details.clear();
      ref.invalidate(_myTicketsProvider);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('We have got this.'),
          content: const Text(
              'Your ticket is in the Bhook support queue. Our team will look into it as soon as possible.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() => _error =
            extractApiError(error) ?? 'Could not send your ticket right now.');
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tickets = ref.watch(_myTicketsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Help and support')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(BhookSpacing.screenPad,
            BhookSpacing.md, BhookSpacing.screenPad, 120),
        children: [
          Container(
            padding: const EdgeInsets.all(BhookSpacing.lg),
            decoration: BoxDecoration(
              color: BhookColors.sky,
              borderRadius: BorderRadius.circular(BhookRadius.lg),
              border: Border.all(color: BhookColors.inkStrong),
              boxShadow: const [
                BoxShadow(
                    color: BhookColors.inkStrong,
                    offset: Offset(3, 3),
                    blurRadius: 0),
              ],
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.support_agent_rounded,
                    size: 30, color: BhookColors.inkStrong),
                SizedBox(width: BhookSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Need a hand?',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w900)),
                      SizedBox(height: 4),
                      Text(
                          'Tell us what went wrong. The Bhook team will look into it as soon as possible.'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: BhookSpacing.xl),
          const _SupportSectionLabel('RAISE A TICKET'),
          const SizedBox(height: BhookSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration:
                const InputDecoration(labelText: 'What can we help with?'),
            items: _categories.entries
                .map((entry) => DropdownMenuItem(
                    value: entry.key, child: Text(entry.value)))
                .toList(),
            onChanged: _submitting
                ? null
                : (value) => setState(() => _category = value ?? 'OTHER'),
          ),
          const SizedBox(height: BhookSpacing.md),
          TextField(
            controller: _subject,
            enabled: !_submitting,
            maxLength: 200,
            decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'Example: My order is missing an item'),
          ),
          const SizedBox(height: BhookSpacing.md),
          TextField(
            controller: _details,
            enabled: !_submitting,
            maxLines: 5,
            maxLength: 4000,
            decoration: const InputDecoration(
                labelText: 'What happened?',
                hintText: 'Share the details so we can help faster.'),
          ),
          if (_error != null) ...[
            const SizedBox(height: BhookSpacing.sm),
            Text(_error!, style: const TextStyle(color: BhookColors.danger)),
          ],
          const SizedBox(height: BhookSpacing.sm),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded),
              label: Text(_submitting ? 'Sending...' : 'Send to Bhook support'),
            ),
          ),
          const SizedBox(height: BhookSpacing.xxl),
          const _SupportSectionLabel('YOUR TICKETS'),
          const SizedBox(height: BhookSpacing.sm),
          tickets.when(
            loading: () => const ListSkeleton(scrollable: false),
            error: (error, _) => ErrorRetry(
              message: extractApiError(error) ?? 'Could not load your tickets.',
              onRetry: () => ref.invalidate(_myTicketsProvider),
            ),
            data: (items) => items.isEmpty
                ? const _EmptyTickets()
                : Column(
                    children: items
                        .map((ticket) => _TicketTile(ticket: ticket))
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SupportSectionLabel extends StatelessWidget {
  const _SupportSectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          color: BhookColors.inkMuted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1));
}

class _EmptyTickets extends StatelessWidget {
  const _EmptyTickets();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(BhookSpacing.lg),
        decoration: BoxDecoration(
          color: BhookColors.card,
          borderRadius: BorderRadius.circular(BhookRadius.md),
          border: Border.all(color: BhookColors.divider),
        ),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: BhookColors.success),
            SizedBox(width: BhookSpacing.sm),
            Expanded(
                child: Text('No tickets yet. Hopefully it stays that way!')),
          ],
        ),
      );
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket});
  final Map<String, dynamic> ticket;

  @override
  Widget build(BuildContext context) {
    final status = ticket['status']?.toString() ?? 'OPEN';
    final createdAt = DateTime.tryParse(ticket['createdAt']?.toString() ?? '');
    final category = ticket['category']?.toString() ?? 'SUPPORT';
    return Container(
      margin: const EdgeInsets.only(bottom: BhookSpacing.sm),
      padding: const EdgeInsets.all(BhookSpacing.md),
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.md),
        border: Border.all(color: BhookColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(status == 'RESOLVED'
              ? Icons.check_circle_outline
              : Icons.pending_actions_rounded),
          const SizedBox(width: BhookSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket['subject']?.toString() ?? 'Support ticket',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text('$category  ·  ${status.replaceAll('_', ' ')}',
                    style: const TextStyle(
                        color: BhookColors.inkMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
                if (createdAt != null)
                  Text(_dateLabel(createdAt),
                      style: const TextStyle(
                          color: BhookColors.inkFaint, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) =>
      '${date.toLocal().day}/${date.toLocal().month}/${date.toLocal().year}';
}
