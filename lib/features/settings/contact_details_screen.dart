import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

import 'package:expenso/models/contact.dart';
import 'package:expenso/providers/contact_provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';

class ContactDetailsScreen extends StatelessWidget {
  final Contact contact;

  const ContactDetailsScreen({super.key, required this.contact});

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  Future<void> _sendEmail(String emailAddress) async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: emailAddress,
    );
    await launchUrl(launchUri);
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Contact?"),
        content: const Text(
            "This will remove the contact from your list. Existing expenses will keep the contact name but won't be linked."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              await context.read<ContactProvider>().deleteContact(contact.id);
              if (context.mounted) {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context); // Go back to list
              }
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final expenses =
        context.watch<ExpenseProvider>().getExpensesForContact(contact.name);
    final currency =
        context.watch<AppSettingsProvider>().currencySymbol;

    final totalSpent = expenses.fold(0.0, (sum, e) => sum + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Details"),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 48,
                  child: Text(
                    contact.name.isNotEmpty
                        ? contact.name[0].toUpperCase()
                        : "?",
                    style: TextStyle(fontSize: 32),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  contact.name,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (contact.phone != null && contact.phone!.isNotEmpty)
                      IconButton.filledTonal(
                        onPressed: () => _makePhoneCall(contact.phone!),
                        icon: const Icon(Icons.phone),
                      ),
                    const SizedBox(width: 16),
                    if (contact.email != null && contact.email!.isNotEmpty)
                      IconButton.filledTonal(
                        onPressed: () => _sendEmail(contact.email!),
                        icon: const Icon(Icons.email),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Total Linked Expenses",
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$currency${totalSpent.toStringAsFixed(2)}",
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      "HISTORY",
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
          expenses.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      "No expenses linked to this contact",
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final expense = expenses[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: Icon(Icons.receipt_long, size: 20),
                        ),
                        title: Text(expense.title),
                        subtitle: Text(
                            DateFormat('MMM d, yyyy').format(expense.date)),
                        trailing: Text(
                          "$currency${expense.amount.toStringAsFixed(0)}",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                    childCount: expenses.length,
                  ),
                ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }
}
