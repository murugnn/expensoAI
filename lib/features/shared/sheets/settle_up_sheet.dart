import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:expenso/providers/shared_provider.dart';

class SettleUpSheet extends StatelessWidget {
  final String roomId;
  final String currentUserId;
  final String currencySymbol;
  const SettleUpSheet({
    super.key,
    required this.roomId,
    required this.currentUserId,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shared = context.watch<SharedProvider>();
    final transfers = shared.suggestSettlementsFor(roomId);
    final members = shared.membersOf(roomId);

    String displayName(String userId) {
      final m = members.where((x) => x.userId == userId);
      if (m.isEmpty) return userId.substring(0, 6);
      return m.first.displayName ?? 'Member';
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          Row(
            children: [
              Icon(Icons.compare_arrows_rounded, color: cs.primary, size: 26),
              const SizedBox(width: 10),
              Text(
                'Settle up',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            transfers.isEmpty
                ? 'Everyone is square — nothing to settle.'
                : 'The fewest transfers needed to balance the books.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13),
          ),
          const SizedBox(height: 18),
          if (transfers.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              alignment: Alignment.center,
              child: Column(
                children: [
                  Icon(Icons.check_circle_outline_rounded,
                      size: 56, color: cs.primary.withOpacity(0.6)),
                  const SizedBox(height: 12),
                  Text(
                    'All clear',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            )
          else
            ...transfers.map((t) {
              final fromIsMe = t.fromUserId == currentUserId;
              final toIsMe = t.toUserId == currentUserId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    _personPill(context,
                        label: fromIsMe ? 'You' : (t.fromName ?? displayName(t.fromUserId)),
                        highlight: fromIsMe),
                    const SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded,
                        size: 16, color: cs.onSurfaceVariant),
                    const SizedBox(width: 8),
                    _personPill(context,
                        label: toIsMe ? 'You' : (t.toName ?? displayName(t.toUserId)),
                        highlight: toIsMe),
                    const Spacer(),
                    Text(
                      '$currencySymbol${t.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                      ),
                    ),
                  ],
                ),
              );
            }),
          if (transfers.isNotEmpty) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  final n = await shared.settleAll(roomId);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(n == 0
                          ? 'Nothing to settle.'
                          : 'Recorded $n settlement${n == 1 ? "" : "s"}.'),
                    ),
                  );
                },
                child: const Text(
                  'Mark all settled',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _personPill(BuildContext context,
      {required String label, required bool highlight}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight ? cs.primary.withOpacity(0.12) : cs.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: highlight ? cs.primary : cs.onSurface,
        ),
      ),
    );
  }
}
