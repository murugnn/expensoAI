import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:expenso/nav.dart';
import 'package:expenso/models/shop_item.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/theme.dart';
import 'dart:ui';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  bool _saving = false;

  String? _selectedAvatar;

  static const List<String> _avatars = [
    'assets/images/avatars/1.png',
    'assets/images/avatars/2.png',
    'assets/images/avatars/3.png',
    'assets/images/avatars/4.png',
    'assets/images/avatars/5.png',
    'assets/images/avatars/7.png',
    'assets/images/avatars/8.png',
    'assets/images/avatars/6.png',
    'assets/images/avatars/9.png',
    'assets/images/avatars/10.png',
    'assets/images/avatars/11.png'
  ];

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    _nameController.text = auth.userName;
    _selectedAvatar = auth.userAvatar;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final game = context.watch<GamificationProvider>();
    final expenseProvider = context.watch<ExpenseProvider>();
    final user = auth.currentUser;
    final cs = Theme.of(context).colorScheme;

    // Equipped pin item
    ShopItem? equippedItem;
    if (game.equippedPin != null) {
      try {
        equippedItem = shopCatalog.firstWhere((i) => i.id == game.equippedPin);
      } catch (_) {}
    }

    // Financial snapshot data
    final now = DateTime.now();
    final yearStart = DateTime(now.year, 1, 1);
    final yearExpenses = expenseProvider.expenses
        .where((e) => e.date.isAfter(yearStart))
        .toList();
    final totalSpentThisYear = yearExpenses.fold(0.0, (sum, e) => sum + e.amount);
    final monthsElapsed = now.month;
    final avgMonthlySpend = monthsElapsed > 0 ? totalSpentThisYear / monthsElapsed : 0.0;
    final currency = context.watch<AppSettingsProvider>().currencySymbol;

    // Member since
    final memberSince = user?.createdAt != null
        ? DateFormat('MMMM yyyy').format(DateTime.parse(user!.createdAt))
        : 'Unknown';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Row(
                children: [
                  _BackButton(),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text('Profile',
                          style: context.textStyles.headlineSmall?.bold)),
                ],
              ),
              const SizedBox(height: 24),

              // --- PROFILE HEADER with Member Since ---
              _ProfileHeader(
                name: auth.userName,
                email: user?.email ?? '',
                avatar: _selectedAvatar ?? auth.userAvatar,
                pinItem: equippedItem,
                memberSince: memberSince,
              ),

              const SizedBox(height: 24),

              // --- 1. FINANCIAL SNAPSHOT ---
              _SectionTitle(title: 'Financial Snapshot'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.calendar_today,
                      label: 'This Year',
                      value: '$currency${totalSpentThisYear.toStringAsFixed(0)}',
                      color: cs.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.trending_up,
                      label: 'Monthly Avg',
                      value: '$currency${avgMonthlySpend.toStringAsFixed(0)}',
                      color: cs.secondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // --- 2. BASIC DETAILS ---
              _SectionTitle(title: 'Basic Details'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  Padding(
                    padding: AppSpacing.paddingMd,
                    child: Column(
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.badge_outlined, color: cs.primary),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: cs.surface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            hintText: user?.email ?? 'No email',
                            prefixIcon: Icon(Icons.alternate_email_rounded, color: cs.onSurfaceVariant),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            filled: true,
                            fillColor: cs.surface,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _saving ? null : () => _saveProfile(context),
                            icon: _saving
                                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.check_circle_rounded),
                            label: const Text('Save changes'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- 3. CHANGE FACE ---
              _SectionTitle(title: 'Change Face'),
              const SizedBox(height: 12),
              _AvatarPicker(
                presets: _avatars,
                selected: _selectedAvatar,
                onSelected: (value) => setState(() => _selectedAvatar = value),
              ),

              const SizedBox(height: 28),

              // --- 4. YOUR PINS ---
              _SectionTitle(title: 'Your Pins'),
              const SizedBox(height: 4),
              Text('Tap to equip/unequip',
                  style: context.textStyles.bodySmall?.copyWith(color: Colors.grey)),
              const SizedBox(height: 12),
              _PinCollectionGrid(game: game),

              const SizedBox(height: 28),

              // --- 5. DATA & PRIVACY ---
              _SectionTitle(title: 'Data & Privacy'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _ActionTile(
                    icon: Icons.file_download_outlined,
                    title: 'Export Data (CSV)',
                    subtitle: 'Download your expense history',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _exportCSV(context, expenseProvider);
                    },
                  ),
                  const Divider(height: 1),
                  _ActionTile(
                    icon: Icons.delete_forever_outlined,
                    title: 'Delete Account',
                    titleColor: cs.error,
                    onTap: () => _showDeleteAccountDialog(context, auth),
                  ),

                ],
              ),

              const SizedBox(height: 28),

              // --- 6. SECURITY ---
              _SectionTitle(title: 'Security'),
              const SizedBox(height: 12),
              _SettingsCard(
                children: [
                  _ActionTile(
                    icon: Icons.lock_outline,
                    title: 'App Lock',
                    subtitle: 'Coming Soon',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('App lock coming in next update!')),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _ActionTile(
                    icon: Icons.password_outlined,
                    title: 'Change Password',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _showChangePasswordDialog(context, auth);
                    },
                  ),
                ],
              ),

              const SizedBox(height: 28),

              // --- 7. LOGOUT ---
              _SettingsCard(
                children: [
                  ListTile(
                    leading: Icon(Icons.logout_rounded, color: cs.error),
                    title: Text('Logout', style: TextStyle(color: cs.error, fontWeight: FontWeight.w600)),
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await auth.logout();
                      if (context.mounted) context.go(AppRoutes.login);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveProfile(BuildContext context) async {
    final authProvider = context.read<AuthProvider>();
    setState(() => _saving = true);
    await authProvider.updateProfile(
        name: _nameController.text, avatar: _selectedAvatar);
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved!')),
      );
    }
  }

  void _exportCSV(BuildContext context, ExpenseProvider provider) {
    // Simple CSV generation
    final expenses = provider.expenses;
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export.')),
      );
      return;
    }

    final buffer = StringBuffer();
    buffer.writeln('Date,Category,Amount,Title,Wallet');
    for (final e in expenses) {
      final date = DateFormat('yyyy-MM-dd').format(e.date);
      buffer.writeln('$date,${e.category},${e.amount},"${e.title}",${e.wallet}');
    }

    // Copy to clipboard as fallback (file export requires path_provider)
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Expense data copied to clipboard as CSV!')),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is irreversible. All your data will be permanently deleted. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Account deletion request sent. Contact murugnn9@gmail.com for confirmation.')),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text(
          'A password reset link will be sent to your registered email.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final email = auth.currentUser?.email;
              if (email != null) {
                final err = await auth.resetPassword(email);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(err ?? 'Reset link sent to $email')),
                  );
                }
              }
            },
            child: const Text('Send Link'),
          ),
        ],
      ),
    );
  }
}

// ====================================================================
// WIDGETS
// ====================================================================

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});
  @override
  Widget build(BuildContext context) {
    return Text(title, style: context.textStyles.titleMedium?.semiBold);
  }
}

class _ProfileHeader extends StatelessWidget {
  final String name;
  final String email;
  final String? avatar;
  final ShopItem? pinItem;
  final String memberSince;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.avatar,
    this.pinItem,
    required this.memberSince,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: AppSpacing.paddingMd,
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [cs.primary, cs.secondary]),
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Row(
        children: [
          ProfileWithPinWidget(imagePath: avatar, pinItem: pinItem, size: 64),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: context.textStyles.titleLarge?.bold
                        .copyWith(color: Colors.white)),
                Text(email,
                    style: context.textStyles.bodyMedium
                        ?.copyWith(color: Colors.white70)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.calendar_month, size: 12, color: Colors.white54),
                    const SizedBox(width: 4),
                    Text('Member since $memberSince',
                        style: const TextStyle(fontSize: 11, color: Colors.white54)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? titleColor;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.titleColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: titleColor ?? cs.primary),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w500, color: titleColor ?? cs.onSurface)),
      subtitle: subtitle != null ? Text(subtitle!, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)) : null,
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// --- PIN COLLECTION GRID ---
class _PinCollectionGrid extends StatelessWidget {
  final GamificationProvider game;

  const _PinCollectionGrid({required this.game});

  @override
  Widget build(BuildContext context) {
    final ownedPins = shopCatalog
        .where((item) => item.type == ShopItemType.avatar && game.isOwned(item.id))
        .toList();

    if (ownedPins.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12)),
        child: const Text("No pins yet. Visit the Shop!"),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemCount: ownedPins.length,
      itemBuilder: (context, index) {
        final item = ownedPins[index];
        final isEquipped = game.equippedPin == item.id;

        Color? glowColor;
        switch (item.rarity) {
          case ShopItemRarity.legendary:
            glowColor = const Color(0xFFFFD700);
            break;
          case ShopItemRarity.rare:
            glowColor = const Color(0xFF00BFFF);
            break;
          case ShopItemRarity.common:
          default:
            glowColor = null;
        }

        final hasGlow = glowColor != null;
        Color borderColor = Colors.transparent;
        if (isEquipped) {
          borderColor = glowColor ?? Theme.of(context).colorScheme.primary;
        }

        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            if (isEquipped) {
              game.unequipPin();
            } else {
              game.equipPin(item.id);
            }
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isEquipped
                  ? (glowColor != null
                      ? glowColor.withOpacity(0.15)
                      : Theme.of(context).colorScheme.primaryContainer)
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: isEquipped ? 2 : 1),
              boxShadow: isEquipped
                  ? [BoxShadow(color: borderColor.withOpacity(0.4), blurRadius: 6, spreadRadius: 1)]
                  : null,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (hasGlow)
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [glowColor.withOpacity(0.4), Colors.transparent],
                      ),
                    ),
                  ),
                if (hasGlow && item.assetPath != null)
                  ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                    child: Transform.scale(
                      scale: 1.1,
                      child: Image.asset(
                        item.assetPath!,
                        color: glowColor,
                        colorBlendMode: BlendMode.srcIn,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                item.assetPath != null
                    ? Image.asset(
                        item.assetPath!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 20),
                      )
                    : Icon(item.icon),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BackButton extends StatefulWidget {
  @override
  State<_BackButton> createState() => _BackButtonState();
}

class _BackButtonState extends State<_BackButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        HapticFeedback.lightImpact();
        context.pop();
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        scale: _pressed ? 0.96 : 1,
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.arrow_back_rounded, color: cs.onSurface),
        ),
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});
  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(children: children),
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final List<String> presets;
  final String? selected;
  final ValueChanged<String> onSelected;
  const _AvatarPicker(
      {required this.presets,
      required this.selected,
      required this.onSelected});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final path = presets[i];
          final isSelected = path == selected;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onSelected(path);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected ? cs.primary : Colors.transparent,
                    width: 3),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                            color: cs.primary.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4))
                      ]
                    : [],
              ),
              child: ClipOval(
                child:
                    Image.asset(path, width: 72, height: 72, fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                  return Container(
                      width: 70,
                      height: 70,
                      color: cs.surfaceContainerHighest,
                      child: Icon(Icons.person, color: cs.onSurfaceVariant));
                }),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfileWithPinWidget extends StatelessWidget {
  final String? imagePath;
  final ShopItem? pinItem;
  final double size;

  const ProfileWithPinWidget({
    super.key,
    required this.imagePath,
    this.pinItem,
    required this.size,
  });

  ImageProvider _getImage() {
    if (imagePath != null && imagePath!.isNotEmpty) {
      return AssetImage(imagePath!);
    }
    return const AssetImage('assets/images/avatars/1.png');
  }

  @override
  Widget build(BuildContext context) {
    Color? glowColor;
    if (pinItem != null) {
      switch (pinItem!.rarity) {
        case ShopItemRarity.legendary:
          glowColor = const Color(0xFFFFD700);
          break;
        case ShopItemRarity.rare:
          glowColor = const Color(0xFF00BFFF);
          break;
        case ShopItemRarity.common:
        default:
          glowColor = null;
      }
    }

    final hasGlow = glowColor != null;
    final pinSize = size * 0.45;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            image: DecorationImage(fit: BoxFit.cover, image: _getImage()),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              )
            ],
          ),
        ),
        if (pinItem != null && pinItem!.assetPath != null)
          Positioned(
            bottom: -5,
            right: -5,
            child: Container(
              width: pinSize,
              height: pinSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Theme.of(context).scaffoldBackgroundColor,
                border: hasGlow ? Border.all(color: glowColor!, width: 1.5) : null,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4),
                  if (hasGlow)
                    BoxShadow(color: glowColor.withOpacity(0.4), blurRadius: 8, spreadRadius: 1),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (hasGlow)
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [glowColor.withOpacity(0.3), Colors.transparent],
                        ),
                      ),
                    ),
                  if (hasGlow)
                    ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                      child: Transform.scale(
                        scale: 1.1,
                        child: Image.asset(
                          pinItem!.assetPath!,
                          color: glowColor,
                          colorBlendMode: BlendMode.srcIn,
                          fit: BoxFit.contain,
                          width: pinSize * 0.7,
                          height: pinSize * 0.7,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Image.asset(
                      pinItem!.assetPath!,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox(),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
