import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for fetching live exchange rates and converting currencies.
/// Uses the Frankfurter API (free, no API key, ECB-backed).
class CurrencyService {
  static final CurrencyService _instance = CurrencyService._internal();
  factory CurrencyService() => _instance;
  CurrencyService._internal();

  // Cache: base currency -> { target -> rate }
  final Map<String, Map<String, double>> _rateCache = {};
  DateTime? _lastFetchTime;
  static const Duration _cacheTTL = Duration(minutes: 10);

  /// Map of common currency symbols to ISO 4217 codes
  static const Map<String, String> symbolToCode = {
    '₹': 'INR',
    '\$': 'USD',
    '€': 'EUR',
    '£': 'GBP',
    '¥': 'JPY',
    '₩': 'KRW',
    '₽': 'RUB',
    '₿': 'BTC',
    'R': 'ZAR',
    'RM': 'MYR',
    '฿': 'THB',
    '₫': 'VND',
    '₦': 'NGN',
    '৳': 'BDT',
    '₱': 'PHP',
  };

  /// Common currency names to ISO codes (for voice parsing)
  static const Map<String, String> nameToCode = {
    'rupee': 'INR',
    'rupees': 'INR',
    'dollar': 'USD',
    'dollars': 'USD',
    'euro': 'EUR',
    'euros': 'EUR',
    'pound': 'GBP',
    'pounds': 'GBP',
    'yen': 'JPY',
    'yuan': 'CNY',
    'dirham': 'AED',
    'dirhams': 'AED',
    'riyal': 'SAR',
    'riyals': 'SAR',
    'ringgit': 'MYR',
    'baht': 'THB',
    'won': 'KRW',
    'peso': 'MXN',
    'pesos': 'MXN',
    'rand': 'ZAR',
    'lira': 'TRY',
    'franc': 'CHF',
    'francs': 'CHF',
    'krona': 'SEK',
    'kronor': 'SEK',
    'real': 'BRL',
    'reais': 'BRL',
    'taka': 'BDT',
  };

  /// Resolve a currency string (symbol, name, or ISO code) to an ISO code.
  String? resolveToCode(String input) {
    final cleaned = input.trim().toUpperCase();

    // Already an ISO code (3 letters)?
    if (cleaned.length == 3 && RegExp(r'^[A-Z]{3}$').hasMatch(cleaned)) {
      return cleaned;
    }

    // Check symbol map
    if (symbolToCode.containsKey(input.trim())) {
      return symbolToCode[input.trim()];
    }

    // Check name map (case-insensitive)
    final lower = input.trim().toLowerCase();
    if (nameToCode.containsKey(lower)) {
      return nameToCode[lower];
    }

    return null;
  }

  /// Fetch latest exchange rates for a base currency.
  Future<Map<String, double>?> _fetchRates(String baseCurrency) async {
    // Check cache freshness
    if (_rateCache.containsKey(baseCurrency) &&
        _lastFetchTime != null &&
        DateTime.now().difference(_lastFetchTime!) < _cacheTTL) {
      return _rateCache[baseCurrency];
    }

    try {
      final uri = Uri.parse(
          'https://api.frankfurter.dev/v1/latest?base=$baseCurrency');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) {
        debugPrint('[CurrencyService] API error: ${response.statusCode}');
        return _rateCache[baseCurrency]; // Return stale cache if available
      }

      final data = jsonDecode(response.body);
      final rates = (data['rates'] as Map<String, dynamic>)
          .map((key, value) => MapEntry(key, (value as num).toDouble()));

      _rateCache[baseCurrency] = rates;
      _lastFetchTime = DateTime.now();

      debugPrint('[CurrencyService] Fetched ${rates.length} rates for $baseCurrency');
      return rates;
    } catch (e) {
      debugPrint('[CurrencyService] Fetch error: $e');
      return _rateCache[baseCurrency]; // Return stale cache if available
    }
  }

  /// Convert an amount from one currency to another.
  /// Returns a [ConversionResult] with the converted amount and rate used,
  /// or null if conversion failed (offline + no cache).
  Future<ConversionResult?> convert({
    required double amount,
    required String fromCurrency,
    required String toCurrency,
  }) async {
    final from = fromCurrency.toUpperCase();
    final to = toCurrency.toUpperCase();

    if (from == to) {
      return ConversionResult(
        convertedAmount: amount,
        exchangeRate: 1.0,
        fromCurrency: from,
        toCurrency: to,
        originalAmount: amount,
      );
    }

    final rates = await _fetchRates(from);
    if (rates == null || !rates.containsKey(to)) {
      debugPrint('[CurrencyService] No rate available for $from -> $to');
      return null;
    }

    final rate = rates[to]!;
    return ConversionResult(
      convertedAmount: double.parse((amount * rate).toStringAsFixed(2)),
      exchangeRate: rate,
      fromCurrency: from,
      toCurrency: to,
      originalAmount: amount,
    );
  }

  /// Get list of supported currency codes (from cache or API)
  Future<List<String>> getSupportedCurrencies() async {
    final rates = await _fetchRates('USD');
    if (rates == null) return ['USD', 'EUR', 'GBP', 'INR', 'JPY'];
    return ['USD', ...rates.keys.toList()..sort()];
  }

  /// Clear the rate cache (for testing or manual refresh)
  void clearCache() {
    _rateCache.clear();
    _lastFetchTime = null;
  }
}

/// Result of a currency conversion
class ConversionResult {
  final double convertedAmount;
  final double exchangeRate;
  final String fromCurrency;
  final String toCurrency;
  final double originalAmount;

  ConversionResult({
    required this.convertedAmount,
    required this.exchangeRate,
    required this.fromCurrency,
    required this.toCurrency,
    required this.originalAmount,
  });

  @override
  String toString() =>
      '$originalAmount $fromCurrency = $convertedAmount $toCurrency (rate: $exchangeRate)';
}
