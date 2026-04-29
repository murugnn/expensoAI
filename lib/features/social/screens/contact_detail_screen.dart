import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:expenso/models/contact_match.dart';
import 'package:expenso/models/shared_room.dart';
import 'package:expenso/models/user_profile.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/shared_provider.dart';
import 'package:expenso/providers/social_provider.dart';
import 'package:expenso/features/shared/screens/shared_room_screen.dart';
import 'package:expenso/features/social/widgets/user_avatar.dart';

/// Detail view for a single contact / friend / Expenso user.
///
/// Pass [profile] for a resolved Expenso user (friend, request, matched
/// contact), [contact] for a raw device contact (may or may not be on
/// Expenso), or both. The screen decides what to show based on what's
/// available.
class ContactDetailScreen extends StatelessWidget {
  final UserProfile? profile;
  final ContactMatch? contact;

  const ContactDetailScreen({
    super.key,
    this.profile,
    this.contact,
  }) : assert(profile != null || contact != null,
            'Need either a profile or a contact');

  /// Convenience push so callers don't need to import MaterialPageRoute.
  static Future<void> open(
    BuildContext context, {
    UserProfile? profile,
    ContactMatch? contact,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ContactDetailScreen(profile: profile, contact: contact),
      ),
    );
  }

  String? get _otherUserId =>
      profile?.id ?? contact?.matchedUserId;

  String get _displayName =>
      profile?.displayName ??
      contact?.displayName ??
      'Expenso User';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final social = context.watch<SocialProvider>();
    final shared = context.watch<SharedProvider>();
    final auth = context.read<AuthProvider>();
    final myId = auth.currentUser?.id;

    // If the profile wasn't resolved at construction time but we know the ID,
    // grab the latest from the provider.
    final resolved = profile ?? (_otherUserId != null
        ? social.profileOf(_otherUserId!)
        : null);

    final otherId = _otherUserId;
    final isOnExpenso = otherId != null;
    final isFriend = otherId != null && social.isFriend(otherId);
    final hasOutgoing =
        otherId != null && social.hasOutgoingRequestTo(otherId);
    final hasIncoming =
        otherId != null && social.hasIncomingRequestFrom(otherId);

    // Rooms we share with this user.
    final commonRooms = <SharedRoom>[];
    if (otherId != null && myId != null) {
      for (final room in shared.rooms) {
        final members = shared.membersOf(room.id);
        if (members.any((m) => m.userId == otherId)) {
          commonRooms.add(room);
        }
      }
    }

    // Pending room invites between us and them.
    final outgoingRoomInvites = otherId == null
        ? const []
        : social.outgoingRoomInvites
            .where((i) => i.toUser == otherId)
            .toList();
    final incomingRoomInvites = otherId == null
        ? const []
        : social.incomingRoomInvites
            .where((i) => i.fromUser == otherId)
            .toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: cs.surface,
            title: Text(_displayName,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            actions: [
              if (isFriend && otherId != null)
                IconButton(
                  tooltip: 'Remove friend',
                  icon: Icon(Icons.person_remove_outlined, color: cs.error),
                  onPressed: () => _confirmRemoveFriend(context, otherId),
                ),
            ],
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              const SizedBox(height: 8),
              _Header(
                displayName: _displayName,
                avatarUrl: resolved?.avatarUrl,
                bio: resolved?.bio,
                phone: contact?.localPhone,
                isOnExpenso: isOnExpenso,
                isFriend: isFriend,
                hasOutgoing: hasOutgoing,
                hasIncoming: hasIncoming,
              ),
              const SizedBox(height: 24),

              // Friendship action panel
              if (otherId != null && otherId != myId)
                _FriendshipActions(
                  otherUserId: otherId,
                  isFriend: isFriend,
                  hasOutgoing: hasOutgoing,
                  hasIncoming: hasIncoming,
                ),

              if (otherId == null) _NotOnExpensoActions(contact: contact!),

              const SizedBox(height: 24),

              // Shared rooms section
              if (otherId != null) ...[
                _SectionHeader(
                  icon: Icons.groups_2_rounded,
                  label: 'Shared rooms',
                  trailing: commonRooms.isEmpty
                      ? null
                      : '${commonRooms.length}',
                ),
                if (commonRooms.isEmpty)
                  _EmptyTile(
                    text: isFriend
                        ? 'No shared rooms yet. Invite ${_displayName.split(' ').first} to a room you own.'
                        : 'No shared rooms yet.',
                  )
                else
                  ...commonRooms.map((r) => _RoomTile(
                        room: r,
                        currencySymbol: context
                            .read<AppSettingsProvider>()
                            .currencySymbol,
                        onTap: () => _openRoom(context, r),
                      )),
                const SizedBox(height: 12),
                if (isFriend)
                  _InviteToRoomButton(otherUserId: otherId),
              ],

              // Pending invites
              if (outgoingRoomInvites.isNotEmpty ||
                  incomingRoomInvites.isNotEmpty) ...[
                const SizedBox(height: 24),
                _SectionHeader(
                  icon: Icons.mail_outline_rounded,
                  label: 'Pending room invites',
                ),
                ...outgoingRoomInvites.map((inv) {
                  final room = shared.roomById(inv.roomId);
                  return ListTile(
                    leading: Icon(Icons.outbox_rounded,
                        color: cs.onSurface.withOpacity(0.5)),
                    title: Text(room?.roomName ?? 'Shared room'),
                    subtitle: Text('You invited ${_displayName.split(' ').first}'),
                  );
                }),
                ...incomingRoomInvites.map((inv) {
                  final room = shared.roomById(inv.roomId);
                  return ListTile(
                    leading: Icon(Icons.inbox_rounded, color: cs.tertiary),
                    title: Text(room?.roomName ?? 'Shared room'),
                    subtitle: Text(
                        '${_displayName.split(' ').first} invited you'),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          icon: Icon(Icons.close_rounded,
                              color: cs.error, size: 20),
                          onPressed: () =>
                              social.declineRoomInvite(inv.id),
                        ),
                        IconButton(
                          icon: const Icon(Icons.check_rounded,
                              color: Color(0xFF4E9F3D), size: 22),
                          onPressed: () async {
                            HapticFeedback.mediumImpact();
                            final id =
                                await social.acceptRoomInvite(inv.id);
                            if (context.mounted && id != null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Joined room!')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 32),
            ]),
          ),
        ],
      ),
    );
  }

  void _openRoom(BuildContext context, SharedRoom room) {
    final auth = context.read<AuthProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SharedRoomScreen(
          roomId: room.id,
          currentUserId: auth.currentUser?.id ?? '',
          currencySymbol: currency,
        ),
      ),
    );
  }

  void _confirmRemoveFriend(BuildContext context, String otherId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend'),
        content:
            Text('Are you sure you want to remove $_displayName from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final social = context.read<SocialProvider>();
              final ok = await social.removeFriend(otherId);
              if (context.mounted && ok) {
                Navigator.of(context).maybePop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Friend removed.')),
                );
              }
            },
            child: Text('Remove',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Header
// ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? phone;
  final bool isOnExpenso;
  final bool isFriend;
  final bool hasOutgoing;
  final bool hasIncoming;

  const _Header({
    required this.displayName,
    required this.avatarUrl,
    required this.bio,
    required this.phone,
    required this.isOnExpenso,
    required this.isFriend,
    required this.hasOutgoing,
    required this.hasIncoming,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initials = _initialsOf(displayName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          UserAvatar(
            avatarUrl: avatarUrl,
            initials: initials,
            radius: 48,
          ),
          const SizedBox(height: 14),
          Text(
            displayName,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
          ),
          if (bio != null && bio!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              bio!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.6),
              ),
            ),
          ],
          if (phone != null && phone!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              phone!,
              style: TextStyle(
                fontSize: 13,
                color: cs.onSurface.withOpacity(0.55),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _StatusChip(
            isOnExpenso: isOnExpenso,
            isFriend: isFriend,
            hasOutgoing: hasOutgoing,
            hasIncoming: hasIncoming,
          ),
        ],
      ),
    );
  }


  static String _initialsOf(String n) {
    final t = n.trim();
    if (t.isEmpty) return '?';
    final parts = t.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _StatusChip extends StatelessWidget {
  final bool isOnExpenso;
  final bool isFriend;
  final bool hasOutgoing;
  final bool hasIncoming;

  const _StatusChip({
    required this.isOnExpenso,
    required this.isFriend,
    required this.hasOutgoing,
    required this.hasIncoming,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    late final String label;
    late final Color color;
    late final IconData icon;

    if (!isOnExpenso) {
      label = 'Not on Expenso';
      color = cs.onSurface.withOpacity(0.5);
      icon = Icons.person_off_outlined;
    } else if (isFriend) {
      label = 'Friends';
      color = const Color(0xFF4E9F3D);
      icon = Icons.check_circle_rounded;
    } else if (hasIncoming) {
      label = 'Wants to be your friend';
      color = cs.tertiary;
      icon = Icons.mark_email_unread_rounded;
    } else if (hasOutgoing) {
      label = 'Friend request sent';
      color = cs.primary;
      icon = Icons.schedule_send_rounded;
    } else {
      label = 'On Expenso';
      color = cs.primary;
      icon = Icons.verified_user_outlined;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Action panels
// ────────────────────────────────────────────────────────────────────

class _FriendshipActions extends StatelessWidget {
  final String otherUserId;
  final bool isFriend;
  final bool hasOutgoing;
  final bool hasIncoming;

  const _FriendshipActions({
    required this.otherUserId,
    required this.isFriend,
    required this.hasOutgoing,
    required this.hasIncoming,
  });

  @override
  Widget build(BuildContext context) {
    final social = context.read<SocialProvider>();
    final cs = Theme.of(context).colorScheme;

    if (isFriend) return const SizedBox.shrink();

    Widget primary;
    if (hasIncoming) {
      final req = social.incomingRequests
          .firstWhere((r) => r.fromUser == otherUserId);
      primary = Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                final ok = await social.declineFriendRequest(req.id);
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Request declined.')),
                  );
                }
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: Icon(Icons.close_rounded, size: 18, color: cs.error),
              label: Text('Decline',
                  style: TextStyle(color: cs.error)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                final ok = await social.acceptFriendRequest(req.id);
                if (context.mounted && ok) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Friend request accepted!')),
                  );
                }
              },
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_rounded, size: 18),
              label: const Text('Accept'),
            ),
          ),
        ],
      );
    } else if (hasOutgoing) {
      final req = social.outgoingRequests
          .firstWhere((r) => r.toUser == otherUserId);
      primary = OutlinedButton.icon(
        onPressed: () async {
          final ok = await social.declineFriendRequest(req.id);
          if (context.mounted && ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Request cancelled.')),
            );
          }
        },
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.cancel_outlined, size: 18),
        label: const Text('Cancel friend request'),
      );
    } else {
      primary = FilledButton.icon(
        onPressed: () async {
          HapticFeedback.lightImpact();
          final ok = await social.sendFriendRequest(otherUserId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(ok
                    ? 'Friend request sent!'
                    : social.lastError ?? 'Could not send request.'),
              ),
            );
          }
        },
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
        label: const Text('Add as friend'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: primary,
    );
  }
}

class _NotOnExpensoActions extends StatelessWidget {
  final ContactMatch contact;
  const _NotOnExpensoActions({required this.contact});

  @override
  Widget build(BuildContext context) {
    final phone = contact.localPhone;
    final email = contact.localEmail;
    final inviteText =
        'Hey! Join me on Expenso — the smart expense tracker. '
        'https://github.com/murugnn/expensoAI/releases';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          FilledButton.icon(
            onPressed: () => Share.share(inviteText),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.share_outlined, size: 18),
            label: const Text('Invite to Expenso'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (phone != null && phone.isNotEmpty) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchSms(phone, inviteText),
                    icon: const Icon(Icons.sms_outlined, size: 16),
                    label: const Text('SMS'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchWhatsapp(phone, inviteText),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: const Text('WhatsApp'),
                  ),
                ),
              ],
              if (email != null && email.isNotEmpty) ...[
                if (phone != null && phone.isNotEmpty) const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _launchEmail(email, inviteText),
                    icon: const Icon(Icons.email_outlined, size: 16),
                    label: const Text('Email'),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _launchSms(String phone, String body) async {
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': body},
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _launchWhatsapp(String phone, String text) async {
    final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse(
        'https://wa.me/$cleaned?text=${Uri.encodeComponent(text)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchEmail(String email, String body) async {
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=${Uri.encodeComponent("Try Expenso")}'
          '&body=${Uri.encodeComponent(body)}',
    );
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

// ────────────────────────────────────────────────────────────────────
// Section helpers
// ────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  const _SectionHeader({
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.onSurface.withOpacity(0.7)),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: cs.onSurface.withOpacity(0.7),
              letterSpacing: 0.3,
            ),
          ),
          const Spacer(),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                trailing!,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyTile extends StatelessWidget {
  final String text;
  const _EmptyTile({required this.text});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: cs.onSurface.withOpacity(0.55),
          ),
        ),
      ),
    );
  }
}

class _RoomTile extends StatelessWidget {
  final SharedRoom room;
  final String currencySymbol;
  final VoidCallback onTap;

  const _RoomTile({
    required this.room,
    required this.currencySymbol,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shared = context.read<SharedProvider>();
    final total = shared.totalSpentInRoom(room.id);
    final memberCount = shared.membersOf(room.id).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: cs.outlineVariant.withOpacity(0.4)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(room.typeIcon, color: cs.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        room.roomName,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${room.typeLabel} • $memberCount members',
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withOpacity(0.55),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currencySymbol${total.toStringAsFixed(0)}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'spent',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurface.withOpacity(0.4)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────
// Invite-to-room button — opens a sheet listing rooms the current user
// owns/belongs to, then sends an invite for the picked room.
// ────────────────────────────────────────────────────────────────────

class _InviteToRoomButton extends StatelessWidget {
  final String otherUserId;
  const _InviteToRoomButton({required this.otherUserId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: OutlinedButton.icon(
        onPressed: () => _showRoomPicker(context),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
        icon: const Icon(Icons.group_add_outlined, size: 18),
        label: const Text('Invite to a shared room'),
      ),
    );
  }

  void _showRoomPicker(BuildContext context) {
    final shared = context.read<SharedProvider>();
    final social = context.read<SocialProvider>();

    // Rooms where this user is NOT already a member
    final rooms = shared.rooms.where((r) {
      final members = shared.membersOf(r.id);
      return !members.any((m) => m.userId == otherUserId);
    }).toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text(
                'Pick a room to invite to',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (rooms.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'You have no rooms to invite this person to.',
                      style: TextStyle(
                          color: cs.onSurface.withOpacity(0.6)),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final r = rooms[i];
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 8),
                        leading: CircleAvatar(
                          backgroundColor: cs.primary.withOpacity(0.12),
                          child: Icon(r.typeIcon, color: cs.primary),
                        ),
                        title: Text(r.roomName),
                        subtitle: Text(
                            '${r.typeLabel} • ${shared.membersOf(r.id).length} members'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final ok = await social.inviteFriendToRoom(
                              r.id, otherUserId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Invite sent for ${r.roomName}'
                                    : social.lastError ??
                                        'Could not send invite.'),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
