import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expenso/models/friend_request.dart';
import 'package:expenso/models/user_profile.dart';
import 'package:expenso/features/social/widgets/user_avatar.dart';
import 'package:expenso/models/user_profile.dart';

class RequestRow extends StatelessWidget {
  final FriendRequest request;
  final UserProfile? profile;
  final bool isIncoming;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const RequestRow({
    super.key,
    required this.request,
    required this.isIncoming,
    this.profile,
    this.onAccept,
    this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final name = profile?.displayName ?? 'Expenso User';
    final avatarUrl = profile?.avatarUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          UserAvatar(
            avatarUrl: avatarUrl,
            initials: profile?.initials ?? '?',
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  isIncoming
                      ? 'Wants to be your friend'
                      : 'Request sent',
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
                if (request.message != null && request.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    '"${request.message}"',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: cs.onSurface.withOpacity(0.6),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (isIncoming) ...[
            IconButton(
              icon: Icon(Icons.close_rounded, color: cs.error, size: 20),
              tooltip: 'Decline',
              onPressed: () {
                HapticFeedback.lightImpact();
                onDecline?.call();
              },
            ),
            const SizedBox(width: 2),
            IconButton(
              icon: Icon(Icons.check_rounded, color: const Color(0xFF4E9F3D), size: 22),
              tooltip: 'Accept',
              onPressed: () {
                HapticFeedback.mediumImpact();
                onAccept?.call();
              },
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Pending',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: cs.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }

}
