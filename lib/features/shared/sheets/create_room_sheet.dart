import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import 'package:expenso/models/shared_room.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/shared_provider.dart';
import 'package:expenso/features/shared/screens/shared_room_screen.dart';
import 'package:expenso/providers/auth_provider.dart';

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final _nameCtrl = TextEditingController();
  SharedRoomType _type = SharedRoomType.flatmates;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final shared = context.read<SharedProvider>();
    final currency = context.read<AppSettingsProvider>().currencySymbol;
    final auth = context.read<AuthProvider>();

    final room = await shared.createRoom(
      roomName: name,
      type: _type,
      currency: currency.replaceAll(RegExp(r'\s+'), ''),
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (room == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not create room. Try again.')),
      );
      return;
    }

    Navigator.of(context).pop();
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (_, __, ___) => SharedRoomScreen(
          roomId: room.id,
          currentUserId: auth.currentUser?.id ?? '',
          currencySymbol: currency,
        ),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.05), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottom),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.5,
        maxChildSize: 0.92,
        expand: false,
        builder: (ctx, controller) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 4, bottom: 18),
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'New shared room',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Pick a category, name it, and we will mint a code your\nfriends can join with.',
                    style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 22),

                  // ---- Name ----
                  Text('Room name',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Goa Trip, Apt 402, Dinner Crew',
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ---- Type picker ----
                  Text('Category',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: SharedRoomType.values
                        .asMap()
                        .entries
                        .map((entry) {
                          final t = entry.value;
                          final selected = _type == t;
                          return GestureDetector(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              setState(() => _type = t);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: selected
                                    ? cs.primary.withOpacity(0.1)
                                    : cs.surface,
                                border: Border.all(
                                  color: selected
                                      ? cs.primary
                                      : cs.outlineVariant.withOpacity(0.5),
                                  width: selected ? 1.5 : 1,
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _iconFor(t),
                                    size: 18,
                                    color: selected ? cs.primary : cs.onSurface,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _labelFor(t),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          selected ? cs.primary : cs.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).animate(delay: (40 * entry.key).ms).fadeIn(duration: 240.ms);
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 28),

                  // ---- Submit ----
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: _saving ? null : _create,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text(
                              'Create room',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  IconData _iconFor(SharedRoomType t) {
    switch (t) {
      case SharedRoomType.flatmates:
        return Icons.home_work_rounded;
      case SharedRoomType.trip:
        return Icons.flight_takeoff_rounded;
      case SharedRoomType.couple:
        return Icons.favorite_rounded;
      case SharedRoomType.friends:
        return Icons.handshake_rounded;
      case SharedRoomType.team:
        return Icons.groups_rounded;
      case SharedRoomType.custom:
        return Icons.category_rounded;
    }
  }

  String _labelFor(SharedRoomType t) {
    switch (t) {
      case SharedRoomType.flatmates:
        return 'Flatmates';
      case SharedRoomType.trip:
        return 'Trip';
      case SharedRoomType.couple:
        return 'Couple';
      case SharedRoomType.friends:
        return 'Friends';
      case SharedRoomType.team:
        return 'Team';
      case SharedRoomType.custom:
        return 'Custom';
    }
  }
}
