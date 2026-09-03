import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/auth_repository.dart';
import '../domain/user.dart';

// state auth, null = belum login. dipake go_router buat redirect
class AuthController extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    return null;
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(
      () => ref.read(authRepositoryProvider).login(email: email, password: password),
    );
  }

  // register gak bikin auto-login, sukses -> state balik null biar tetep di /login
  Future<void> register(String name, String email, String password) async {
    state = const AsyncValue.loading();
    try {
      await ref
          .read(authRepositoryProvider)
          .register(name: name, email: email, password: password);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // balikin sesi dari token tersimpen (abis Face ID sukses), tanpa password.
  // true = berhasil (auto pindah ke /home), false = sesi abis, tetep di login
  Future<bool> restoreSession() async {
    final user = await ref.read(authRepositoryProvider).restoreSession();
    if (user == null) return false;
    state = AsyncValue.data(user);
    return true;
  }

  Future<void> logout() async {
    await ref.read(authRepositoryProvider).logout();
    state = const AsyncValue.data(null);
  }

  // error dilempar ke pemanggil aja biar dialognya yg nampilin, state gak diubah
  Future<void> updateProfile(String name, {String? email}) async {
    final updated =
        await ref.read(authRepositoryProvider).updateProfile(name: name, email: email);
    state = AsyncValue.data(updated);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return ref.read(authRepositoryProvider).changePassword(
          currentPassword: currentPassword,
          newPassword: newPassword,
        );
  }
}

final authControllerProvider =
    AsyncNotifierProvider<AuthController, AppUser?>(AuthController.new);

// shortcut buat cek lagi login apa engga
final isLoggedInProvider = Provider<bool>(
  (ref) => ref.watch(authControllerProvider).valueOrNull != null,
);
