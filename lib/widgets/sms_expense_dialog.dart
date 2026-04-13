import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/models/expense.dart';
import 'package:uuid/uuid.dart';

class SmsExpenseDialog extends StatefulWidget {
  final double amount;
  final String merchant;
  final DateTime date;

  const SmsExpenseDialog({
    super.key,
    required this.amount,
    required this.merchant,
    required this.date,
  });

  @override
  State<SmsExpenseDialog> createState() => _SmsExpenseDialogState();
}

class _SmsExpenseDialogState extends State<SmsExpenseDialog> {
  String? _selectedCategory;
  final TextEditingController _merchantController = TextEditingController();
  
  final List<String> _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Entertainment',
    'Health',
    'Bills',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _merchantController.text = widget.merchant;
    _selectedCategory = _predictCategory(widget.merchant);
  }

  String _predictCategory(String merchant) {
    String m = merchant.toLowerCase();
    if (m.contains('swiggy') || m.contains('zomato') || m.contains('food') || m.contains('restaurant') || m.contains('cafe') || m.contains('pizza') || m.contains('burger')) return 'Food';
    if (m.contains('uber') || m.contains('ola') || m.contains('rapido') || m.contains('fuel') || m.contains('petrol') || m.contains('metro')) return 'Transport';
    if (m.contains('amazon') || m.contains('flipkart') || m.contains('myntra') || m.contains('mart') || m.contains('store')) return 'Shopping';
    if (m.contains('netflix') || m.contains('spotify') || m.contains('cinema') || m.contains('movie')) return 'Entertainment';
    if (m.contains('hospital') || m.contains('pharmacy') || m.contains('med') || m.contains('doctor')) return 'Health';
    if (m.contains('bill') || m.contains('recharge') || m.contains('electric') || m.contains('water') || m.contains('jio') || m.contains('airtel')) return 'Bills';
    return 'Other';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Expense Detected'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("We found a transaction of ₹${widget.amount}."),
          const SizedBox(height: 10),
          TextField(
            controller: _merchantController,
            decoration: const InputDecoration(
              labelText: 'Merchant/Title',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: _selectedCategory,
            items: _categories.map((c) {
              return DropdownMenuItem(value: c, child: Text(c));
            }).toList(),
            onChanged: (val) => setState(() => _selectedCategory = val),
            decoration: const InputDecoration(
              labelText: 'Category',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Ignore'),
        ),
        FilledButton(
          onPressed: () async {
            final expense = Expense(
              id: const Uuid().v4(),
              userId: '', // Provider will handle this or we fetch current user
              title: _merchantController.text,
              amount: widget.amount,
              date: widget.date,
              category: _selectedCategory ?? 'Other',
            );
            
            // Add via Provider
            try {
               await context.read<ExpenseProvider>().addExpense(expense);
               if (context.mounted) {
                 Navigator.pop(context);
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text("Expense added successfully!")),
                 );
               }
            } catch (e) {
               // Handle error
            }
          },
          child: const Text('Add Expense'),
        ),
      ],
    );
  }
}
