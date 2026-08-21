import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/app_config.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui/widgets.dart';

final socialProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final response =
      await ref.read(customerClientProvider).dio.get('/api/v1/customers/me');
  return (response.data as Map).cast<String, dynamic>();
});

final sharedOrdersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref
      .read(socialClientProvider)
      .dio
      .get('/api/v1/social/shared-orders');
  final shares =
      (response.data as List).whereType<Map<String, dynamic>>().toList();
  return Future.wait(shares.map((share) async {
    try {
      final profile = await ref
          .read(customerClientProvider)
          .dio
          .get('/api/v1/customers/directory/code/${share['ownerUserId']}');
      return {...share, ...((profile.data as Map).cast<String, dynamic>())};
    } catch (_) {
      return share;
    }
  }));
});

final relationshipsProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final response = await ref
      .read(socialClientProvider)
      .dio
      .get('/api/v1/social/friends/relationships');
  return (response.data as List).whereType<Map<String, dynamic>>().toList();
});

class SocialScreen extends ConsumerWidget {
  const SocialScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final relationships = ref.watch(relationshipsProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(title: const Text('Friends')),
        body: Column(
          children: [
            const Material(
              color: BhookColors.surface,
              child:
                  TabBar(tabs: [Tab(text: 'Friends'), Tab(text: 'Activities')]),
            ),
            Expanded(
              child: TabBarView(children: [
                RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(relationshipsProvider);
                    await ref.read(relationshipsProvider.future);
                  },
                  child: ListView(
                    padding: const EdgeInsets.all(BhookSpacing.screenPad),
                    children: [
                      const PlayfulBanner(
                        title: 'THE BHOOK CREW',
                        subtitle: 'Food tastes better together.',
                        icon: Icons.people_alt_rounded,
                        color: BhookColors.mint,
                        margin: EdgeInsets.zero,
                      ),
                      ref.watch(socialProfileProvider).when(
                            loading: () => const LinearProgressIndicator(),
                            error: (error, _) =>
                                Text('Could not load your friend code: $error'),
                            data: (data) => _FriendCodeCard(
                              code: data['friendCode']?.toString() ?? '',
                              onShare: () => Share.share(
                                'Add me on Bhook: ${ref.read(appConfigProvider).friendLinkBaseUrl}/befriend/${data['friendCode']}',
                                subject: 'Add me on Bhook',
                              ),
                            ),
                          ),
                      const SectionHeader(
                          title: 'Add a friend',
                          subtitle:
                              'Paste a Bhook friend link or enter its code.'),
                      const _FriendCodeEntry(),
                      relationships.when(
                        loading: () => const Padding(
                            padding: EdgeInsets.only(top: BhookSpacing.xl),
                            child: ListSkeleton(scrollable: false)),
                        error: (error, _) => Padding(
                            padding:
                                const EdgeInsets.only(top: BhookSpacing.xl),
                            child: Text('Could not load friends: $error')),
                        data: (items) {
                          final incoming = items
                              .where((item) =>
                                  item['status'] == 'PENDING' &&
                                  item['direction'] == 'INCOMING')
                              .toList();
                          final outgoing = items
                              .where((item) =>
                                  item['status'] == 'PENDING' &&
                                  item['direction'] == 'OUTGOING')
                              .toList();
                          final accepted = items
                              .where((item) => item['status'] == 'ACCEPTED')
                              .toList();
                          final denied = items
                              .where((item) => item['status'] == 'DECLINED')
                              .toList();
                          return Column(
                            children: [
                              _FriendGroup(
                                title: 'Requested',
                                subtitle: 'People waiting for your response',
                                count: incoming.length,
                                emptyLabel: 'No incoming requests.',
                                children: [
                                  for (final request in incoming)
                                    _RequestRow(
                                      item: request,
                                      onAccept: () =>
                                          _respond(ref, request, true),
                                      onDecline: () =>
                                          _respond(ref, request, false),
                                    ),
                                ],
                              ),
                              _FriendGroup(
                                title: 'Requested by you',
                                count: outgoing.length,
                                emptyLabel: 'No outgoing requests.',
                                children: _relationshipRows(outgoing),
                              ),
                              _FriendGroup(
                                title: 'Approved',
                                count: accepted.length,
                                emptyLabel: 'No accepted friends yet.',
                                children: _relationshipRows(accepted),
                              ),
                              _FriendGroup(
                                title: 'Denied',
                                count: denied.length,
                                emptyLabel: 'No denied requests.',
                                children: _relationshipRows(denied),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const _ActivitiesTab(),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _respond(
      WidgetRef ref, Map<String, dynamic> item, bool accept) async {
    await ref.read(socialClientProvider).dio.post(
        '/api/v1/social/friends/${item['friendshipId']}/${accept ? 'accept' : 'decline'}');
    ref.invalidate(relationshipsProvider);
  }

  List<Widget> _relationshipRows(List<Map<String, dynamic>> items) => [
        for (final item in items) _FriendRow(item: item),
      ];
}

class _ActivitiesTab extends ConsumerWidget {
  const _ActivitiesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(sharedOrdersProvider);
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(sharedOrdersProvider);
        await ref.read(sharedOrdersProvider.future);
      },
      child: activities.when(
        loading: () => const ListSkeleton(),
        error: (_, __) => ErrorRetry(
          message: 'Could not load friend activities.',
          onRetry: () => ref.invalidate(sharedOrdersProvider),
        ),
        data: (items) => items.isEmpty
            ? ListView(children: const [
                EmptyState(
                  title: 'No friend activities yet',
                  message: 'Shared orders from your friends will appear here.',
                )
              ])
            : ListView.separated(
                padding: const EdgeInsets.all(BhookSpacing.screenPad),
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: BhookSpacing.md),
                itemBuilder: (_, index) => _ActivityCard(item: items[index]),
              ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final profileImage =
        AppConfig.imageUrl(item['profileImageObjectKey']?.toString());
    final dishImage =
        AppConfig.imageUrl(item['itemImageObjectKey']?.toString());
    final vendorId = item['vendorId']?.toString();
    final category = item['categoryName']?.toString();
    final friendName = item['displayName']?.toString().trim();
    final dishName = item['itemName']?.toString() ?? 'a featured dish';
    const phrases = [
      'Your pal is into',
      'Your buddy picked',
      'A friend just tried',
      'Your food mate ordered',
      'Someone from your crew chose',
    ];
    final phraseIndex =
        (item['ownerUserId']?.toString().hashCode ?? 0).abs() % phrases.length;
    final phrase = phrases[phraseIndex];
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: vendorId == null
            ? null
            : () {
                final query = category == null || category.isEmpty
                    ? ''
                    : '?category=${Uri.encodeComponent(category)}';
                context.push('/vendors/$vendorId$query');
              },
        child: Padding(
          padding: const EdgeInsets.all(BhookSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _ActivityThumb(
                imageUrl: profileImage,
                fallback: const Icon(Icons.person_outline),
                label: friendName?.isEmpty ?? true ? 'Friend' : friendName!,
                isCircle: true,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: BhookSpacing.sm),
                child: Icon(Icons.swap_horiz,
                    color: BhookColors.primary, size: 24),
              ),
              _ActivityThumb(
                imageUrl: dishImage,
                fallback: const Icon(Icons.restaurant_outlined),
                label: dishName,
              ),
              const SizedBox(width: BhookSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      phrase,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: BhookColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dishName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['vendorName']?.toString() ?? 'A Bhook vendor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: BhookSpacing.sm),
              const Icon(Icons.chevron_right, color: BhookColors.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityThumb extends StatelessWidget {
  const _ActivityThumb({
    required this.imageUrl,
    required this.fallback,
    required this.label,
    this.isCircle = false,
  });

  final String? imageUrl;
  final Widget fallback;
  final String label;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    final child = imageUrl == null
        ? ColoredBox(
            color: BhookColors.primarySoft,
            child: Center(child: fallback),
          )
        : Image.network(imageUrl!, fit: BoxFit.cover);
    return Semantics(
      label: label,
      image: true,
      child: SizedBox(
        width: 58,
        height: 58,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isCircle ? 29 : BhookRadius.md),
          child: child,
        ),
      ),
    );
  }
}

class _FriendGroup extends StatelessWidget {
  const _FriendGroup(
      {required this.title,
      required this.count,
      required this.emptyLabel,
      required this.children,
      this.subtitle});

  final String title;
  final String? subtitle;
  final int count;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(top: BhookSpacing.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(BhookSpacing.md, BhookSpacing.md,
              BhookSpacing.md, BhookSpacing.sm),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null)
                      Text(subtitle!,
                          style: Theme.of(context).textTheme.bodySmall),
                  ])),
              _CountBadge(count: count),
            ]),
            const Divider(height: BhookSpacing.lg),
            if (children.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: BhookSpacing.sm),
                child: Text(emptyLabel,
                    style: Theme.of(context).textTheme.bodySmall),
              )
            else
              ...children,
          ]),
        ),
      );
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(minWidth: 28),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: BhookColors.primarySoft,
            borderRadius: BorderRadius.circular(BhookRadius.pill)),
        child: Text('$count',
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: BhookColors.primary, fontWeight: FontWeight.w800)),
      );
}

class _FriendRow extends StatelessWidget {
  const _FriendRow({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final imageUrl =
        AppConfig.imageUrl(item['profileImageObjectKey']?.toString());
    final name = item['displayName']?.toString().trim();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
          backgroundImage: imageUrl == null ? null : NetworkImage(imageUrl),
          child: imageUrl == null ? const Icon(Icons.person_outline) : null),
      title: Text(name == null || name.isEmpty ? 'Bhook customer' : name),
      subtitle: Text(
          item['status'] == 'PENDING' ? 'Request pending' : 'Bhook friend'),
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow(
      {required this.item, required this.onAccept, required this.onDecline});
  final Map<String, dynamic> item;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) => Column(children: [
        _FriendRow(item: item),
        Row(children: [
          Expanded(
              child: OutlinedButton(
                  onPressed: onDecline, child: const Text('Decline'))),
          const SizedBox(width: BhookSpacing.sm),
          Expanded(
              child: FilledButton(
                  onPressed: onAccept, child: const Text('Accept'))),
        ]),
        const SizedBox(height: BhookSpacing.sm),
      ]);
}

class _FriendCodeCard extends StatelessWidget {
  const _FriendCodeCard({required this.code, required this.onShare});

  final String code;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(BhookSpacing.md),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Your Bhook friend link',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
                'Share this with someone you know. They can request you after signing in.'),
            const SizedBox(height: BhookSpacing.md),
            SelectableText(code,
                style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: BhookSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onShare,
                icon: const Icon(Icons.ios_share_outlined),
                label: const Text('Share link'),
              ),
            ),
          ]),
        ),
      );
}

class _FriendCodeEntry extends ConsumerStatefulWidget {
  const _FriendCodeEntry();

  @override
  ConsumerState<_FriendCodeEntry> createState() => _FriendCodeEntryState();
}

class _FriendCodeEntryState extends ConsumerState<_FriendCodeEntry> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _request() async {
    final value = _controller.text.trim();
    final code = value.split('/').where((part) => part.isNotEmpty).last;
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final profile = await ref
          .read(customerClientProvider)
          .dio
          .get('/api/v1/customers/directory/code/$code');
      await ref.read(socialClientProvider).dio.post(
        '/api/v1/social/friends/request',
        data: {
          'friendCode':
              (profile.data as Map<String, dynamic>)['friendCode'] ?? code
        },
      );
      setState(() {
        _message = 'Friend request sent. They need to accept it.';
        _controller.clear();
      });
    } catch (error) {
      setState(() => _message =
          extractApiError(error) ?? 'Could not send friend request.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
        TextField(
          controller: _controller,
          decoration: const InputDecoration(
            labelText: 'Friend link or code',
            prefixIcon: Icon(Icons.link),
          ),
        ),
        const SizedBox(height: BhookSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _busy ? null : _request,
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.person_add_alt_1),
            label: const Text('Send request'),
          ),
        ),
        if (_message != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_message!,
                style: const TextStyle(color: BhookColors.inkMuted)),
          ),
      ]);
}
