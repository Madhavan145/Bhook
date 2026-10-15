import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/responsive.dart';
import '../../core/ui/widgets.dart';
import '../menu/upload_service.dart';
import 'vendor_providers.dart';

class VendorSettingsBody extends ConsumerWidget {
  const VendorSettingsBody({super.key, required this.vendorId});
  final String vendorId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vendor = ref.watch(vendorDetailProvider(vendorId));
    return vendor.when(
      loading: () => const ListSkeleton(count: 2),
      error: (e, _) => ErrorRetry(
        message: 'Could not load vendor settings.',
        onRetry: () => ref.invalidate(vendorDetailProvider(vendorId)),
      ),
      data: (v) => _SettingsForm(vendorId: vendorId, vendor: v),
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.vendorId, required this.vendor});
  final String vendorId;
  final Map<String, dynamic> vendor;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late final _displayName = TextEditingController(text: widget.vendor['displayName']?.toString() ?? '');
  late final _legalName = TextEditingController(text: widget.vendor['legalName']?.toString() ?? '');
  late final _description = TextEditingController(text: widget.vendor['description']?.toString() ?? '');
  late final _phone = TextEditingController(text: widget.vendor['contactPhone']?.toString() ?? '');
  late final _email = TextEditingController(text: widget.vendor['contactEmail']?.toString() ?? '');
  bool _busy = false;
  String? _logoObjectKey;
  String? _coverObjectKey;
  late bool _manualApprove = !(widget.vendor['autoAcceptOrders'] as bool? ?? true);

  @override
  void initState() {
    super.initState();
    _logoObjectKey = widget.vendor['logoObjectKey']?.toString();
    _coverObjectKey = widget.vendor['coverObjectKey']?.toString();
  }

  @override
  void dispose() {
    _displayName.dispose();
    _legalName.dispose();
    _description.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref.read(catalogClientProvider).dio.patch(
        '/api/v1/vendors/${widget.vendorId}',
        data: {
          'displayName': _displayName.text.trim(),
          'legalName': _legalName.text.trim(),
          'description': _description.text.trim(),
          'contactPhone': _phone.text.replaceAll(' ', '').trim(),
          if (_email.text.trim().isNotEmpty) 'contactEmail': _email.text.trim(),
          if (_logoObjectKey != null) 'logoObjectKey': _logoObjectKey,
          if (_coverObjectKey != null) 'coverObjectKey': _coverObjectKey,
          'autoAcceptOrders': !_manualApprove,
        },
      );
      ref.invalidate(vendorDetailProvider(widget.vendorId));
      if (mounted) _snack('Profile saved');
    } catch (e) {
      if (mounted) _snack('Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickImage({required bool cover}) async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 82);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final bytes = await picked.readAsBytes();
      final result = await ref.read(uploadServiceProvider).uploadBytes(
            bytes,
            contentType: _contentType(picked.name),
            purpose: cover ? 'VENDOR_COVER' : 'VENDOR_LOGO',
          );
      setState(() {
        if (cover) {
          _coverObjectKey = result.objectKey;
        } else {
          _logoObjectKey = result.objectKey;
        }
      });
      await _save();
    } catch (e) {
      if (mounted) _snack('Could not upload image: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _lifecycle(String action) async {
    setState(() => _busy = true);
    try {
      await ref.read(catalogClientProvider).dio.post('/api/v1/vendors/${widget.vendorId}/$action');
      ref.invalidate(vendorDetailProvider(widget.vendorId));
      if (mounted) _snack(action == 'activate' ? 'Your kitchen is live' : 'Kitchen paused');
    } catch (e) {
      if (mounted) _snack('Action failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.vendor['lifecycleStatus']?.toString() ?? '';
    final canGoLive = status == 'APPROVED' || status == 'SUSPENDED';
    final canPause = status == 'ACTIVE';
    final pending = status == 'APPLICATION' || status == 'UNDER_REVIEW' || status == 'PROSPECT';

    return ListView(
      padding: const EdgeInsets.fromLTRB(
          BhookSpacing.screenPad, BhookSpacing.lg, BhookSpacing.screenPad, BhookSpacing.xxl),
      children: [
        ContentBound(
          maxWidth: 720,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text('Status', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        StatusPill(label: _pretty(status), color: StatusPill.colorFor(status)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pending
                          ? 'Your application is under review. You can prepare your menu now; you will be able to go live once approved.'
                          : canGoLive
                              ? 'You are approved. Go live to start accepting orders.'
                              : canPause
                                  ? 'Your kitchen is live and accepting orders.'
                                  : 'Manage your kitchen status below.',
                      style: const TextStyle(color: BhookColors.inkMuted),
                    ),
                    if (canGoLive || canPause) ...[
                      const SizedBox(height: 12),
                      if (canGoLive)
                        FilledButton.icon(
                          onPressed: _busy ? null : () => _lifecycle('activate'),
                          icon: const Icon(Icons.rocket_launch_outlined, size: 18),
                          label: const Text('Go live'),
                        ),
                      if (canPause)
                        OutlinedButton.icon(
                          onPressed: _busy ? null : () => _lifecycle('pause'),
                          icon: const Icon(Icons.pause_circle_outline, size: 18),
                          label: const Text('Pause kitchen'),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: BhookSpacing.lg),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Manual approve orders', style: Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 4),
                              const Text(
                                'By default, new paid orders are accepted automatically the moment payment '
                                'succeeds. Turn this on if you\'d rather review and accept each order yourself.',
                                style: TextStyle(color: BhookColors.inkMuted, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Switch(
                          value: _manualApprove,
                          onChanged: _busy
                              ? null
                              : (value) {
                                  setState(() => _manualApprove = value);
                                  _save();
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BhookSpacing.lg),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Kitchen profile', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _ImagePickerTile(
                          label: 'Shop logo',
                          objectKey: _logoObjectKey,
                          onPick: _busy ? null : () => _pickImage(cover: false),
                        )),
                        const SizedBox(width: 12),
                        Expanded(child: _ImagePickerTile(
                          label: 'Cover image',
                          objectKey: _coverObjectKey,
                          onPick: _busy ? null : () => _pickImage(cover: true),
                          wide: true,
                        )),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(controller: _displayName, decoration: const InputDecoration(labelText: 'Display name')),
                    const SizedBox(height: 12),
                    TextField(controller: _legalName, decoration: const InputDecoration(labelText: 'Legal name')),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _description,
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: 'Contact phone'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(labelText: 'Contact email'),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _save,
                      child: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save changes'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BhookSpacing.lg),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Account', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    const Text('Switch kitchens or sign out.', style: TextStyle(color: BhookColors.inkMuted)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => context.go('/'),
                            icon: const Icon(Icons.swap_horiz, size: 18),
                            label: const Text('Switch kitchen'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: BhookColors.danger,
                              side: BorderSide(color: BhookColors.danger.withValues(alpha: 0.4)),
                            ),
                            onPressed: () async {
                              await ref.read(tokenStorageProvider).clear();
                              ref.invalidate(authSessionProvider);
                              if (context.mounted) context.go('/login');
                            },
                            icon: const Icon(Icons.logout, size: 18),
                            label: const Text('Sign out'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _pretty(String s) =>
      s.split('_').map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()).join(' ');
}

class _ImagePickerTile extends StatelessWidget {
  const _ImagePickerTile({required this.label, required this.objectKey, required this.onPick, this.wide = false});
  final String label;
  final String? objectKey;
  final VoidCallback? onPick;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final url = AppConfig.imageUrl(objectKey);
    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(BhookRadius.md),
      child: Container(
        height: wide ? 96 : 96,
        decoration: BoxDecoration(
          color: BhookColors.primarySoft,
          borderRadius: BorderRadius.circular(BhookRadius.md),
          border: Border.all(color: BhookColors.divider),
          image: url == null ? null : DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
        ),
        child: url == null
            ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.add_photo_alternate_outlined, color: BhookColors.primary),
                const SizedBox(height: 4),
                Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ])
            : Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  width: double.infinity,
                  color: Colors.black54,
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Text(label, textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                ),
              ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(BhookSpacing.lg),
      decoration: BoxDecoration(
        color: BhookColors.card,
        borderRadius: BorderRadius.circular(BhookRadius.lg),
        border: Border.all(color: BhookColors.divider),
      ),
      child: child,
    );
  }
}
