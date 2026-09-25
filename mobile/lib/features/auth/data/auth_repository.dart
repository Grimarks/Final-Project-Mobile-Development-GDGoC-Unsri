import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/token_storage.dart';
import '../domain/user.dart';

// semua request http auth ngumpul di sini, widget gaperlu manggil dio langsung
class AuthRepository {
  AuthRepository(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  // register emang sengaja gak nyimpen token (gak auto-login), user disuruh
  // login manual pake akun barunya
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      await _dio.post('/auth/register', data: {
        'name': name,
        'email': email,
        'password': password,
      });
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<AppUser> login({required String email, required String password}) async {
    try {
      final resp = await _dio.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      return _handleAuthResponse(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<AppUser> _handleAuthResponse(Map<String, dynamic> body) async {
    final tokens = body['tokens'] as Map<String, dynamic>;
    await _storage.saveTokens(
      access: tokens['access_token'] as String,
      refresh: tokens['refresh_token'] as String,
    );
    return AppUser.fromJson(body['user'] as Map<String, dynamic>);
  }

  // patokannya refresh token, soalnya abis logout (Face ID nyala) access token
  // udah dihapus tapi refresh token masih disimpen
  Future<bool> hasSession() async => (await _storage.readRefreshToken()) != null;

  // ambil user pake token yg udah kesimpen (tanpa password), dipake abis Face ID
  // sukses. access token expired di-refresh otomatis di interceptor api_client.
  // null = sesi bener2 abis, mesti login manual lagi. server gak kejangkau ->
  // lempar ApiException, sesinya jangan dianggep abis
  Future<AppUser?> restoreSession() async {
    final refresh = await _storage.readRefreshToken();
    if (refresh == null) return null;
    try {
      if (await _storage.readAccessToken() == null) {
        final resp = await _dio.post('/auth/refresh', data: {'refresh_token': refresh});
        await _storage.saveTokens(
          access: resp.data['access_token'] as String,
          refresh: resp.data['refresh_token'] as String,
        );
      }
      final resp = await _dio.get('/auth/me');
      return AppUser.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.clear();
        return null;
      }
      throw toApiException(e);
    }
  }

  // Face ID nyala -> refresh token disimpen biar abis logout bisa masuk lagi
  // pake Face ID. mati -> hapus semua kayak biasa
  Future<void> logout() async {
    if (await _storage.isBiometricEnabled()) {
      await _storage.clearAccessToken();
    } else {
      await _storage.clear();
    }
  }

  Future<AppUser> updateProfile({required String name, String? email}) async {
    try {
      final resp = await _dio.put('/auth/me', data: {
        'name': name,
        if (email != null) 'email': email,
      });
      return AppUser.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _dio.post('/auth/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
      });
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider), ref.watch(tokenStorageProvider)),
);
