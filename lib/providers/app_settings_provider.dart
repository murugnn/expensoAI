import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:expenso/features/updater/services/update_service.dart';

class AppSettingsProvider extends ChangeNotifier {
  static const String _boxName = 'expenso_settings';
  late Box _box; // Reference to the open box

  String _currencySymbol = '₹';
  ThemeMode _themeMode = ThemeMode.system;
  String _themeModeString = 'system'; // 'light', 'dark', 'amoled_dark'
  bool _walkthroughEnabled = true;
  bool _isTutorialShown = false;
  bool _smsTrackingEnabled = true;
  String _vapiKey = '';

  List<String> _categories = [
    'Food',
    'Transport',
    'Shopping',
    'Bills',
    'Entertainment',
    'Health',
    'Other'
  ];
  List<String> _tags = ['Personal', 'Office', 'Urgent', 'Trip'];
  List<String> _contacts = [];
  List<String> _wallets = ['Cash', 'Bank Account', 'UPI'];

  // Getters
  String get currencySymbol => _currencySymbol;
  ThemeMode get themeMode => _themeMode;
  String get themeModeString => _themeModeString;
  bool get isAmoled => _themeModeString == 'amoled_dark';
  bool get walkthroughEnabled => _walkthroughEnabled;
  bool get isTutorialShown => _isTutorialShown;
  bool get smsTrackingEnabled => _smsTrackingEnabled;
  String get vapiKey => _vapiKey;
  List<String> get categories => _categories;
  List<String> get tags => _tags;
  List<String> get contacts => _contacts;
  List<String> get wallets => _wallets;
  
  bool _isUpdateAvailable = false;
  bool get isUpdateAvailable => _isUpdateAvailable;

  AppSettingsProvider() {
    // Box is guaranteed to be open by main.dart
    _box = Hive.box(_boxName);
    _readFromBox();
  }

  // isAmoled is now derived from _themeModeString getter above

  void _readFromBox() {
    _currencySymbol = _box.get('currency', defaultValue: '₹');
    _categories =
        List<String>.from(_box.get('categories', defaultValue: _categories));
    _tags = List<String>.from(_box.get('tags', defaultValue: _tags));
    _contacts = List<String>.from(_box.get('contacts', defaultValue: []));
    _wallets = List<String>.from(_box.get('wallets', defaultValue: _wallets));

    _themeModeString = _box.get('themeModeString', defaultValue: 'system');
    if (_themeModeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (_themeModeString == 'dark' || _themeModeString == 'amoled_dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }

    _walkthroughEnabled = _box.get('walkthrough', defaultValue: true);
    _isTutorialShown = _box.get('isTutorialShown', defaultValue: false);
    _smsTrackingEnabled = _box.get('smsTrackingEnabled', defaultValue: true);
    _vapiKey = _box.get('vapiKey', defaultValue: '');
    
    _ambientEffect = _box.get('ambientEffect', defaultValue: 'none');
    _migrateLegacySettings();
  }

  // ... (existing methods)

  // setAmoled removed; use setThemeModeString instead

  Future<void> setCurrency(String symbol) async {
    _currencySymbol = symbol;
    await _box.put('currency', symbol);
    notifyListeners();
  }

  Future<void> setThemeModeString(String mode) async {
    _themeModeString = mode;
    if (mode == 'light') {
      _themeMode = ThemeMode.light;
    } else if (mode == 'dark' || mode == 'amoled_dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    await _box.put('themeModeString', mode);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == ThemeMode.light) {
      await setThemeModeString('light');
    } else if (mode == ThemeMode.dark) {
      await setThemeModeString('dark');
    } else {
      await setThemeModeString('system');
    }
  }

  Future<void> setWalkthroughEnabled(bool enabled) async {
    _walkthroughEnabled = enabled;
    await _box.put('walkthrough', enabled);
    notifyListeners();
  }

  // --- List Helpers ---

  Future<void> _addToList(String key, List<String> list, String item) async {
    if (!list.contains(item)) {
      list.add(item);
      await _box.put(key, list);
      notifyListeners();
    }
  }

  Future<void> _removeFromList(
      String key, List<String> list, String item) async {
    list.remove(item);
    await _box.put(key, list);
    notifyListeners();
  }

  // --- Public List Methods ---

  Future<void> addCategory(String item) =>
      _addToList('categories', _categories, item);
  Future<void> removeCategory(String item) =>
      _removeFromList('categories', _categories, item);

  Future<void> addTag(String item) => _addToList('tags', _tags, item);
  Future<void> removeTag(String item) => _removeFromList('tags', _tags, item);

  Future<void> addContact(String item) =>
      _addToList('contacts', _contacts, item);
  Future<void> removeContact(String item) =>
      _removeFromList('contacts', _contacts, item);

  Future<void> addWallet(String item) => _addToList('wallets', _wallets, item);
  Future<void> removeWallet(String item) =>
      _removeFromList('wallets', _wallets, item);

  // --- Last Used Wallet ---
  String? get lastUsedWallet => _box.get('lastUsedWallet');

  Future<void> setLastUsedWallet(String wallet) async {
    await _box.put('lastUsedWallet', wallet);
    notifyListeners();
  }

  Future<void> setTutorialShown(bool shown) async {
    _isTutorialShown = shown;
    await _box.put('isTutorialShown', shown);
    notifyListeners();
  }

  Future<void> setSmsTrackingEnabled(bool enabled) async {
    _smsTrackingEnabled = enabled;
    await _box.put('smsTrackingEnabled', enabled);
    notifyListeners();
  }

  Future<void> setVapiKey(String key) async {
    _vapiKey = key;
    await _box.put('vapiKey', key);
    notifyListeners();
  }

  // --- Premium Features ---
  String _ambientEffect = 'none'; // 'none', 'snow', 'wave', 'light_sweep'
  String get ambientEffect => _ambientEffect;

  // Backward compatibility: If old boolean exists and is true, migrate to 'snow'
  void _migrateLegacySettings() {
    if (_box.containsKey('snowEffectEnabled')) {
      final oldSnow = _box.get('snowEffectEnabled', defaultValue: false);
      if (oldSnow == true) {
        _ambientEffect = 'snow';
        _box.put('ambientEffect', 'snow');
      }
      _box.delete('snowEffectEnabled'); // Cleanup
    }
  }

  Future<void> setAmbientEffect(String effect) async {
    _ambientEffect = effect;
    await _box.put('ambientEffect', effect);
    notifyListeners();
  }

  Future<void> checkUpdate() async {
    final available = await UpdateService.checkNewVersion();
    if (available != _isUpdateAvailable) {
      _isUpdateAvailable = available;
      notifyListeners();
    }
  }
}
