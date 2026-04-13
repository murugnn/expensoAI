import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:expenso/models/contact.dart';
import 'package:expenso/providers/auth_provider.dart';

class ContactProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;

  AuthProvider? _authProvider;

  List<Contact> _contacts = [];
  bool _isLoading = false;

  List<Contact> get contacts => _contacts;
  bool get isLoading => _isLoading;

  void updateAuth(AuthProvider auth) {
    final oldUserId = _authProvider?.currentUser?.id;
    final newUserId = auth.currentUser?.id;

    _authProvider = auth;

    if (oldUserId != newUserId) {
      _contacts = [];
      notifyListeners();
    }

    if (newUserId != null) {
      loadContacts();
    }
  }

  Future<void> loadContacts() async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _supabase
          .from('contacts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _contacts = rows.map((row) => Contact.fromMap(row)).toList();
    } catch (e) {
      debugPrint("loadContacts error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> addContact(String name, {String? phone, String? email}) async {
    final user = _authProvider?.currentUser;
    if (user == null) return "Not logged in";

    final cleanName = name.trim();
    if (cleanName.isEmpty) return "Name cannot be empty";

    try {
      debugPrint("🟢 Inserting contact for uid=${user.id}, name=$cleanName");

      final res = await _supabase.from('contacts').insert({
        'user_id': user.id,
        'name': cleanName,
        'phone': phone,
        'email': email,
      }).select();

      debugPrint("✅ Insert success: $res");

      await loadContacts();
      return null;
    } catch (e) {
      debugPrint("❌ addContact error REAL: $e");
      return "Failed: $e";
    }
  }

  Future<void> deleteContact(String id) async {
    final user = _authProvider?.currentUser;
    if (user == null) return;

    try {
      await _supabase
          .from('contacts')
          .delete()
          .eq('id', id)
          .eq('user_id', user.id);

      _contacts.removeWhere((c) => c.id == id);
      notifyListeners();
    } catch (e) {
      debugPrint("deleteContact error: $e");
    }
  }
}
