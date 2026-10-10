// Helper bersama skrip screenshot booth (booth_screenshots_*_test.dart).
import 'package:campusflow/core/network/local_cache.dart';
import 'package:campusflow/core/widgets/brutal_bottom_nav.dart';
import 'package:campusflow/core/widgets/brutal_text_field.dart';
import 'package:campusflow/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const demoEmail = String.fromEnvironment('DEMO_EMAIL', defaultValue: 'demo@campusflow.app');
const demoPassword = String.fromEnvironment('DEMO_PASSWORD');

Future<void> sleep(WidgetTester tester, int ms) =>
    tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

// pumpAndSettle gak nungguin HTTP beneran, jadi polling manual sampai muncul
Future<void> waitFor(WidgetTester tester, Finder finder, {int seconds = 90}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) {
      await tester.pumpAndSettle();
      return;
    }
    await sleep(tester, 400);
  }
  throw TestFailure('Timeout nunggu $finder');
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await sleep(tester, 700);
  await tester.pump();
  // ignore: avoid_print
  print('SHOT:$name');
  await sleep(tester, 3000);
}

Future<void> enterField(WidgetTester tester, String label, String text) async {
  final field = find.byWidgetPredicate((w) => w is BrutalTextField && w.label == label);
  await tester.enterText(find.descendant(of: field.first, matching: find.byType(TextField)), text);
  await tester.pump();
}

Future<void> tapText(WidgetTester tester, String text) async {
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> tapNav(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(BrutalBottomNav), matching: find.text(label)));
  await tester.pumpAndSettle();
  await sleep(tester, 1500);
  await tester.pumpAndSettle();
}

Future<void> hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await sleep(tester, 500);
}

// mulai dari kondisi bersih (gak ada sesi lama / gerbang Face ID) di layar login
Future<void> launchApp(WidgetTester tester) async {
  expect(demoPassword, isNotEmpty, reason: 'isi --dart-define=DEMO_PASSWORD=...');
  await (await SharedPreferences.getInstance()).clear();
  await LocalCache.init();
  await tester.pumpWidget(const ProviderScope(child: CampusFlowApp()));
  await tester.pumpAndSettle();
}

Future<void> logIn(WidgetTester tester) async {
  await enterField(tester, 'Email', demoEmail);
  await enterField(tester, 'Password', demoPassword);
  await hideKeyboard(tester);
  await tapText(tester, 'LOG IN');
  await waitFor(tester, find.textContaining('Hi, '));
  await sleep(tester, 2500);
}
