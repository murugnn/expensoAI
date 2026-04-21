import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:expenso/models/expense.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AIService {
  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';
  final String _geminiApiKey = dotenv.env['GEMINI_API_KEY'] ?? '';

  final String _model = "llama-3.1-8b-instant";

  bool get hasKey => _apiKey.isNotEmpty || _geminiApiKey.isNotEmpty;
  static const String _systemPrompt = """
You are EXPENSO AI, a finance assistant that ONLY answers using the user's expense data provided in the prompt.
Rules:
1) Only talk about spending, expenses, categories, budgets, saving tips, trends, and suggestions.
2) If the user asks anything outside expenses (general knowledge, coding, jokes, etc.), reply:
   "I can only help with your expenses and spending insights."
3) Never invent expenses. Never assume missing data.
4) Always keep responses short, actionable, and numeric where possible.
5) Prefer bullet points and small sections.
Output style:
- Use headings
- Use numbers and currency amounts
- Keep it easy to understand
""";

  List<Map<String, dynamic>> _compactExpenses(List<Expense> expenses) {
    return expenses.map((e) {
      return {
        "title": e.title,
        "amount": e.amount,
        "date": e.date.toIso8601String(),
        "category": e.category,
        "wallet": e.wallet,
        "tags": e.tags,
      };
    }).toList();
  }

  Future<String> generateInsights(List<Expense> expenses,
      {double? monthlyBudget, String currency = "₹"}) async {
    if (!hasKey) return "API Key Missing";

    if (expenses.isEmpty) {
      return "No expenses found. Add a few expenses and I’ll generate insights.";
    }

    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) {
      return e.date.month == now.month && e.date.year == now.year;
    }).toList();

    final payload = {
      "mode": "monthly_insights",
      "currency": currency,
      "monthly_budget": monthlyBudget,
      "today": now.toIso8601String(),
      "total_expenses_count": expenses.length,
      "current_month_expenses_count": currentMonthExpenses.length,
      "expenses": _compactExpenses(currentMonthExpenses),
    };

    final userPrompt = """
You are EXPENSO AI. You MUST answer ONLY using the expense JSON provided.

Rules:
1) Use ONLY the data in the JSON. Do NOT guess or invent anything.
2) If the user asks anything not related to spending/expenses/budget, reply exactly:
   "I can only help with your expenses and spending insights."
3) Keep it short, numeric, and actionable.

Output rules (IMPORTANT):
- Output MUST be plain ASCII text only.
- Currency MUST be written as: INR 1234 (never use the ₹ symbol)
- Use "-" for bullet points only (no fancy bullets)
- Do NOT use markdown tables.
- Do NOT use special quotes (use only ' and ").

Return in this format:

1) SUMMARY
- Total spent: INR X
- Avg per day: INR Y
- Transactions: N

2) TOP CATEGORIES (Top 3)
- Category: INR Amount (Percent%)

3) BIGGEST EXPENSES (Top 3)
- Title (Category) - INR Amount - Date (YYYY-MM-DD)

4) WALLET BREAKDOWN
- Wallet: INR Amount (Percent%)

5) PATTERNS
- 1-2 short points about trends (days, categories, repeat spends)

6) SAVINGS TIPS (3)
- Tip 1 (numeric suggestion if possible)
- Tip 2
- Tip 3

7) NEXT 7 DAYS PLAN (2)
- Plan 1
- Plan 2

Data JSON:
{PASTE_JSON_HERE}

Data:
${jsonEncode(payload)}
""";

    return await _callAI(userPrompt);
  }

  Future<String> chatWithAI(String userMessage, List<Expense> expenses,
      {double? monthlyBudget, String currency = "₹"}) async {
    if (!hasKey) return "API Key Missing";

    final now = DateTime.now();
    final currentMonthExpenses = expenses.where((e) {
      return e.date.month == now.month && e.date.year == now.year;
    }).toList();

    final payload = {
      "mode": "chat",
      "currency": currency,
      "monthly_budget": monthlyBudget,
      "today": now.toIso8601String(),
      "expenses": _compactExpenses(currentMonthExpenses),
      "user_question": userMessage,
    };

    final userPrompt = """
User asked: "$userMessage"

Answer ONLY using the expense JSON data below.
If question is unrelated to expenses, refuse politely.

Data:
${jsonEncode(payload)}
""";

    return await _callAI(userPrompt);
  }

  String _sanitizeAIText(String text) {
    return text
        .replaceAll('Â₹', '₹')
        .replaceAll('â‚¹', '₹')
        .replaceAll('’', "'")
        .replaceAll('‘', "'")
        .replaceAll('“', '"')
        .replaceAll('”', '"')
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u200B', '')
        .replaceAll('\u200C', '')
        .replaceAll('\u200D', '')
        .replaceAll('\uFEFF', '')
        .replaceAll('�', '');
  }

  Future<String> _callAI(String userPrompt) async {
    String? responseText;
    
    if (_apiKey.isNotEmpty) {
      responseText = await _callGroq(userPrompt);
    }
    
    // If Groq fails (returns error message) or key is empty, strictly fallback to Gemini
    if ((responseText == null || responseText.startsWith("AI failed") || responseText.startsWith("AI error")) && _geminiApiKey.isNotEmpty) {
      debugPrint("Groq unavailable or failed. Falling back to Gemini.");
      responseText = await _callGemini(userPrompt);
    }
    
    return responseText ?? "AI failed. Try again later.";
  }

  Future<String?> _callGroq(String userPrompt) async {
    try {
      final uri = Uri.parse("https://api.groq.com/openai/v1/chat/completions");

      final response = await http.post(
        uri,
        headers: {
          "Authorization": "Bearer $_apiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": _model,
          "temperature": 0.3,
          "max_tokens": 700,
          "messages": [
            {"role": "system", "content": _systemPrompt},
            {"role": "user", "content": userPrompt},
          ]
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("Groq error: ${response.statusCode} ${response.body}");
        return null;
      }

      final data = jsonDecode(response.body);
      final content = data["choices"][0]["message"]["content"];
      return _sanitizeAIText(content.toString().trim());
    } catch (e) {
      debugPrint("Groq AI exception: $e");
      return null;
    }
  }

  Future<String?> _callGemini(String userPrompt) async {
    try {
      final uri = Uri.parse("https://generativelanguage.googleapis.com/v1beta/openai/chat/completions");

      final response = await http.post(
        uri,
        headers: {
          "Authorization": "Bearer $_geminiApiKey",
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "model": "gemini-1.5-flash", 
          "temperature": 0.3,
          "max_tokens": 700,
          "messages": [
            {"role": "system", "content": _systemPrompt},
            {"role": "user", "content": userPrompt},
          ]
        }),
      );

      if (response.statusCode != 200) {
        debugPrint("Gemini error: ${response.statusCode} ${response.body}");
        return null;
      }

      final data = jsonDecode(response.body);
      final content = data["choices"][0]["message"]["content"];
      return _sanitizeAIText(content.toString().trim());
    } catch (e) {
      debugPrint("Gemini AI exception: $e");
      return null;
    }
  }
}
