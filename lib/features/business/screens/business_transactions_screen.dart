import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expenso/providers/business_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/models/business_transaction.dart';
import 'package:expenso/theme.dart';

class BusinessTransactionsScreen extends StatefulWidget {
  const BusinessTransactionsScreen({super.key});

  @override
  State<BusinessTransactionsScreen> createState() => _BusinessTransactionsScreenState();
}

class _BusinessTransactionsScreenState extends State<BusinessTransactionsScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = 'Month';
  String _selectedCategory = 'All';

  final List<String> _filters = ['Today', 'Week', 'Month', 'All Time'];
  final List<String> _categories = ['All', 'Revenue', 'Expense', 'Inventory'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete(BusinessTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Transaction?"),
        content: Text("Are you sure you want to remove '${transaction.title}'?"),
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
      final provider = context.read<BusinessProvider>();
      await provider.deleteTransaction(transaction.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Transaction deleted")),
        );
      }
    }
  }

  List<BusinessTransaction> _getFilteredTransactions(List<BusinessTransaction> transactions) {
    final now = DateTime.now();
    List<BusinessTransaction> filtered = transactions;

    // 1. Date Filter
    switch (_selectedFilter) {
      case 'Today':
        filtered = transactions.where((e) => e.date.year == now.year && e.date.month == now.month && e.date.day == now.day).toList();
        break;
      case 'Week':
        final weekAgo = now.subtract(const Duration(days: 7));
        filtered = transactions.where((e) => e.date.isAfter(weekAgo)).toList();
        break;
      case 'Month':
        filtered = transactions.where((e) => e.date.year == now.year && e.date.month == now.month).toList();
        break;
      case 'All Time':
        break;
    }

    // 2. Category / Type Filter
    switch (_selectedCategory) {
      case 'Revenue':
        filtered = filtered.where((t) => t.isRevenue).toList();
        break;
      case 'Expense':
        filtered = filtered.where((t) => t.isExpense).toList();
        break;
      case 'Inventory':
        filtered = filtered.where((t) => t.isInventory).toList();
        break;
    }

    // 3. Search Filter
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((e) =>
          e.title.toLowerCase().contains(query) ||
          (e.customerName?.toLowerCase().contains(query) ?? false) ||
          (e.itemName?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    // Sort by date descending
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  Map<String, List<BusinessTransaction>> _groupByDate(List<BusinessTransaction> transactions) {
    final Map<String, List<BusinessTransaction>> grouped = {};
    for (var t in transactions) {
      final dateKey = DateFormat('MMM dd, yyyy').format(t.date);
      grouped.putIfAbsent(dateKey, () => []).add(t);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    final bizProvider = context.watch<BusinessProvider>();
    final settings = context.watch<AppSettingsProvider>();

    final filteredTransactions = _getFilteredTransactions(bizProvider.transactions);
    final groupedTransactions = _groupByDate(filteredTransactions);

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
                  Text('Business History',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontFamily: AppTheme.kDisplayFontFamily)),
                  const SizedBox(height: 16),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search customer, bill...',
                      prefixIcon: Icon(Icons.search_rounded,
                          color: Theme.of(context).colorScheme.onSurfaceVariant),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                        onTap: () => setState(() => _selectedFilter = _filters[index]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Category Filters
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) => _FilterChip(
                        label: _categories[index],
                        isSelected: _selectedCategory == _categories[index],
                        onTap: () => setState(() => _selectedCategory = _categories[index]),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- TRANSACTION LIST ---
            Expanded(
              child: bizProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredTransactions.isEmpty
                      ? _buildEmptyState(context)
                      : ListView.builder(
                          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 100),
                          itemCount: groupedTransactions.length,
                          itemBuilder: (context, index) {
                            final dateKey = groupedTransactions.keys.elementAt(index);
                            final transactions = groupedTransactions[dateKey]!;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  child: Text(
                                    dateKey,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                                ...transactions.map((t) => GestureDetector(
                                  onLongPress: () => _confirmDelete(t),
                                  child: Dismissible(
                                    key: Key(t.id),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (direction) async {
                                      _confirmDelete(t);
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
                                    child: _BusinessTransactionCard(transaction: t, currency: settings.currencySymbol),
                                  ),
                                )),
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
          Icon(Icons.point_of_sale_rounded,
              size: 64, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 16),
          Text(
            'No transactions yet',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.isSelected, required this.onTap});

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

class _BusinessTransactionCard extends StatelessWidget {
  final BusinessTransaction transaction;
  final String currency;

  const _BusinessTransactionCard({required this.transaction, required this.currency});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color amountColor = cs.onSurface;
    IconData icon = Icons.receipt_long;
    Color iconColor = cs.primary;
    String prefix = "";

    if (transaction.isRevenue) {
      amountColor = Colors.green;
      icon = Icons.point_of_sale_rounded;
      iconColor = Colors.green;
      prefix = "+";
    } else if (transaction.isExpense) {
      amountColor = Colors.red;
      icon = Icons.trending_down_rounded;
      iconColor = Colors.red;
      prefix = "-";
    } else if (transaction.isInventory) {
      amountColor = Colors.orange;
      icon = Icons.inventory_2_rounded;
      iconColor = Colors.orange;
      prefix = "-";
    }

    String subtitle = transaction.category;
    if (transaction.customerName != null && transaction.customerName!.isNotEmpty) {
      subtitle += " • ${transaction.customerName}";
    }
    if (transaction.quantity != null && transaction.quantity! > 0) {
       subtitle += " • x${transaction.quantity}";
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  subtitle,
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            "$prefix$currency${transaction.amount.toStringAsFixed(0)}",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
