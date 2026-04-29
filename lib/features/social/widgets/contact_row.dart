import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:expenso/models/contact_match.dart';

class ContactRow extends StatelessWidget {
  final ContactMatch contact;
  final bool isFriend;
  final bool hasPendingRequest;
  final VoidCallback? onAddFriend;
  final VoidCallback? onInviteToExpenso;
  final VoidCallback? onTap;

  const ContactRow({
    super.key,
    required this.contact,
    this.isFriend = false,
    this.hasPendingRequest = false,
    this.onAddFriend,
    this.onInviteToExpenso,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: contact.isOnExpenso
            ? cs.primary.withOpacity(0.12)
            : cs.surfaceContainerHighest,
        child: Text(
          contact.initials,
          style: TextStyle(
            color: contact.isOnExpenso ? cs.primary : cs.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ),
      title: Text(
        contact.displayName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        contact.isOnExpenso ? 'On Expenso' : 'Not on Expenso',
        style: TextStyle(
          fontSize: 12,
          color: contact.isOnExpenso
              ? const Color(0xFF4E9F3D)
              : cs.onSurface.withOpacity(0.4),
        ),
      ),
      trailing: _buildAction(cs),
    );
  }

  Widget? _buildAction(ColorScheme cs) {
    if (contact.isOnExpenso) {
      if (isFriend) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Friends',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: cs.onSurface.withOpacity(0.5),
            ),
          ),
        );
      }
      if (hasPendingRequest) {
        return Container(
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
        );
      }
      return _SmallButton(
        label: 'Add',
        icon: Icons.person_add_outlined,
        color: cs.primary,
        onTap: onAddFriend,
      );
    }
    return _SmallButton(
      label: 'Invite',
      icon: Icons.share_outlined,
      color: cs.tertiary,
      onTap: onInviteToExpenso,
    );
  }
}

class _SmallButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _SmallButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
