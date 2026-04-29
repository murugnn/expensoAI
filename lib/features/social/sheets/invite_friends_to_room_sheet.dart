import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/social_provider.dart';
import 'package:expenso/models/user_profile.dart';
import 'package:expenso/features/social/widgets/user_avatar.dart';

/// Bottom sheet to invite friends from your friend list into a shared room.
class InviteFriendsToRoomSheet extends StatefulWidget {
  final String roomId;
  final String roomName;
  const InviteFriendsToRoomSheet({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  static void show(BuildContext context,
      {required String roomId, required String roomName}) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          InviteFriendsToRoomSheet(roomId: roomId, roomName: roomName),
    );
  }

  @override
  State<InviteFriendsToRoomSheet> createState() =>
      _InviteFriendsToRoomSheetState();
}

class _InviteFriendsToRoomSheetState extends State<InviteFriendsToRoomSheet> {
  final Set<String> _sentTo = {};
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final social = context.watch<SocialProvider>();
    final friends = social.friends;

    final filtered = _search.isEmpty
        ? friends
        : friends
            .where((f) =>
                (f.displayName ?? '')
                    .toLowerCase()
                    .contains(_search.toLowerCase()))
            .toList();

    // Exclude friends that already have a pending invite for this room
    final pendingToUsers = social.outgoingRoomInvites
        .where((i) => i.roomId == widget.roomId)
        .map((i) => i.toUser)
        .toSet();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite to ${widget.roomName}',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select friends to invite',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ),
              // Search
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: TextField(
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search friends',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: cs.surfaceContainerHighest.withOpacity(0.6),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          friends.isEmpty
                              ? 'No friends yet. Add friends first!'
                              : 'No matches found.',
                          style: TextStyle(
                            color: cs.onSurface.withOpacity(0.4),
                            fontSize: 14,
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final f = filtered[i];
                          final alreadyInvited =
                              pendingToUsers.contains(f.id) ||
                                  _sentTo.contains(f.id);
                          return _FriendInviteRow(
                            profile: f,
                            alreadyInvited: alreadyInvited,
                            onInvite: () => _invite(f.id),
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

  Future<void> _invite(String userId) async {
    final social = context.read<SocialProvider>();
    final ok = await social.inviteFriendToRoom(widget.roomId, userId);
    if (!mounted) return;
    if (ok) {
      setState(() => _sentTo.add(userId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite sent!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(social.lastError ?? 'Failed to send invite.')),
      );
    }
  }
}

class _FriendInviteRow extends StatelessWidget {
  final UserProfile profile;
  final bool alreadyInvited;
  final VoidCallback onInvite;
  const _FriendInviteRow({
    required this.profile,
    required this.alreadyInvited,
    required this.onInvite,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final url = profile.avatarUrl;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: UserAvatar(
        avatarUrl: url,
        initials: profile.initials,
        radius: 20,
      ),
      title: Text(
        profile.displayName ?? 'Expenso User',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
      trailing: alreadyInvited
          ? Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Invited',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurface.withOpacity(0.5),
                ),
              ),
            )
          : Material(
              color: cs.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {
                  HapticFeedback.lightImpact();
                  onInvite();
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  child: Text(
                    'Invite',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
