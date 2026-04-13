import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:expenso/providers/subscription_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/features/settings/add_subscription_sheet.dart';

class ManageSubscriptionsScreen extends StatelessWidget {
  const ManageSubscriptionsScreen({super.key});

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const AddSubscriptionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    final currency = context.watch<AppSettingsProvider>().currencySymbol;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Subscriptions"),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddSheet(context),
        child: const Icon(Icons.add),
      ),
      body: subProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : subProvider.subscriptions.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.subscriptions_outlined,
                          size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text("No subscriptions yet",
                          style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: subProvider.subscriptions.length,
                  itemBuilder: (context, index) {
                    final sub = subProvider.subscriptions[index];
                    final isDueSoon = sub.nextBillDate
                            .difference(DateTime.now())
                            .inDays <
                        3;
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                        child: InkWell(
                          onTap: () {
                            // Optional: Open detail/edit sheet
                          },
                          onLongPress: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text("Delete Subscription?"),
                                content: const Text(
                                    "This will stop future auto-generated expenses."),
                                actions: [
                                  TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text("Cancel")),
                                  FilledButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, true),
                                      child: const Text("Delete")),
                                ],
                              ),
                            );

                            if (confirm == true && context.mounted) {
                              await context
                                  .read<SubscriptionProvider>()
                                  .deleteSubscription(sub.id);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .primaryContainer,
                                  foregroundColor: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                  child: Text(sub.name[0].toUpperCase(),
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  sub.name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "$currency${sub.amount.toStringAsFixed(0)}",
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Next: ${DateFormat('MMM d').format(sub.nextBillDate)}",
                                  style: TextStyle(
                                    color: isDueSoon ? Colors.red : Colors.grey,
                                    fontSize: 12,
                                    fontWeight:
                                        isDueSoon ? FontWeight.bold : null,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                    );
                  },
                ),
    );
  }
}
