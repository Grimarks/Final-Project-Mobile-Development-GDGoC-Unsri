import 'package:campusflow/core/network/api_client.dart';
import 'package:campusflow/features/planner/data/planner_repository.dart';
import 'package:campusflow/features/planner/domain/chat_message.dart';
import 'package:campusflow/features/planner/domain/plan.dart';
import 'package:campusflow/features/planner/presentation/planner_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test ini merender PlannerScreen dengan PlannerRepository di-override,
/// jadi tidak ada panggilan HTTP sungguhan (pola sama dengan task_card_test.dart).
void main() {
  Widget wrap() => ProviderScope(
        overrides: [plannerRepositoryProvider.overrideWithValue(_FakePlannerRepository())],
        child: const MaterialApp(home: PlannerScreen()),
      );

  testWidgets('menampilkan 3 kartu pilihan alur di layar awal', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('Let me generate a random plan based on your free time'), findsOneWidget);
    expect(find.text('Adjust my plan right now'), findsOneWidget);
    expect(find.text('Talk to me'), findsOneWidget);
  });

  testWidgets('tap kartu random memicu alur tanya jam luang', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Let me generate a random plan based on your free time'));
    await tester.pumpAndSettle();

    expect(find.textContaining('how many hours do you have free today'), findsOneWidget);
    // Kartu pilihan lain sudah tidak tampil lagi.
    expect(find.text('Talk to me'), findsNothing);
  });

  testWidgets('tap kartu adjust menampilkan form instruksi bebas', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adjust my plan right now'));
    await tester.pumpAndSettle();

    expect(find.text('What should change?'), findsOneWidget);
    expect(find.text('ADJUST PLAN'), findsOneWidget); // BrutalButton merender label kapital
  });

  testWidgets('tap kartu chat memuat histori kosong dan menampilkan input pesan',
      (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Talk to me'));
    await tester.pumpAndSettle();

    expect(find.byType(TextField), findsWidgets);
    expect(find.textContaining('Tell me about your day'), findsOneWidget);
  });

  testWidgets('back button dari mode manapun kembali ke 3 kartu pilihan', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adjust my plan right now'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('← Back'));
    await tester.pumpAndSettle();

    expect(find.text('Let me generate a random plan based on your free time'), findsOneWidget);
    expect(find.text('Adjust my plan right now'), findsOneWidget);
    expect(find.text('Talk to me'), findsOneWidget);
  });
}

class _FakePlannerRepository extends PlannerRepository {
  _FakePlannerRepository() : super(Dio());

  @override
  Future<List<ChatMessage>> chatHistory() async => [];

  @override
  Future<AdjustPlanResult> adjustPlan(String instruction) async {
    throw ApiException('Belum ada plan aktif — generate plan dulu', statusCode: 404);
  }
}
