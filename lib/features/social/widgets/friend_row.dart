import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expenso/models/user_profile.dart';
import 'package:expenso/features/social/widgets/user_avatar.dart';

class FriendRow extends StatelessWidget {
  final UserProfile profile;
  final VoidCallback? onRemove;
  final VoidCallback? onTap;

  const FriendRow({
    super.key,
    required this.profile,
    this.onRemove,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: UserAvatar(
        avatarUrl: profile.avatarUrl,
        initials: profile.initials,
      ),
      title: Text(
        profile.displayName ?? 'Expenso User',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: profile.bio != null && profile.bio!.isNotEmpty
          ? Text(
              profile.bio!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.5)),
            )
          : null,
      trailing: onRemove != null
          ? IconButton(
              icon: Icon(Icons.person_remove_outlined, size: 20, color: cs.error),
              tooltip: 'Remove friend',
              onPressed: () {
                HapticFeedback.lightImpact();
                _confirmRemove(context);
              },
            )
          : null,
      onTap: onTap,
    );
  }

  void _confirmRemove(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove friend'),
        content: Text(
          'Are you sure you want to remove ${profile.displayName ?? "this user"} from your friends?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRemove?.call();
            },
            child: Text('Remove', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );
  }
}

