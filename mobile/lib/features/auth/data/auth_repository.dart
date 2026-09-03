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

  Future<bool> hasSession() async => (await _storage.readAccessToken()) != null;

  // ambil user pake token yg udah kesimpen (tanpa password), dipake abis Face ID
  // sukses. token expired udah otomatis di-refresh di interceptor api_client.
  // null = sesi bener2 abis, mesti login manual lagi
  Future<AppUser?> restoreSession() async {
    if (!await hasSession()) return null;
    try {
      final resp = await _dio.get('/auth/me');
      return AppUser.fromJson(resp.data as Map<String, dynamic>);
    } on DioException {
      return null;
    }
  }

  Future<void> logout() => _storage.clear();

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
