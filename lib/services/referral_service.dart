import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expenso/models/user.dart';
import 'package:expenso/services/user_service.dart';

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingReferralCode;

  String? get pendingReferralCode => _pendingReferralCode;

  /// Initialize the service, listen for deep links
  Future<void> init() async {
    // 1. Check initial link (if app was launched via link)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Error handling initial deep link: $e");
    }

    // 2. Listen for subsequent links (if app is already running)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    });

    // 3. Load any pending code from storage (in case install/launch interrupted)
    await _loadPendingCode();
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  /// Parses the deep link to extract referral code
  /// Scheme: expenso://invite?code=123
  /// Or Universal Link: https://expenso.app/invite?code=123
  void _handleDeepLink(Uri uri) {
    debugPrint("Deep link received: $uri");
    
    // Check for 'code' parameter
    final code = uri.queryParameters['code'];
    if (code != null && code.isNotEmpty) {
      debugPrint("Referral Code detected: $code");
      _setPendingReferralCode(code);
    }
  }

  /// Saves the code to persistent storage so we can use it after Signup/Login
  Future<void> _setPendingReferralCode(String code) async {
    _pendingReferralCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_referral_code', code);
  }

  Future<void> _loadPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingReferralCode = prefs.getString('pending_referral_code');
  }

  /// Clears the pending code after it has been used
  Future<void> clearPendingCode() async {
    _pendingReferralCode = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_referral_code');
  }

  /// Generates a sharable link for the current user
  String generateShareLink(String? referralCode) {
    // Ideally this should be a Universal Link / App Link hosted on your website
    // For now, we use a custom scheme or a placeholder web link
    if (referralCode == null) return "https://expenso.app";
    
    // Link to the project page (where updates are found)
    return "https://murugan-one.vercel.app/#projects-expenso";
  }

  static String generateReferralCode(String name) {
    // Basic code generation: Name prefix (3 chars) + Random 4 digits
    // e.g., MUR1234
    final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final prefix = cleanName.length >= 3 ? cleanName.substring(0, 3) : cleanName.padRight(3, 'X');
    final randomPart = (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();
    return "$prefix$randomPart";
  }
}
