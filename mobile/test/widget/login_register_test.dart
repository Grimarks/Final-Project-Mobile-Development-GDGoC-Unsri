import 'package:campusflow/core/network/token_storage.dart';
import 'package:campusflow/core/widgets/brutal_text_field.dart';
import 'package:campusflow/features/auth/data/auth_repository.dart';
import 'package:campusflow/features/auth/presentation/login_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registrasi TIDAK boleh auto-login — user harus login manual dengan kredensial
/// barunya setelah sukses daftar (permintaan produk).
void main() {
  Widget wrap(AuthRepository repo) => ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(repo)],
        child: const MaterialApp(home: LoginScreen()),
      );

  Future<void> goToRegisterTab(WidgetTester tester) async {
    await tester.tap(find.text('REGISTER'));
    await tester.pumpAndSettle();
  }

  Future<void> fillField(WidgetTester tester, String label, String text) async {
    final field = find.byWidgetPredicate((w) => w is BrutalTextField && w.label == label);
    await tester.enterText(find.descendant(of: field, matching: find.byType(TextField)), text);
  }

  testWidgets('password lemah ditolak sebelum memanggil register()', (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(wrap(fake));
    await goToRegisterTab(tester);

    await fillField(tester, 'Full name', 'Rel');
    await fillField(tester, 'Email', 'rel@unsri.ac.id');
    await fillField(tester, 'Password', 'password123'); // tanpa huruf besar & simbol
    await fillField(tester, 'Confirm password', 'password123');

    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(fake.registerCalled, isFalse);
    expect(find.textContaining('upper & lowercase'), findsOneWidget);
  });

  testWidgets('konfirmasi password tidak cocok ditolak sebelum memanggil register()',
      (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(wrap(fake));
    await goToRegisterTab(tester);

    await fillField(tester, 'Full name', 'Rel');
    await fillField(tester, 'Email', 'rel@unsri.ac.id');
    await fillField(tester, 'Password', 'Str0ng!Pass');
    await fillField(tester, 'Confirm password', 'Different!9');

    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(fake.registerCalled, isFalse);
    expect(find.textContaining('does not match'), findsOneWidget);
  });

  testWidgets('register sukses -> balik ke tab Log In, tidak auto-login', (tester) async {
    final fake = _FakeAuthRepository();
    await tester.pumpWidget(wrap(fake));
    await goToRegisterTab(tester);

    await fillField(tester, 'Full name', 'Rel');
    await fillField(tester, 'Email', 'rel@unsri.ac.id');
    await fillField(tester, 'Password', 'Str0ng!Pass');
    await fillField(tester, 'Confirm password', 'Str0ng!Pass');

    await tester.ensureVisible(find.text('CREATE ACCOUNT'));
    await tester.tap(find.text('CREATE ACCOUNT'));
    await tester.pumpAndSettle();

    expect(fake.registerCalled, isTrue);
    // Balik ke form Log In (field Full name & Confirm password hilang lagi).
    expect(find.text('FULL NAME'), findsNothing);
    expect(find.text('CONFIRM PASSWORD'), findsNothing);
    expect(find.textContaining('log in to continue'), findsOneWidget);
  });
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository() : super(Dio(), TokenStorage());

  bool registerCalled = false;

  @override
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    registerCalled = true;
  }
}
