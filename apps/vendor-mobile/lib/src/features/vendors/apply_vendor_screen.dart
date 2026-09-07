import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';

final _campusesProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response =
      await ref.read(campusClientProvider).dio.get('/api/v1/campuses');
  return ((response.data as List?) ?? const [])
      .whereType<Map<String, dynamic>>()
      .toList();
});

class ApplyVendorScreen extends ConsumerStatefulWidget {
  const ApplyVendorScreen({super.key});

  @override
  ConsumerState<ApplyVendorScreen> createState() => _ApplyVendorScreenState();
}

class _ApplyVendorScreenState extends ConsumerState<ApplyVendorScreen> {
  final _legalName = TextEditingController();
  final _displayName = TextEditingController();
  final _description = TextEditingController();
  final _phone = TextEditingController();
  String? _campusId;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _legalName.dispose();
    _displayName.dispose();
    _description.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final campusId = _campusId;
    if (campusId == null ||
        _legalName.text.trim().isEmpty ||
        _displayName.text.trim().isEmpty) {
      setState(() => _error = 'Choose a campus and enter both business names.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(catalogClientProvider)
          .dio
          .post('/api/v1/vendors/apply', data: {
        'campusId': campusId,
        'legalName': _legalName.text.trim(),
        'displayName': _displayName.text.trim(),
        'description': _description.text.trim(),
        if (_phone.text.trim().isNotEmpty)
          'contactPhone': _phone.text.replaceAll(RegExp(r'\s+'), ''),
      });
      if (!mounted) return;
      context.go('/');
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = 'Could not submit the application. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final campuses = ref.watch(_campusesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Open your kitchen')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(BhookSpacing.screenPad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Tell us about your business',
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 8),
              const Text(
                  'Submit an application and start preparing your menu while Bhook reviews it.'),
              const SizedBox(height: 24),
              campuses.when(
                loading: () => const LinearProgressIndicator(),
                error: (_, __) =>
                    const Text('Campuses are unavailable right now.'),
                data: (items) => DropdownButtonFormField<String>(
                  initialValue: _campusId,
                  decoration: const InputDecoration(
                      labelText: 'Campus',
                      prefixIcon: Icon(Icons.school_outlined)),
                  items: items.map((campus) {
                    final id = campus['id']?.toString() ?? '';
                    final name = campus['displayName']?.toString() ??
                        campus['name']?.toString() ??
                        id;
                    return DropdownMenuItem(value: id, child: Text(name));
                  }).toList(),
                  onChanged: (value) => setState(() => _campusId = value),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                  controller: _displayName,
                  decoration: const InputDecoration(
                      labelText: 'Customer-facing name *',
                      prefixIcon: Icon(Icons.storefront_outlined))),
              const SizedBox(height: 12),
              TextField(
                  controller: _legalName,
                  decoration: const InputDecoration(
                      labelText: 'Legal business name *',
                      prefixIcon: Icon(Icons.business_outlined))),
              const SizedBox(height: 12),
              TextField(
                  controller: _description,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      labelText: 'Description',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes_outlined))),
              const SizedBox(height: 12),
              TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'Contact phone',
                      hintText: '+919876543210',
                      prefixIcon: Icon(Icons.phone_outlined))),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: const TextStyle(color: BhookColors.danger)),
              ],
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_outlined),
                label: Text(_busy ? 'Submitting...' : 'Submit application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
