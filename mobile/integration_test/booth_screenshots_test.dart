// Bukan test fungsional — skrip buat ngambil ulang screenshot README/booth.
// App asli lawan backend lokal yg udah diisi `scripts/seed_demo.py`. Tiap layar
// siap, test nge-print `SHOT:<nama>` lalu nunggu beberapa detik; runner di host
// yg nangkep baris itu dan manggil `xcrun simctl io booted screenshot`.
//
//   flutter test integration_test/booth_screenshots_test.dart (atau booth_screenshots_planner_test.dart) -d <simulator> \
//     --dart-define=DEMO_PASSWORD=... | while read l; do ...; done
import 'package:campusflow/features/materials/presentation/quiz_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'booth_shot_helpers.dart';

const _announcement =
    '[Info Kelas] Assalamualaikum teman-teman, reminder ya:\n'
    '1. Kuis Basis Data Terdistribusi bab 4 hari Rabu depan jam 10.00\n'
    '2. Laporan praktikum Kecerdasan Buatan modul 5 dikumpul Jumat jam 17.00 lewat e-learning\n'
    '3. Presentasi SRS Rekayasa Perangkat Lunak Senin depan, siapkan slide per kelompok\n'
    'Makasih 🙏';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshot booth', (tester) async {
    await launchApp(tester);

    // --- Login ---------------------------------------------------------------
    await enterField(tester, 'Email', demoEmail);
    await enterField(tester, 'Password', demoPassword);
    await hideKeyboard(tester);
    await shot(tester, '01_login');
    await logIn(tester);
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
    await sleep(tester, 3000);
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
