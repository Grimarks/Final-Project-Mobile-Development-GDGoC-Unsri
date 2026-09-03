// Integration test end-to-end: jalanin app beneran (bukan widget test dengan
// provider palsu) lawan backend asli. Nyoba golden path: register -> login ->
// tambah matkul & task -> generate plan AI. Backend harus jalan lebih dulu di
// http://127.0.0.1:8000 (base URL default buat simulator iOS).
import 'package:campusflow/core/network/local_cache.dart';
import 'package:campusflow/core/widgets/brutal_bottom_nav.dart';
import 'package:campusflow/core/widgets/brutal_text_field.dart';
import 'package:campusflow/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

Future<void> enterField(WidgetTester tester, String label, String text) async {
  final field = find.byWidgetPredicate((w) => w is BrutalTextField && w.label == label);
  await tester.enterText(find.descendant(of: field.first, matching: find.byType(TextField)), text);
}

Future<void> tapButton(WidgetTester tester, String label) async {
  // .last soalnya beberapa layar punya tab/label yang teksnya sama persis
  // dengan tombolnya sendiri (mis. tab "LOG IN" vs tombol submit "Log in").
  await tester.tap(find.text(label.toUpperCase()).last);
  await tester.pumpAndSettle();
}

Future<void> tapNav(WidgetTester tester, String label) async {
  // scoped ke BrutalBottomNav soalnya "AI" juga muncul di AiTag badge
  await tester.tap(find.descendant(of: find.byType(BrutalBottomNav), matching: find.text(label)));
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('register, login, tambah matkul & task, generate plan AI', (tester) async {
    await LocalCache.init();
    await tester.pumpWidget(const ProviderScope(child: CampusFlowApp()));
    await tester.pumpAndSettle();

    final stamp = DateTime.now().millisecondsSinceEpoch;
    final email = 'itest_$stamp@unsri.ac.id';
    const password = 'Password123!';

    // --- Register (gak auto-login, harus login manual sesudahnya) -------------
    await tester.tap(find.text('REGISTER'));
    await tester.pumpAndSettle();
    await enterField(tester, 'Full name', 'Integration Tester');
    await enterField(tester, 'Email', email);
    await enterField(tester, 'Password', password);
    await enterField(tester, 'Confirm password', password);
    await tapButton(tester, 'Create account');
    await tester.pumpAndSettle();

    expect(find.text('LOG IN'), findsWidgets, reason: 'harusnya balik ke tab Log In setelah register');

    // --- Login ------------------------------------------------------------------
    await enterField(tester, 'Email', email);
    await enterField(tester, 'Password', password);
    await tapButton(tester, 'Log in');
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Hi, Integration'), findsOneWidget);

    // --- Tambah matkul ------------------------------------------------------------
    await tapNav(tester, 'PROFILE');
    await tester.tap(find.text('+ Add course'));
    await tester.pumpAndSettle();
    await enterField(tester, 'Name', 'CS 301');
    await tapButton(tester, 'Save course');
    expect(find.text('CS 301'), findsOneWidget);

    // --- Tambah task, cek muncul di Tasks & Home ------------------------------
    await tapNav(tester, 'TASKS');
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CS 301'));
    await tester.pump();
    await enterField(tester, 'Title', 'Integration Test Task');
    await tapButton(tester, 'Save task');

    expect(find.text('Integration Test Task'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tapNav(tester, 'HOME');
    expect(find.text('Integration Test Task'), findsOneWidget);

    // --- Generate plan AI dari opsi random -----------------------------------
    await tapNav(tester, 'AI');
    await tester.tap(find.textContaining('random plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Only 2 hours today'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Generate plan');

    var settled = false;
    for (var i = 0; i < 60 && !settled; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      settled = find.textContaining('open tasks').evaluate().isNotEmpty;
    }
    expect(settled, isTrue, reason: 'plan AI harus selesai ke-generate dalam 30 detik');
    expect(find.text('Integration Test Task'), findsOneWidget,
        reason: 'task yang baru dibuat harus ikut kejadwal');
  });
}
