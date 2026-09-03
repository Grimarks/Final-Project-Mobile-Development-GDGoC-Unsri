import 'package:shared_preferences/shared_preferences.dart';

// nyimpen token JWT. skrg masih pake SharedPreferences aja buat submission ini,
// kalo mau prod beneran ganti flutter_secure_storage — sengaja class-nya kecil
// biar gampang diganti tanpa ubah2 file lain
class TokenStorage {
  static const _accessKey = 'cf_access_token';
  static const _refreshKey = 'cf_refresh_token';
  static const _biometricKey = 'cf_biometric_enabled';

  Future<void> saveTokens({required String access, required String refresh}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, access);
    await prefs.setString(_refreshKey, refresh);
  }

  Future<String?> readAccessToken() async =>
      (await SharedPreferences.getInstance()).getString(_accessKey);

  Future<String?> readRefreshToken() async =>
      (await SharedPreferences.getInstance()).getString(_refreshKey);

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  // setting face id/touch id, dipisah dari token biar gak ikut kehapus pas logout
  Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricKey, enabled);
  }

  Future<bool> isBiometricEnabled() async =>
      (await SharedPreferences.getInstance()).getBool(_biometricKey) ?? false;
}
