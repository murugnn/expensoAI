import 'dart:io'; // Required for Local File images
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/demon_game_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/features/settings/manage_items_screen.dart';
import 'package:expenso/features/settings/manage_contacts_screen.dart';
import 'package:expenso/features/settings/manage_subscriptions_screen.dart';
import 'package:expenso/features/settings/about_screen.dart';
import 'package:expenso/nav.dart';
import 'package:expenso/services/supabase_config.dart';
import 'package:expenso/features/updater/services/update_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expenso/services/sms_service.dart';
import 'package:expenso/services/sms_service.dart';
import 'package:expenso/utils/sms_utils.dart';
import 'package:expenso/providers/expense_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  void _showAmoledPurchaseDialog(BuildContext context, GamificationProvider game) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Unlock AMOLED Dark", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "True black theme for OLED screens.\nSaves battery and looks stunning.",
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.monetization_on, color: Colors.amber, size: 20),
                SizedBox(width: 6),
                Text(
                  "6000 coins",
                  style: TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel", style: TextStyle(color: Colors.white54)),
          ),
          FilledButton(
            onPressed: game.coins >= 6000
                ? () async {
                    final err = await game.purchaseAmoled();
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      if (err == null) {
                        // Auto-apply AMOLED theme
                        context.read<AppSettingsProvider>().setThemeModeString('amoled_dark');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("AMOLED Dark unlocked!")),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(err)),
                        );
                      }
                    }
                  }
                : null,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.deepPurpleAccent,
            ),
            child: const Text("Unlock"),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text("Select Currency"),
        children: const [
          _CurrencyOption(label: "₹ INR", symbol: "₹"),
          _CurrencyOption(label: "\$ USD", symbol: "\$"),
          _CurrencyOption(label: "€ EUR", symbol: "€"),
          _CurrencyOption(label: "£ GBP", symbol: "£"),
          _CurrencyOption(label: "¥ JPY", symbol: "¥"),
        ],
      ),
    );
  }

  void _showBudgetDialog(
      BuildContext context, DemonGameProvider game, String currency) {
    if (!game.canChangeBudget) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text("Weekly change limit reached. Try again next Monday.")),
      );
      return;
    }

    final controller =
        TextEditingController(text: game.dailyBudget.toInt().toString());
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Set Daily Budget"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Changing budget resets the current week's Boss HP.",
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.orangeAccent,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: "$currency ",
                border: const OutlineInputBorder(),
                labelText: "Daily Amount",
              ),
            ),
            const SizedBox(height: 8),
            Text("Changes remaining: ${game.budgetChangesRemaining}/2",
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(controller.text);
              if (val != null && val > 0) {
                final success = await game.setDailyBudget(val);
                if (context.mounted) {
                  Navigator.pop(ctx);
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Budget updated! Boss HP reset.")));
                  }
                }
              }
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  // --- ROBUST IMAGE PROVIDER ---
  ImageProvider? _getProfileImage(String? path) {
    if (path == null || path.isEmpty) return null;
    try {
      if (path.startsWith('http')) return NetworkImage(path);
      if (path.contains('assets')) return AssetImage(path);
      return FileImage(File(path));
    } catch (e) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettingsProvider>();
    final auth = context.watch<AuthProvider>();
    final game = context.watch<DemonGameProvider>();
    final gamification = context.watch<GamificationProvider>();

    final profileImage = _getProfileImage(auth.userAvatar);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Hub", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // --- PROFILE HEADER ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: ListTile(
              leading: CircleAvatar(
                radius: 28,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                backgroundImage: profileImage,
                child: profileImage == null
                    ? Icon(Icons.person,
                        size: 28,
                        color: Theme.of(context).colorScheme.onSurfaceVariant)
                    : null,
              ),
              title: Text(auth.userName,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text(auth.currentUser?.email ?? ""),
            ),
          ),
          const Divider(indent: 16, endIndent: 16),

          // --- 1. STRUCTURE (Categories, Tags, Wallets) ---
          const _SectionHeader(title: "STRUCTURE"),
          ListTile(
            leading: const Icon(Icons.category_outlined),
            title: const Text("Categories"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManageItemsScreen(
                  title: "Category",
                  items: settings.categories,
                  onAdd: (val) => settings.addCategory(val),
                  onDelete: (val) => settings.removeCategory(val),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.label_outline),
            title: const Text("Tags"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManageItemsScreen(
                  title: "Tag",
                  items: settings.tags,
                  onAdd: (val) => settings.addTag(val),
                  onDelete: (val) => settings.removeTag(val),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet_outlined),
            title: const Text("Wallets"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ManageItemsScreen(
                  title: "Wallet",
                  items: settings.wallets,
                  onAdd: (val) => settings.addWallet(val),
                  onDelete: (val) => settings.removeWallet(val),
                ),
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.track_changes_outlined),
            title: const Text("Goals"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.push('/goals'),
          ),

          // --- 2. BUDGET (Daily Goal, Subscriptions) ---
          const _SectionHeader(title: "BUDGET"),
          
          // Daily Goal Card
           Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5))
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: game.canChangeBudget
                  ? () => _showBudgetDialog(context, game, settings.currencySymbol)
                  : () {
                     ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Weekly budget change limit reached."))
                     );
                  },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12)),
                      child: Icon(Icons.track_changes,
                          color: Theme.of(context).colorScheme.onPrimaryContainer, size: 20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Daily Goal",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                              "${settings.currencySymbol}${game.dailyBudget.toInt()} / day",
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary, 
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_outlined, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant)
                  ],
                ),
              ),
            ),
          ),

          ListTile(
            leading: const Icon(Icons.subscriptions_outlined),
            title: const Text("Subscriptions"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManageSubscriptionsScreen(),
              ),
            ),
          ),

          // --- 3. GAMIFICATION ---
          const _SectionHeader(title: "GAMIFICATION"),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined, color: Colors.orange),
            title: const Text("Rewards Shop"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.push('/rewards-shop'),
          ),
          ListTile(
            leading: const Icon(Icons.group_add_outlined, color: Colors.blueAccent),
            title: const Text("Refer & Earn"),
            subtitle: const Text("Get 3000 coins"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.push('/settings/referral'),
          ),
          ListTile(
            leading: const Icon(Icons.local_fire_department_outlined, color: Colors.redAccent),
            title: const Text("Streak & Rewards"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => context.push('/streak'),
          ),

          SwitchListTile(
            title: const Text("Show Tutorial"),
            subtitle: const Text("Re-plays the overlay guide"),
            value: !settings.isTutorialShown, 
            onChanged: (val) {
               if (val) {
                 settings.setTutorialShown(false);
                 // Go back to main screen
                 context.go('/'); 
                 // Instantly trigger
                 Future.delayed(const Duration(milliseconds: 100), () {
                   mainScreenKey.currentState?.checkTutorialAndShow();
                 });
               } else {
                 // User wants to HIDE tutorial
                 settings.setTutorialShown(true);
               }
            },
            secondary: const Icon(Icons.help_outline),
          ),


          
          SwitchListTile(
            title: const Text("SMS Auto-Tracking"),
            subtitle: const Text("Detect expenses from bank SMS"),
            value: settings.smsTrackingEnabled,
            onChanged: (val) async {
              settings.setSmsTrackingEnabled(val);
              if (val) {
                 final granted = await SmsService().requestPermissions();
                 if (!granted && context.mounted) {
                   settings.setSmsTrackingEnabled(false); // Revert if denied
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("SMS permission is required for this feature.")),
                   );
                 } else {
                   // Granted! Start listening now.
                   SmsService().startListening();
                 }
              }
            },
            secondary: const Icon(Icons.sms_outlined),
          ),
          


          // --- 5. DISPLAY ---
          const _SectionHeader(title: "DISPLAY"),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Theme", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 12),
                SegmentedButton<String>(
                  segments: [
                    const ButtonSegment(value: 'light', label: Text('Light')),
                    const ButtonSegment(value: 'dark', label: Text('Dark')),
                    if (gamification.ownsAmoled)
                      const ButtonSegment(value: 'amoled_dark', label: Text('Amoled')),
                  ],
                  selected: {
                    // If user somehow has amoled_dark set but doesn't own it, show dark
                    (settings.themeModeString == 'amoled_dark' && !gamification.ownsAmoled)
                        ? 'dark'
                        : settings.themeModeString
                  },
                  onSelectionChanged: (selected) {
                    settings.setThemeModeString(selected.first);
                  },
                ),
                
                if (gamification.ownsSnowTheme || gamification.ownsWaveTheme || gamification.ownsLightSweepTheme) ...[
                  const SizedBox(height: 16),
                  const SizedBox(height: 16),
                  const Text("Ambience", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        _AmbienceChip(
                          label: 'None', 
                          selected: settings.ambientEffect == 'none',
                          onSelected: () => settings.setAmbientEffect('none'),
                        ),
                        if (gamification.ownsSnowTheme)
                          _AmbienceChip(
                            label: 'Snow', 
                            icon: Icons.ac_unit,
                            selected: settings.ambientEffect == 'snow',
                            onSelected: () => settings.setAmbientEffect('snow'),
                          ),
                        if (gamification.ownsWaveTheme)
                          _AmbienceChip(
                            label: 'Wave', 
                            icon: Icons.ssid_chart,
                            selected: settings.ambientEffect == 'wave',
                            onSelected: () => settings.setAmbientEffect('wave'),
                          ),
                        if (gamification.ownsLightSweepTheme)
                          _AmbienceChip(
                            label: 'Crystal', 
                            icon: Icons.diamond,
                            selected: settings.ambientEffect == 'light_sweep',
                            onSelected: () => settings.setAmbientEffect('light_sweep'),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // --- AMOLED PREMIUM CARD (only if not owned) ---
          if (!gamification.ownsAmoled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Material(
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _showAmoledPurchaseDialog(context, gamification),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.deepPurple.shade900,
                          Colors.black,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.deepPurpleAccent.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.deepPurpleAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.lock_outline, color: Colors.deepPurpleAccent, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "AMOLED Dark",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "True black for OLED screens",
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.monetization_on, color: Colors.amber, size: 16),
                              SizedBox(width: 4),
                              Text(
                                "6000",
                                style: TextStyle(
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

           // --- 4. ACCOUNT (Currency, Contacts) ---
          const _SectionHeader(title: "ACCOUNT"),
          ListTile(
            leading: const Icon(Icons.mic_outlined, color: Colors.deepPurpleAccent),
            title: const Text("Niva Voice Connect"),
            subtitle: Text(settings.vapiKey.isEmpty ? "API Key not set" : "Connected (Custom Key)"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () {
              final controller = TextEditingController(text: settings.vapiKey);
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text("Niva Voice Connect"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "Paste your Vapi Public Key here to use Niva using your own credits.",
                        style: TextStyle(fontSize: 13, color: Colors.white70),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "VAPI Public Key",
                          hintText: "Enter your public key",
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("Cancel"),
                    ),
                    FilledButton(
                      onPressed: () {
                        settings.setVapiKey(controller.text.trim());
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("Niva API Key updated!")),
                        );
                      },
                      child: const Text("Save"),
                    ),
                  ],
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.currency_exchange),
            title: const Text("Currency"),
            subtitle: Text("Active: ${settings.currencySymbol}"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => _showCurrencyPicker(context),
          ),
          ListTile(
            leading: const Icon(Icons.contacts_outlined),
            title: const Text("Contacts"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ManageContactsScreen(),
              ),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("About"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AboutScreen()),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.system_update_outlined),
            title: const Text("Check for Updates"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => UpdateService.checkForUpdates(context, showIfLatest: true),
          ),
          
          const Divider(height: 32),

          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await auth.logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _CurrencyOption extends StatelessWidget {
  final String label;
  final String symbol;
  const _CurrencyOption({required this.label, required this.symbol});
  @override
  Widget build(BuildContext context) {
    return SimpleDialogOption(
      onPressed: () {
        context.read<AppSettingsProvider>().setCurrency(symbol);
        Navigator.pop(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}

class _AmbienceChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onSelected;

  const _AmbienceChip({
    required this.label,
    this.icon,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: selected ? Theme.of(context).colorScheme.onPrimaryContainer : null),
              const SizedBox(width: 6),
            ],
            Text(label, style: TextStyle(color: selected ? Theme.of(context).colorScheme.onPrimaryContainer : null)),
          ],
        ),
        selected: selected,
        onSelected: (_) => onSelected(),
        showCheckmark: false,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        selectedColor: Theme.of(context).colorScheme.primaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
