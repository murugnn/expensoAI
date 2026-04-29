import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Pure utilities for normalizing & hashing user-identifiable contact fields.
///
/// We never upload raw phone numbers or emails to the server — only their
/// SHA-256 hashes. The hash is computed against a normalized form (E.164-ish
/// for phones, lowercased trimmed string for emails) so two devices producing
/// the same identifier always produce the same hash.
class ContactHash {
  /// Best-effort phone normalization. We don't ship a full E.164 parser to
  /// stay dependency-light; instead we strip punctuation, spaces, and the
  /// leading "00" trunk used outside North America. Pre-pending the
  /// [defaultCountryCode] handles the common case where the address book
  /// stores numbers without an international prefix.
  static String? normalizePhone(String? raw, {String? defaultCountryCode}) {
    if (raw == null) return null;
    var s = raw.trim();
    if (s.isEmpty) return null;

    // Strip punctuation/spaces, keep digits and leading +.
    final hasPlus = s.startsWith('+');
    s = s.replaceAll(RegExp(r'[^0-9]'), '');
    if (s.isEmpty) return null;

    // "00" → "+" (international trunk)
    if (!hasPlus && s.startsWith('00')) {
      s = s.substring(2);
    } else if (hasPlus) {
      // already international
    } else if (defaultCountryCode != null && defaultCountryCode.isNotEmpty) {
      // Local number — assume default country code if provided.
      final cc = defaultCountryCode.replaceAll(RegExp(r'[^0-9]'), '');
      // If number already starts with the country code, don't prepend twice.
      if (!s.startsWith(cc)) {
        // For India (cc=91), strip leading 0 trunk before prepending.
        if (s.startsWith('0')) {
          s = s.substring(1);
        }
        s = '$cc$s';
      }
    }

    if (s.length < 6) return null; // too short to be meaningful
    return '+$s';
  }

  /// Lowercase + trim, drop empty.
  static String? normalizeEmail(String? raw) {
    if (raw == null) return null;
    final s = raw.trim().toLowerCase();
    if (s.isEmpty || !s.contains('@')) return null;
    return s;
  }

  static String _sha256(String s) {
    final bytes = utf8.encode(s);
    return sha256.convert(bytes).toString();
  }

  static String? hashPhone(String? raw, {String? defaultCountryCode}) {
    final n = normalizePhone(raw, defaultCountryCode: defaultCountryCode);
    if (n == null) return null;
    return _sha256(n);
  }

  static String? hashEmail(String? raw) {
    final n = normalizeEmail(raw);
    if (n == null) return null;
    return _sha256(n);
  }
}
