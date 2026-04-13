import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/services/receipt_scanner_service.dart'; // For ParsedReceipt
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:uuid/uuid.dart';

class AddBillSheet extends StatefulWidget {
  final ParsedReceipt receipt;

  const AddBillSheet({super.key, required this.receipt});

  @override
  State<AddBillSheet> createState() => _AddBillSheetState();
}

class _AddBillSheetState extends State<AddBillSheet> {
  // Metadata Controllers
  final _billNameController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  // Financial Controllers
  final _subtotalController = TextEditingController();
  final _taxController = TextEditingController();
  final _totalController = TextEditingController(); // User can override total

  // Item Controllers
  late List<_BillItemController> _itemControllers;
  
  bool _isLoading = false;
  String? _selectedCurrency;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    debugPrint("AddBillSheet: Initializing with ${widget.receipt.items.length} items");
    _billNameController.text = widget.receipt.merchantName;
    _selectedDate = widget.receipt.date;
    _selectedCurrency = widget.receipt.currency;

    _subtotalController.text = widget.receipt.subtotal.toStringAsFixed(2);
    _taxController.text = widget.receipt.tax.toStringAsFixed(2);
    _totalController.text = widget.receipt.total.toStringAsFixed(2);

    _itemControllers = widget.receipt.items.map((item) {
      return _BillItemController(
        nameController: TextEditingController(text: item.name),
        amountController: TextEditingController(text: item.amount.toStringAsFixed(2)),
        id: const Uuid().v4(),
      );
    }).toList();

    // Listeners to auto-recalculate total if items change
    for (var c in _itemControllers) {
      c.amountController.addListener(_recalculateTotalFromItems);
    }
  }

  void _recalculateTotalFromItems() {
    double sum = 0;
    for (var c in _itemControllers) {
      sum += double.tryParse(c.amountController.text) ?? 0.0;
    }
    // Simple logic: If items change, update subtotal. Tax remains fixed unless manually edited.
    _subtotalController.text = sum.toStringAsFixed(2);
    
    // Update Total = Subtotal + Tax
    double tax = double.tryParse(_taxController.text) ?? 0.0;
    _totalController.text = (sum + tax).toStringAsFixed(2);
  }

  // Add a new empty item manually
  void _addNewItem() {
    setState(() {
      final ctrl = _BillItemController(
        nameController: TextEditingController(),
        amountController: TextEditingController(),
        id: const Uuid().v4(),
      );
      ctrl.amountController.addListener(_recalculateTotalFromItems);
      _itemControllers.add(ctrl);
    });
  }

  void _removeItem(int index) {
    setState(() {
      _itemControllers[index].amountController.removeListener(_recalculateTotalFromItems);
      _itemControllers[index].dispose();
      _itemControllers.removeAt(index);
      _recalculateTotalFromItems();
    });
  }

  Future<void> _saveBill() async {
    setState(() => _isLoading = true);
    final expenseProvider = context.read<ExpenseProvider>();
    final userId = context.read<AuthProvider>().currentUser?.id;
    final billId = const Uuid().v4();
    final billName = _billNameController.text.trim().isEmpty ? "Bill" : _billNameController.text.trim();

    if (userId == null) return;

    int savedCount = 0;

    try {
      // Get User's Wallet Preference
      final settings = context.read<AppSettingsProvider>();
      String walletToUse = 'Cash';
      
      if (settings.lastUsedWallet != null && settings.wallets.contains(settings.lastUsedWallet)) {
        walletToUse = settings.lastUsedWallet!;
      } else if (settings.wallets.isNotEmpty) {
        walletToUse = settings.wallets.first;
      }

      // 1. Save Line Items
      for (var ctrl in _itemControllers) {
        final name = ctrl.nameController.text.trim();
        final amount = double.tryParse(ctrl.amountController.text) ?? 0.0;

        if (name.isEmpty && amount == 0) continue; // Skip empty rows

        final expense = Expense(
          id: ctrl.id,
          userId: userId,
          title: name.isEmpty ? "Item" : name,
          amount: amount,
          date: _selectedDate,
          category: 'Groceries', // Default for scanned items
          wallet: walletToUse,
          contact: billName, // Map Merchant Name to Contact so it syncs!
          billId: billId,
          billName: billName, // Keep locally for reference if needed
        );
        await expenseProvider.addExpense(expense);
        savedCount++;
      }

      // 2. Handle Tax as a separate expense if explicit
      double tax = double.tryParse(_taxController.text) ?? 0.0;
      if (tax > 0) {
        final taxExpense = Expense(
          id: const Uuid().v4(),
          userId: userId,
          title: "Tax / VAT",
          amount: tax,
          date: _selectedDate,
          category: 'Bills',
          wallet: walletToUse,
          contact: billName, // Map Merchant Name to Contact
          billId: billId,
          billName: billName,
        );
        await expenseProvider.addExpense(taxExpense);
        savedCount++;
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Saved $billName with $savedCount items!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _billNameController.dispose();
    _subtotalController.dispose();
    _taxController.dispose();
    _totalController.dispose();
    for (var c in _itemControllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(bottom: viewInsets),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Column(
        children: [
          // 1. Drag Handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // 2. Header (Title & Date)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("VERIFY BILL", style: TextStyle(color: cs.primary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      TextField(
                        controller: _billNameController,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "Merchant Name",
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
                // Date Picker Button
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today, size: 14, color: cs.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(DateFormat('MMM dd').format(_selectedDate), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // 3. Scrollable Content (Items + Summary)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- ITEMS LIST ---
                  Text("DETECTED ITEMS", style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  
                  ..._itemControllers.asMap().entries.map((entry) {
                    final index = entry.key;
                    final ctrl = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Row(
                        children: [
                          // Item Name
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: ctrl.nameController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: cs.surfaceContainerLow,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                hintText: "Item name",
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Amount
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: ctrl.amountController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              textAlign: TextAlign.right,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: cs.surfaceContainerLow,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                prefixText: _selectedCurrency,
                                hintText: "0.00",
                              ),
                            ),
                          ),
                          // Delete Btn
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline, color: Colors.grey, size: 20),
                            onPressed: () => _removeItem(index),
                          )
                        ],
                      ),
                    );
                  }),

                  TextButton.icon(
                    onPressed: _addNewItem,
                    icon: const Icon(Icons.add),
                    label: const Text("Add Item"),
                  ),

                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 24),

                  // --- SUMMARY SECTION ---
                  _buildSummaryRow(context, "Subtotal", _subtotalController, cs, isTotal: false),
                  const SizedBox(height: 12),
                  _buildSummaryRow(context, "Tax / VAT", _taxController, cs, isTotal: false),
                  const SizedBox(height: 12),
                  _buildSummaryRow(context, "Total Due", _totalController, cs, isTotal: true),
                ],
              ),
            ),
          ),

          // 4. Save Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saveBill,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("SAVE TO EXPENSES", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(BuildContext context, String label, TextEditingController ctrl, ColorScheme cs, {required bool isTotal}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(
          fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
          fontSize: isTotal ? 18 : 14,
          color: isTotal ? cs.primary : cs.onSurfaceVariant,
        )),
        SizedBox(
          width: 120,
          child: TextField(
            controller: ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 18 : 14,
              color: isTotal ? cs.primary : cs.onSurface,
            ),
            decoration: InputDecoration(
              border: InputBorder.none,
              prefixText: "$_selectedCurrency ",
              hintText: "0.00",
              isDense: true,
            ),
            onChanged: (val) {
               // If user manually edits tax, trigger recalc of total
               if (ctrl == _taxController) _recalculateTotalFromItems();
            },
          ),
        ),
      ],
    );
  }
}

class _BillItemController {
  final TextEditingController nameController;
  final TextEditingController amountController;
  final String id;

  _BillItemController({
    required this.nameController,
    required this.amountController,
    required this.id,
  });

  void dispose() {
    nameController.dispose();
    amountController.dispose();
  }
}
