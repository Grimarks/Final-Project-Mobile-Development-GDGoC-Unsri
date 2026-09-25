import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/local_cache.dart';
import '../../../core/notifications/notification_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/task.dart';

class TaskRepository {
  TaskRepository(this._dio);

  final Dio _dio;

  static const _cacheKey = 'tasks';

  // ambil dari server, kalo jaringan mati pake cache hive terakhir biar tetep
  // bisa dibaca offline
  Future<List<Task>> fetchAll() async {
    try {
      final resp = await _dio.get('/tasks');
      final list = resp.data as List<dynamic>;
      await LocalCache.putList(_cacheKey, list);
      return list.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      // cache cuma buat offline (gak ada respons server). kalo server bales
      // error (401 dll) jangan pura2 sukses pake data lama
      final cached = e.response == null ? LocalCache.getList(_cacheKey) : null;
      if (cached != null) {
        return cached.map((e) => Task.fromJson(e as Map<String, dynamic>)).toList();
      }
      throw toApiException(e);
    }
  }

  Future<List<Task>> fetchToday() async {
    try {
      final resp = await _dio.get('/tasks/today');
      return (resp.data as List<dynamic>)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<Task> create({
    required String title,
    int? courseId,
    String type = TaskType.assignment,
    String difficulty = Difficulty.medium,
    DateTime? dueDate,
  }) async {
    try {
      final resp = await _dio.post('/tasks', data: {
        'title': title,
        'course_id': courseId,
        'type': type,
        'difficulty': difficulty,
        'due_date': dueDate?.toUtc().toIso8601String(),
      });
      return Task.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<Task> update(int id, Map<String, dynamic> patch) async {
    try {
      final resp = await _dio.put('/tasks/$id', data: patch);
      return Task.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/tasks/$id');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final taskRepositoryProvider =
    Provider<TaskRepository>((ref) {
  ref.watch(currentUserIdProvider); // ganti akun -> data dimuat ulang
  return TaskRepository(ref.watch(apiClientProvider));
});

class TaskList extends AsyncNotifier<List<Task>> {
  @override
  Future<List<Task>> build() => ref.watch(taskRepositoryProvider).fetchAll();

  Future<void> add({
    required String title,
    int? courseId,
    required String type,
    required String difficulty,
    DateTime? dueDate,
  }) async {
    final created = await ref.read(taskRepositoryProvider).create(
          title: title,
          courseId: courseId,
          type: type,
          difficulty: difficulty,
          dueDate: dueDate,
        );
    if (created.dueDate != null) {
      await ref.read(notificationServiceProvider).scheduleTaskDueReminder(
            taskId: created.id,
            title: created.title,
            dueDate: created.dueDate!,
          );
    }
    ref.invalidateSelf();
    await future;
  }

  // centang/uncentang task dari kartu dashboard atau list
  Future<void> toggleDone(Task task) async {
    final next = task.isDone ? TaskStatus.notStarted : TaskStatus.done;
    if (next == TaskStatus.done) {
      HapticFeedback.mediumImpact(); // getar dikit pas task kelar
      // udah kelar, gaperlu diingetin soal deadline lagi
      await ref.read(notificationServiceProvider).cancelTaskDueReminder(task.id);
    }
    await ref.read(taskRepositoryProvider).update(task.id, {'status': next});
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(int id) async {
    await ref.read(notificationServiceProvider).cancelTaskDueReminder(id);
    await ref.read(taskRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final taskListProvider = AsyncNotifierProvider<TaskList, List<Task>>(TaskList.new);

// filter yg lagi aktif di Tasks (chip All/Not Started/dst)
final taskFilterProvider = StateProvider<String?>((ref) => null);

// task yg lolos filter, dipisah dari provider data biar ganti chip gak
// nge-trigger request http baru
final filteredTasksProvider = Provider<List<Task>>((ref) {
  final tasks = ref.watch(taskListProvider).valueOrNull ?? const <Task>[];
  final filter = ref.watch(taskFilterProvider);
  if (filter == null) return tasks;
  return tasks.where((t) => t.status == filter).toList();
});

// task dikelompokin per matkul
final groupedTasksProvider = Provider<Map<String, List<Task>>>((ref) {
  final grouped = <String, List<Task>>{};
  for (final task in ref.watch(filteredTasksProvider)) {
    grouped.putIfAbsent(task.courseName ?? 'No course', () => []).add(task);
  }
  return grouped;
});
