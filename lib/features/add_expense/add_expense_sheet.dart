import 'dart:async'; // Required for Timer (Debounce)
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:expenso/models/expense.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/providers/contact_provider.dart';
import 'package:expenso/theme.dart';

// --- IMPORT ML SERVICE ---
import 'package:expenso/services/ml_service.dart';
import 'package:expenso/ml/detectors/anomaly_detector.dart'; // For AnomalyResult type

class AddExpenseSheet extends StatefulWidget {
  final Expense? expenseToEdit;
  final Expense? prefilledData; // New parameter for scanned data
  const AddExpenseSheet({super.key, this.expenseToEdit, this.prefilledData});

  @override
  State<AddExpenseSheet> createState() => _AddExpenseSheetState();
}

class _AddExpenseSheetState extends State<AddExpenseSheet> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedCategory;
  String? _selectedWallet;
  final List<String> _selectedTags = [];
  String? _selectedContactName;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  // --- AI STATE VARIABLES ---
  Timer? _debounceTimer; // Delays AI prediction while typing
  bool _isAutoCategorizing = false;
  AnomalyResult? _anomalyWarning; // Stores current anomaly status

  @override
  void initState() {
    super.initState();

    // Initialize ML Service
    //MLService().init();

    if (widget.expenseToEdit != null) {
      _populateExistingData(widget.expenseToEdit!);
    } else if (widget.prefilledData != null) {
       _populateExistingData(widget.prefilledData!);
    }

    // Add Listeners for AI
    _titleController.addListener(_onTitleChanged);
    _amountController.addListener(_checkAnomaly);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final settings = context.read<AppSettingsProvider>();

      if (_selectedCategory == null && settings.categories.isNotEmpty) {
        setState(() => _selectedCategory = settings.categories.first);
      }
      if (_selectedWallet == null) {
        if (settings.lastUsedWallet != null &&
            settings.wallets.contains(settings.lastUsedWallet)) {
          setState(() => _selectedWallet = settings.lastUsedWallet);
        } else if (settings.wallets.isNotEmpty) {
          setState(() => _selectedWallet = settings.wallets.first);
        }
      }
      await context.read<ContactProvider>().loadContacts();
    });
  }

  void _populateExistingData(Expense e) {
    _titleController.text = e.title;
    _amountController.text = e.amount.toString();
    _selectedCategory = e.category;
    _selectedWallet = e.wallet;
    _selectedDate = e.date;
    _selectedTags.addAll(e.tags);

    final contactTag = e.tags
        .firstWhere((t) => t.startsWith("contact:"), orElse: () => "");
    if (contactTag.isNotEmpty) {
      _selectedContactName = contactTag.replaceFirst("contact:", "");
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTitleChanged);
    _amountController.removeListener(_checkAnomaly);
    _titleController.dispose();
    _amountController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  // --- LAYER 1: AUTO-CATEGORIZATION LOGIC ---
  void _onTitleChanged() {
    // If user is editing an existing expense, don't auto-change category
    if (widget.expenseToEdit != null) return;

    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();

    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      final text = _titleController.text.trim();
      if (text.length < 3) return;

      setState(() => _isAutoCategorizing = true);

      final predictedCat = await MLService().predictCategory(text);

      if (mounted) {
        setState(() {
          _isAutoCategorizing = false;
          // Only auto-select if valid and user hasn't manually locked one (optional logic)
          if (predictedCat != null) {
            // Verify this category actually exists in settings
            final settings = context.read<AppSettingsProvider>();
            if (settings.categories.contains(predictedCat)) {
              _selectedCategory = predictedCat;

              // Re-check anomaly since category changed
              _checkAnomaly();
            }
          }
        });
      }
    });
  }

  // --- LAYER 2: ANOMALY DETECTION LOGIC ---
  void _checkAnomaly() {
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    final category = _selectedCategory;

    if (amount == null || category == null) {
      if (_anomalyWarning != null) setState(() => _anomalyWarning = null);
      return;
    }

    // 1. Get History from Provider
    final allExpenses = context.read<ExpenseProvider>().expenses;
    final history = allExpenses
        .where((e) => e.category == category)
        .map((e) => e.amount)
        .toList();

    // 2. Check with AI
    final result = MLService().checkAnomaly(amount, history);

    setState(() {
      _anomalyWarning = result.isAnomaly ? result : null;
    });
  }

  IconData _getCategoryIcon(String category) {
    final cat = category.toLowerCase();
    if (cat.contains('food') || cat.contains('eat'))
      return Icons.restaurant_rounded;
    if (cat.contains('transport') || cat.contains('fuel'))
      return Icons.directions_car_rounded;
    if (cat.contains('shop') || cat.contains('buy'))
      return Icons.shopping_bag_rounded;
    if (cat.contains('bill')) return Icons.receipt_long_rounded;
    return Icons.category_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettingsProvider>();
    final currency = settings.currencySymbol;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final contactProvider = context.watch<ContactProvider>();
    final contacts = contactProvider.contacts;

    return Container(
      padding: EdgeInsets.fromLTRB(24, 24, 24, viewInsets + 24),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // HEADER
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.expenseToEdit == null ? 'New Expense' : 'Edit Expense',
                  style: context.textStyles.titleLarge?.bold,
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // AMOUNT
            TextField(
              controller: _amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style: context.textStyles.headlineMedium?.bold
                  .copyWith(color: cs.primary),
              decoration: InputDecoration(
                prefixText: '$currency ',
                hintText: '0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
              ),
            ),

            // --- ANOMALY WARNING WIDGET ---
            if (_anomalyWarning != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: AnimatedOpacity(
                  opacity: 1.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded,
                            color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _anomalyWarning!.message,
                            style: const TextStyle(
                                color: Colors.deepOrange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // TITLE
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'What was this for?',
                prefixIcon:
                    Icon(Icons.edit_note_rounded, color: cs.onSurfaceVariant),
                // Show AI Loading Indicator
                suffixIcon: _isAutoCategorizing
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 16),

            // CATEGORY + WALLET
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    context,
                    value: _selectedCategory,
                    items: settings.categories,
                    iconBuilder: (item) => _getCategoryIcon(item),
                    onChanged: (val) {
                      setState(() => _selectedCategory = val);
                      _checkAnomaly(); // Re-check if user manually changes category
                    },
                    hint: "Category",
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDropdown(
                    context,
                    value: _selectedWallet,
                    items: settings.wallets,
                    iconBuilder: (_) => Icons.account_balance_wallet_rounded,
                    onChanged: (val) => setState(() => _selectedWallet = val),
                    hint: "Wallet",
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // CONTACT DROPDOWN (Unchanged logic)
            Text("Contact", style: context.textStyles.titleMedium?.bold),
            const SizedBox(height: 10),
            _buildContactDropdown(cs, contacts, contactProvider),

            const SizedBox(height: 16),

            // DATE PICKER
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today_rounded,
                        size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, y').format(_selectedDate),
                      style: context.textStyles.bodyMedium?.bold,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // SAVE BUTTON
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isLoading ? null : _saveExpense,
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Expense"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- HELPER WIDGETS ---

  Widget _buildDropdown(
    BuildContext context, {
    required String? value,
    required List<String> items,
    required IconData Function(String) iconBuilder,
    required Function(String?) onChanged,
    required String hint,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.contains(value) ? value : null,
          isExpanded: true,
          hint: Text(hint),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.primary),
          items: items.map((item) {
            return DropdownMenuItem(
              value: item,
              child: Row(
                children: [
                  Icon(iconBuilder(item), size: 18, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item, overflow: TextOverflow.ellipsis)),
                ],
              ),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildContactDropdown(
      ColorScheme cs, List<dynamic> contacts, ContactProvider provider) {
    if (provider.isLoading) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16)),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (contacts.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16)),
        child: Text("Add contacts in Settings → Manage Contacts",
            style: TextStyle(color: cs.onSurfaceVariant)),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: (contacts.any((c) => c.name == _selectedContactName))
              ? _selectedContactName
              : null,
          isExpanded: true,
          hint: const Text("Select Contact"),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.primary),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Row(
                children: [
                  Icon(Icons.person_off_rounded, size: 18, color: Colors.grey),
                  SizedBox(width: 8),
                  Text("None", style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            ...contacts.map((c) {
              return DropdownMenuItem<String>(
                value: c.name,
                child: Row(
                  children: [
                    Icon(Icons.person_rounded, size: 18, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(c.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              );
            }).toList(),
          ],
          onChanged: (val) => setState(() => _selectedContactName = val),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _saveExpense() async {
    final amountText = _amountController.text.trim();
    final title = _titleController.text.trim();

    if (amountText.isEmpty || title.isEmpty || _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter a valid amount")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = context.read<AuthProvider>().currentUser;
      if (user == null) throw Exception("User not logged in");

      // Handle tags
      _selectedTags.removeWhere((t) => t.startsWith("contact:"));
      if (_selectedContactName != null &&
          _selectedContactName!.trim().isNotEmpty) {
        _selectedTags.add("contact:${_selectedContactName!.trim()}");
      }

      final newExpense = Expense(
        id: widget.expenseToEdit?.id ?? '',
        userId: user.id,
        title: title,
        amount: amount,
        date: _selectedDate,
        category: _selectedCategory!,
        contact: _selectedContactName,
        tags: List<String>.from(_selectedTags),
        wallet: _selectedWallet ?? 'Cash',
      );

      final provider = context.read<ExpenseProvider>();

      if (widget.expenseToEdit != null) {
        // await provider.updateExpense(newExpense); // Uncomment if update exists
      } else {
        await provider.addExpense(newExpense);
        
        // Save last used wallet
        if (_selectedWallet != null) {
          context.read<AppSettingsProvider>().setLastUsedWallet(_selectedWallet!);
        }

        // --- LAYER 1 TRAINING: TEACH AI ---
        // We teach the AI that this 'Title' belongs to this 'Category'
        await MLService().learn(title, _selectedCategory!);
      }

      // Notification handled entirely by ExpenseProvider.addExpense() returning the streakResult logic now.
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to save: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
