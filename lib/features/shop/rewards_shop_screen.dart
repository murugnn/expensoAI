import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expenso/models/shop_item.dart';
import 'package:expenso/providers/gamification_provider.dart';
import 'package:expenso/providers/app_settings_provider.dart';
import 'dart:ui'; // Required for ImageFilter

class RewardsShopScreen extends StatelessWidget {
  const RewardsShopScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final game = context.watch<GamificationProvider>();
    final theme = Theme.of(context);

    // Split catalog
    final pins =
        shopCatalog.where((i) => i.type == ShopItemType.avatar).toList();
    final consumables =
        shopCatalog.where((i) => i.type != ShopItemType.avatar).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("REWARDS SHOP",
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const XCoin(size: 18),
                const SizedBox(width: 8),
                Text(
                  "${game.coins}",
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onPrimaryContainer),
                ),
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. WALLET CARD
            _buildWalletCard(context, game),

            const SizedBox(height: 24),
            
            // --- PREMIUM EXCLUSIVES ---
            if (!game.ownsSnowTheme || !game.ownsWaveTheme || !game.ownsLightSweepTheme) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text("PREMIUM EXCLUSIVES",
                    style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
              ),
              const SizedBox(height: 12),
              // Filter logic for premium items
              _buildPremiumSection(context, game),
              const SizedBox(height: 24),
            ],

            // 2. CONSUMABLES / FEATURED REWARDS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text("FEATURED REWARDS",
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                itemCount: consumables.length,
                separatorBuilder: (_, __) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  return _buildRewardCard(context, consumables[index], game);
                },
              ),
            ),

            const SizedBox(height: 32),

            // 3. EXCLUSIVE PINS
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text("EXCLUSIVE PINS",
                  style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16), // Reduced padding slightly
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing:
                    12, // Reduced spacing to give cells more width
                mainAxisSpacing: 16,
                childAspectRatio: 0.65, // Keep this tall aspect ratio
              ),
              itemCount: pins.length,
              itemBuilder: (context, index) {
                return _buildPinCard(context, pins[index], game);
              },
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildWalletCard(BuildContext context, GamificationProvider game) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
           colors: [const Color(0xFF1E1E2C), const Color(0xFF0F0F16)],
           begin: Alignment.topLeft,
           end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("YOUR WALLET",
              style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("X Coins", style: TextStyle(color: Colors.white)),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const XCoin(size: 28), // Large Coin
                      const SizedBox(width: 8),
                      Text(
                        "${game.coins}",
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text("Level", style: TextStyle(color: Colors.white)),
                  Text(
                    "Lvl ${game.level}",
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("XP",
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
              Text("${game.xp} / ${game.xpToNextLevel}",
                  style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: game.progress,
              minHeight: 8,
              backgroundColor: Colors.black26,
              valueColor: const AlwaysStoppedAnimation(Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardCard(
      BuildContext context, ShopItem item, GamificationProvider game) {
    final theme = Theme.of(context);
    bool isOwned = game.isOwned(item.id);
    bool isDisabled = isOwned;
    String buttonText = isOwned ? "Owned" : "Buy";

    if (item.id == "shield") {
      if (game.streakShields >= 2) {
         isOwned = true; 
         isDisabled = true;
         buttonText = "Max (2/2)";
      } else if (game.isShieldOnCooldown) {
         isOwned = false;
         isDisabled = true;
         buttonText = "Wait ${game.shieldCooldownText}";
      } else {
         isOwned = false; 
         isDisabled = false;
      }
    }

    final canAfford = game.coins >= item.cost;

    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOwned
              ? Colors.green.withOpacity(0.5)
              : theme.colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 60,
            width: double.infinity,
            decoration: BoxDecoration(
              color: item.color ?? theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item.icon,
                size: 30,
                color: item.color != null
                    ? Colors.white
                    : theme.colorScheme.primary),
          ),
          const SizedBox(height: 12),
          Text(item.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Row(
            children: [
              if (!isOwned && !isDisabled) const XCoin(size: 12),
              if (!isOwned && !isDisabled) const SizedBox(width: 4),
              Text(
                isOwned ? "Owned" : (isDisabled && item.id == 'shield' ? "Cooldown" : "${item.cost}"),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isOwned
                      ? Colors.green
                      : (canAfford && !isDisabled ? theme.colorScheme.primary : Colors.grey),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: FilledButton.icon(
              onPressed:
                  isDisabled ? null : () => _handlePurchase(context, item, game),
              icon: const XCoin(size: 14),
              label: Text(
                buttonText,
                style: const TextStyle(fontSize: 12),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: isOwned
                    ? Colors.transparent
                    : (canAfford ? theme.colorScheme.primary : Colors.grey),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinCard(
      BuildContext context, ShopItem item, GamificationProvider game) {
    final theme = Theme.of(context);
    final isOwned = game.isOwned(item.id);
    final canAfford = game.coins >= item.cost;

    // 1. DETERMINE RARITY COLORS
    Color? glowColor;
    Color? borderColor;

    switch (item.rarity) {
      case ShopItemRarity.legendary:
        glowColor = const Color(0xFFFFD700); // Gold
        borderColor = const Color(0xFFFFA000);
        break;
      case ShopItemRarity.rare:
        glowColor = const Color(0xFF00BFFF); // Electric Blue
        borderColor = const Color(0xFF1E90FF);
        break;
      case ShopItemRarity.common:
      default:
        glowColor = null;
        borderColor = null;
    }

    final hasGlow = glowColor != null;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 🔒 ICON BOX
        Container(
          width: 64,
          height: 64,
          padding: const EdgeInsets.all(8), // Slightly reduced internal padding
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: isOwned
                ? Border.all(color: Colors.green, width: 2)
                : Border.all(
                    color: borderColor ??
                        theme.colorScheme.outline.withOpacity(0.2),
                    width: hasGlow ? 1.5 : 1,
                  ),
          ),
          // STACK for Silhouetted Glow
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (hasGlow && item.assetPath != null)
                // LAYER 1: THE GLOWING BLURRED SILHOUETTE
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Transform.scale(
                    scale: 1.1, // Slightly larger to radiate outwards
                    child: Image.asset(
                      item.assetPath!,
                      // Tint the whole image to the glow color solid
                      color: glowColor.withOpacity(0.8),
                      colorBlendMode: BlendMode.srcIn,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

              // LAYER 2: THE SHARP ORIGINAL IMAGE
              item.assetPath != null
                  ? Image.asset(item.assetPath!, fit: BoxFit.contain)
                  : Icon(item.icon, size: 32),
            ],
          ),
        ),

        const SizedBox(height: 8), // Reduced spacing

        // 📛 NAME (Fixed: FittedBox to prevent overflow)
        SizedBox(
          height: 36, // Fixed height for 2 lines
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: FittedBox(
              fit: BoxFit.scaleDown, // Shrink text if it's too wide
              alignment: Alignment.center,
              child: Text(
                item.name,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: glowColor, // Text color matches rarity
                  shadows: hasGlow
                      ? [
                          Shadow(
                            color: glowColor.withOpacity(0.8),
                            blurRadius: 8,
                          )
                        ]
                      : null,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 4),

        // 🪙 PRICE
        SizedBox(
          height: 24,
          child: TextButton(
            onPressed:
                isOwned ? null : () => _handlePurchase(context, item, game),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              // Ensure button tap target is big enough even if text is small
              minimumSize: const Size(60, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              isOwned ? "OWNED" : "${item.cost} Coins",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: isOwned
                    ? Colors.green
                    : (canAfford ? theme.colorScheme.primary : Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _handlePurchase(
      BuildContext context, ShopItem item, GamificationProvider game) async {
    // Shield Logic
    if (item.id == "shield") {
      final error = await game.buyShieldFromShop();

      if (!context.mounted) return;

      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Streak Shield purchased!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
      return;
    }

    // Normal Item Logic
    final success = await game.purchaseItem(item);

    if (!context.mounted) return;

    if (success) {
      if (item.id == 'snow_theme' || item.id == 'wave_theme' || item.id == 'light_sweep_theme') {
        final effectMap = {
          'snow_theme': 'snow',
          'wave_theme': 'wave',
          'light_sweep_theme': 'light_sweep'
        };
        context.read<AppSettingsProvider>().setAmbientEffect(effectMap[item.id]!);
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("${item.name} unlocked and equipped!")),
        );
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Unlocked ${item.name}!")),
         );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Not enough X Coins!")),
      );
    }
  }
  Widget _buildPremiumSection(BuildContext context, GamificationProvider game) {
    final premiumItems = [
      shopCatalog.firstWhere((i) => i.id == 'snow_theme', orElse: () => shopCatalog.first),
      shopCatalog.firstWhere((i) => i.id == 'wave_theme', orElse: () => shopCatalog.first),
      shopCatalog.firstWhere((i) => i.id == 'light_sweep_theme', orElse: () => shopCatalog.first),
    ].where((item) => item.type == ShopItemType.premium).toList();

    return Column(
      children: premiumItems.map((item) {
        if (game.isOwned(item.id)) return const SizedBox.shrink();
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 12, left: 20, right: 20),
          child: _buildPremiumCard(context, item, game),
        );
      }).toList(),
    );
  }

  Widget _buildPremiumCard(BuildContext context, ShopItem item, GamificationProvider game) {
    final isSnow = item.id == 'snow_theme';
    final isWave = item.id == 'wave_theme';
    
    // Default to Light Sweep (Gold/Platinum look)
    List<Color> bgColors = [Colors.grey.shade900, Colors.blueGrey.shade700];
    Color shadowColor = Colors.grey;
    Color iconBg = Colors.white.withOpacity(0.1);
    Color iconColor = Colors.white;
    Color buttonBg = Colors.white;
    Color buttonFg = Colors.black;

    if (isSnow) {
      bgColors = [Colors.lightBlue.shade900, Colors.blueAccent.shade700];
      shadowColor = Colors.blueAccent;
      iconBg = Colors.white.withOpacity(0.2);
      buttonFg = Colors.blueAccent;
    } else if (isWave) {
      bgColors = [Colors.teal.shade900, Colors.tealAccent.shade700];
      shadowColor = Colors.tealAccent;
      iconColor = Colors.tealAccent;
      buttonFg = Colors.tealAccent;
    } else {
      // Light Sweep
      bgColors = [Colors.purple.shade900, Colors.deepPurpleAccent.shade700];
      shadowColor = Colors.deepPurpleAccent;
      iconColor = Colors.amberAccent;
      buttonFg = Colors.deepPurple;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: bgColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: shadowColor.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle),
            child: Icon(item.icon, color: iconColor, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16)),
                Text(item.description,
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _handlePurchase(context, item, game),
            style: FilledButton.styleFrom(
                backgroundColor: buttonBg, foregroundColor: buttonFg),
            child: Row(
              children: [
                  Text("${item.cost}"),
                  const SizedBox(width: 4),
                  const XCoin(size: 14),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// --- X COIN WIDGET ---
class XCoin extends StatelessWidget {
  final double size;
  const XCoin({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/icons/coin.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
    );
  }
}
