import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:expenso/models/contact_match.dart';
import 'package:expenso/providers/social_provider.dart';
import 'package:expenso/features/social/widgets/friend_row.dart';
import 'package:expenso/features/social/widgets/contact_row.dart';
import 'package:expenso/features/social/widgets/request_row.dart';
import 'package:expenso/features/social/sheets/contact_sync_consent_sheet.dart';
import 'package:expenso/features/social/screens/contact_detail_screen.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Social',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabCtrl,
                indicator: BoxDecoration(
                  color: cs.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: cs.onPrimary,
                unselectedLabelColor: cs.onSurface,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Friends'),
                  Tab(text: 'Contacts'),
                  Tab(text: 'Requests'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _FriendsTab(),
          _ContactsTab(onSwitchToRequests: () => _tabCtrl.animateTo(2)),
          _RequestsTab(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Tab 1 — Friends
// ──────────────────────────────────────────────

class _FriendsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final social = context.watch<SocialProvider>();
    final friends = social.friends;

    if (social.isLoading && friends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (friends.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.people_outline_rounded,
                  size: 56, color: cs.onSurface.withOpacity(0.15)),
              const SizedBox(height: 16),
              Text(
                'No friends yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sync your contacts or share your invite code to start connecting.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await social.loadAll();
        await social.refreshProfiles();
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: friends.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: cs.outlineVariant.withOpacity(0.3),
        ),
        itemBuilder: (_, i) {
          final f = friends[i];
          return FriendRow(
            profile: f,
            onTap: () => ContactDetailScreen.open(context, profile: f),
            onRemove: () async {
              final ok = await social.removeFriend(f.id);
              if (context.mounted && ok) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Friend removed.')),
                );
              }
            },
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Tab 2 — Contacts
// ──────────────────────────────────────────────

class _ContactsTab extends StatefulWidget {
  final VoidCallback onSwitchToRequests;
  const _ContactsTab({required this.onSwitchToRequests});

  @override
  State<_ContactsTab> createState() => _ContactsTabState();
}

class _ContactsTabState extends State<_ContactsTab> {
  String _search = '';
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _loadLastSync();
  }

  Future<void> _loadLastSync() async {
    final ts = await context.read<SocialProvider>().contactsLastSyncedAt();
    if (mounted) setState(() => _lastSync = ts);
  }

  String _relativeSyncTime(DateTime ts) {
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${(diff.inDays / 7).floor()}w ago';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final social = context.watch<SocialProvider>();
    final allMatches = social.contactMatches;

    // Apply search filter
    final matches = _search.isEmpty
        ? allMatches
        : allMatches
            .where((c) => c.displayName
                .toLowerCase()
                .contains(_search.toLowerCase()))
            .toList();

    // Split into "on Expenso" vs the rest so matches show first.
    final onExpenso = matches.where((m) => m.isOnExpenso).toList();
    final notOnExpenso = matches.where((m) => !m.isOnExpenso).toList();

    return Column(
      children: [
        // Sync button + last-sync timestamp
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                side: BorderSide(color: cs.primary.withOpacity(0.5)),
              ),
              icon: social.isSyncingContacts
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: cs.primary),
                    )
                  : Icon(Icons.sync_rounded, size: 18, color: cs.primary),
              label: Text(
                social.isSyncingContacts
                    ? 'Syncing contacts...'
                    : 'Sync contacts',
                style: TextStyle(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              onPressed: social.isSyncingContacts
                  ? null
                  : () => _syncContacts(context),
            ),
          ),
        ),
        if (_lastSync != null && !social.isSyncingContacts)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Last synced ${_relativeSyncTime(_lastSync!)}',
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurface.withOpacity(0.5),
              ),
            ),
          ),

        // Search bar (only shown when contacts exist)
        if (allMatches.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: TextField(
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search contacts',
                prefixIcon: const Icon(Icons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.6),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

        // List
        Expanded(
          child: allMatches.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.import_contacts_rounded,
                            size: 48,
                            color: cs.onSurface.withOpacity(0.15)),
                        const SizedBox(height: 16),
                        Text(
                          'Tap "Sync contacts" to find\nfriends already on Expenso',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: cs.onSurface.withOpacity(0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : matches.isEmpty
                  ? Center(
                      child: Text(
                        'No contacts matching "$_search"',
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withOpacity(0.45),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        if (onExpenso.isNotEmpty) ...[
                          _SectionLabel(
                              label: 'On Expenso · ${onExpenso.length}'),
                          const SizedBox(height: 4),
                          for (final c in onExpenso)
                            _buildContactRow(context, social, c),
                          if (notOnExpenso.isNotEmpty)
                            const SizedBox(height: 12),
                        ],
                        if (notOnExpenso.isNotEmpty) ...[
                          _SectionLabel(
                              label: 'Invite to Expenso · ${notOnExpenso.length}'),
                          const SizedBox(height: 4),
                          for (final c in notOnExpenso)
                            _buildContactRow(context, social, c),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }

  Future<void> _syncContacts(BuildContext context) async {
    final social = context.read<SocialProvider>();
    final hasPerm = await social.hasContactPermission();
    if (!hasPerm) {
      if (!context.mounted) return;
      final wasDenied = await social.wasContactPermissionDenied();
      if (wasDenied) {
        // OS won't re-prompt; tell the user where to enable it.
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Contact permission was denied. Enable it from system settings to sync.'),
            duration: Duration(seconds: 4),
          ),
        );
        return;
      }
      final consented = await ContactSyncConsentSheet.show(context);
      if (!consented) return;
    }
    if (!context.mounted) return;
    final ok = await social.syncContacts();
    if (!context.mounted) return;
    if (!ok) {
      final code = social.lastError;
      final msg = code == 'permission_denied'
          ? 'Contact permission denied. Enable it from system settings.'
          : (code ?? 'Contact sync failed.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      return;
    }
    await _loadLastSync();
  }

  Widget _buildContactRow(
      BuildContext context, SocialProvider social, ContactMatch c) {
    final isFriend =
        c.matchedUserId != null && social.isFriend(c.matchedUserId!);
    final hasPending = c.matchedUserId != null &&
        social.hasOutgoingRequestTo(c.matchedUserId!);
    return ContactRow(
      contact: c,
      isFriend: isFriend,
      hasPendingRequest: hasPending,
      onTap: () {
        final profile = c.matchedUserId != null
            ? social.profileOf(c.matchedUserId!)
            : null;
        ContactDetailScreen.open(
          context,
          profile: profile,
          contact: c,
        );
      },
      onAddFriend: c.matchedUserId != null
          ? () async {
              final ok = await social.sendFriendRequest(c.matchedUserId!);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? 'Friend request sent!'
                        : social.lastError ?? 'Could not send request.'),
                  ),
                );
              }
            }
          : null,
      onInviteToExpenso: () {
        final msg = 'Hey! Join me on Expenso — the smart expense tracker. '
            'Download it here: https://github.com/murugnn/expensoAI/releases';
        Share.share(msg);
      },
    );
  }
}

// ──────────────────────────────────────────────
// Tab 3 — Requests
// ──────────────────────────────────────────────

class _RequestsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final social = context.watch<SocialProvider>();
    final incoming = social.incomingRequests;
    final outgoing = social.outgoingRequests;
    final incomingRoomInvites = social.incomingRoomInvites;

    if (incoming.isEmpty && outgoing.isEmpty && incomingRoomInvites.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mail_outline_rounded,
                size: 48, color: cs.onSurface.withOpacity(0.15)),
            const SizedBox(height: 16),
            Text(
              'No pending requests',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.45),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => social.loadAll(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // Incoming room invites
          if (incomingRoomInvites.isNotEmpty) ...[
            _SectionLabel(label: 'Room Invites'),
            const SizedBox(height: 8),
            ...incomingRoomInvites.map((inv) {
              final from = social.profileOf(inv.fromUser);
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: cs.outlineVariant.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cs.tertiary.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.group_add_outlined,
                          size: 20, color: cs.tertiary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            from?.displayName ?? 'Someone',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Invited you to a shared room',
                            style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: cs.error, size: 20),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        social.declineRoomInvite(inv.id);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.check_rounded,
                          color: Color(0xFF4E9F3D), size: 22),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        final roomId =
                            await social.acceptRoomInvite(inv.id);
                        if (context.mounted && roomId != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Joined room successfully!')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Incoming friend requests
          if (incoming.isNotEmpty) ...[
            _SectionLabel(label: 'Incoming Requests'),
            const SizedBox(height: 8),
            ...incoming.map((r) {
              final profile = social.profileOf(r.fromUser);
              return RequestRow(
                request: r,
                profile: profile,
                isIncoming: true,
                onAccept: () async {
                  final ok = await social.acceptFriendRequest(r.id);
                  if (context.mounted && ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Friend request accepted!')),
                    );
                  }
                },
                onDecline: () => social.declineFriendRequest(r.id),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Outgoing friend requests
          if (outgoing.isNotEmpty) ...[
            _SectionLabel(label: 'Sent Requests'),
            const SizedBox(height: 8),
            ...outgoing.map((r) {
              final profile = social.profileOf(r.toUser);
              return RequestRow(
                request: r,
                profile: profile,
                isIncoming: false,
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      label,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: cs.onSurface.withOpacity(0.5),
        letterSpacing: 0.3,
      ),
    );
  }
}
