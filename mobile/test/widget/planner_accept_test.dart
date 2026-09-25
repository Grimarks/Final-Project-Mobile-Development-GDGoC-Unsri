import 'package:campusflow/core/notifications/notification_service.dart';
import 'package:campusflow/features/planner/data/planner_repository.dart';
import 'package:campusflow/features/planner/domain/plan.dart';
import 'package:campusflow/features/planner/presentation/planner_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Accept plan harus beneran nyimpen plan (nembak backend pake plan_id yg lagi
/// diliat), terus planner direset — bukan cuma pindah ke Home dan plan lama
/// masih bisa di-Adjust/Accept pas dibuka lagi.
void main() {
  testWidgets('accept memanggil backend dengan plan_id lalu planner kembali ke pilihan awal',
      (tester) async {
    final fake = _FakeRepo();
    final notifications = _FakeNotifications();
    final router = GoRouter(initialLocation: '/planner', routes: [
      GoRoute(path: '/planner', builder: (_, __) => const PlannerScreen()),
      GoRoute(
        path: '/home',
        builder: (context, __) => Scaffold(
          body: TextButton(
            onPressed: () => context.go('/planner'),
            child: const Text('HOME'),
          ),
        ),
      ),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        plannerRepositoryProvider.overrideWithValue(fake),
        notificationServiceProvider.overrideWithValue(notifications),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Let me generate a random plan based on your free time'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3 hours'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('GENERATE PLAN'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Free time 10:00–13:00'), findsOneWidget);
    expect(find.text('Latihan soal Matematika Dasar'), findsOneWidget);

    await tester.tap(find.text('ACCEPT PLAN'));
    await tester.pumpAndSettle();

    expect(fake.requestedHours, 3.0);
    expect(fake.acceptedPlanId, 7);
    // tiap sesi plan yg di-accept dijadwalin pengingatnya
    expect(notifications.sessions?.single.title, 'Latihan soal Matematika Dasar');
    expect(find.text('HOME'), findsOneWidget);

    // buka planner lagi -> balik ke kartu pilihan, bukan plan lama
    await tester.tap(find.text('HOME'));
    await tester.pumpAndSettle();
    expect(find.text('ACCEPT PLAN'), findsNothing);
    expect(find.text('Talk to me'), findsOneWidget);
  });
}

const _plan = StudyPlan(
  generatedBy: 'groq',
  availableHours: 3,
  openTaskCount: 1,
  startTime: '10:00',
  endTime: '13:00',
  planId: 7,
  blocks: [
    PlanBlock(
      taskId: null,
      title: 'Latihan soal Matematika Dasar',
      course: 'Matematika Dasar',
      startTime: '10:00',
      endTime: '11:00',
      durationMinutes: 60,
    ),
  ],
);

class _FakeNotifications extends NotificationService {
  List<PlanSessionReminder>? sessions;

  @override
  Future<void> schedulePlanSessionReminders(List<PlanSessionReminder> sessions) async {
    this.sessions = sessions;
  }
}

class _FakeRepo extends PlannerRepository {
  _FakeRepo() : super(Dio());

  int? acceptedPlanId;

  double? requestedHours;

  @override
  Future<StudyPlan> generateRandom({required double availableHours}) async {
    requestedHours = availableHours;
    return _plan;
  }

  @override
  Future<StudyPlan> acceptPlan(int planId) async {
    acceptedPlanId = planId;
    return _plan;
  }

  @override
  Future<StudyPlan?> todayPlan() async => null;
}
