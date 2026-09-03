import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';

import '../../../core/network/api_client.dart';

// wrapper tipis buat local_auth, cuma di sini yg nyentuh Face ID/Touch ID
// langsung biar gampang di-fake pas testing
class BiometricService {
  final _auth = LocalAuthentication();

  Future<bool> isSupported() async {
    try {
      return await _auth.isDeviceSupported() && await _auth.canCheckBiometrics;
    } catch (_) {
      return false; // simulator gaada Face ID atau apinya gaada
    }
  }

  Future<bool> authenticate({required String reason}) async {
    try {
      // biometricOnly false -> boleh fallback ke passcode kalo Face ID gagal mulu
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}

final biometricServiceProvider = Provider<BiometricService>((ref) => BiometricService());

// setting "login pake Face ID" punya user, kesimpen lokal per hp
class BiometricSetting extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.watch(tokenStorageProvider).isBiometricEnabled();

  Future<void> toggle(bool value) async {
    if (value) {
      final supported = await ref.read(biometricServiceProvider).isSupported();
      if (!supported) {
        throw Exception('Face ID/Touch ID tidak tersedia di perangkat ini');
      }
      final confirmed = await ref.read(biometricServiceProvider).authenticate(
            reason: 'Konfirmasi untuk mengaktifkan login Face ID',
          );
      if (!confirmed) {
        throw Exception('Verifikasi Face ID dibatalkan atau gagal');
      }
    }
    await ref.read(tokenStorageProvider).setBiometricEnabled(value);
    state = AsyncValue.data(value);
  }
}

final biometricSettingProvider =
    AsyncNotifierProvider<BiometricSetting, bool>(BiometricSetting.new);

// true kalo ada sesi + Face ID nyala -> LoginScreen munculin gerbang Face ID,
// bukan form email/password. autoDispose biar tiap balik ke login dihitung ulang
final biometricGateProvider = FutureProvider.autoDispose<bool>((ref) async {
  final storage = ref.watch(tokenStorageProvider);
  final hasToken = await storage.readAccessToken() != null;
  if (!hasToken) return false;
  return storage.isBiometricEnabled();
});
