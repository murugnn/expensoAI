import 'dart:io';
import 'package:csv/csv.dart';
import 'package:expenso/models/expense.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  /// Converts a list of expenses into a CSV file and triggers the native share sheet.
  /// Returns [true] if successful, [false] otherwise.
  static Future<bool> exportExpensesToCsv(List<Expense> expenses) async {
    try {
      if (expenses.isEmpty) {
        debugPrint("No expenses to export.");
        return false;
      }

      // 1. Define CSV Headers
      List<List<dynamic>> rows = [
        ["Date", "Title", "Amount", "Category", "Wallet", "Tags", "Contact"]
      ];

      // 2. Map Expenses to Rows
      for (var exp in expenses) {
        rows.add([
          exp.date.toIso8601String().split('T').first, // Format: YYYY-MM-DD
          exp.title,
          exp.amount.toStringAsFixed(2),
          exp.category,
          exp.wallet,
          exp.tags.join(', '),
          exp.contact ?? "",
        ]);
      }

      // 3. Convert to CSV String
      String csvData = const CsvEncoder().convert(rows);

      // 4. Get Temporary Directory
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final String filePath = '${tempDir.path}/expenso_export_$timestamp.csv';

      // 5. Write to File
      final File file = File(filePath);
      await file.writeAsString(csvData);

      // 6. Share File
      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Expenso Financial Data Export',
        subject: 'Expenso Export',
      );

      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint("Error exporting to CSV: $e");
      return false;
    }
  }

  /// Writes a raw CSV string to a file and shares it.
  static Future<bool> exportRawCsvString(String csvData, String filenamePrefix) async {
    try {
      final Directory tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.').first;
      final String filePath = '${tempDir.path}/${filenamePrefix}_$timestamp.csv';

      final File file = File(filePath);
      await file.writeAsString(csvData);

      final result = await Share.shareXFiles(
        [XFile(filePath)],
        text: 'Expenso Business Data Export',
        subject: 'Expenso Export',
      );

      return result.status == ShareResultStatus.success;
    } catch (e) {
      debugPrint("Error sharing raw CSV string: $e");
      return false;
    }
  }
}

