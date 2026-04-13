import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ParsedItem {
  String name;
  double amount;

  ParsedItem({required this.name, required this.amount});
}

class ParsedReceipt {
  final String merchantName;
  final DateTime date;
  final List<ParsedItem> items;
  final double subtotal;
  final double tax;
  final double total;
  final String currency;

  ParsedReceipt({
    required this.merchantName,
    required this.date,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.currency,
  });
}

class ReceiptScannerService {
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();

  Future<ParsedReceipt?> scanReceipt() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.camera);
      if (image == null) return null;

      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText =
          await _textRecognizer.processImage(inputImage);

      return _parseReceipt(recognizedText.text);
    } catch (e) {
      debugPrint("❌ Scan Error: $e");
      return null;
    }
  }

  ParsedReceipt _parseReceipt(String text) {
    final lines = text.split('\n');

    // 1. Metadata
    String merchant = _findMerchantName(lines);
    DateTime date = _findDate(lines) ?? DateTime.now();
    String currency = _detectCurrency(text);

    // 2. Line Items & Financials
    List<ParsedItem> items = [];
    double subtotal = 0;
    double tax = 0;
    double total = 0;

    final priceRegex = RegExp(r'[0-9,]*\.?[0-9]{2}');

    for (var line in lines) {
      final lower = line.toLowerCase();
      
      // Check for Financials first to avoid adding them as items
      if (lower.contains('total') && !lower.contains('sub')) {
        total = _extractAmount(line);
        continue;
      }
      if (lower.contains('subtotal') || lower.contains('net')) {
        subtotal = _extractAmount(line);
        continue;
      }
      if (lower.contains('tax') || lower.contains('vat') || lower.contains('gst')) {
        tax = _extractAmount(line);
        continue;
      }

      // Check for Items
      // Heuristic: Must have a price at the end, and some text before it
      final matches = priceRegex.allMatches(line);
      if (matches.isNotEmpty) {
        final lastMatch = matches.last;
        String priceStr = lastMatch.group(0)!.replaceAll(RegExp(r'[^0-9.]'), '');
        double? price = double.tryParse(priceStr);

        if (price != null && price > 0 && price < 100000) {
           String name = line.substring(0, lastMatch.start).trim();
           name = _cleanTitle(name);

           // Filter out common non-item lines
           if (name.length > 2 && !name.toLowerCase().contains('total')) {
             items.add(ParsedItem(name: name, amount: price));
           }
        }
      }
    }

    // Fallback calculations if OCR missed some fields
    if (total == 0) {
      total = items.fold(0, (sum, item) => sum + item.amount);
      if (tax > 0) total += tax;
    }
    if (subtotal == 0) {
       subtotal = total - tax;
    }

    return ParsedReceipt(
      merchantName: merchant,
      date: date,
      items: items,
      subtotal: subtotal,
      tax: tax,
      total: total,
      currency: currency,
    );
  }

  double _extractAmount(String line) {
     final regex = RegExp(r'[0-9,]*\.?[0-9]{2}');
     final matches = regex.allMatches(line);
     if (matches.isNotEmpty) {
       String clean = matches.last.group(0)!.replaceAll(',', '');
       return double.tryParse(clean) ?? 0.0;
     }
     return 0.0;
  }

  String _detectCurrency(String text) {
    if (text.contains('€')) return '€';
    if (text.contains('£')) return '£';
    if (text.contains('₹')) return '₹';
    return '\$'; // Default
  }

  String _findMerchantName(List<String> lines) {
    // Top 3 lines usually contain the merchant
    for (int i = 0; i < lines.length && i < 3; i++) {
       final line = lines[i].trim();
       if (line.isNotEmpty && line.length > 3 && !RegExp(r'[0-9]').hasMatch(line)) {
         return line;
       }
    }
    return "Unknown Merchant";
  }

  DateTime? _findDate(List<String> lines) {
    // Regex for various date formats
    final dateRegex = RegExp(r'\b(\d{1,2}[/-]\d{1,2}[/-]\d{2,4})|(\d{4}[/-]\d{1,2}[/-]\d{1,2})|(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})\b');
    
    for (var line in lines) {
      final match = dateRegex.firstMatch(line);
      if (match != null) {
        return DateTime.now(); // Placeholder
      }
    }
    return null;
  }

  String _cleanTitle(String title) {
    title = title.replaceAll(RegExp(r'^\d+\s*[x@]\s*'), ''); // Remove "1 x"
    title = title.replaceAll(RegExp(r'[^a-zA-Z0-9\s%]'), ''); // Remove garbage
    return title.trim();
  }
}


