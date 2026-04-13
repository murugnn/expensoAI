import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/theme.dart';
import 'package:expenso/providers/app_settings_provider.dart';

class ExpenseCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const ExpenseCard({
    super.key,
    required this.expense,
    this.onTap,
    this.onDelete,
  });

  // String-based Icon Finder
  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('eat') || cat.contains('dinner'))
      return Icons.restaurant_menu; // More elegant icon
    if (cat.contains('transport') ||
        cat.contains('fuel') ||
        cat.contains('uber')) return Icons.directions_car_filled;
    if (cat.contains('shop') || cat.contains('buy') || cat.contains('mall'))
      return Icons.shopping_bag;
    if (cat.contains('bill') || cat.contains('rent') || cat.contains('wifi'))
      return Icons.receipt;
    if (cat.contains('health') || cat.contains('doctor') || cat.contains('med'))
      return Icons.medical_services;
    if (cat.contains('movie') || cat.contains('fun')) return Icons.theater_comedy;
    if (cat.contains('game')) return Icons.sports_esports;
    return Icons.widgets;
  }

  // String-based Color Finder (Muted/Premium)
  Color _getCategoryColor(BuildContext context, String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food')) return const Color(0xFFE2B495); // Muted Orange
    if (cat.contains('transport')) return const Color(0xFF9DADCC); // Muted Blue
    if (cat.contains('shop')) return const Color(0xFFD4A5A5); // Muted Pink
    if (cat.contains('bill')) return const Color(0xFFB5A5D4); // Muted Purple
    if (cat.contains('health')) return const Color(0xFFA5D4B5); // Muted Green
    return Theme.of(context).colorScheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    // Get Currency
    final currency = context.watch<AppSettingsProvider>().currencySymbol;
    final cs = Theme.of(context).colorScheme;

    return Dismissible(
      key: Key(expense.id),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      onDismissed: (_) => onDelete?.call(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: AppSpacing.paddingMd,
        decoration: BoxDecoration(
          color: cs.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(Icons.delete_outline, color: cs.error),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outline.withValues(alpha: 0.1)),
           boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(context, expense.category)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCategoryIcon(expense.category),
                    color: _getCategoryColor(context, expense.category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),

                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: cs.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                       Row(
                          children: [
                            Text(
                              DateFormat('MMM dd • ').format(expense.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                            Text(
                              expense.category,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: cs.onSurface.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Amount
                Text(
                  '$currency${expense.amount.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: cs.primary,
                    fontFamily: 'Ndot', // Number emphasis
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
