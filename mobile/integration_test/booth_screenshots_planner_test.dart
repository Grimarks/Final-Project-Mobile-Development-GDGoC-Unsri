// Lanjutan booth_screenshots_test.dart: register, form task, AI Planner (3 mode),
// Study session, dan dialog akun di Profile. Cara jalaninnya sama.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'booth_shot_helpers.dart';

const _adjustInstruction =
    'Malam ini aku cuma punya 1,5 jam, fokus ke UTS Rekayasa Perangkat Lunak dulu ya';

const _chatMessage =
    'Besok jam 8 pagi ada UTS RPL dan aku baru baca setengah materi, agak panik. '
    'Oh iya, barusan dosen Statistika kasih tugas baru: resume jurnal regresi, '
    'dikumpul Kamis jam 23.59. Malam ini aku free dari jam 7 sampai jam 10.';

Finder _byTypeName(String name) =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == name);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('screenshot booth: planner & study', (tester) async {
    await launchApp(tester);

    // --- Register (cuma diisi, gak dikirim) ----------------------------------
    await tapText(tester, 'REGISTER');
    await enterField(tester, 'Full name', 'Darrell Satriano');
    await enterField(tester, 'Email', 'darrell@student.unsri.ac.id');
    await enterField(tester, 'Password', 'CampusFlow2026!');
    await enterField(tester, 'Confirm password', 'CampusFlow2026!');
    await hideKeyboard(tester);
    await shot(tester, '02_register');
    await tester.tap(find.text('LOG IN').first);
    await tester.pumpAndSettle();
    await logIn(tester);

    // --- Form tambah task ----------------------------------------------------
    await tapNav(tester, 'TASKS');
    await tester.tap(find.text('+'));
    await tester.pumpAndSettle();
    await tapText(tester, 'STATISTIKA');
    await enterField(tester, 'Title', 'Rangkuman bab regresi linear');
    await hideKeyboard(tester);
    await shot(tester, '05_add_task_sheet');
    await tapText(tester, 'CANCEL');

    // --- AI Planner: generate acak ------------------------------------------
    await tapNav(tester, 'AI');
    await shot(tester, '06_ai_choice');
    await tapText(tester, 'Let me generate a random plan based on your free time');
    await shot(tester, '07_ai_random_ask');
    await tapText(tester, '3 hours');
    await shot(tester, '08_ai_random_reply');
    await tapText(tester, 'GENERATE PLAN');
    await waitFor(tester, find.text('ACCEPT PLAN'));
    await shot(tester, '09_ai_random_generated');
    await tapText(tester, 'ACCEPT PLAN');
    await waitFor(tester, find.textContaining('Hi, '));
    await sleep(tester, 3500);

    // --- AI Planner: adjust plan aktif ---------------------------------------
    await tapNav(tester, 'AI');
    await tapText(tester, 'Adjust my plan right now');
    await waitFor(tester, find.textContaining('Current plan'));
    await enterField(tester, 'Instruction', _adjustInstruction);
    await hideKeyboard(tester);
    await shot(tester, '10_ai_adjust_input');
    await tapText(tester, 'ADJUST PLAN');
    await waitFor(tester, find.text('ACCEPT PLAN'));
    await shot(tester, '11_ai_adjust_result');
    await tapText(tester, '← Back');

    // --- AI Planner: chat bebas -> review task -> plan -----------------------
    await tapText(tester, 'Talk to me');
    await waitFor(tester, find.textContaining('Tell me about your day'));
    await shot(tester, '12_ai_chat_empty');
    await enterField(tester, 'Message', _chatMessage);
    await tester.tap(_byTypeName('_SendButton'));
    await tester.pump();
    await waitFor(tester, find.text('GENERATE PLAN FROM THIS CHAT'));
    await hideKeyboard(tester);
    await shot(tester, '13_ai_chat_reply');
    await tapText(tester, 'GENERATE PLAN FROM THIS CHAT');
    await waitFor(
      tester,
      find.byWidgetPredicate((w) =>
          w is Text && (w.data == 'I found these in our chat' || w.data == 'ACCEPT PLAN')),
    );
    if (find.text('I found these in our chat').evaluate().isNotEmpty) {
      await shot(tester, '14_ai_chat_review');
      await tester.tap(find.textContaining(RegExp(r'^ADD \d+ & GENERATE PLAN')));
      await tester.pump();
      await waitFor(tester, find.text('ACCEPT PLAN'));
    }
    await shot(tester, '15_ai_chat_generated');
    await tapText(tester, 'ACCEPT PLAN');
    await waitFor(tester, find.textContaining('Hi, '));
    await sleep(tester, 3500);

    // --- Study session -------------------------------------------------------
    await tapNav(tester, 'STUDY');
    await shot(tester, '16_study_idle');
    await tapText(tester, 'START');
    await sleep(tester, 3200);
    await shot(tester, '17_study_running');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.fast_forward));
      await tester.pump();
    }
    await sleep(tester, 1200);
    await shot(tester, '18_study_fastforward');
    while (find.text('Session complete').evaluate().isEmpty) {
      await tester.tap(find.byIcon(Icons.fast_forward));
      await tester.pumpAndSettle();
    }
    await sleep(tester, 1500);
    await shot(tester, '19_study_feedback');
    await tapText(tester, 'NORMAL');
    await sleep(tester, 2500);
    await tapNav(tester, 'TASKS');
    await shot(tester, '20_tasks_after_session');

    // --- Dialog akun di Profile ---------------------------------------------
    await tapNav(tester, 'PROFILE');
    await tapText(tester, 'Edit profile');
    await shot(tester, '23_edit_profile');
    await tapText(tester, 'CANCEL');
    await tapText(tester, 'Change password');
    await shot(tester, '24_change_password');
    await tapText(tester, 'CANCEL');
  });
}
