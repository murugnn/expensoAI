import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:app_links/app_links.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

class ReferralService {
  static final ReferralService _instance = ReferralService._internal();
  factory ReferralService() => _instance;
  ReferralService._internal();

  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  String? _pendingReferralCode;
  String? _ownReferralCode;

  /// Single source for the public-facing invite landing page. Update this if
  /// you migrate to a real universal-link domain.
  static const String _baseInviteUrl =
      'https://murugan-one.vercel.app/#projects-expenso';

  String? get pendingReferralCode => _pendingReferralCode;
  String? get ownReferralCode => _ownReferralCode;

  /// Initialize the service, listen for deep links, hydrate the cached
  /// referral code (own + pending).
  Future<void> init() async {
    // 1. Initial deep link.
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint('Error handling initial deep link: $e');
    }

    // 2. Subsequent deep links.
    _linkSubscription = _appLinks.uriLinkStream.listen(_handleDeepLink);

    // 3. Hydrate pending code from disk.
    await _loadPendingCode();

    // 4. Try to fetch the user's own referral code (from user_stats).
    await refreshOwnReferralCode();
  }

  void dispose() {
    _linkSubscription?.cancel();
  }

  // ============================================================
  // DEEP LINK HANDLING
  // ============================================================

  /// Scheme: `expenso://invite?code=ABC123`
  /// Universal:  `https://expenso.app/invite?code=ABC123`
  /// Or our public landing page with the code in query.
  void _handleDeepLink(Uri uri) {
    debugPrint('Deep link received: $uri');
    final code = uri.queryParameters['code'] ??
        uri.queryParameters['ref'] ??
        uri.queryParameters['referral'];
    if (code != null && code.trim().isNotEmpty) {
      debugPrint('Referral code detected: $code');
      _setPendingReferralCode(code.trim().toUpperCase());
    }
  }

  Future<void> _setPendingReferralCode(String code) async {
    _pendingReferralCode = code;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pending_referral_code', code);
  }

  Future<void> _loadPendingCode() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingReferralCode = prefs.getString('pending_referral_code');
  }

  Future<void> clearPendingCode() async {
    _pendingReferralCode = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('pending_referral_code');
  }

  // ============================================================
  // OWN REFERRAL CODE (from user_stats)
  // ============================================================

  Future<String?> refreshOwnReferralCode() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _ownReferralCode = null;
      return null;
    }
    try {
      final res = await Supabase.instance.client
          .from('user_stats')
          .select('referral_code')
          .eq('user_id', user.id)
          .maybeSingle();
      _ownReferralCode = res?['referral_code']?.toString();
      return _ownReferralCode;
    } catch (e) {
      debugPrint('refreshOwnReferralCode failed: $e');
      return _ownReferralCode;
    }
  }

  // ============================================================
  // SHARE PIPELINE
  // ============================================================

  /// Public landing URL with the user's code attached. Falls back to bare
  /// landing page when no code is available yet.
  String generateShareLink(String? referralCode) {
    if (referralCode == null || referralCode.isEmpty) return _baseInviteUrl;
    return '$_baseInviteUrl?ref=$referralCode';
  }

  /// Builds the canonical invite copy. Personalized to the inviter's name
  /// and the recipient's first name when available.
  String buildShareMessage({
    required String? referralCode,
    String? inviterName,
    String? recipientName,
  }) {
    final link = generateShareLink(referralCode);
    final hello = (recipientName == null || recipientName.trim().isEmpty)
        ? 'Hey'
        : 'Hey ${recipientName.split(' ').first}';
    final fromBit =
        (inviterName == null || inviterName.trim().isEmpty) ? '' : ' — $inviterName';
    final codeBit = (referralCode == null || referralCode.isEmpty)
        ? ''
        : '\n\nUse my code $referralCode for a head start.';
    return '$hello! Join me on Expenso for smart shared expenses, '
        'AI finance help, and easy split tracking.$codeBit\n\n$link$fromBit';
  }

  /// Builds a personal message for sharing a *room*, using the room code
  /// directly. Friends-of-friends can join by punching in this code.
  String buildRoomShareMessage({
    required String roomName,
    required String roomCode,
    String? inviterName,
  }) {
    final fromBit = (inviterName == null || inviterName.trim().isEmpty)
        ? ''
        : ' — $inviterName';
    return 'Join "$roomName" on Expenso to split shared expenses with us.\n\n'
        'Tap to open: $_baseInviteUrl?room=$roomCode\n'
        'Or open Expenso → Shared Rooms → Join with code: $roomCode$fromBit';
  }

  // ============================================================
  // CHANNELS
  // ============================================================

  /// System share-sheet (iOS / Android share-target picker).
  Future<void> shareViaSystem(String message, {String? subject}) async {
    await Share.share(message, subject: subject);
  }

  /// WhatsApp via `whatsapp://send`. Returns false if WhatsApp isn't
  /// installed (or the launch failed).
  Future<bool> shareViaWhatsApp(String message, {String? phone}) async {
    final phoneClean = (phone ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    final encoded = Uri.encodeComponent(message);
    final uri = phoneClean.isEmpty
        ? Uri.parse('whatsapp://send?text=$encoded')
        : Uri.parse('whatsapp://send?phone=$phoneClean&text=$encoded');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('shareViaWhatsApp failed: $e');
      return false;
    }
  }

  Future<bool> shareViaSms(String phone, String message) async {
    final encoded = Uri.encodeComponent(message);
    final uri = Uri.parse('sms:$phone?body=$encoded');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('shareViaSms failed: $e');
      return false;
    }
  }

  Future<bool> shareViaEmail(
    String email,
    String message, {
    String subject = 'Join me on Expenso',
  }) async {
    final body = Uri.encodeComponent(message);
    final subj = Uri.encodeComponent(subject);
    final uri = Uri.parse('mailto:$email?subject=$subj&body=$body');
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('shareViaEmail failed: $e');
      return false;
    }
  }

  // ============================================================
  // CONVERSION TRACKING
  // ============================================================

  /// Logs an outbound referral attempt to the server. Best-effort — failures
  /// don't break the share flow.
  Future<void> recordOutboundReferral({
    required String channel, // 'whatsapp' | 'sms' | 'email' | 'share' | 'other'
    String? code,
  }) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final c = code ?? _ownReferralCode;
    if (c == null || c.isEmpty) return;
    try {
      await Supabase.instance.client.rpc('record_referral', params: {
        'p_code': c,
        'p_channel': channel,
      });
    } catch (e) {
      debugPrint('recordOutboundReferral failed: $e');
    }
  }

  // ============================================================
  // CODE GENERATION (used at signup)
  // ============================================================

  static String generateReferralCode(String name) {
    final cleanName = name.replaceAll(RegExp(r'[^a-zA-Z]'), '').toUpperCase();
    final prefix = cleanName.length >= 3
        ? cleanName.substring(0, 3)
        : cleanName.padRight(3, 'X');
    final randomPart =
        (1000 + DateTime.now().millisecondsSinceEpoch % 9000).toString();
    return '$prefix$randomPart';
  }
}
