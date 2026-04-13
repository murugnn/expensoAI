import 'package:flutter_dotenv/flutter_dotenv.dart';

class SupabaseConfig {
  // These getters allow main.dart to access the keys directly
  static String get url {
    final val = dotenv.env['SUPABASE_URL'];
    if (val == null || val.isEmpty) {
      throw Exception("SUPABASE_URL is missing in .env");
    }
    return val;
  }

  static String get anonKey {
    final val = dotenv.env['SUPABASE_ANON_KEY'];
    if (val == null || val.isEmpty) {
      throw Exception("SUPABASE_ANON_KEY is missing in .env");
    }
    return val;
  }
}
