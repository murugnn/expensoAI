import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:expenso/models/shared_expense.dart';
import 'package:expenso/models/shared_member.dart';
import 'package:expenso/providers/shared_provider.dart';
import 'package:expenso/features/social/widgets/user_avatar.dart';

class AddSharedExpenseSheet extends StatefulWidget {
  final String roomId;
  final String currencySymbol;
  const AddSharedExpenseSheet({
    super.key,
    required this.roomId,
    required this.currencySymbol,
  });

  @override
  State<AddSharedExpenseSheet> createState() => _AddSharedExpenseSheetState();
}

class _AddSharedExpenseSheetState extends State<AddSharedExpenseSheet> {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  String _category = 'General';
  SharedSplitType _splitType = SharedSplitType.equal;
  final Map<String, double> _customShares = {};
  bool _saving = false;

  static const _categories = [
    'General', 'Food', 'Transport', 'Stay', 'Entertainment',
    'Bills', 'Shopping', 'Health', 'Other',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleCtrl.text.trim();
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (title.isEmpty || amount == null || amount <= 0) return;

    setState(() => _saving = true);
    HapticFeedback.mediumImpact();

    final shared = context.read<SharedProvider>();

    Map<String, double>? splitMap;
    if (_splitType == SharedSplitType.custom && _customShares.isNotEmpty) {
      final total = _customShares.values.fold(0.0, (s, v) => s + v);
      // Allow off-by-rounding-cent tolerance.
      if ((total - amount).abs() > 0.5) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'The shares must add up exactly to ${widget.currencySymbol}${amount.toStringAsFixed(2)}. (Currently: ${widget.currencySymbol}${total.toStringAsFixed(2)})'),
          ),
        );
        return;
      }
      splitMap = Map.of(_customShares);
    }

    final exp = await shared.addExpense(
      roomId: widget.roomId,
      title: title,
      amount: amount,
      category: _category,
      splitType: _splitType,
      splitMap: splitMap,
    );

    if (!mounted) return;
    setState(() => _saving = false);
    if (exp != null) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save expense.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shared = context.watch<SharedProvider>();
    final members = shared.membersOf(widget.roomId);
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      padding: EdgeInsets.only(bottom: bottom),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, controller) {
          return Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 4, bottom: 18),
                      decoration: BoxDecoration(
                        color: cs.outlineVariant,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    'Add expense',
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),

                  TextField(
                    controller: _titleCtrl,
                    autofocus: true,
                    textCapitalization: TextCapitalization.sentences,
                    decoration:
                        const InputDecoration(labelText: 'What was it for?'),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      prefixText: '${widget.currencySymbol} ',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 18),

                  Text('Category',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categories.map((c) {
                      final selected = _category == c;
                      return GestureDetector(
                        onTap: () => setState(() => _category = c),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: selected
                                ? cs.primary.withOpacity(0.1)
                                : cs.surface,
                            border: Border.all(
                              color: selected
                                  ? cs.primary
                                  : cs.outlineVariant.withOpacity(0.5),
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            c,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: selected ? cs.primary : cs.onSurface,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 22),

                  Text('Split',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                          fontSize: 13)),
                  const SizedBox(height: 8),
                  _SplitTypeToggle(
                    value: _splitType,
                    onChanged: (t) {
                      setState(() {
                        _splitType = t;
                        if (t == SharedSplitType.custom && _customShares.isEmpty) {
                          // Prefill with equal splits
                          final amount = double.tryParse(_amountCtrl.text.trim()) ?? 0;
                          if (amount > 0 && members.isNotEmpty) {
                            final per = amount / members.length;
                            for (var m in members) {
                              _customShares[m.userId] = double.parse(per.toStringAsFixed(2));
                            }
                            // Adjust the last one to fix rounding
                            final totalAssigned = _customShares.values.fold(0.0, (s, v) => s + v);
                            final diff = amount - totalAssigned;
                            _customShares[members.last.userId] = (_customShares[members.last.userId] ?? 0) + diff;
                          }
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 14),

                  if (_splitType == SharedSplitType.custom)
                    _CustomSplitEditor(
                      members: members,
                      shares: _customShares,
                      currency: widget.currencySymbol,
                      onChanged: () => setState(() {}),
                    )
                  else
                    _EqualSplitPreview(
                      members: members,
                      total: double.tryParse(_amountCtrl.text.trim()) ?? 0,
                      currency: widget.currencySymbol,
                    ),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text(
                              'Save expense',
                              style: TextStyle(
                                  fontSize: 15, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SplitTypeToggle extends StatelessWidget {
  final SharedSplitType value;
  final ValueChanged<SharedSplitType> onChanged;
  const _SplitTypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    Widget pill(SharedSplitType t, String label) {
      final selected = value == t;
      return Expanded(
        child: GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onChanged(t);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? cs.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? cs.onPrimary : cs.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        pill(SharedSplitType.equal, 'Equal'),
        pill(SharedSplitType.custom, 'Custom'),
      ]),
    );
  }
}

class _EqualSplitPreview extends StatelessWidget {
  final List<SharedMember> members;
  final double total;
  final String currency;
  const _EqualSplitPreview({
    required this.members,
    required this.total,
    required this.currency,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final n = members.isEmpty ? 1 : members.length;
    final per = total / n;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.balance_rounded, size: 18, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              members.isEmpty
                  ? 'Splits will be calculated when members join.'
                  : 'Each member pays $currency${per.toStringAsFixed(2)} of $currency${total.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 13, color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomSplitEditor extends StatelessWidget {
  final List<SharedMember> members;
  final Map<String, double> shares;
  final String currency;
  final VoidCallback onChanged;
  const _CustomSplitEditor({
    required this.members,
    required this.shares,
    required this.currency,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: members.map((m) {
        final ctrl = TextEditingController(
          text: (shares[m.userId] ?? 0).toStringAsFixed(0) == '0'
              ? ''
              : shares[m.userId]!.toStringAsFixed(2),
        );
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              UserAvatar(
                avatarUrl: m.avatarUrl,
                initials: (m.displayName ?? '?').isEmpty
                    ? '?'
                    : (m.displayName ?? '?').substring(0, 1).toUpperCase(),
                radius: 14,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  m.displayName ?? 'Member',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: ctrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                  ],
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: currency,
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                  onChanged: (v) {
                    final parsed = double.tryParse(v);
                    if (parsed == null) {
                      shares.remove(m.userId);
                    } else {
                      shares[m.userId] = parsed;
                    }
                    onChanged();
                  },
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
