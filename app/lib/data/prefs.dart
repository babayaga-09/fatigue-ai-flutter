import 'package:shared_preferences/shared_preferences.dart';

abstract class Prefs {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class MemoryPrefs implements Prefs {
  final _values = <String, String>{};
  @override
  Future<String?> read(String key) async => _values[key];
  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

class DevicePrefs implements Prefs {
  @override
  Future<String?> read(String key) async => (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}
