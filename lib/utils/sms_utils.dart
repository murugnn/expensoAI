class SmsUtils {
  static final RegExp _amountRegex = RegExp(r'(?:\b(?:INR|Rs\.?|₹)\s*(\d+(?:,\d+)*(?:\.\d{1,2})?))', caseSensitive: false);
  static final List<String> _debitKeywords = ['debited', 'spent', 'paid', 'sent', 'withdrawn'];
  static final List<String> _upiKeywords = ['UPI', 'VPA', 'P2M', 'P2P'];

  static double? extractAmount(String body) {
    final match = _amountRegex.firstMatch(body);
    if (match != null) {
      String amountStr = match.group(1)!.replaceAll(',', '');
      return double.tryParse(amountStr);
    }
    return null;
  }

  static bool isDebitTransaction(String body) {
    String lowerBody = body.toLowerCase();
    bool hasDebitKeyword = _debitKeywords.any((keyword) => lowerBody.contains(keyword));
    // It's good to check for "credited" to avoid false positives if a message says "debited... but credited back" or similar complex structures, 
    // but for now, simple keyword match is a good start. 
    // We should avoid "credited" messages unless they are refunds (which are income).
    bool isCredit = lowerBody.contains('credited') || lowerBody.contains('received');
    
    return hasDebitKeyword && !isCredit;
  }

  static String extractMerchant(String body) {
    // This is the hardest part. Usually follows 'to', 'at', 'via'.
    // Example: "paid to SWIGGY", "spent at STARBUCKS"
    // Heuristic: Look for "to" or "at" followed by capitalized words or specific patterns.
    
    RegExp merchantRegex = RegExp(r'(?:to|at)\s+([A-Z0-9\s]+?)(?=\s+(?:on|via|ref|bal|avl)|$)', caseSensitive: false);
    final match = merchantRegex.firstMatch(body);
    if (match != null) {
      return cleanMerchantName(match.group(1)!);
    }
    return "Unknown Merchant";
  }

  static String cleanMerchantName(String rawName) {
    String name = rawName.toUpperCase();
    name = name.replaceAll(RegExp(r'\b(PVT|LTD|PRIVATE|LIMITED|India|IND|CORP)\b', caseSensitive: false), '');
    name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (name.isEmpty) return "Unknown Merchant";
    return name; // You could add Title Case conversion here
  }
  
  static DateTime extractDate(int timestamp) {
      return DateTime.fromMillisecondsSinceEpoch(timestamp);
  }
}
