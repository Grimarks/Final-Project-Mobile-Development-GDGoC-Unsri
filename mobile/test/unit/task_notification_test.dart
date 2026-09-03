import 'package:campusflow/core/notifications/notification_service.dart';
import 'package:campusflow/features/tasks/data/task_repository.dart';
import 'package:campusflow/features/tasks/domain/task.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Task due reminders harus dijadwalkan/dibatalkan lewat NotificationService (di-fake
/// di sini, bukan plugin asli) pada titik yang tepat: dibuat dengan deadline, selesai,
/// atau dihapus.
void main() {
  // toggleDone() memicu HapticFeedback (platform channel) — butuh binding walau
  // test ini murni ProviderContainer, tanpa widget tree.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('add() dengan due date menjadwalkan pengingat', () async {
    final fakeTasks = _FakeTaskRepository();
    final fakeNotifs = _FakeNotificationService();
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(fakeTasks),
      notificationServiceProvider.overrideWithValue(fakeNotifs),
    ]);
    addTearDown(container.dispose);
    await container.read(taskListProvider.future);

    await container.read(taskListProvider.notifier).add(
          title: 'Baca modul',
          type: TaskType.assignment,
          difficulty: Difficulty.medium,
          dueDate: DateTime.now().add(const Duration(days: 1)),
        );

    expect(fakeNotifs.scheduledTaskIds, [fakeTasks.lastCreated!.id]);
  });

  test('add() tanpa due date tidak menjadwalkan apa pun', () async {
    final fakeTasks = _FakeTaskRepository();
    final fakeNotifs = _FakeNotificationService();
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(fakeTasks),
      notificationServiceProvider.overrideWithValue(fakeNotifs),
    ]);
    addTearDown(container.dispose);
    await container.read(taskListProvider.future);

    await container.read(taskListProvider.notifier).add(
          title: 'Baca modul',
          type: TaskType.assignment,
          difficulty: Difficulty.medium,
        );

    expect(fakeNotifs.scheduledTaskIds, isEmpty);
  });

  test('toggleDone ke done membatalkan pengingat task itu', () async {
    final fakeTasks = _FakeTaskRepository();
    final fakeNotifs = _FakeNotificationService();
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(fakeTasks),
      notificationServiceProvider.overrideWithValue(fakeNotifs),
    ]);
    addTearDown(container.dispose);
    await container.read(taskListProvider.future);

    const task = Task(
      id: 5,
      title: 'X',
      type: TaskType.assignment,
      difficulty: Difficulty.medium,
      status: TaskStatus.notStarted,
      progressPct: 0,
      priority: 'low',
    );
    await container.read(taskListProvider.notifier).toggleDone(task);

    expect(fakeNotifs.cancelledTaskIds, contains(5));
  });

  test('remove() membatalkan pengingat task itu', () async {
    final fakeTasks = _FakeTaskRepository();
    final fakeNotifs = _FakeNotificationService();
    final container = ProviderContainer(overrides: [
      taskRepositoryProvider.overrideWithValue(fakeTasks),
      notificationServiceProvider.overrideWithValue(fakeNotifs),
    ]);
    addTearDown(container.dispose);
    await container.read(taskListProvider.future);

    await container.read(taskListProvider.notifier).remove(7);

    expect(fakeNotifs.cancelledTaskIds, contains(7));
  });
}

class _FakeTaskRepository extends TaskRepository {
  _FakeTaskRepository() : super(Dio());

  Task? lastCreated;
  int _nextId = 1;

  @override
  Future<List<Task>> fetchAll() async => [];

  @override
  Future<Task> create({
    required String title,
    int? courseId,
    String type = TaskType.assignment,
    String difficulty = Difficulty.medium,
    DateTime? dueDate,
  }) async {
    final task = Task(
      id: _nextId++,
      title: title,
      type: type,
      difficulty: difficulty,
      status: TaskStatus.notStarted,
      progressPct: 0,
      priority: 'low',
      dueDate: dueDate,
    );
    lastCreated = task;
    return task;
  }

  @override
  Future<Task> update(int id, Map<String, dynamic> patch) async => Task(
        id: id,
        title: 'X',
        type: TaskType.assignment,
        difficulty: Difficulty.medium,
        status: patch['status'] as String? ?? TaskStatus.notStarted,
        progressPct: 0,
        priority: 'low',
      );

  @override
  Future<void> delete(int id) async {}
}

class _FakeNotificationService extends NotificationService {
  final scheduledTaskIds = <int>[];
  final cancelledTaskIds = <int>[];

  @override
  Future<void> scheduleTaskDueReminder({
    required int taskId,
    required String title,
    required DateTime dueDate,
  }) async {
    scheduledTaskIds.add(taskId);
  }

  @override
  Future<void> cancelTaskDueReminder(int taskId) async {
    cancelledTaskIds.add(taskId);
  }
}
