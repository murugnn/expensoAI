import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/core/components/expense_card.dart';
import 'package:expenso/theme.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'Month';
  String _selectedCategory = 'All';

  final List<String> _filters = ['Today', 'Week', 'Month', 'All Time'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- DELETE CONFIRMATION DIALOG ---
  Future<void> _confirmDelete(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Transaction?"),
        content: Text("Are you sure you want to remove '${expense.title}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final expenseProvider = context.read<ExpenseProvider>();
      await expenseProvider.deleteExpense(expense.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transaction deleted")),
        );
      }
    }
  }

  // --- CALENDAR POPUP LOGIC ---
  void _showCalendarPopup(
      BuildContext context, ExpenseProvider provider, String currency) {
    final now = DateTime.now();
    // Get stats for current month
    final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
    final firstDayOffset =
        DateTime(now.year, now.month, 1).weekday - 1; // 0=Mon, 6=Sun

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('MMMM yyyy').format(now),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),

              // Days of Week Header
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DayHeader("Mon"),
                  _DayHeader("Tue"),
                  _DayHeader("Wed"),
                  _DayHeader("Thu"),
                  _DayHeader("Fri"),
                  _DayHeader("Sat"),
                  _DayHeader("Sun"),
                ],
              ),
              const SizedBox(height: 8),

              // Calendar Grid
              SizedBox(
                height: 300,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: daysInMonth + firstDayOffset,
                  itemBuilder: (context, index) {
                    if (index < firstDayOffset) {
                      return const SizedBox(); // Empty slots
                    }

                    final dayNum = index - firstDayOffset + 1;

                    // Filter expenses for this specific day
                    final dayTotal = provider.expenses
                        .where((e) =>
                            e.date.year == now.year &&
                            e.date.month == now.month &&
                            e.date.day == dayNum)
                        .fold(0.0, (sum, e) => sum + e.amount);

                    final hasSpend = dayTotal > 0;

                    return Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: hasSpend
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                        border: hasSpend
                            ? Border.all(color: Colors.red.withValues(alpha: 0.3))
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text("$dayNum",
                              style: TextStyle(
                                  fontWeight: hasSpend
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12)),
                          if (hasSpend)
                            FittedBox(
                              child: Text(
                                "$currency${dayTotal.toInt()}",
                                style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.red,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),

              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Close")),
            ],
          ),
        ),
      ),
    );
  }

  List<Expense> _getFilteredExpenses(List<Expense> expenses) {
    final now = DateTime.now();
    List<Expense> filtered = expenses;

    // 1. Date Filter
    switch (_selectedFilter) {
      case 'Today':
        filtered = expenses
            .where((e) =>
                e.date.year == now.year &&
                e.date.month == now.month &&
                e.date.day == now.day)
            .toList();
        break;
      case 'Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = expenses.where((e) => e.date.isAfter(weekAgo)).toList();
        break;
      case 'Month':
        filtered = expenses
            .where((e) => e.date.year == now.year && e.date.month == now.month)
            .toList();
        break;
      case 'All Time':
        break;
    }

    // 2. Category Filter
    if (_selectedCategory != 'All') {
      filtered =
          filtered.where((e) => e.category == _selectedCategory).toList();
    }

    // 3. Search Filter
    if (_searchController.text.isNotEmpty) {
      filtered = filtered
          .where((e) => e.title
              .toLowerCase()
              .contains(_searchController.text.toLowerCase()))
          .toList();
    }

    return filtered;
  }

  Map<String, List<Expense>> _groupByDate(List<Expense> expenses) {
    final Map<String, List<Expense>> grouped = {};
    for (var expense in expenses) {
      final dateKey = DateFormat('MMM dd, yyyy').format(expense.date);
      grouped.putIfAbsent(dateKey, () => []).add(expense);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final expenseProvider = context.watch<ExpenseProvider>();
    final settings = context.watch<AppSettingsProvider>();

    // DYNAMIC CATEGORIES LIST
    final categories = ['All', ...settings.categories];

    final filteredExpenses = _getFilteredExpenses(expenseProvider.expenses);
    final groupedExpenses = _groupByDate(filteredExpenses);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: AppSpacing.paddingMd,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // --- HEADER ROW (Title + Calendar Icon) ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('History',
                            style: context.textStyles.headlineSmall?.bold
                                ?.copyWith(fontFamily: AppTheme.kDisplayFontFamily)),
                        IconButton(
                          onPressed: () => _showCalendarPopup(
                              context, expenseProvider, settings.currencySymbol),
                          icon: const Icon(Icons.calendar_month_rounded),
                          tooltip: "Monthly Overview",
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Search Bar
                    TextField(
                      controller: _searchController,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: Icon(Icons.search_rounded,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor:
                            Theme.of(context).colorScheme.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Time Filters
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => _FilterChip(
                          label: _filters[index],
                          isSelected: _selectedFilter == _filters[index],
                          onTap: () =>
                              setState(() => _selectedFilter = _filters[index]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Filters (Dynamic)
                    SizedBox(
                      height: 40,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: categories.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) => _FilterChip(
                          label: categories[index],
                          isSelected: _selectedCategory == categories[index],
                          onTap: () => setState(
                              () => _selectedCategory = categories[index]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // --- EXPENSE LIST ---
              Expanded(
                child: expenseProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredExpenses.isEmpty
                        ? _buildEmptyState(context)
                        : ListView.builder(
                            padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                            itemCount: groupedExpenses.length,
                            itemBuilder: (context, index) {
                              final dateKey = groupedExpenses.keys.elementAt(index);
                              final expenses = groupedExpenses[dateKey]!;
                              
                              // Group expenses by billId
                              final List<Widget> dayWidgets = [];
                              final processedBills = <String>{};

                              for (var expense in expenses) {
                                if (expense.billId != null) {
                                  if (processedBills.contains(expense.billId)) continue;
                                  
                                  // Found a new bill
                                  processedBills.add(expense.billId!);
                                  final billExpenses = expenses.where((e) => e.billId == expense.billId).toList();
                                  final billTotal = billExpenses.fold(0.0, (sum, e) => sum + e.amount);
                                  final billTitle = (billExpenses.first.billName != null && billExpenses.first.billName!.isNotEmpty) 
                                      ? billExpenses.first.billName! 
                                      : (billExpenses.first.title.isNotEmpty ? billExpenses.first.title : "Bill");
                                  final subtitle = "${billExpenses.length} items • ${billExpenses.first.title} & more";

                                  dayWidgets.add(
                                    _BillCard(
                                      title: billTitle, 
                                      subtitle: subtitle,
                                      count: billExpenses.length,
                                      totalAmount: billTotal,
                                      date: expense.date,
                                      expenses: billExpenses,
                                      onDelete: () async {
                                         // Confirm delete all
                                         final confirm = await showDialog<bool>(
                                           context: context,
                                           builder: (ctx) => AlertDialog(
                                             title: const Text("Delete Bill?"),
                                             content: Text("This will delete all ${billExpenses.length} items in this bill."),
                                             actions: [
                                               TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
                                               FilledButton(
                                                 style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                                 onPressed: () => Navigator.pop(ctx, true), 
                                                 child: const Text("Delete All")
                                               ),
                                             ],
                                           )
                                         );
                                         if (confirm == true) {
                                           final provider = context.read<ExpenseProvider>();
                                           for(var e in billExpenses) {
                                             await provider.deleteExpense(e.id);
                                           }
                                         }
                                      },
                                    )
                                  );
                                } else {
                                  // Standalone Expense
                                  dayWidgets.add(
                                    GestureDetector(
                                        onLongPress: () => _confirmDelete(expense),
                                        child: Dismissible(
                                          key: Key(expense.id),
                                          direction: DismissDirection.endToStart,
                                          confirmDismiss: (direction) async {
                                            _confirmDelete(expense);
                                            return false;
                                          },
                                          background: Container(
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(right: 20),
                                            margin: const EdgeInsets.only(bottom: 12),
                                            decoration: BoxDecoration(
                                              color: Theme.of(context).colorScheme.error,
                                              borderRadius: BorderRadius.circular(16),
                                            ),
                                            child: const Icon(Icons.delete_outline, color: Colors.white),
                                          ),
                                          child: Padding(
                                            padding: const EdgeInsets.only(bottom: 12),
                                            child: ExpenseCard(expense: expense),
                                          ),
                                        ),
                                      )
                                  );
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Text(
                                      dateKey,
                                      style: context.textStyles.titleSmall?.semiBold.copyWith(
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  ...dayWidgets,
                                ],
                              );
                            },
                          ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_rounded,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No transactions found',
            style: context.textStyles.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// --- HELPER WIDGETS ---

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip(
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? cs.primary : Colors.transparent,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? cs.onPrimary : cs.onSurface,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String text;
  const _DayHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int count;
  final double totalAmount;
  final DateTime date;
  final List<Expense> expenses;
  final VoidCallback onDelete;

  const _BillCard({
    required this.title,
    this.subtitle = "",
    required this.count,
    required this.totalAmount,
    required this.date,
    required this.expenses,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // ...
    // Update UI to show subtitle
    // ...
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettingsProvider>();

    return Dismissible(
      key: ValueKey("bill_${expenses.first.billId}"),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onDelete();
        return false; 
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cs.error,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: GestureDetector(
        onTap: () {
          // ... (Modal logic same as before) ...
           showModalBottomSheet(
            context: context,
            backgroundColor: Colors.transparent,
            builder: (ctx) => Container(
              decoration: BoxDecoration(
                color: cs.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), // Bill Name
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: expenses.length,
                      separatorBuilder: (_,__) => const Divider(),
                      itemBuilder: (ctx, i) {
                        final e = expenses[i];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(e.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(e.category),
                          trailing: Text("${settings.currencySymbol} ${e.amount.toStringAsFixed(2)}",
                             style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            )
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.primaryContainer.withValues(alpha: 0.3), // Glassy feel
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: cs.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.receipt_long, color: cs.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "${settings.currencySymbol}${totalAmount.toStringAsFixed(0)}", 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cs.primary)
                  ),
                  const Icon(Icons.arrow_forward_ios, size: 12, color: Colors.grey)
                ],
              )
            ],
          ),
        ),
      ),
    );
  }
}
