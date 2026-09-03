import 'package:campusflow/features/auth/presentation/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gerbang Face ID hanya muncul kalau ADA sesi tersimpan DAN user pernah
/// mengaktifkan Face ID dari Profile — bukan default, dan bisa dilewati manual.
void main() {
  Widget wrap() => const ProviderScope(child: MaterialApp(home: LoginScreen()));

  testWidgets('tanpa sesi tersimpan -> langsung form email/password biasa', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('EMAIL'), findsOneWidget);
  });

  testWidgets('ada sesi tapi Face ID belum diaktifkan -> tetap form biasa', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cf_access_token': 'token123',
      'cf_refresh_token': 'refresh123',
    });
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('EMAIL'), findsOneWidget);
  });

  testWidgets('ada sesi + Face ID aktif -> tampilkan gerbang, bukan form', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cf_access_token': 'token123',
      'cf_refresh_token': 'refresh123',
      'cf_biometric_enabled': true,
    });
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('UNLOCK WITH FACE ID'), findsOneWidget);
    expect(find.text('EMAIL'), findsNothing);
  });

  testWidgets('"Use password instead" melewati gerbang ke form biasa', (tester) async {
    SharedPreferences.setMockInitialValues({
      'cf_access_token': 'token123',
      'cf_refresh_token': 'refresh123',
      'cf_biometric_enabled': true,
    });
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Use password instead'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsNothing);
    expect(find.text('EMAIL'), findsOneWidget);
  });
}
