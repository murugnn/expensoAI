import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expenso/services/referral_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  User? _currentUser;
  bool _isLoading = false;
  bool _isPasswordRecovery = false;

  StreamSubscription<AuthState>? _authSub;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isPasswordRecovery => _isPasswordRecovery;

  String get userName =>
      _currentUser?.userMetadata?['name']?.toString() ?? 'User';
  String? get userAvatar => _currentUser?.userMetadata?['avatar']?.toString();

  AuthProvider() {
    _init();
  }

  void _init() {
    _currentUser = _supabase.auth.currentUser;
    _authSub = _supabase.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      _currentUser = session?.user;
      
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      } else {
        _isPasswordRecovery = false;
      }
      notifyListeners();
    });
  }

  Future<String?> signup(String name, String email, String password, {String? manualReferralCode}) async {
    try {
      // 1. Determine referral code source
      final referralService = ReferralService();
      await referralService.init(); // Ensure loaded
      
      String? referredBy = referralService.pendingReferralCode;

      // Manual code overrides deep link if provided and valid
      if (manualReferralCode != null && manualReferralCode.isNotEmpty) {
          final codeUpper = manualReferralCode.toUpperCase();
          final isValid = await _validateReferralCode(codeUpper);
          if (!isValid) {
            return "Invalid referral code";
          }
          referredBy = codeUpper;
      }
      
      // 2. Generate a referral code for this new user
      final String myReferralCode = ReferralService.generateReferralCode(name);

      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          // 'coins': 0, // Coins now in user_stats
        },
      );

      final user = res.user;

      // 🚨 THIS IS THE IMPORTANT CHECK
      if (user != null && user.identities != null && user.identities!.isEmpty) {
        return "Email already exists";
      }

      // 3. Create initial user_stats via server-side RPC (bypasses RLS)
      if (user != null) {
        try {
          // DEBUG: Check referrer's coins BEFORE
          if (referredBy != null && referredBy.isNotEmpty) {
            final beforeRes = await _supabase.from('user_stats').select('coins').eq('referral_code', referredBy).maybeSingle();
            debugPrint("🔍 BEFORE RPC: Referrer coins = ${beforeRes?['coins']}");
          }

          await _supabase.rpc('create_user_stats', params: {
            'p_user_id': user.id,
            'p_referral_code': myReferralCode,
            'p_referred_by': referredBy,
          });
          debugPrint("✅ User stats created via RPC. referredBy=$referredBy");

          // DEBUG: Check referrer's coins AFTER
          if (referredBy != null && referredBy.isNotEmpty) {
            final afterRes = await _supabase.from('user_stats').select('coins').eq('referral_code', referredBy).maybeSingle();
            debugPrint("🔍 AFTER RPC: Referrer coins = ${afterRes?['coins']}");
          }

          // DEBUG: Check referee's coins
          final refStats = await _supabase.from('user_stats').select('coins').eq('user_id', user.id).maybeSingle();
          debugPrint("🔍 New user coins = ${refStats?['coins']}");
        } catch (e) {
          debugPrint("❌ Failed to create user stats via RPC: $e");
        }

        // Clear used referral code (if from deep link)
        if (referredBy != null && referredBy == referralService.pendingReferralCode) {
          await referralService.clearPendingCode();
        }
      }

      // New user → allow confirm email flow
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return "Something went wrong. Please try again.";
    }
  }

  Future<bool> _validateReferralCode(String code) async {
      debugPrint("Attempting to validate referral code: '$code'");
      try {
        final res = await _supabase.from('user_stats').select('user_id').eq('referral_code', code).maybeSingle();
        debugPrint("Validation result for '$code': $res");
        return res != null;
      } catch (e) {
        debugPrint("Error validating referral code: $e");
        return false;
      }
  }



  Future<String?> verifyOtp(String email, String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase.auth.verifyOTP(
        type: OtpType.signup,
        token: token,
        email: email,
      );
      _currentUser = response.user;
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Verification failed.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      _currentUser = response.user;
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "An unexpected error occurred.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> resetPassword(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.expenso://login-callback/reset-password',
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return "Failed to send reset email.";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePassword(String newPassword) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );
      _currentUser = response.user;
      _isPasswordRecovery = false; // Clear recovery state
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateProfile({required String name, String? avatar}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _supabase.auth.updateUser(
        UserAttributes(data: {'name': name, 'avatar': avatar}),
      );
      _currentUser = response.user;
      return true;
    } catch (e) {
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
