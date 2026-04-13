import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/gamification_provider.dart';

enum BossMood { calm, angry, enraged, weakened }

enum QuestType { avoidCategory, spendBelowAmount, logStreak }

class GameQuest {
  final String id;
  final String title;
  final QuestType type;
  final String? targetCategory;
  final double? targetAmount;
  final double damageReward;
  bool isCompleted;

  GameQuest({
    required this.id,
    required this.title,
    required this.type,
    this.targetCategory,
    this.targetAmount,
    this.damageReward = 20.0,
    this.isCompleted = false,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'type': type.index,
        'targetCategory': targetCategory,
        'targetAmount': targetAmount,
        'damageReward': damageReward,
        'isCompleted': isCompleted,
      };
  factory GameQuest.fromMap(Map<String, dynamic> map) {
    return GameQuest(
      id: map['id'],
      title: map['title'],
      type: QuestType.values[map['type']],
      targetCategory: map['targetCategory'],
      targetAmount: map['targetAmount'],
      damageReward: map['damageReward'],
      isCompleted: map['isCompleted'],
    );
  }
}

class DemonGameProvider extends ChangeNotifier {
  AuthProvider? _authProvider;
  GamificationProvider? _gamificationProvider;
  final SupabaseClient _supabase = Supabase.instance.client;

  // ---------------------------------------------------------
  // 🛠️ DEVELOPER AREA: RENAME YOUR BOSSES HERE
  // ---------------------------------------------------------
  final List<Map<String, String>> _bossConfig = [
    {
      'image': 'assets/images/game/deadlinedialga.png',
      'name': 'Deadline Dialga'
    }, // Week 1
    {
      'image': 'assets/images/game/debt_darkrai.png',
      'name': 'Debt Darkrai'
    }, // Week 2
    {
      'image': 'assets/images/game/emi_giratina.png',
      'name': 'EMI Giratina'
    }, // Week 3
    {
      'image': 'assets/images/game/overspend_rayquaza.png',
      'name': 'Overspend Rayquaza'
    }, // Week 4
  ];
  // ---------------------------------------------------------

  // --- STATE ---
  late String _bossImage;
  late String _bossName;

  DemonGameProvider() {
    final boss = _getBossDataForCurrentWeek();
    _bossImage = boss['image']!;
    _bossName = boss['name']!;
  }

  double _dailyBudget = 500.0;
  double _realBossHp = 3500.0;
  double _bossMaxHp = 3500.0;
  double _visualBossHp = 3500.0;

  final double _heroMaxHp = 100.0;
  double _heroCurrentHp = 100.0;

  List<GameQuest> _dailyQuests = [];
  String _dialogMessage = "New Week! Defeat the demon!";

  bool _isBossHit = false;
  bool _isHeroHit = false;
  bool _isHeroAttacking = false;
  bool _hasPendingAnimation = false;
  bool _isVictoryClaimed = false;
  bool _isTransitionPending = false;

  int _budgetChangesThisWeek = 0;
  String? _lastBudgetChangeDateStr;
  static const int maxWeeklyBudgetChanges = 2;

  // --- GETTERS (Fixed: All Getters Present) ---
  bool get isHeroAttacking => _isHeroAttacking;
  double get bossHp => _visualBossHp;
  double get bossMaxHp => _bossMaxHp;
  double get heroHp => _heroCurrentHp;
  double get heroMaxHp => _heroMaxHp;
  String get bossImage => _bossImage;
  String get bossName => _bossName;
  String get dialogMessage => _dialogMessage;
  String get heroName => _authProvider?.userName ?? "Hero";
  BossMood _bossMood = BossMood.calm;
  BossMood get bossMood => _bossMood;

  List<GameQuest> get quests => _dailyQuests;
  bool get isBossHit => _isBossHit;
  bool get isHeroHit => _isHeroHit;
  bool get isTransitionPending => _isTransitionPending;
  double get dailyBudget => _dailyBudget;
  int get budgetChangesRemaining =>
      max(0, maxWeeklyBudgetChanges - _budgetChangesThisWeek);
  bool get canChangeBudget => budgetChangesRemaining > 0;

  void updateAuth(AuthProvider auth) {
    _authProvider = auth;
    if (_authProvider?.currentUser != null) _loadFromSupabase();
  }

  void updateGamification(GamificationProvider game) =>
      _gamificationProvider = game;

  // Helper to get boss data based on date
  Map<String, String> _getBossDataForCurrentWeek() {
    final day = DateTime.now().day;
    int weekIndex = ((day - 1) / 7).floor();
    if (weekIndex >= _bossConfig.length) weekIndex = _bossConfig.length - 1;
    return _bossConfig[weekIndex];
  }

  Future<void> _loadFromSupabase() async {
    final userId = _authProvider?.currentUser?.id;
    if (userId == null) return;

    try {
      final data = await _supabase
          .from('game_saves')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      if (data != null) {
        // Load saved name/image OR fallback to config for current week
        final boss = _getBossDataForCurrentWeek();
        _bossName = boss['name']!;
        _bossImage = boss['image']!;

        _realBossHp = (data['boss_hp'] as num).toDouble();
        _heroCurrentHp = (data['hero_hp'] as num).toDouble();
        _dailyBudget = (data['daily_budget'] as num?)?.toDouble() ?? 500.0;
        _bossMaxHp = _dailyBudget * 7;
        _visualBossHp = _realBossHp;

        if (data['quests'] != null) {
          _dailyQuests = (data['quests'] as List)
              .map((q) => GameQuest.fromMap(q))
              .toList();
        }

        _budgetChangesThisWeek = data['budget_changes_this_week'] ?? 0;
        _lastBudgetChangeDateStr = data['last_budget_change_date'];

        await _checkWeeklyResets(
            data['last_reset'], data['last_budget_change_date']);
      } else {
        await finalizeWeeklyTransition();
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Game Load Error: $e");
    }
  }

  Future<void> _saveToSupabase() async {
    final userId = _authProvider?.currentUser?.id;
    if (userId == null) return;
    try {
      final nowStr = DateTime.now().toIso8601String().substring(0, 10);
      await _supabase.from('game_saves').upsert({
        'user_id': userId,
        'boss_hp': _realBossHp,
        'hero_hp': _heroCurrentHp,
        'boss_name': _bossName,
        'boss_image': _bossImage,
        'daily_budget': _dailyBudget,
        'quests': _dailyQuests.map((q) => q.toMap()).toList(),
        'last_reset': nowStr,
        'budget_changes_this_week': _budgetChangesThisWeek,
        'last_budget_change_date': _lastBudgetChangeDateStr ?? nowStr,
      });
    } catch (e) {
      debugPrint("Game Save Error: $e");
    }
  }

  Future<void> _checkWeeklyResets(
      String? lastResetStr, String? lastBudgetChangeStr) async {
    final now = DateTime.now();

    // Check Game Week
    if (lastResetStr != null) {
      final lastResetDate = DateTime.parse(lastResetStr);
      if (_isNewWeek(lastResetDate, now)) {
        _isTransitionPending = true;
        notifyListeners();
      }
    }

    // Check Budget Limit
    if (lastBudgetChangeStr != null) {
      final lastChangeDate = DateTime.parse(lastBudgetChangeStr);
      if (_isNewWeek(lastChangeDate, now)) {
        _budgetChangesThisWeek = 0;
        _lastBudgetChangeDateStr = now.toIso8601String().substring(0, 10);
        await _saveToSupabase();
      }
    }
  }

  bool _isNewWeek(DateTime lastDate, DateTime now) {
    final lastDateMonday =
        lastDate.subtract(Duration(days: lastDate.weekday - 1));
    final nowMonday = now.subtract(Duration(days: now.weekday - 1));
    return !DateUtils.isSameDay(lastDateMonday, nowMonday);
  }

  /// Sets up the new boss stats and name
  Future<void> finalizeWeeklyTransition() async {
    final bossData = _getBossDataForCurrentWeek();

    _bossImage = bossData['image']!;
    _bossName = bossData['name']!;
    _bossMaxHp = _dailyBudget * 7;
    _realBossHp = _bossMaxHp;
    _visualBossHp = _bossMaxHp;
    _heroCurrentHp = _heroMaxHp; // Heal Hero
    _isVictoryClaimed = false;
    _isTransitionPending = false;

    _budgetChangesThisWeek = 0;
    _lastBudgetChangeDateStr =
        DateTime.now().toIso8601String().substring(0, 10);

    _dailyQuests = [
      GameQuest(
          id: "1",
          title: "Micro-saver",
          type: QuestType.spendBelowAmount,
          targetAmount: _dailyBudget * 0.1,
          damageReward: 50),
      GameQuest(
          id: "2",
          title: "Streak Master",
          type: QuestType.logStreak,
          damageReward: 30),
    ];

    await _saveToSupabase();
    _dialogMessage = "A new $_bossName has arrived!";
    notifyListeners();
  }

  Future<bool> setDailyBudget(double amount) async {
    if (!canChangeBudget) return false;
    _dailyBudget = amount;
    await finalizeWeeklyTransition();
    _budgetChangesThisWeek++;
    await _saveToSupabase();
    notifyListeners();
    return true;
  }

  Future<void> recordExpenseDamage(
      double amount, double totalSpentToday) async {
    if (_realBossHp <= 0 && !_isVictoryClaimed) return;

    _realBossHp = (_realBossHp - amount).clamp(0, _bossMaxHp);

    if (totalSpentToday > _dailyBudget) {
      double overspend = totalSpentToday - _dailyBudget;
      double damageToHero = (overspend / _dailyBudget * 50).clamp(5.0, 50.0);
      _heroCurrentHp = (_heroCurrentHp - damageToHero).clamp(0, _heroMaxHp);
      _isHeroHit = true;
    } else {
      _isHeroAttacking = true;
    }

    if (_realBossHp <= 0 && !_isVictoryClaimed) {
      _isVictoryClaimed = true;
      _dialogMessage = "VICTORY! The $_bossName is defeated!";
    }

    _hasPendingAnimation = true;
    await _saveToSupabase();
    notifyListeners();
  }

  void updateDailyMood({
    required double todaySpent,
    required double yesterdaySpent,
    required double dailyBudget,
  }) {
    if (todaySpent < yesterdaySpent) {
      _bossMood = BossMood.weakened;
      _dialogMessage = "The $_bossName looks weakened by your discipline";
    } else if (todaySpent <= dailyBudget * 0.7) {
      _bossMood = BossMood.calm;
      _dialogMessage = "The $_bossName watches calmly...";
    } else if (todaySpent <= dailyBudget) {
      _bossMood = BossMood.angry;
      _dialogMessage = "The $_bossName is getting angry";
    } else {
      _bossMood = BossMood.enraged;
      _dialogMessage = "ENRAGED! You crossed the limit";
    }

    notifyListeners();
  }

  Future<void> checkQuestCompletion(List<Expense> todayExpenses) async {
    // Hidden logic for background quests can be added here
  }

  Future<void> playPendingBattleAnimations() async {
    if (!_hasPendingAnimation) return;
    double damageTaken = _visualBossHp - _realBossHp;
    _dialogMessage = "Syncing Battle Data...";
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 500));

    if (_heroCurrentHp < 50 && damageTaken < 10) {
      _isHeroHit = true;
      _dialogMessage = "Demon Attacked! You overspent!";
    } else {
      _isHeroAttacking = true;
      _isBossHit = true;
      _dialogMessage = "Hero Attacks! Boss took ${damageTaken.toInt()} damage!";
    }

    _visualBossHp = _realBossHp;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 600));
    _isBossHit = false;
    _isHeroHit = false;
    _isHeroAttacking = false;
    _hasPendingAnimation = false;

    if (_heroCurrentHp <= 0)
      _dialogMessage = "DEFEAT... The $_bossName overpowered you.";
    if (_realBossHp <= 0) _dialogMessage = "VICTORY! The $_bossName is slain!";
    notifyListeners();
  }

  // DEBUG METHODS
  void debugSimulateBackgroundDamage(double amount) {
    _realBossHp = (_realBossHp - amount).clamp(0, _bossMaxHp);
    _hasPendingAnimation = true;
    notifyListeners();
  }

  void debugTriggerNewWeek() {
    _isTransitionPending = true;
    notifyListeners();
  }

  void debugResetGame() => finalizeWeeklyTransition();
}
