import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expenso/models/user.dart';

class UserService {
  static const String _userKey = 'current_user';

  Future<User?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userData = prefs.getString(_userKey);
      if (userData != null) {
        return User.fromJson(jsonDecode(userData));
      }
      return null;
    } catch (e) {
      debugPrint('Failed to get current user: $e');
      return null;
    }
  }

  Future<bool> saveUser(User user) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_userKey, jsonEncode(user.toJson()));
      return true;
    } catch (e) {
      debugPrint('Failed to save user: $e');
      return false;
    }
  }

  Future<bool> updateUser(User user) async {
    // For now, updating the user is the same as saving it.
    // If/when a backend is connected, this becomes the sync point.
    return saveUser(user);
  }

  Future<bool> login(String email, String password) async {
    try {
      final user = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: email.split('@')[0],
        email: email,
        avatar: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return await saveUser(user);
    } catch (e) {
      debugPrint('Failed to login: $e');
      return false;
    }
  }

  Future<bool> signup(String name, String email, String password) async {
    try {
      final user = User(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        email: email,
        avatar: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      return await saveUser(user);
    } catch (e) {
      debugPrint('Failed to signup: $e');
      return false;
    }
  }

  Future<bool> logout() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userKey);
      return true;
    } catch (e) {
      debugPrint('Failed to logout: $e');
      return false;
    }
  }
}
