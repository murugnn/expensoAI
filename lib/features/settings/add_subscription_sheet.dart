import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expenso/models/subscription.dart';
import 'package:expenso/providers/subscription_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';

class AddSubscriptionSheet extends StatefulWidget {
  const AddSubscriptionSheet({super.key});

  @override
  State<AddSubscriptionSheet> createState() => _AddSubscriptionSheetState();
}

class _AddSubscriptionSheetState extends State<AddSubscriptionSheet> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();

  String _selectedCycle = 'Monthly';
  DateTime _nextBillDate = DateTime.now();
  String? _selectedCategory;
  String? _selectedWallet;
  bool _autoAdd = true;
  bool _isLoading = false;

  final List<String> _cycles = ['Weekly', 'Monthly', 'Yearly'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = context.read<AppSettingsProvider>();
      if (settings.categories.isNotEmpty) {
        setState(() => _selectedCategory = settings.categories.first);
      }
      if (settings.wallets.isNotEmpty) {
        setState(() => _selectedWallet = settings.wallets.first);
      }
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextBillDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null) setState(() => _nextBillDate = picked);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final amountText = _amountController.text.trim();

    if (name.isEmpty || amountText.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid amount")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) return;

      final sub = Subscription(
        id: const Uuid().v4(), // Placeholder, Supabase or Provider might handle ID but better generate here if needed or let DB do it. 
        // Actually, for Supabase insert, we usually let DB generate ID or generate UUID here. 
        // Provider addSubscription inserts and then replaces with DB return.
        // Let's rely on provider logic or just generate one.
        // Provider code uses `subscription.toSupabase()` which doesn't include ID. 
        // So ID here is just for local object creation.
        userId: user.id,
        name: name,
        amount: amount,
        billingCycle: _selectedCycle,
        nextBillDate: _nextBillDate,
        category: _selectedCategory!,
        wallet: _selectedWallet ?? 'Cash',
        autoAdd: _autoAdd,
      );

      final err = await context.read<SubscriptionProvider>().addSubscription(sub);

      if (mounted) {
        if (err != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(err)),
          );
        } else {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final currency = settings.currencySymbol;

    return Container(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("New Subscription",
                    style: Theme.of(context).textTheme.titleLarge),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Service Name (e.g. Netflix)",
                prefixIcon: Icon(Icons.subscriptions),
                border: OutlineInputBorder(),
              ),
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
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: "Billing Cycle",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCycle,
                        isDense: true,
                        items: _cycles.map((c) => DropdownMenuItem(
                          value: c,
                          child: Text(c),
                        )).toList(),
                        onChanged: (val) => setState(() => _selectedCycle = val!),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: "Next Bill Date",
                        border: OutlineInputBorder(),
                        suffixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(
                        DateFormat('MMM d, y').format(_nextBillDate),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isDense: true,
                  items: settings.categories.map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c),
                  )).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text("Auto-Add Expense"),
              subtitle: const Text("Automatically create an expense when due"),
              value: _autoAdd,
              onChanged: (val) => setState(() => _autoAdd = val),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _isLoading ? null : _save,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Add Subscription"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
