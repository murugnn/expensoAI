import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:expenso/models/shared_room.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/shared_provider.dart';
import 'package:expenso/features/shared/screens/shared_room_screen.dart';
import 'package:expenso/features/shared/sheets/create_room_sheet.dart';
import 'package:expenso/features/shared/sheets/join_room_sheet.dart';

/// Premium "Shared" card that lives directly under the Ask Niva button on the
/// dashboard. Designed to match the existing Expenso visual language —
/// rounded surface, outline variant border, no glassy fluff, just space + type.
class SharedDashboardSection extends StatelessWidget {
  const SharedDashboardSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shared = context.watch<SharedProvider>();
    final rooms = shared.rooms;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Shared',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: cs.onSurface,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: rooms.length + 1,
            separatorBuilder: (_, __) => const SizedBox(width: 16),
            itemBuilder: (ctx, i) {
              if (i == rooms.length) {
                // The + button at the end
                return _DottedAddButton(onTap: () => _showJoinOrCreateOptions(context));
              }
              final r = rooms[i];
              return _RoomAvatar(
                room: r,
                index: i,
                onTap: () => _open(context, r),
                onLongPress: () => _showRoomOptions(context, r),
              );
            },
          ),
        ),
      ],
    ).animate().fadeIn(duration: 380.ms).slideY(begin: 0.05, end: 0, duration: 380.ms, curve: Curves.easeOutCubic);
  }

  void _showJoinOrCreateOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Text('Shared Rooms', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.add_circle_outline_rounded),
                title: const Text('Create a new room'),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const CreateRoomSheet(),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.input_rounded),
                title: const Text('Join existing room'),
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const JoinRoomSheet(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRoomOptions(BuildContext context, SharedRoom room) {
    HapticFeedback.heavyImpact();
    final cs = Theme.of(context).colorScheme;
    final shared = context.read<SharedProvider>();
    final isOwner = room.ownerId == context.read<AuthProvider>().currentUser?.id;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text(room.roomName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(Icons.logout_rounded, color: cs.error),
                title: Text('Leave room', style: TextStyle(color: cs.error)),
                onTap: () async {
                  Navigator.pop(ctx);
                  final ok = await _confirm(context, 'Leave room?', 'You can rejoin with the code later.');
                  if (ok && context.mounted) {
                    await shared.leaveRoom(room.id);
                  }
                },
              ),
              if (isOwner)
                ListTile(
                  leading: Icon(Icons.delete_forever_rounded, color: cs.error),
                  title: Text('Delete room', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final ok = await _confirm(context, 'Delete room?', 'All members will lose access.');
                    if (ok && context.mounted) {
                      await shared.deleteRoom(room.id);
                    }
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final cs = Theme.of(context).colorScheme;
    final res = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cs.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    return res ?? false;
  }

  void _open(BuildContext context, SharedRoom room) {
    HapticFeedback.selectionClick();
    final auth = context.read<AuthProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => SharedRoomScreen(
          roomId: room.id,
          currentUserId: auth.currentUser?.id ?? '',
          currencySymbol: currency,
        ),
        transitionsBuilder: (_, anim, __, child) {
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}

class _RoomAvatar extends StatelessWidget {
  final SharedRoom room;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _RoomAvatar({
    required this.room,
    required this.index,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              shape: BoxShape.circle,
              border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
            ),
            child: ClipOval(
              child: room.imageUrl != null && room.imageUrl!.isNotEmpty
                  ? Image.network(
                      room.imageUrl!,
                      fit: BoxFit.cover,
                      width: 52,
                      height: 52,
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(room.typeIcon, size: 24, color: cs.primary),
                    )
                  : Icon(room.typeIcon, size: 24, color: cs.primary),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              room.roomName,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.onSurface),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (40 * index).ms, duration: 320.ms).scaleXY(begin: 0.8, end: 1.0, delay: (40 * index).ms, curve: Curves.easeOutCubic);
  }
}

class _DottedAddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DottedAddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            painter: _DottedCirclePainter(color: cs.outlineVariant, strokeWidth: 1.5, dashWidth: 4, dashSpace: 4),
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              child: Icon(Icons.add_rounded, size: 24, color: cs.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 60,
            child: Text(
              'Add',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _DottedCirclePainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;

  _DottedCirclePainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashWidth = 4.0,
    this.dashSpace = 4.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final circumference = 2 * 3.141592653589793 * radius;
    final dashCount = (circumference / (dashWidth + dashSpace)).floor();

    final sweepAngle = (dashWidth / circumference) * 2 * 3.141592653589793;
    final spaceAngle = (dashSpace / circumference) * 2 * 3.141592653589793;

    double startAngle = -3.141592653589793 / 2; // Start at top

    for (int i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(radius, radius), radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle + spaceAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DottedCirclePainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }
}
