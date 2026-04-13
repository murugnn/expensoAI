import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:home_widget/home_widget.dart';
import 'package:expenso/models/shop_item.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/services/referral_service.dart';

class GamificationProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  AuthProvider? _authProvider;
  RealtimeChannel? _statsChannel;

  // --- STATE ---
  int _coins = 0;
  int _xp = 0;
  int _level = 1;
  int _currentStreak = 0;
  int _bestStreak = 0;
  int _streakShields = 0;
  String? _equippedPin;

  // Daily Tracking & Limits
  int _dailyCoinsEarned = 0;
  static const int _dailyCap = 50;
  bool _dailyRewardClaimed = false;
  double _dailyLimit = 0;

  DateTime? _lastActionDate;
  DateTime? _lastLogDate;
  DateTime? _lastShieldPurchaseDate;

  // Inventory & History
  List<String> _inventory = [];
  List<DateTime> _logDates = [];
  List<DateTime> _restoredDates = [];

  // --- GETTERS ---
  int get coins => _coins;
  int get xp => _xp;
  int get level => _level;
  int get currentStreak => isStreakBroken() ? 0 : _currentStreak;
  int get bestStreak => _bestStreak;
  int get streakShields => _streakShields;
  String? get equippedPin => _equippedPin;
  int get xpToNextLevel => _level * 200;
  bool get dailyRewardClaimed => _dailyRewardClaimed;
  List<String> get inventory => _inventory;
  List<DateTime> get logDates => _logDates;
  List<DateTime> get restoredDates => _restoredDates;
  double get dailyLimit => _dailyLimit;

  int get daysMissed {
    if (_lastLogDate == null) return 0;
    final now = DateTime.now();
    final d1 = DateTime(now.year, now.month, now.day);
    final d2 =
        DateTime(_lastLogDate!.year, _lastLogDate!.month, _lastLogDate!.day);
    final difference = d1.difference(d2).inDays;
    return difference > 1 ? difference - 1 : 0;
  }

  bool get hasLoggedToday {
    if (_lastLogDate == null) return false;
    return _isSameDay(DateTime.now(), _lastLogDate!);
  }
  
  bool get isShieldOnCooldown {
    if (_lastShieldPurchaseDate == null) return false;
    final deadline = _lastShieldPurchaseDate!.add(const Duration(days: 7));
    return DateTime.now().isBefore(deadline);
  }

  String? get shieldCooldownText {
    if (!isShieldOnCooldown) return null;
    final deadline = _lastShieldPurchaseDate!.add(const Duration(days: 7));
    final diff = deadline.difference(DateTime.now());
    if (diff.inDays > 0) return "${diff.inDays}d";
    if (diff.inHours > 0) return "${diff.inHours}h";
    return "${diff.inMinutes}m";
  }

  double get progress {
    if (xpToNextLevel == 0) return 0.0;
    return (_xp / xpToNextLevel).clamp(0.0, 1.0);
  }

  // --- INITIALIZATION ---
  void updateAuth(AuthProvider auth) {
    _authProvider = auth;
    if (_authProvider?.currentUser != null) {
      _loadStats();
      _subscribeToChanges();
    }
  }

  /// Listen for real-time changes to this user's row in user_stats
  void _subscribeToChanges() {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    // Remove old channel if it exists
    _statsChannel?.unsubscribe();

    _statsChannel = _supabase
        .channel('user_stats_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'user_stats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            debugPrint('Real-time user_stats update received');
            final newRow = payload.newRecord;
            if (newRow.isNotEmpty) {
              _applyCloudUpdate(newRow);
            }
          },
        )
        .subscribe();
  }

  /// Apply an incoming cloud update to local state
  void _applyCloudUpdate(Map<String, dynamic> data) {
    _coins = data['coins'] ?? _coins;
    _xp = data['xp'] ?? _xp;
    _level = data['level'] ?? _level;
    _inventory = List<String>.from(data['inventory'] ?? _inventory);
    _currentStreak = data['current_streak'] ?? _currentStreak;
    _bestStreak = data['best_streak'] ?? _bestStreak;
    _streakShields = data['streak_shields'] ?? _streakShields;
    _dailyCoinsEarned = data['daily_coins_earned'] ?? _dailyCoinsEarned;
    _equippedPin = data['equipped_pin'];
    _dailyLimit = (data['daily_limit'] as num?)?.toDouble() ?? _dailyLimit;

    if (data['last_action_date'] != null) {
      _lastActionDate = DateTime.parse(data['last_action_date']);
    }
    if (data['last_shield_purchase_date'] != null) {
      _lastShieldPurchaseDate = DateTime.parse(data['last_shield_purchase_date']);
    }
    final logDatesList = List<String>.from(data['log_dates'] ?? []);
    if (logDatesList.isNotEmpty) {
      _logDates = logDatesList.map((e) => DateTime.parse(e)).toList();
      _logDates.sort();
      _lastLogDate = _logDates.last;
    }
    final restoredList = List<String>.from(data['restored_dates'] ?? []);
    if (restoredList.isNotEmpty) {
      _restoredDates = restoredList.map((e) => DateTime.parse(e)).toList();
    }

    notifyListeners();
    updateBattleWidget();
  }

  Future<void> _loadStats() async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('user_stats')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (response != null) {
        _coins = response['coins'] ?? 100;
        _xp = response['xp'] ?? 0;
        _level = response['level'] ?? 1;
        _inventory = List<String>.from(response['inventory'] ?? []);
        _currentStreak = response['current_streak'] ?? 0;
        _bestStreak = response['best_streak'] ?? 0;
        _streakShields = response['streak_shields'] ?? 0;
        _dailyCoinsEarned = response['daily_coins_earned'] ?? 0;
        _equippedPin = response['equipped_pin'];
        _dailyLimit = (response['daily_limit'] as num?)?.toDouble() ?? 0.0;
        
        // Referral fields might be null if old user
        String? referralCode = response['referral_code'];
        if (referralCode == null) {
           // Generate and save lazy
           final newCode = ReferralService.generateReferralCode(user.userMetadata?['name'] ?? 'USER');
           // Fire and forget update
           _supabase.from('user_stats').update({'referral_code': newCode}).eq('user_id', user.id).then((_) {
             debugPrint("Generated missing referral code: $newCode");
           });
        }

        if (response['last_action_date'] != null) {
          _lastActionDate = DateTime.parse(response['last_action_date']);
          _checkDailyReset();
        }

        if (response['last_shield_purchase_date'] != null) {
          _lastShieldPurchaseDate =
              DateTime.parse(response['last_shield_purchase_date']);
        }

        final logDatesList = List<String>.from(response['log_dates'] ?? []);
        _logDates = logDatesList.map((e) => DateTime.parse(e)).toList();

        if (_logDates.isNotEmpty) {
          _logDates.sort();
          _lastLogDate = _logDates.last;
        }

        final restoredList =
            List<String>.from(response['restored_dates'] ?? []);
        _restoredDates = restoredList.map((e) => DateTime.parse(e)).toList();

        notifyListeners();
        await updateBattleWidget();
      } else {
         // Stats not found. This can happen for older users who signed up before Gamification.
         // Let's auto-migrate them by creating their user_stats row now.
         debugPrint("No user_stats row found for ${user.id}. Attempting auto-migration...");
         try {
           final newCode = ReferralService.generateReferralCode(user.userMetadata?['name'] ?? 'USER');
           await _supabase.rpc('create_user_stats', params: {
             'p_user_id': user.id,
             'p_referral_code': newCode,
             'p_referred_by': null, // Old users didn't have a referrer
           });
           debugPrint("✅ Auto-migrated old user ${user.id} to user_stats with code $newCode.");
           // Recursively load stats now that they exist
           await _loadStats();
           return;
         } catch (migrationError) {
           debugPrint("❌ Auto-migration failed for ${user.id}: $migrationError");
           _coins = 0;
           notifyListeners();
         }
      }
    } catch (e) {
      debugPrint("Gamification Load Error: $e");
    }

  }

  // --- WIDGET SYNC LOGIC ---
  Future<void> updateBattleWidget() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      int heroHpVal = (progress * 100).toInt();
      if (heroHpVal < 5) heroHpVal = 5;

      int bossHpVal = 100 - heroHpVal;
      if (bossHpVal < 5) bossHpVal = 5;

      await prefs.setString('streak', currentStreak.toString());
      await prefs.setString('hero_hp', heroHpVal.toString());
      await prefs.setString('boss_hp', bossHpVal.toString());

      await HomeWidget.updateWidget(
        name: 'BattleWidgetProvider',
        androidName: 'BattleWidgetProvider',
      );
    } catch (e) {
      debugPrint("Widget Update Error: $e");
    }
  }

  void _checkDailyReset() {
    final now = DateTime.now();
    if (_lastActionDate == null) return;
    if (!_isSameDay(now, _lastActionDate!)) {
      _dailyCoinsEarned = 0;
      _dailyRewardClaimed = false;
    }
  }

  Future<void> setDailyLimit(double limit) async {
    // REPLACED WITH RPC CALL
    try {
      final res = await _supabase.rpc<bool>('set_daily_limit', params: {'new_limit': limit});
      if (res == true) {
         _dailyLimit = limit;
         notifyListeners();
      }
    } catch (e) {
      debugPrint("Error setting daily limit: $e");
    }
  }

  bool isStreakBroken() {
    if (_lastLogDate == null) return false;
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    return !_isSameDay(_lastLogDate!, now) &&
        !_isSameDay(_lastLogDate!, yesterday);
  }

  Future<Map<String, dynamic>?> onExpenseLogged() async {
    final now = DateTime.now();
    if (_isSameDay(now, _lastLogDate ?? DateTime(2000))) return null;

    bool wasBroken = isStreakBroken();
    if (wasBroken) {
      _currentStreak = 1;
    } else {
      _currentStreak++;
    }

    if (_currentStreak > _bestStreak) _bestStreak = _currentStreak;

    _lastLogDate = now;
    _logDates.add(now);
    if (_logDates.length > 60) _logDates.removeAt(0);

    // Sync streak immediately
    await _syncStreakLocallyToDb();

    // Call the RPC to officially record it on the backend
    try {
      await _supabase.rpc('claim_daily_reward');
      // Reload stats immediately so UI reflects the true DB state (coins, XP, streak)
      await _loadStats();
    } catch (e) {
      debugPrint("Error claiming daily reward: $e");
    }

    notifyListeners();
    await updateBattleWidget();

    Map<String, dynamic> result = {'streak': _currentStreak, 'reward': 0, 'message': null};
    return result;
  }

  Future<String?> recordDailyExpense(
      {required double amount, required double totalSpentToday}) async {
    final now = DateTime.now();
    // REPLACED WITH RPC CALL
    try {
      final res = await _supabase.rpc<String?>('record_expense_reward', params: {
        'amount': amount,
        'total_spent_today': totalSpentToday
      });

      if (res != null) {
        // If we got a message, it means we got coins/xp.
        await _loadStats(); // Reload to get updated state
      }
      return res;
    } catch (e) {
      debugPrint("Error recording daily expense reward: $e");
      return null;
    }
  }

  Future<String?> buyShield() async {
    if (_coins < 200) {
      return "Not enough coins! Need 200.";
    }
    if (_streakShields >= 2) {
      return "Max shields reached (2/2)!";
    }
    if (isShieldOnCooldown) {
      return "Cooldown active. Wait $shieldCooldownText.";
    }

    // Optimistic Update
    _coins -= 200;
    _streakShields += 1;
    _lastShieldPurchaseDate = DateTime.now();
    notifyListeners();

    try {
      // The RPC might return a String error if it fails
      final err = await _supabase.rpc<String?>('purchase_shield');
      if (err != null) {
        // Revert on error
        await _loadStats();
        return err;
      }
      
      await _loadStats();
      return null;
    } catch (e) {
      await _loadStats();
      return "Purchase Failed: ${e.toString()}";
    }
  }

  Future<String?> buyShieldFromShop() async {
    return await buyShield();
  }

  Future<String?> restoreStreak() async {
    try {
      final err = await _supabase.rpc<String?>('restore_streak');
      if (err != null) return err; // Error message from SQL
      
      await _loadStats();
      return null; // Success
    } catch (e) {
      return "Restore Failed: ${e.toString()}";
    }
  }

  Future<int> claimDailyReward() async {
    if (_dailyRewardClaimed) return 0;
    int reward = 20;
    if (_currentStreak % 7 == 0) reward += 50;
    if (_currentStreak % 30 == 0) reward += 100;
    _coins += reward;
    _dailyRewardClaimed = true;
    _xp += 15;
    notifyListeners();
    await _syncToCloud();
    await updateBattleWidget();
    return reward;
  }

  bool isOwned(String itemId) => _inventory.contains(itemId);

  // AMOLED Premium
  bool get ownsAmoled => _inventory.contains('amoled_theme');
  bool get ownsSnowTheme => _inventory.contains('snow_theme');
  bool get ownsWaveTheme => _inventory.contains('wave_theme');
  bool get ownsLightSweepTheme => _inventory.contains('light_sweep_theme');
  
  bool get isPremium => ownsAmoled || ownsSnowTheme || ownsWaveTheme || ownsLightSweepTheme; // Helper for general premium features

  // ... (Removed Aurora methods)

  Future<String?> purchaseAmoled() async {
    if (ownsAmoled) return 'Already owned';
    if (_coins < 6000) return 'Not enough coins (Need 6000)';

    // Optimistic Update
    _coins -= 6000;
    _inventory.add('amoled_theme');
    notifyListeners();

    try {
      await _supabase.rpc('purchase_item', params: {
        'item_id': 'amoled_theme',
        'is_category_item': false
      });
      return null; // success
    } catch (e) {
      // Revert on failure
      _coins += 6000;
      _inventory.remove('amoled_theme');
      notifyListeners();
      debugPrint("Amoled Purchase Error: $e");
      return "Purchase failed. Try again.";
    }
  }

  Future<String?> purchaseSnowTheme() async {
    if (ownsSnowTheme) return 'Already owned';
    if (_coins < 3000) return 'Not enough coins (Need 3000)';
    
    // Optimistic Update
    _coins -= 3000;
    _inventory.add('snow_theme');
    notifyListeners();
    
    // We try to use the generic purchase method if possible, but fallback to manual update
    // Actually, let's just use manual update since purchase_item RPC might not handle this ID if it has foreign key constraints
    // Assuming 'snow_theme' is NOT in item_catalog table, we can't use purchase_item RPC if it checks FK.
    // So we use the same strategy as AMOLED (local + sync/rpc patch).
    
    // Wait... if we added it to Models/ShopItem, it doesn't mean it's in the DB.
    // The previous dev used `purchaseAmoled` with manual update. I will follow that pattern.
    
    // But wait, `_syncToCloud` is commented out. We need a way to persist this.
    // `purchase_shield` is an RPC. 
    // `purchase_item` is an RPC.
    
    // If I cannot add to DB, this will not persist across installs.
    // However, I must assume `_syncToCloud` or some RPC is needed.
    // Looking at `purchaseAmoled`: it decreases coins and adds to inventory locally.
    // And `_syncToCloud` prints "skipped".
    // This implies `purchaseAmoled` DOES NOT PERSIST currently in this codebase version??
    // OR `purchase_item` is expected to be used.
    
    // Let's try to use `purchase_item` RPC for consistency, passing `snow_theme`.
    // If it fails, we catch it.
    
    try {
        await _supabase.rpc('purchase_item', params: {
            'item_id': 'snow_theme', 
            'is_category_item': false
        });
        return null;
    } catch (e) {
        // If RPC fails (e.g. item not in DB), we revert local state
        _coins += 3000;
        _inventory.remove('snow_theme');
        notifyListeners();
        debugPrint("Purchase Error: $e");
        return "Purchase failed. Try again properly.";
    }
  }

  Future<String?> purchaseWaveTheme() async {
    if (ownsWaveTheme) return 'Already owned';
    if (_coins < 3000) return 'Not enough coins (Need 3000)';

    // Optimistic Update
    _coins -= 3000;
    _inventory.add('wave_theme');
    notifyListeners();

    try {
      await _supabase.rpc('purchase_item', params: {
        'item_id': 'wave_theme',
        'is_category_item': false
      });
      return null; // success
    } catch (e) {
      // Revert on failure
      _coins += 3000;
      _inventory.remove('wave_theme');
      notifyListeners();
      debugPrint("Wave Purchase Error: $e");
      return "Purchase failed. Try again properly.";
    }
  }

  Future<String?> purchaseLightSweepTheme() async {
    if (ownsLightSweepTheme) return 'Already owned';
    if (_coins < 3000) return 'Not enough coins (Need 3000)';

    // Optimistic Update
    _coins -= 3000;
    _inventory.add('light_sweep_theme');
    notifyListeners();

    try {
      await _supabase.rpc('purchase_item', params: {
        'item_id': 'light_sweep_theme',
        'is_category_item': false
      });
      return null; // success
    } catch (e) {
      // Revert on failure
      _coins += 3000;
      _inventory.remove('light_sweep_theme');
      notifyListeners();
      debugPrint("Light Sweep Purchase Error: $e");
      return "Purchase failed. Try again properly.";
    }
  }

  Future<bool> purchaseItem(ShopItem item) async {
    if (item.id == 'shield') {
      final err = await buyShield();
      return err == null;
    }
    
    if (item.id == 'snow_theme') {
        final err = await purchaseSnowTheme();
        return err == null;
    }

    if (item.id == 'wave_theme') {
        final err = await purchaseWaveTheme();
        return err == null;
    }

    if (item.id == 'light_sweep_theme') {
        final err = await purchaseLightSweepTheme();
        return err == null;
    }

    try {
      await _supabase.rpc('purchase_item', params: {
        'item_id': item.id, 
        'is_category_item': false
      });
      await _loadStats();
      return true;
    } catch (e) {
      debugPrint("Purchase verification failed: $e");
      return false;
    }
    return false;
  }

  Future<void> equipPin(String pinId) async {
    try {
       await _supabase.rpc('equip_pin', params: {'pin_id': pinId});
       await _loadStats();
    } catch (e) {
       debugPrint("Equip Error: $e");
    }
  }

  Future<void> unequipPin() async {
    try {
       await _supabase.rpc('unequip_pin');
       _equippedPin = null;
       await _loadStats();
    } catch (e) {
       debugPrint("Unequip Error: $e");
    }
  }

  // --- FIXED: MISSING METHOD ADDED HERE ---
  String? getEquippedPinAsset() {
    if (_equippedPin == null) return null;

    try {
      final item = shopCatalog.firstWhere(
        (i) => i.id == _equippedPin && i.type == ShopItemType.avatar,
      );
      return item.assetPath;
    } catch (_) {
      return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _syncToCloud() async {
    final user = _authProvider?.currentUser;
    if (user == null) return;
    try {
      /* 
      SECURITY UPDATE: 
      Direct updates are disabled to prevent client-side exploitation.
      We only update fields that are NOT critical (like UI preferences if any), 
      or we rely entirely on RPCs. 
      For now, we will ONLY update fields that are strictly client-tracking regular usage 
      but arguably even these should be server-side if strict security is required.
      
      For this fix, we COMMENT OUT the critical stats update. 
      */
      
      // await _supabase.from('user_stats').upsert({ ... });
      debugPrint("Sync to cloud skipped for security. Use RPCs.");
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  Future<void> _syncStreakLocallyToDb() async {
    final Map<String, dynamic> params = {
      'new_streak': _currentStreak,
      'new_best': _bestStreak,
      'new_last_action_date': _lastActionDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
      'new_log_dates': _logDates.map((e) => e.toIso8601String()).toList(),
    };
    
    debugPrint("🚀 SYNCING STREAK: $params");
    
    try {
      final res = await _supabase.rpc('sync_streak_v2', params: params);
      debugPrint("✅ SYNC SUCCESS. Result: $res");
    } catch (e) {
      debugPrint("❌ STREAK SYNC FAILED: $e");
      try {
        final errText = "Streak sync failed: $e | Params: $params\n";
        File('/home/cerelac/expenso/debug_streak.txt').writeAsStringSync(errText, mode: FileMode.append);
      } catch (_) {}
    }
  }



  @override
  void dispose() {
    _statsChannel?.unsubscribe();
    super.dispose();
  }
}
