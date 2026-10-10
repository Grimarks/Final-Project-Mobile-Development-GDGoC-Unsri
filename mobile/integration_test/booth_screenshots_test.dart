// Bukan test fungsional — skrip buat ngambil ulang screenshot README/booth.
// App asli lawan backend lokal yg udah diisi `scripts/seed_demo.py`. Tiap layar
// siap, test nge-print `SHOT:<nama>` lalu nunggu beberapa detik; runner di host
// yg nangkep baris itu dan manggil `xcrun simctl io booted screenshot`.
//
//   flutter test integration_test/booth_screenshots_test.dart -d <simulator> \
//     --dart-define=DEMO_PASSWORD=... | while read l; do ...; done
import 'package:campusflow/core/network/local_cache.dart';
import 'package:campusflow/core/widgets/brutal_bottom_nav.dart';
import 'package:campusflow/core/widgets/brutal_text_field.dart';
import 'package:campusflow/features/materials/presentation/quiz_screen.dart';
import 'package:campusflow/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _email = String.fromEnvironment('DEMO_EMAIL', defaultValue: 'demo@campusflow.app');
const _password = String.fromEnvironment('DEMO_PASSWORD');

const _announcement =
    '[Info Kelas] Assalamualaikum teman-teman, reminder ya:\n'
    '1. Kuis Basis Data Terdistribusi bab 4 hari Rabu depan jam 10.00\n'
    '2. Laporan praktikum Kecerdasan Buatan modul 5 dikumpul Jumat jam 17.00 lewat e-learning\n'
    '3. Presentasi SRS Rekayasa Perangkat Lunak Senin depan, siapkan slide per kelompok\n'
    'Makasih 🙏';

Future<void> _sleep(WidgetTester tester, int ms) =>
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
    await _sleep(tester, 400);
  }
  throw TestFailure('Timeout nunggu $finder');
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  await _sleep(tester, 700);
  await tester.pump();
  // ignore: avoid_print
  print('SHOT:$name');
  await _sleep(tester, 3000);
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
  await _sleep(tester, 1500);
  await tester.pumpAndSettle();
}

Future<void> hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  await _sleep(tester, 500);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshot booth', (tester) async {
    expect(_password, isNotEmpty, reason: 'isi --dart-define=DEMO_PASSWORD=...');
    // mulai dari kondisi bersih: gak ada sesi lama / gerbang Face ID
    await (await SharedPreferences.getInstance()).clear();
    await LocalCache.init();
    await tester.pumpWidget(const ProviderScope(child: CampusFlowApp()));
    await tester.pumpAndSettle();

    // --- Login ---------------------------------------------------------------
    await enterField(tester, 'Email', _email);
    await enterField(tester, 'Password', _password);
    await hideKeyboard(tester);
    await shot(tester, '01_login');
    await tapText(tester, 'LOG IN');
    await waitFor(tester, find.textContaining('Hi, '));
    await _sleep(tester, 2500);
    await shot(tester, '03_home');

    // --- Tasks + menu aksi --------------------------------------------------
    await tapNav(tester, 'TASKS');
    await shot(tester, '04_tasks');
    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await shot(tester, '25_task_actions');
    await tapText(tester, 'EDIT TASK');
    await shot(tester, '26_edit_task');
    await tapText(tester, 'CANCEL');

    // --- Snap & Go (paste teks pengumuman -> AI -> review -> Tasks) ----------
    await tester.tap(find.byIcon(Icons.photo_camera_outlined).first);
    await tester.pumpAndSettle();
    await shot(tester, '27_snap_pick');
    await tapText(tester, 'Paste text');
    await enterField(tester, 'Announcement', _announcement);
    await hideKeyboard(tester);
    await shot(tester, '28_snap_paste');
    await tapText(tester, 'READ WITH AI');
    await waitFor(tester, find.textContaining(RegExp(r'^Found \d')));
    await shot(tester, '30_snap_review');
    await tester.tap(find.textContaining(RegExp(r'^ADD \d+ TO TASKS')));
    await tester.pump();
    await waitFor(tester, find.text('Tasks'));
    await shot(tester, '31_snap_added');
    await _sleep(tester, 3000);
    await tester.pumpAndSettle();

    // --- Profile -> Materials -> ringkasan & kuis ---------------------------
    await tapNav(tester, 'PROFILE');
    await shot(tester, '21_profile_full');
    await tapText(tester, 'Upload notes, get AI summaries & quizzes');
    await waitFor(tester, find.textContaining('Normalisasi'));
    await shot(tester, '22_materials');
    await tester.tap(find.textContaining('Normalisasi').first);
    await tester.pumpAndSettle();
    await shot(tester, '32_material_detail');
    await tapText(tester, 'SUMMARIZE');
    await waitFor(tester, find.text('KEY POINTS'));
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -500));
    await shot(tester, '33_material_summary');
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, 1500));
    await tester.pumpAndSettle();
    await tapText(tester, 'GENERATE QUIZ');
    await waitFor(tester, find.textContaining('QUESTION 1 OF'));
    await shot(tester, '34_quiz_question');

    // jawab semua soal pakai kunci jawaban dari quiz-nya sendiri
    final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen)).quiz;
    var index = 0;
    var first = true;
    while (find.textContaining(RegExp(r'^QUESTION \d+ OF')).evaluate().isNotEmpty) {
      final option = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_OptionTile');
      await tester.tap(option.at(quiz.questions[index++].correctIndex));
      await tester.pumpAndSettle();
      if (first) {
        await shot(tester, '35_quiz_answered');
        first = false;
      }
      final next = find.text('NEXT QUESTION');
      await tapText(tester, next.evaluate().isNotEmpty ? 'NEXT QUESTION' : 'SEE RESULTS');
    }
    await waitFor(tester, find.text('Quiz complete'));
    await shot(tester, '36_quiz_result');
  });
}
