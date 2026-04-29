import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:expenso/providers/social_provider.dart';
import 'package:expenso/features/social/widgets/user_avatar.dart';

/// A compact entry-point widget for the dashboard. Shows the friends count,
/// any pending invites, and tapping opens the Social hub.
class SocialDashboardCard extends StatelessWidget {
  const SocialDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final social = context.watch<SocialProvider>();
    final friends = social.friends;
    final pending =
        social.incomingRequests.length + social.incomingRoomInvites.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Material(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/social'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border:
                  Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                _AvatarStack(
                  names: friends.take(3).map((p) => p.displayName ?? '').toList(),
                  imageUrls:
                      friends.take(3).map((p) => p.avatarUrl).toList(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Friends',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        friends.isEmpty
                            ? 'Find friends on Expenso'
                            : '${friends.length} on Expenso',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (pending > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: cs.error.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$pending pending',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.error,
                      ),
                    ),
                  )
                else
                  Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    ).animate().fadeIn(duration: 380.ms).slideY(
          begin: 0.05,
          end: 0,
          duration: 380.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _AvatarStack extends StatelessWidget {
  final List<String> names;
  final List<String?> imageUrls;
  const _AvatarStack({required this.names, required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (names.isEmpty) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.10),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(Icons.group_add_outlined, color: cs.primary),
      );
    }

    return SizedBox(
      width: 44.0 + (names.length - 1) * 22.0,
      height: 44,
      child: Stack(
        children: [
          for (var i = 0; i < names.length; i++)
            Positioned(
              left: i * 22.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: cs.surfaceContainerHigh, width: 2),
                ),
                child: UserAvatar(
                  initials: names[i].isNotEmpty ? names[i][0].toUpperCase() : '?',
                  avatarUrl: imageUrls[i],
                  radius: 19, // 38 / 2
                ),
              ),
            ),
        ],
      ),
    );
  }
}
