import 'package:campusflow/core/network/token_storage.dart';
import 'package:campusflow/features/auth/presentation/biometric_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('toggle(true) gagal kalau perangkat tidak mendukung biometrik, tidak tersimpan',
      () async {
    final container = ProviderContainer(overrides: [
      biometricServiceProvider.overrideWithValue(_FakeBiometricService(supported: false)),
    ]);
    addTearDown(container.dispose);
    await container.read(biometricSettingProvider.future);

    await expectLater(
      container.read(biometricSettingProvider.notifier).toggle(true),
      throwsA(isA<Exception>()),
    );
    expect(container.read(biometricSettingProvider).value, isFalse);
    expect(await TokenStorage().isBiometricEnabled(), isFalse);
  });

  test('toggle(true) gagal kalau verifikasi Face ID dibatalkan/gagal, tidak tersimpan',
      () async {
    final container = ProviderContainer(overrides: [
      biometricServiceProvider
          .overrideWithValue(_FakeBiometricService(supported: true, authResult: false)),
    ]);
    addTearDown(container.dispose);
    await container.read(biometricSettingProvider.future);

    await expectLater(
      container.read(biometricSettingProvider.notifier).toggle(true),
      throwsA(isA<Exception>()),
    );
    expect(container.read(biometricSettingProvider).value, isFalse);
  });

  test('toggle(true) sukses -> tersimpan; toggle(false) mematikan tanpa perlu verifikasi',
      () async {
    final container = ProviderContainer(overrides: [
      biometricServiceProvider
          .overrideWithValue(_FakeBiometricService(supported: true, authResult: true)),
    ]);
    addTearDown(container.dispose);
    await container.read(biometricSettingProvider.future);

    await container.read(biometricSettingProvider.notifier).toggle(true);
    expect(container.read(biometricSettingProvider).value, isTrue);
    expect(await TokenStorage().isBiometricEnabled(), isTrue);

    await container.read(biometricSettingProvider.notifier).toggle(false);
    expect(container.read(biometricSettingProvider).value, isFalse);
    expect(await TokenStorage().isBiometricEnabled(), isFalse);
  });
}

class _FakeBiometricService extends BiometricService {
  _FakeBiometricService({required this.supported, this.authResult = true});

  final bool supported;
  final bool authResult;

  @override
  Future<bool> isSupported() async => supported;

  @override
  Future<bool> authenticate({required String reason}) async => authResult;
}
