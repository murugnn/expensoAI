import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/providers/business_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/models/business_due.dart';

/// Bottom sheet for recording a new due (receivable or payable).
class AddDueSheet extends StatefulWidget {
  const AddDueSheet({super.key});

  @override
  State<AddDueSheet> createState() => _AddDueSheetState();
}

class _AddDueSheetState extends State<AddDueSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  DueDirection _direction = DueDirection.receivable;

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid name and amount.")),
      );
      return;
    }

    final due = BusinessDue(
      id: '',
      userId: '',
      personName: name,
      amount: amount,
      direction: _direction,
      reason: _reasonController.text.trim().isNotEmpty ? _reasonController.text.trim() : null,
    );

    context.read<BusinessProvider>().addDue(due);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Due recorded for $name")),
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
            Text("Record Due",
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Direction selector
            SegmentedButton<DueDirection>(
              segments: const [
                ButtonSegment(value: DueDirection.receivable, label: Text('They Owe Me'), icon: Icon(Icons.arrow_downward, size: 18)),
                ButtonSegment(value: DueDirection.payable, label: Text('I Owe Them'), icon: Icon(Icons.arrow_upward, size: 18)),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: _direction == DueDirection.receivable ? "Customer Name" : "Supplier Name",
                hintText: "e.g. Rahul",
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
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
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: "Reason (optional)",
                hintText: "e.g. 2kg sugar on credit",
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
                child: const Text("Save Due", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
