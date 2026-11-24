import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeSettings extends ChangeNotifier {
  ThemeSettings({ThemeMode initialMode = ThemeMode.system})
    : _mode = initialMode;

  static const _key = 'appearance.themeMode';
  late final _storage = SharedPreferencesAsync();
  bool _disposed = false;
  Future<void> _writes = Future.value();
  ThemeMode _mode;
  ThemeMode get mode => _mode;

  static Future<ThemeMode> load() async {
    try {
      final name = await SharedPreferencesAsync().getString(_key);
      return ThemeMode.values.where((mode) => mode.name == name).firstOrNull ??
          ThemeMode.system;
    } catch (_) {
      return ThemeMode.system;
    }
  }

  Future<void> change(ThemeMode mode) {
    final write = _writes.then((_) async {
      await _storage.setString(_key, mode.name);
      _mode = mode;
      if (!_disposed) notifyListeners();
    });
    _writes = write.catchError((Object _) {});
    return write;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
