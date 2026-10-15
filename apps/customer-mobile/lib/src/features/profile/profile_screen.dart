import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_config.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';
import '../auth/auth_service.dart';
import '../auth/auth_state.dart';

final customerProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response =
      await ref.read(customerClientProvider).dio.get('/api/v1/customers/me');
  return (response.data as Map).cast<String, dynamic>();
});

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  String? _imageKey;
  bool _loaded = false;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      setState(() => _message = 'Profile images must be 5 MB or smaller.');
      return;
    }
    setState(() => _busy = true);
    try {
      final contentType = _contentType(picked.name);
      final upload = await ref
          .read(uploadClientProvider)
          .dio
          .post('/api/v1/uploads', data: {
        'purpose': 'PROFILE_IMAGE',
        'contentType': contentType,
        'sizeBytes': bytes.length,
      });
      final uploadData = upload.data as Map<String, dynamic>;
      final uploadId = uploadData['uploadId'];
      await ref.read(uploadClientProvider).dio.put(
            '/api/v1/uploads/$uploadId/content',
            data: bytes,
            options: Options(contentType: contentType),
          );
      await ref.read(uploadClientProvider).dio.post(
        '/api/v1/uploads/$uploadId/commit',
        data: const {},
      );
      setState(() {
        _imageKey = uploadData['objectKey']?.toString();
        _message = 'Image uploaded. Save your profile to apply it.';
      });
    } catch (error) {
      setState(() => _message =
          extractApiError(error) ?? 'Could not upload profile image.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref
          .read(customerClientProvider)
          .dio
          .put('/api/v1/customers/me/profile', data: {
        'displayName': _name.text.trim(),
        'bio': _bio.text.trim(),
        if (_imageKey != null) 'profileImageObjectKey': _imageKey,
      });
      ref.invalidate(customerProfileProvider);
      if (mounted) setState(() => _message = 'Profile saved.');
    } catch (error) {
      if (mounted)
        setState(() =>
            _message = extractApiError(error) ?? 'Could not save profile.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(customerProfileProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profile.when(
        loading: () => const ListSkeleton(),
        error: (error, _) => ErrorRetry(
          message: extractApiError(error) ?? 'Could not load profile.',
          onRetry: () => ref.invalidate(customerProfileProvider),
        ),
        data: (data) {
          if (!_loaded) {
            _name.text = data['displayName']?.toString() ?? '';
            _bio.text = data['bio']?.toString() ?? '';
            _imageKey = data['profileImageObjectKey']?.toString();
            _loaded = true;
          }
          return ListView(
            padding: const EdgeInsets.all(BhookSpacing.screenPad),
            children: [
              Container(
                padding: const EdgeInsets.all(BhookSpacing.lg),
                decoration: BoxDecoration(
                  color: BhookColors.mustard,
                  borderRadius: BorderRadius.circular(BhookRadius.xl),
                  border: Border.all(color: BhookColors.inkStrong, width: 1.1),
                  boxShadow: const [
                    BoxShadow(
                      color: BhookColors.inkStrong,
                      offset: Offset(4, 4),
                      blurRadius: 0,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _busy ? null : _pickImage,
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: BhookColors.card,
                        backgroundImage: AppConfig.imageUrl(_imageKey) != null
                            ? NetworkImage(AppConfig.imageUrl(_imageKey)!)
                            : null,
                        child: AppConfig.imageUrl(_imageKey) == null
                            ? const Icon(Icons.person_outline,
                                size: 38, color: BhookColors.inkStrong)
                            : null,
                      ),
                    ),
                    const SizedBox(width: BhookSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('YOUR CAMPUS IDENTITY',
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.2)),
                          const SizedBox(height: 6),
                          Text('Make it unmistakably yours.',
                              style: Theme.of(context).textTheme.titleMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: BhookSpacing.sm),
              Center(
                child: TextButton.icon(
                  onPressed: _busy ? null : _pickImage,
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Change profile photo'),
                ),
              ),
              const SizedBox(height: BhookSpacing.md),
              TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: BhookSpacing.md),
              TextField(
                  controller: _bio,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Short bio')),
              const SizedBox(height: BhookSpacing.lg),
              if (_message != null)
                Text(_message!,
                    style: const TextStyle(color: BhookColors.inkMuted)),
              const SizedBox(height: BhookSpacing.md),
              FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_outlined),
                label: Text(_busy ? 'Saving...' : 'Save profile'),
              ),
              const SizedBox(height: BhookSpacing.xl),
              const _ProfileSectionLabel('YOUR BHOOK'),
              const SizedBox(height: BhookSpacing.sm),
              _ProfileActionTile(
                icon: Icons.receipt_long_outlined,
                title: 'My orders',
                subtitle: 'Track past and active orders',
                onTap: () => context.push('/orders'),
              ),
              _ProfileActionTile(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Bhook wallet',
                subtitle: 'Coming soon',
                trailing: const _ComingSoonTag(),
                onTap: () => _showComingSoon('Wallet payments and rewards'),
              ),
              _ProfileActionTile(
                icon: Icons.location_on_outlined,
                title: 'Campus and delivery',
                subtitle: 'Manage where your orders arrive',
                onTap: () => _showComingSoon('Campus delivery preferences'),
              ),
              const SizedBox(height: BhookSpacing.lg),
              const _ProfileSectionLabel('SUPPORT & SETTINGS'),
              const SizedBox(height: BhookSpacing.sm),
              _ProfileActionTile(
                icon: Icons.help_outline_rounded,
                title: 'Help and support',
                subtitle: 'Get help with an order or account',
                onTap: () => context.push('/support'),
              ),
              _ProfileActionTile(
                icon: Icons.notifications_none_rounded,
                title: 'Notifications',
                subtitle: 'Order updates and offer alerts',
                onTap: () => _showComingSoon('Notification preferences'),
              ),
              _ProfileActionTile(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                subtitle: 'Sign out of this device',
                onTap: _logout,
              ),
              const SizedBox(height: BhookSpacing.xl),
              const Center(
                child: Text('Bhook · made for campus cravings',
                    style: TextStyle(
                        color: BhookColors.inkFaint,
                        fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is coming soon.')),
    );
  }

  Future<void> _logout() async {
    await ref.read(authServiceProvider).logout();
    ref.invalidate(authSessionProvider);
    if (mounted) context.go('/login');
  }

  String _contentType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class _ProfileSectionLabel extends StatelessWidget {
  const _ProfileSectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(label,
      style: const TextStyle(
          color: BhookColors.inkMuted,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.1));
}

class _ComingSoonTag extends StatelessWidget {
  const _ComingSoonTag();

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: BhookColors.primarySoft,
          borderRadius: BorderRadius.circular(BhookRadius.pill),
        ),
        child: const Text('SOON',
            style: TextStyle(
                color: BhookColors.primary,
                fontSize: 9,
                fontWeight: FontWeight.w900)),
      );
}

class _ProfileActionTile extends StatelessWidget {
  const _ProfileActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: BhookSpacing.sm),
        child: Material(
          color: BhookColors.card,
          borderRadius: BorderRadius.circular(BhookRadius.md),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(BhookRadius.md),
            child: Padding(
              padding: const EdgeInsets.all(BhookSpacing.md),
              child: Row(children: [
                Icon(icon, color: BhookColors.inkStrong),
                const SizedBox(width: BhookSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 14)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              color: BhookColors.inkMuted, fontSize: 12)),
                    ],
                  ),
                ),
                trailing ??
                    const Icon(Icons.chevron_right_rounded,
                        color: BhookColors.inkFaint),
              ]),
            ),
          ),
        ),
      );
}
