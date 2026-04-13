import 'package:flutter/material.dart';

enum ShopItemType { consumable, avatar, premium }

// 1. New Enum for Rarity
enum ShopItemRarity { common, rare, legendary }

class ShopItem {
  final String id;
  final String name;
  final String description;
  final int cost;
  final ShopItemType type;
  final IconData icon;
  final Color? color;
  final String? assetPath;

  // 2. New Field
  final ShopItemRarity rarity;

  const ShopItem({
    required this.id,
    required this.name,
    required this.description,
    required this.cost,
    required this.type,
    required this.icon,
    this.color,
    this.assetPath,
    this.rarity = ShopItemRarity.common, // 3. Default value prevents errors
  });
}

// 4. COMPLETE CATALOG (Copy this entire list)
final List<ShopItem> shopCatalog = [
  // --- CONSUMABLES ---
  const ShopItem(
    id: 'shield',
    name: 'Streak Shield',
    description: 'Protects streak for 1 day',
    cost: 200,
    type: ShopItemType.consumable,
    icon: Icons.shield,
    color: Colors.blue,
    rarity: ShopItemRarity.common,
  ),

  // --- PREMIUM ---
  const ShopItem(
    id: 'snow_theme',
    name: 'Snow Theme',
    description: 'Winter ambience for your app',
    cost: 3000,
    type: ShopItemType.premium,
    icon: Icons.ac_unit,
    color: Colors.lightBlueAccent,
    rarity: ShopItemRarity.legendary,
  ),

  const ShopItem(
    id: 'wave_theme',
    name: 'Financial Wave',
    description: 'Subtle fintech ambient motion',
    cost: 3000,
    type: ShopItemType.premium,
    icon: Icons.ssid_chart, // Or show_chart, waves
    color: Colors.tealAccent,
    rarity: ShopItemRarity.legendary,
  ),

  const ShopItem(
    id: 'light_sweep_theme',
    name: 'Crystal Luxury',
    description: 'Premium crystal shimmer',
    cost: 3000,
    type: ShopItemType.premium,
    icon: Icons.diamond_outlined, 
    color: Colors.deepPurpleAccent,
    rarity: ShopItemRarity.legendary,
  ),

  // --- PINS ---
  const ShopItem(
    id: 'pin_ghost',
    name: 'Pacman Ghost',
    description: 'somewhere alone in the woods...',
    cost: 500,
    type: ShopItemType.avatar,
    icon: Icons.emoji_events,
    assetPath: 'assets/images/pins/ghost.png',
  ),
  const ShopItem(
    id: 'pin_tea',
    name: 'Without Chaya',
    description: 'Without chaya is all you want',
    cost: 1000,
    type: ShopItemType.avatar,
    icon: Icons.emoji_events,
    assetPath: 'assets/images/pins/tea.png',
  ),
  const ShopItem(
    id: 'pin_dollar',
    name: 'Dollar',
    description: 'Hail Trump',
    cost: 1500,
    type: ShopItemType.avatar,
    icon: Icons.emoji_events,
    assetPath: 'assets/images/pins/dollar.png',
  ),
  const ShopItem(
    id: 'pin_bot',
    name: 'Robo',
    description: 'Mecha Robo',
    cost: 2000,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/bot.png',
  ),
  const ShopItem(
    id: 'pin_ramen',
    name: 'Ramen',
    description: 'Ichiraku Ramen',
    cost: 2200,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/naruto.png',
  ),
  const ShopItem(
    id: 'pin_nin',
    name: 'Ninja',
    description: 'Shuriken shoooo',
    cost: 2500,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/ninja.png',
  ),
  const ShopItem(
    id: 'pin_jack',
    name: 'Jack Sparrow',
    description: 'wooz booz',
    cost: 3000,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/jack.png',
  ),
  const ShopItem(
    id: 'pin_assassin',
    name: 'Assassins Creed',
    description: 'Creed',
    cost: 3500,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/assassin.png',
  ),
  const ShopItem(
    id: 'pin_zeus',
    name: 'Thunderbolt',
    description: 'Thud thud thunder',
    cost: 4000,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/zeus.png',
  ),
  const ShopItem(
    id: 'pin_bat',
    name: 'Bat',
    description: 'I am batman!',
    cost: 4000,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/bat.png',
  ),
  const ShopItem(
    id: 'pin_shield',
    name: 'Shield',
    description: 'The Captain',
    cost: 4000,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/shield.png',
  ),
  const ShopItem(
    id: 'pin_spidey',
    name: 'Spidey',
    description: 'Where is MJ?',
    cost: 4200,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/spidey.png',
  ),
  const ShopItem(
    id: 'pin_spider',
    name: 'Black Spydih',
    description: 'Who is MJ?',
    cost: 4200,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/spider.png',
  ),
  const ShopItem(
    id: 'pin_pool',
    name: 'Deadpool',
    description: 'baby da da da',
    cost: 4200,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/deadpool.png',
  ),
  const ShopItem(
    id: 'pin_logan',
    name: 'Logan',
    description: 'Wolverine',
    cost: 4200,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/logan.png',
  ),
  const ShopItem(
    id: 'pin_cap',
    name: 'Captain America',
    description: 'Hail Hydra',
    cost: 4200,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/marvel.png',
  ),
  const ShopItem(
    id: 'pin_bp',
    name: 'Black Panther',
    description: 'Wakanda Forever',
    cost: 4500,
    type: ShopItemType.avatar,
    icon: Icons.monetization_on,
    assetPath: 'assets/images/pins/black.png',
    rarity: ShopItemRarity.rare, // Example Rare Item
  ),
  const ShopItem(
    id: 'pin_lion',
    name: 'The Lion',
    description: 'The Lion grapes anyone who talk',
    cost: 5000,
    type: ShopItemType.avatar,
    icon: Icons.smart_toy,
    assetPath: 'assets/images/pins/lion.png',
    rarity: ShopItemRarity.legendary, // 🔥 LEGENDARY GLOW
  ),
];
