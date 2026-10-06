import 'package:campusflow/core/notifications/notification_service.dart';
import 'package:campusflow/features/study_session/data/session_repository.dart';
import 'package:campusflow/features/study_session/domain/study_session_record.dart';
import 'package:campusflow/features/study_session/presentation/focus_session_controller.dart';
import 'package:campusflow/features/tasks/data/task_repository.dart';
import 'package:campusflow/features/tasks/domain/task.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sesi Pomodoro disimpan di provider (bukan State widget) dan sisa waktunya dihitung
/// dari jam selesai — jadi gak hilang pas pindah tab & gak molor pas app di-background.
void main() {
  late _FakeSessionRepository sessions;
  late ProviderContainer container;

  setUp(() {
    sessions = _FakeSessionRepository();
    container = ProviderContainer(overrides: [
      taskListProvider.overrideWith(_EmptyTaskList.new),
      sessionRepositoryProvider.overrideWithValue(sessions),
      notificationServiceProvider.overrideWithValue(_SilentNotifications()),
    ]);
  });
  tearDown(() => container.dispose());

  test('sisa waktu dihitung dari endsAt, bukan hitungan mundur per detik', () {
    final now = DateTime(2026, 10, 6, 9);
    final state = FocusSessionState(
      started: true,
      endsAt: now.add(const Duration(minutes: 10)),
    );
    // "app di-background" 4 menit: tanpa tick apa pun, sisa tetap akurat
    expect(state.remaining(now.add(const Duration(minutes: 4))), const Duration(minutes: 6));
    expect(state.remaining(now.add(const Duration(hours: 1))), Duration.zero);
  });

  test('pause membekukan sisa waktu, resume melanjutkan', () async {
    final ctrl = container.read(focusSessionProvider.notifier);
    await ctrl.start(null);
    expect(container.read(focusSessionProvider).running, isTrue);
    expect(container.read(focusSessionProvider).sessionId, 7);

    ctrl.pause();
    final paused = container.read(focusSessionProvider);
    expect(paused.running, isFalse);
    expect(paused.remaining().inMinutes, greaterThanOrEqualTo(24));

    ctrl.resume();
    expect(container.read(focusSessionProvider).running, isTrue);
  });

  test('fast forward sampai habis -> selesai, feedback kirim durasi penuh & reset', () async {
    final ctrl = container.read(focusSessionProvider.notifier);
    await ctrl.start(null);
    for (var i = 0; i < 5; i++) {
      ctrl.fastForward();
    }
    expect(container.read(focusSessionProvider).finished, isTrue);

    await ctrl.sendFeedback('easy');
    expect(sessions.completed, [(7, 'easy', 25)]);
    expect(container.read(focusSessionProvider).started, isFalse);
  });
}

class _EmptyTaskList extends TaskList {
  @override
  Future<List<Task>> build() async => [];
}

class _FakeSessionRepository extends SessionRepository {
  _FakeSessionRepository() : super(Dio());

  final completed = <(int, String, int)>[];

  @override
  Future<List<StudySessionRecord>> fetchAll() async => [];

  @override
  Future<int> start({int? taskId, DateTime? plannedStart, DateTime? plannedEnd}) async => 7;

  @override
  Future<void> complete(int sessionId, String feedback, int actualMinutes) async {
    completed.add((sessionId, feedback, actualMinutes));
  }
}

class _SilentNotifications extends NotificationService {
  @override
  Future<void> scheduleSessionEndReminder(Duration after) async {}

  @override
  Future<void> cancelSessionEndReminder() async {}
}
