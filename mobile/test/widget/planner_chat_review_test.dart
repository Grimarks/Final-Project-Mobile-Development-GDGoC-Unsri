import 'package:campusflow/features/planner/data/planner_repository.dart';
import 'package:campusflow/features/planner/domain/chat_message.dart';
import 'package:campusflow/features/planner/domain/plan.dart';
import 'package:campusflow/features/planner/domain/task_candidate.dart';
import 'package:campusflow/features/planner/presentation/planner_screen.dart';
import 'package:campusflow/features/tasks/domain/task.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// "AI mengurus semuanya": setelah chat, tombol "Generate plan from this chat" harus
/// menampilkan panel review task/course yang diusulkan AI sebelum benar-benar disimpan.
void main() {
  testWidgets('menampilkan panel review lalu confirm memicu confirmTasks + planFromChat',
      (tester) async {
    final fake = _FakeChatRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [plannerRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Talk to me'));
    await tester.pumpAndSettle();

    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Type a message…',
    );
    await tester.enterText(field, 'Aku ada tugas CS 301');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();

    await tester.tap(find.text('GENERATE PLAN FROM THIS CHAT'));
    await tester.pumpAndSettle();

    expect(find.text('I found these in our chat'), findsOneWidget);
    expect(find.text('Latihan soal'), findsOneWidget);
    expect(find.text('Ringkasan materi'), findsOneWidget);

    // Uncheck satu kandidat sebelum konfirmasi.
    await tester.tap(find.text('Ringkasan materi'));
    await tester.pump();

    await tester.tap(find.textContaining('ADD 1 & GENERATE PLAN'));
    await tester.pumpAndSettle();

    expect(fake.confirmedTasks, hasLength(1));
    expect(fake.confirmedTasks!.single.title, 'Latihan soal');
    expect(fake.planFromChatCallCount, 1);
    // Hasil generate langsung ditampilkan, bukan balik ke panel review.
    expect(find.text('I found these in our chat'), findsNothing);
  });

  testWidgets('skip review tetap generate plan tanpa memanggil confirmTasks', (tester) async {
    final fake = _FakeChatRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [plannerRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Talk to me'));
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Type a message…',
    );
    await tester.enterText(field, 'Aku ada tugas CS 301');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GENERATE PLAN FROM THIS CHAT'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip, just use existing tasks'));
    await tester.pumpAndSettle();

    expect(fake.confirmedTasks, isNull);
    expect(fake.planFromChatCallCount, 1);
  });

  testWidgets('tanpa kandidat, generate langsung ke plan tanpa panel review', (tester) async {
    final fake = _FakeChatRepository()..candidatesToReturn = const [];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [plannerRepositoryProvider.overrideWithValue(fake)],
        child: const MaterialApp(home: PlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Talk to me'));
    await tester.pumpAndSettle();
    final field = find.byWidgetPredicate(
      (w) => w is TextField && w.decoration?.hintText == 'Type a message…',
    );
    await tester.enterText(field, 'halo');
    await tester.tap(find.byIcon(Icons.arrow_upward));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GENERATE PLAN FROM THIS CHAT'));
    await tester.pumpAndSettle();

    expect(find.text('I found these in our chat'), findsNothing);
    expect(fake.planFromChatCallCount, 1);
    expect(fake.confirmedTasks, isNull);
  });
}

class _FakeChatRepository extends PlannerRepository {
  _FakeChatRepository() : super(Dio());

  List<TaskCandidate> candidatesToReturn = const [
    TaskCandidate(course: 'CS 301', title: 'Latihan soal', difficulty: 'medium'),
    TaskCandidate(course: 'CS 301', title: 'Ringkasan materi', difficulty: 'easy'),
  ];

  List<TaskCandidate>? confirmedTasks;
  int planFromChatCallCount = 0;

  @override
  Future<List<ChatMessage>> chatHistory() async => [];

  @override
  Future<ChatReply> sendChatMessage(String message) async =>
      const ChatReply(reply: 'Oke, dicatat!', generatedBy: 'heuristic');

  @override
  Future<List<TaskCandidate>> extractTasksFromChat() async => candidatesToReturn;

  @override
  Future<List<Task>> confirmTasks(List<TaskCandidate> tasks) async {
    confirmedTasks = tasks;
    return [
      for (final t in tasks)
        Task(
          id: tasks.indexOf(t) + 1,
          title: t.title,
          type: t.type,
          difficulty: t.difficulty,
          status: 'not_started',
          progressPct: 0,
          priority: 'low',
        ),
    ];
  }

  @override
  Future<StudyPlan> planFromChat() async {
    planFromChatCallCount++;
    return const StudyPlan(
      generatedBy: 'heuristic',
      availableHours: 3.5,
      openTaskCount: 1,
      blocks: [],
    );
  }
}
