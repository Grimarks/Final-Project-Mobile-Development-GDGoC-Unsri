import 'package:campusflow/core/notifications/notification_service.dart';
import 'package:campusflow/features/courses/data/course_repository.dart';
import 'package:campusflow/features/courses/domain/course.dart';
import 'package:campusflow/features/planner/data/planner_repository.dart';
import 'package:campusflow/features/planner/domain/plan.dart';
import 'package:campusflow/features/planner/domain/task_candidate.dart';
import 'package:campusflow/features/tasks/domain/task.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regresi: confirmTasks() bisa membuat course BARU di backend (lewat POST
/// /ai/chat/confirm-tasks), jadi Profile tab (courseListProvider) harus ikut di-invalidate
/// juga — bukan cuma Tasks tab — supaya course baru langsung terlihat tanpa restart app.
void main() {
  test('confirmCandidatesAndGenerate invalidates courseListProvider, not just taskListProvider',
      () async {
    final fakePlanner = _FakePlannerRepo();
    final fakeCourses = _FakeCourseRepo();

    final container = ProviderContainer(overrides: [
      plannerRepositoryProvider.overrideWithValue(fakePlanner),
      courseRepositoryProvider.overrideWithValue(fakeCourses),
    ]);
    addTearDown(container.dispose);

    await container.read(courseListProvider.future);
    expect(fakeCourses.fetchAllCallCount, 1);

    await container.read(chatControllerProvider.notifier).generatePlan();
    await container.read(chatControllerProvider.notifier).confirmCandidatesAndGenerate();

    // Dibaca lagi setelah confirm -> harus fetch ulang (invalidated), bukan cache lama.
    await container.read(courseListProvider.future);
    expect(fakeCourses.fetchAllCallCount, 2);
  });

  test('task dari chat yang punya deadline ikut dijadwalkan pengingatnya', () async {
    final due = DateTime.now().add(const Duration(days: 2));
    final notifications = _FakeNotifications();
    final container = ProviderContainer(overrides: [
      plannerRepositoryProvider.overrideWithValue(_FakePlannerRepo(dueDate: due)),
      courseRepositoryProvider.overrideWithValue(_FakeCourseRepo()),
      notificationServiceProvider.overrideWithValue(notifications),
    ]);
    addTearDown(container.dispose);

    await container.read(chatControllerProvider.notifier).generatePlan();
    await container.read(chatControllerProvider.notifier).confirmCandidatesAndGenerate();

    expect(notifications.scheduled, [(1, due)]);
  });
}

class _FakeNotifications extends NotificationService {
  final scheduled = <(int, DateTime)>[];

  @override
  Future<void> scheduleTaskDueReminder({
    required int taskId,
    required String title,
    required DateTime dueDate,
  }) async =>
      scheduled.add((taskId, dueDate));
}

class _FakePlannerRepo extends PlannerRepository {
  _FakePlannerRepo({this.dueDate}) : super(Dio());

  final DateTime? dueDate;

  @override
  Future<List<TaskCandidate>> extractTasksFromChat() async =>
      const [TaskCandidate(course: 'CS 301', title: 'Latihan soal')];

  @override
  Future<List<Task>> confirmTasks(List<TaskCandidate> tasks) async => [
        Task(
          id: 1,
          title: 'Latihan soal',
          type: 'assignment',
          difficulty: 'medium',
          status: 'not_started',
          progressPct: 0,
          priority: 'low',
          dueDate: dueDate,
        ),
      ];

  @override
  Future<StudyPlan> planFromChat() async => const StudyPlan(
        generatedBy: 'heuristic',
        availableHours: 3.5,
        openTaskCount: 1,
        blocks: [],
      );
}

class _FakeCourseRepo extends CourseRepository {
  _FakeCourseRepo() : super(Dio());

  int fetchAllCallCount = 0;

  @override
  Future<List<Course>> fetchAll() async {
    fetchAllCallCount++;
    return const [];
  }
}
