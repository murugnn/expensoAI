import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:go_router/go_router.dart';

class ScannedItemsScreen extends StatefulWidget {
  final List<Expense> scannedItems;

  const ScannedItemsScreen({super.key, required this.scannedItems});

  @override
  State<ScannedItemsScreen> createState() => _ScannedItemsScreenState();
}

class _ScannedItemsScreenState extends State<ScannedItemsScreen> {
  late List<Expense> _items;

  @override
  void initState() {
    super.initState();
    _items = List.from(widget.scannedItems);
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
  }

  void _updateItem(int index, Expense newItem) {
    setState(() {
      _items[index] = newItem;
    });
  }

  Future<void> _saveAll() async {
    final expenseProvider = context.read<ExpenseProvider>();
    final userId = context.read<AuthProvider>().currentUser?.id;

    if (userId == null) return;

    for (var item in _items) {
      final expenseToSave = Expense(
        id: item.id,
        userId: userId,
        title: item.title,
        amount: item.amount,
        date: item.date,
        category: item.category,
        wallet: item.wallet, 
      );
      await expenseProvider.addExpense(expenseToSave);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Added ${_items.length} expenses!')),
      );
      context.pop(); 
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final categories = context.watch<AppSettingsProvider>().categories;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Scanned Items'),
        actions: [
          if (_items.isNotEmpty)
            TextButton.icon(
              onPressed: _saveAll,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Add All"),
            )
        ],
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.receipt_long_outlined, size: 64, color: cs.secondary),
                   const SizedBox(height: 16),
                   Text("No items found", style: Theme.of(context).textTheme.titleLarge),
                   const SizedBox(height: 8),
                   const Text("Try scanning again with better lighting."),
                ],
              ),
            )
          : ListView.separated(
              itemCount: _items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = _items[index];
                return Dismissible(
                  key: Key(item.id),
                  background: Container(
                    color: cs.errorContainer,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: Icon(Icons.delete, color: cs.onErrorContainer),
                  ),
                  onDismissed: (_) => _removeItem(index),
                  child: ListTile(
                    title: TextFormField(
                      initialValue: item.title,
                      decoration: const InputDecoration(border: InputBorder.none),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      onChanged: (val) {
                         _updateItem(index, item.copyWith(title: val));
                      },
                    ),
                    subtitle: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: categories.contains(item.category) ? item.category : categories.firstOrNull,
                        isDense: true,
                        style: TextStyle(color: cs.primary, fontSize: 13),
                        icon: Icon(Icons.arrow_drop_down, color: cs.primary, size: 20),
                        items: categories.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        )).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            _updateItem(index, item.copyWith(category: val));
                          }
                        },
                      ),
                    ),
                    trailing: SizedBox(
                      width: 80,
                      child: TextFormField(
                        initialValue: item.amount.toStringAsFixed(2),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          prefixText: '\$ ', 
                          border: InputBorder.none
                        ),
                        onChanged: (val) {
                          final amt = double.tryParse(val);
                          if (amt != null) {
                            _updateItem(index, item.copyWith(amount: amt));
                          }
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
