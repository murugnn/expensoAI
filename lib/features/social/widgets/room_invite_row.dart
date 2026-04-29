import 'package:flutter/material.dart';

import 'package:expenso/models/room_invite.dart';
import 'package:expenso/models/shared_room.dart';
import 'package:expenso/models/user_profile.dart';

class RoomInviteRow extends StatelessWidget {
  final RoomInvite invite;
  final SharedRoom? room;
  final UserProfile? fromProfile;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const RoomInviteRow({
    super.key,
    required this.invite,
    this.room,
    this.fromProfile,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final roomName = room?.roomName ?? 'A shared room';
    final fromName = fromProfile?.displayName ?? 'A friend';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              room?.typeIcon ?? Icons.group_outlined,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  roomName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$fromName invited you',
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Decline',
            icon: Icon(Icons.close_rounded, color: cs.onSurfaceVariant),
            onPressed: onDecline,
          ),
          FilledButton(
            onPressed: onAccept,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}
