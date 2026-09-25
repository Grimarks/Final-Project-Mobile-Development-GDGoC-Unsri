import 'package:campusflow/core/network/token_storage.dart';
import 'package:campusflow/features/auth/data/auth_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final repo = AuthRepository(Dio(), TokenStorage());

  test('logout dengan Face ID aktif -> refresh token disimpan buat gerbang Face ID', () async {
    SharedPreferences.setMockInitialValues({
      'cf_access_token': 'access123',
      'cf_refresh_token': 'refresh123',
      'cf_biometric_enabled': true,
    });

    await repo.logout();

    expect(await TokenStorage().readAccessToken(), isNull);
    expect(await TokenStorage().readRefreshToken(), 'refresh123');
    expect(await repo.hasSession(), isTrue);
  });

  test('logout tanpa Face ID -> semua token dihapus', () async {
    SharedPreferences.setMockInitialValues({
      'cf_access_token': 'access123',
      'cf_refresh_token': 'refresh123',
    });

    await repo.logout();

    expect(await TokenStorage().readAccessToken(), isNull);
    expect(await TokenStorage().readRefreshToken(), isNull);
    expect(await repo.hasSession(), isFalse);
  });
}
