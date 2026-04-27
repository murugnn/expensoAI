import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/business_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/models/business_transaction.dart';

/// Bottom sheet for adding a revenue / sale transaction.
class AddRevenueSheet extends StatefulWidget {
  const AddRevenueSheet({super.key});

  @override
  State<AddRevenueSheet> createState() => _AddRevenueSheetState();
}

class _AddRevenueSheetState extends State<AddRevenueSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _customerController = TextEditingController();
  final _noteController = TextEditingController();
  TransactionType _type = TransactionType.revenue;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _customerController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _save() {
    final title = _titleController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid title and amount.")),
      );
      return;
    }

    final txn = BusinessTransaction(
      id: '',
      userId: '',
      type: _type,
      title: title,
      amount: amount,
      date: DateTime.now(),
      category: _type == TransactionType.revenue ? 'Sales' : (_type == TransactionType.expense ? 'Business Expense' : 'Inventory'),
      customerName: _customerController.text.trim().isNotEmpty ? _customerController.text.trim() : null,
      note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
    );

    context.read<BusinessProvider>().addTransaction(txn);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("${_type == TransactionType.revenue ? 'Sale' : 'Expense'} recorded!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final currency = context.read<AppSettingsProvider>().currencySymbol;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text("Add Business Entry",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Type selector
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(value: TransactionType.revenue, label: Text('Sale'), icon: Icon(Icons.point_of_sale_rounded, size: 18)),
                ButtonSegment(value: TransactionType.expense, label: Text('Expense'), icon: Icon(Icons.trending_down, size: 18)),
                ButtonSegment(value: TransactionType.inventoryPurchase, label: Text('Stock'), icon: Icon(Icons.inventory_2, size: 18)),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Title",
                hintText: _type == TransactionType.revenue ? "e.g. Sold 5 chai" : "e.g. Bought sugar",
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: "Amount",
                prefixText: "$currency ",
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _customerController,
              decoration: InputDecoration(
                labelText: _type == TransactionType.revenue ? "Customer Name (optional)" : "Supplier (optional)",
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: "Note (optional)",
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: _save,
                child: const Text("Save", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
