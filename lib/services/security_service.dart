import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  // Use encryptedSharedPreferences on Android so reads always succeed.
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  static const String _passwordKey = 'admin_password';

  // Hard-coded recovery password — lets you reset the admin password
  // if it is ever forgotten without wiping the device.
  static const String recoveryPassword = 'dce_reset_26442';

  static const String _defaultPassword = 'dceadmin';

  /// Must be called once from main() before the app renders.
  static Future<void> initialize() async {
    final existing = await _storage.read(key: _passwordKey);
    if (existing == null || existing.isEmpty) {
      await _storage.write(key: _passwordKey, value: _defaultPassword);
    }
  }

  /// Returns true if [input] matches the stored admin password.
  static Future<bool> verifyPassword(String input) async {
    if (input.isEmpty) return false;
    final saved = await _storage.read(key: _passwordKey);
    // Guard against null (storage read failure) — fall back to default.
    return input == (saved ?? _defaultPassword);
  }

  /// Synchronous check for the recovery password.
  static bool verifyRecoveryPassword(String input) {
    return input == recoveryPassword;
  }

  /// Replaces the stored admin password.
  static Future<void> changePassword(String newPassword) async {
    await _storage.write(key: _passwordKey, value: newPassword);
  }

  /// Wipes the stored password so it resets to default on next initialize().
  /// Useful for debugging.
  static Future<void> resetToDefault() async {
    await _storage.write(key: _passwordKey, value: _defaultPassword);
  }
}
