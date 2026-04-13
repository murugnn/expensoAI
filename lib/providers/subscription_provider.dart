import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expenso/models/subscription.dart';
import 'package:expenso/models/expense.dart';
import 'package:expenso/providers/auth_provider.dart';
import 'package:expenso/providers/expense_provider.dart';
import 'package:uuid/uuid.dart';

class SubscriptionProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthProvider? _authProvider;
  ExpenseProvider? _expenseProvider;

  List<Subscription> _subscriptions = [];
  bool _isLoading = false;

  List<Subscription> get subscriptions => _subscriptions;
  bool get isLoading => _isLoading;

  void update(AuthProvider auth, ExpenseProvider expenseProvider) {
    final oldUserId = _authProvider?.currentUser?.id;
    final newUserId = auth.currentUser?.id;

    _authProvider = auth;
    _expenseProvider = expenseProvider;

    if (oldUserId != newUserId) {
      _subscriptions = [];
      notifyListeners();
    }

    if (newUserId != null && _subscriptions.isEmpty) {
      loadSubscriptions();
    }
  }

  Future<void> loadSubscriptions() async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('subscriptions')
          .select()
          .eq('user_id', user.id)
          .order('next_bill_date', ascending: true);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _subscriptions = rows.map((row) => Subscription.fromMap(row)).toList();

      // Check for due bills immediately after loading
      await checkDueSubscriptions();
    } catch (e) {
      debugPrint("loadSubscriptions error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addSubscription(Subscription subscription) async {
    final user = _authProvider?.currentUser;
    if (user == null) return "Not logged in";

    try {
      final res =
          await _supabase.from('subscriptions').insert(subscription.toSupabase()).select();
      
      final newSub = Subscription.fromMap(res.first);
      _subscriptions.add(newSub);
      _subscriptions.sort((a, b) => a.nextBillDate.compareTo(b.nextBillDate));
      
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint("addSubscription error: $e");
      return "Failed: $e";
    }
  }

  Future<void> deleteSubscription(String id) async {
    try {
      await _supabase.from('subscriptions').delete().eq('id', id);
      _subscriptions.removeWhere((s) => s.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("deleteSubscription error: $e");
    }
  }

  Future<void> checkDueSubscriptions() async {
    if (_expenseProvider == null) return;
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    bool changed = false;

    for (int i = 0; i < _subscriptions.length; i++) {
      final sub = _subscriptions[i];
      
      // If due date is today or in the past
      if (sub.nextBillDate.isBefore(today) || sub.nextBillDate.isAtSameMomentAs(today)) {
        
        if (sub.autoAdd) {
          // 1. Create Expense
          final newExpense = Expense(
            id: const Uuid().v4(),
            userId: sub.userId,
            title: sub.name, // e.g. "Netflix"
            amount: sub.amount,
            date: sub.nextBillDate, // Use the bill date, not today
            category: sub.category,
            wallet: sub.wallet,
            tags: ['#subscription', 'auto-generated'],
          );

          await _expenseProvider!.addExpense(newExpense);
          debugPrint("✅ Auto-generated expense for ${sub.name}");
        }

        // 2. Calculate next bill date
        DateTime nextDate = sub.nextBillDate;
        if (sub.billingCycle == 'Monthly') {
          nextDate = DateTime(nextDate.year, nextDate.month + 1, nextDate.day);
        } else if (sub.billingCycle == 'Yearly') {
          nextDate = DateTime(nextDate.year + 1, nextDate.month, nextDate.day);
        } else if (sub.billingCycle == 'Weekly') {
          nextDate = nextDate.add(const Duration(days: 7));
        }

        // 3. Update Subscription in DB
        try {
          await _supabase
              .from('subscriptions')
              .update({'next_bill_date': nextDate.toIso8601String()})
              .eq('id', sub.id)
              .select();

          // 4. Update memory
          _subscriptions[i] = sub.copyWith(nextBillDate: nextDate);
          changed = true;
        } catch (e) {
          debugPrint("Failed to update subscription date: $e");
        }
      }
    }

    if (changed) {
      _subscriptions.sort((a, b) => a.nextBillDate.compareTo(b.nextBillDate));
      notifyListeners();
    }
  }
}
