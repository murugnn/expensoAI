import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expenso/services/referral_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Web OAuth Client ID from Google Cloud Console (used as serverClientId
  // so Supabase can verify the ID token). Override at build time with:
  //   --dart-define=GOOGLE_WEB_CLIENT_ID=...
  static const String _googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue:
        '1057208578912-ijjmo157cc1fsl4b1vi9nl32bitvd7gi.apps.googleusercontent.com',
  );

  // Reused singleton — calling signOut() on this instance clears the cached
  // Google account so the picker re-appears on the next sign-in.
  late final GoogleSignIn _googleSignIn =
      GoogleSignIn(serverClientId: _googleWebClientId);

  User? _currentUser;
  bool _isLoading = false;
  bool _isPasswordRecovery = false;
  bool _isReady = false;
  bool _needsSetup = false;

  StreamSubscription<AuthState>? _authSub;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _currentUser != null;
  bool get isPasswordRecovery => _isPasswordRecovery;
  bool get isReady => _isReady;
  bool get needsSetup => _needsSetup;

  String get userName =>
      _currentUser?.userMetadata?['name']?.toString() ??
      _currentUser?.userMetadata?['full_name']?.toString() ??
      'User';
  String? get userAvatar =>
      _currentUser?.userMetadata?['avatar']?.toString() ??
      _currentUser?.userMetadata?['avatar_url']?.toString();

  AuthProvider() {
    _init();
  }

  Future<void> _init() async {
    _currentUser = _supabase.auth.currentUser;

    // Check if existing session user needs onboarding
    if (_currentUser != null) {
      await _checkNeedsSetup(_currentUser!);
    }
    _isReady = true;
    notifyListeners();

    _authSub = _supabase.auth.onAuthStateChange.listen((data) async {
      final session = data.session;
      _currentUser = session?.user;

      if (data.event == AuthChangeEvent.passwordRecovery) {
        _isPasswordRecovery = true;
      } else {
        _isPasswordRecovery = false;
      }

      // After OAuth sign-in, check if user_stats exist
      if (data.event == AuthChangeEvent.signedIn && _currentUser != null) {
        await _checkNeedsSetup(_currentUser!);
      }
      notifyListeners();
    });
  }

  Future<void> _checkNeedsSetup(User user) async {
    try {
      final res = await _supabase
          .from('user_stats')
          .select('user_id')
          .eq('user_id', user.id)
          .maybeSingle();
      _needsSetup = res == null;
    } catch (_) {
      _needsSetup = false;
    }
  }

  void completeSetup() {
    _needsSetup = false;
    notifyListeners();
  }

  /// Native Google Sign-In: shows the account picker, then authenticates
  /// with Supabase via the Google ID token.
  ///
  /// Returns `null` on success OR on user-cancellation (no error to surface).
  /// Returns a human-readable message string on real failures.
  ///
  /// Requires:
  ///  - A **Web** OAuth Client ID (configured in the Supabase dashboard
  ///    under Authentication → Providers → Google).
  ///  - An **Android** OAuth Client ID linked to the app's SHA-1.
  ///  - An **iOS** OAuth Client ID + reversed-client-id URL scheme.
  Future<String?> signInWithGoogle() async {
    _isLoading = true;
    notifyListeners();
    try {
      // Always sign out first so the account picker actually shows up
      // (otherwise google_sign_in silently re-uses the last account).
      try {
        await _googleSignIn.signOut();
      } catch (_) {}

      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User dismissed the picker — not an error.
        return null;
      }

      final googleAuth = await googleUser.authentication;
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;

      if (idToken == null) {
        return 'Could not obtain Google ID token. Please try again.';
      }

      final res = await _supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      _currentUser = res.user;
      if (_currentUser != null) {
        await _checkNeedsSetup(_currentUser!);
      }
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      debugPrint('[AuthProvider] signInWithGoogle failed: $e');
      return 'Google sign-in failed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

      final res = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );

      final user = res.user;

      // Supabase returns a user with an empty `identities` array when the
      // email already exists (the new password is not applied). Documented
      // here: https://supabase.com/docs/reference/dart/auth-signup
      if (user != null && (user.identities?.isEmpty ?? false)) {
        return "An account with this email already exists.";
      }

      if (user != null) {
        try {
          await _supabase.rpc('create_user_stats', params: {
            'p_user_id': user.id,
            'p_referral_code': myReferralCode,
            'p_referred_by': referredBy,
          });
        } catch (e) {
          debugPrint('[AuthProvider] create_user_stats failed: $e');
        }

        if (referredBy != null &&
            referredBy == referralService.pendingReferralCode) {
          await referralService.clearPendingCode();
        }
      }

      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return "Something went wrong. Please try again.";
    }
  }

  Future<bool> _validateReferralCode(String code) async {
    try {
      final res = await _supabase
          .from('user_stats')
          .select('user_id')
          .eq('referral_code', code)
          .maybeSingle();
      return res != null;
    } catch (e) {
      debugPrint('[AuthProvider] referral validate failed: $e');
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
    // Clear Google's cached account so the picker re-appears next time.
    try {
      await _googleSignIn.signOut();
    } catch (_) {}
    await _supabase.auth.signOut();
    _needsSetup = false;
    _isPasswordRecovery = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
