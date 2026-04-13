import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';

import '../models/goal_model.dart';
import '../services/goal_service.dart';
import '../widgets/goal_type_selector.dart';
import 'package:expenso/providers/app_settings_provider.dart';

class GoalCreationScreen extends StatefulWidget {
  const GoalCreationScreen({super.key});

  @override
  State<GoalCreationScreen> createState() => _GoalCreationScreenState();
}

class _GoalCreationScreenState extends State<GoalCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  
  GoalType _selectedType = GoalType.savings;
  DateTime? _selectedDeadline;
  String? _selectedCategory;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)), // Default 1 month out
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
         return Theme(
           data: Theme.of(context).copyWith(
             colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: Theme.of(context).colorScheme.primary,
             ),
           ),
           child: child!,
         );
      }
    );
    if (picked != null && picked != _selectedDeadline) {
      setState(() {
        _selectedDeadline = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedType == GoalType.expenseLimit && _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please select a category for the spending limit.")),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _isLoading = true);

    final amount = double.parse(_amountController.text);
    final user = context.read<GoalService>(); // Since UUID is attached in toInsertJson

    final newGoal = GoalModel(
      id: '', // Supabase generates this
      userId: '', // Supabase grabs from auth in toInsertJson
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      goalType: _selectedType,
      targetAmount: amount,
      currentAmount: 0.0,
      category: _selectedType == GoalType.expenseLimit ? _selectedCategory : null,
      deadline: _selectedType != GoalType.custom ? _selectedDeadline : null,
      createdAt: DateTime.now(),
    );

    final success = await context.read<GoalService>().createGoal(newGoal);

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Goal Created! Let's get to work!"),
          backgroundColor: Colors.green.shade600,
        )
      );
      context.pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to create goal. Try again later."),
          backgroundColor: Theme.of(context).colorScheme.error,
        )
      );
    }
  }

  String _getSubtitle() {
    switch (_selectedType) {
      case GoalType.savings:
        return "Track money you are saving toward a target.";
      case GoalType.expenseLimit:
        return "Automatically monitor spending in this category.";
      case GoalType.custom:
        return "Create a personal financial target.";
    }
  }

  Widget _buildSavingsForm(ColorScheme cs) {
    return Column(
      key: const ValueKey('savings'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleField(cs, "What are you saving for?"),
        const SizedBox(height: 16),
        _buildAmountField(cs, "Target Amount"),
        const SizedBox(height: 16),
        _buildMotivationField(cs),
        const SizedBox(height: 24),
        _buildDeadlineField(cs),
      ],
    );
  }

  Widget _buildExpenseLimitForm(ColorScheme cs) {
    final settings = context.watch<AppSettingsProvider>();
    return Column(
      key: const ValueKey('expenseLimit'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleField(cs, "Limit Name (e.g. Eating Out)"),
        const SizedBox(height: 16),
        _buildAmountField(cs, "Monthly Limit Amount"),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.outline.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              hint: const Text("Select Category to Track"),
              value: _selectedCategory,
              icon: Icon(Icons.keyboard_arrow_down_rounded, color: cs.primary),
              items: settings.categories.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() => _selectedCategory = newValue);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildDeadlineField(cs),
      ],
    );
  }

  Widget _buildCustomForm(ColorScheme cs) {
    return Column(
      key: const ValueKey('custom'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTitleField(cs, "Goal Title"),
        const SizedBox(height: 16),
        _buildAmountField(cs, "Target Number"),
        const SizedBox(height: 16),
        _buildMotivationField(cs, label: "Notes (Optional)"),
        const SizedBox(height: 24),
        _buildDeadlineField(cs),
      ],
    );
  }

  Widget _buildTitleField(ColorScheme cs, String label) {
    return TextFormField(
      controller: _titleController,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: cs.surface,
      ),
      textCapitalization: TextCapitalization.words,
      validator: (v) => v!.trim().isEmpty ? "Title is required" : null,
    );
  }

  Widget _buildAmountField(ColorScheme cs, String label) {
    return TextFormField(
      controller: _amountController,
      decoration: InputDecoration(
         labelText: label,
         prefixText: "₹ ",
         border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
         filled: true,
         fillColor: cs.surface,
         labelStyle: TextStyle(
            fontFamily: 'Ndot',
            color: cs.primary,
         )
      ),
      style: TextStyle(fontFamily: 'Ndot', fontSize: 18, color: cs.onSurface),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      validator: (v) {
         if (v!.isEmpty) return "Amount is required";
         if (double.tryParse(v) == null || double.parse(v) <= 0) {
           return "Enter a valid amount";
         }
         return null;
      },
    );
  }

  Widget _buildMotivationField(ColorScheme cs, {String label = "Motivation (Optional)"}) {
    return TextFormField(
      controller: _descController,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        filled: true,
        fillColor: cs.surface,
      ),
      maxLines: 2,
    );
  }

  Widget _buildDeadlineField(ColorScheme cs) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text("Completion Deadline"),
      subtitle: Text(
         _selectedDeadline == null 
            ? "Optional but recommended" 
            : "Due on ${_selectedDeadline!.day}/${_selectedDeadline!.month}/${_selectedDeadline!.year}",
         style: TextStyle(
           color: _selectedDeadline == null ? cs.onSurface.withOpacity(0.5) : cs.primary,
           fontWeight: _selectedDeadline == null ? FontWeight.normal : FontWeight.bold,
         ),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: cs.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.calendar_today_rounded, color: cs.primary, size: 20),
      ),
      onTap: _selectDeadline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outline.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  "Set a New Goal",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getSubtitle(),
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),

                // Types
                GoalTypeSelector(
                  selectedType: _selectedType,
                  onTypeChanged: (type) => setState(() => _selectedType = type),
                ),
                const SizedBox(height: 24),

                // Dynamic Form Fields
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.05),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _selectedType == GoalType.savings 
                      ? _buildSavingsForm(cs)
                      : _selectedType == GoalType.expenseLimit 
                          ? _buildExpenseLimitForm(cs)
                          : _buildCustomForm(cs),
                ),
                
                const SizedBox(height: 40),

                // Submit
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text(
                            "Start Tracking", 
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                          ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
