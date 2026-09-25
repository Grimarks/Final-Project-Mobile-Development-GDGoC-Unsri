import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'token_storage.dart';

// url backend. simulator ios/web langsung localhost, emulator android
// mesti 10.0.2.2, kalau hp fisik override pake --dart-define=API_BASE_URL=...
String defaultBaseUrl() {
  const fromEnv = String.fromEnvironment('API_BASE_URL');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    return 'http://10.0.2.2:8000';
  }
  return 'http://127.0.0.1:8000';
}

// error yg udah dirapiin biar enak ditampilin ke user
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

ApiException toApiException(DioException e) {
  final data = e.response?.data;
  if (data is Map && data['detail'] != null) {
    final detail = data['detail'];
    if (detail is String) return ApiException(detail, statusCode: e.response?.statusCode);
    if (detail is List && detail.isNotEmpty) {
      final first = detail.first;
      if (first is Map && first['msg'] != null) {
        return ApiException(first['msg'].toString(), statusCode: e.response?.statusCode);
      }
    }
  }
  if (e.type == DioExceptionType.connectionError ||
      e.type == DioExceptionType.connectionTimeout) {
    return ApiException(
      'Tidak bisa terhubung ke server. Pastikan backend jalan dan API_BASE_URL benar.',
    );
  }
  return ApiException(e.message ?? 'Terjadi kesalahan jaringan',
      statusCode: e.response?.statusCode);
}

final tokenStorageProvider = Provider<TokenStorage>((ref) => TokenStorage());

final apiClientProvider = Provider<Dio>((ref) {
  final storage = ref.watch(tokenStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: defaultBaseUrl(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 60), // ai kadang lelet
      headers: {'Content-Type': 'application/json'},
    ),
  );

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        final serverUrl = await storage.readServerUrl();
        if (serverUrl != null) {
          options.baseUrl = serverUrl;
          dio.options.baseUrl = serverUrl; // biar refresh token ikut ke server yg sama
        }
        final token = await storage.readAccessToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        // /auth/me dll tetep boleh di-refresh, cuma endpoint yg ngeluarin token yg engga
        final path = error.requestOptions.path;
        final isTokenCall =
            path == '/auth/login' || path == '/auth/register' || path == '/auth/refresh';
        if (error.response?.statusCode != 401 || isTokenCall) {
          return handler.next(error);
        }

        // token expired -> coba refresh sekali, terus ulang requestnya
        final refresh = await storage.readRefreshToken();
        if (refresh == null) return handler.next(error);

        try {
          final fresh = Dio(BaseOptions(baseUrl: dio.options.baseUrl));
          final resp = await fresh.post('/auth/refresh', data: {'refresh_token': refresh});
          final newAccess = resp.data['access_token'] as String;
          await storage.saveTokens(
            access: newAccess,
            refresh: resp.data['refresh_token'] as String? ?? refresh,
          );

          final retry = error.requestOptions;
          retry.headers['Authorization'] = 'Bearer $newAccess';
          final result = await dio.fetch(retry);
          return handler.resolve(result);
        } on DioException catch (e) {
          // cuma hapus sesi kalo refresh token-nya beneran ditolak, bukan pas
          // server lagi mati/gak kejangkau (nanti Face ID ilang padahal sesi masih ok)
          if (e.response?.statusCode == 401) await storage.clear();
          return handler.next(error);
        }
      },
    ),
  );

  return dio;
});
