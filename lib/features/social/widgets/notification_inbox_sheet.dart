import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/social_provider.dart';
import 'package:expenso/models/notification_event.dart';

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}/${dt.year}';
}

class NotificationInboxSheet extends StatelessWidget {
  const NotificationInboxSheet({super.key});

  static void show(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const NotificationInboxSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final social = context.watch<SocialProvider>();
    final events = social.notificationEvents;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (social.unreadNotificationCount > 0)
                      TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          social.markAllNotificationsRead();
                        },
                        child: Text(
                          'Mark all read',
                          style: TextStyle(
                            fontSize: 13,
                            color: cs.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              // List
              Expanded(
                child: events.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.notifications_none_rounded,
                                size: 48, color: cs.onSurface.withOpacity(0.2)),
                            const SizedBox(height: 12),
                            Text(
                              'No notifications yet',
                              style: TextStyle(
                                  color: cs.onSurface.withOpacity(0.4),
                                  fontSize: 14),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: events.length,
                        separatorBuilder: (_, __) => Divider(
                          height: 1,
                          color: cs.outlineVariant.withOpacity(0.3),
                        ),
                        itemBuilder: (_, i) {
                          final ev = events[i];
                          return _NotificationTile(
                            event: ev,
                            onTap: () {
                              social.markNotificationRead(ev.id);
                              _handleAction(context, ev);
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

  void _handleAction(BuildContext context, NotificationEvent ev) {
    final social = context.read<SocialProvider>();
    switch (ev.type) {
      case NotificationEvent.typeFriendRequest:
        final reqId = ev.payload['request_id']?.toString();
        if (reqId != null) {
          _showFriendRequestDialog(context, social, ev, reqId);
        }
        break;
      case NotificationEvent.typeRoomInvite:
        final invId = ev.payload['invite_id']?.toString();
        if (invId != null) {
          _showRoomInviteDialog(context, social, ev, invId);
        }
        break;
      default:
        break;
    }
  }

  void _showFriendRequestDialog(
      BuildContext context, SocialProvider social, NotificationEvent ev, String reqId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ev.title),
        content: ev.body != null ? Text(ev.body!) : null,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              social.declineFriendRequest(reqId);
            },
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              social.acceptFriendRequest(reqId);
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _showRoomInviteDialog(
      BuildContext context, SocialProvider social, NotificationEvent ev, String invId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ev.title),
        content: ev.body != null ? Text(ev.body!) : null,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              social.declineRoomInvite(invId);
            },
            child: const Text('Decline'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final roomId = await social.acceptRoomInvite(invId);
              if (ctx.mounted && roomId != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Joined room successfully!')),
                );
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationEvent event;
  final VoidCallback onTap;
  const _NotificationTile({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isUnread = !event.isRead;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _iconColor(event.type, cs).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_icon(event.type), size: 20, color: _iconColor(event.type, cs)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.title,
                    style: TextStyle(
                      fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  if (event.body != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      event.body!,
                      style: TextStyle(
                        fontSize: 12,
                        color: cs.onSurface.withOpacity(0.55),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _relativeTime(event.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurface.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
            if (isUnread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String type) {
    switch (type) {
      case NotificationEvent.typeFriendRequest:
        return Icons.person_add_outlined;
      case NotificationEvent.typeFriendAccepted:
        return Icons.how_to_reg_outlined;
      case NotificationEvent.typeRoomInvite:
        return Icons.group_add_outlined;
      case NotificationEvent.typeRoomInviteAccepted:
        return Icons.check_circle_outline;
      case NotificationEvent.typeSharedExpenseAdded:
        return Icons.receipt_long_outlined;
      case NotificationEvent.typeSettleOwed:
      case NotificationEvent.typeSettlementReceived:
        return Icons.payments_outlined;
      case NotificationEvent.typeSettlementReminder:
        return Icons.alarm_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(String type, ColorScheme cs) {
    switch (type) {
      case NotificationEvent.typeFriendRequest:
      case NotificationEvent.typeFriendAccepted:
        return cs.primary;
      case NotificationEvent.typeRoomInvite:
      case NotificationEvent.typeRoomInviteAccepted:
        return cs.tertiary;
      case NotificationEvent.typeSettlementReminder:
        return cs.error;
      default:
        return cs.secondary;
    }
  }
}
