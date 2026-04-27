import 'package:flutter/material.dart';
import 'package:expenso/models/business_due.dart';

/// Compact card showing pending customer dues (receivables).
/// Shown on the dashboard when Expenso for Business mode is active.
class PendingDuesCard extends StatelessWidget {
  final List<BusinessDue> pendingDues;
  final String currency;
  final VoidCallback? onMarkPaid;

  const PendingDuesCard({
    super.key,
    required this.pendingDues,
    this.currency = '₹',
    this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) {
    if (pendingDues.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final displayDues = pendingDues.take(4).toList();
    final totalAmount = pendingDues.fold(0.0, (s, d) => s + d.amount);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.people_alt_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 8),
              Text(
                'Pending Collections',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$currency${totalAmount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade400,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Due items
          ...displayDues.map((due) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: cs.primaryContainer.withOpacity(0.6),
                      child: Text(
                        due.personName.isNotEmpty
                            ? due.personName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            due.personName,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cs.onSurface,
                            ),
                          ),
                          if (due.reason != null && due.reason!.isNotEmpty)
                            Text(
                              due.reason!,
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurface.withOpacity(0.5),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(
                      '$currency${due.amount.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade400,
                      ),
                    ),
                  ],
                ),
              )),

          if (pendingDues.length > 4)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '+${pendingDues.length - 4} more',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
