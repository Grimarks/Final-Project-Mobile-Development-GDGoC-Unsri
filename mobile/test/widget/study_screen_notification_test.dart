import 'package:campusflow/core/notifications/notification_service.dart';
import 'package:campusflow/features/study_session/data/session_repository.dart';
import 'package:campusflow/features/study_session/domain/study_session_record.dart';
import 'package:campusflow/features/study_session/presentation/study_screen.dart';
import 'package:campusflow/features/tasks/data/task_repository.dart';
import 'package:campusflow/features/tasks/domain/task.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sesi Pomodoro menjadwalkan pengingat "selesai" di Start dan membatalkannya begitu
/// sesi benar-benar selesai (End session / Fast forward / habis alami) — supaya user
/// yang masih di app tidak dapat notifikasi dobel dengan layar feedback yang sudah tampil.
void main() {
  Widget wrap(_FakeNotificationService notifs) => ProviderScope(
        overrides: [
          taskListProvider.overrideWith(_EmptyTaskList.new),
          sessionRepositoryProvider.overrideWithValue(_FakeSessionRepository()),
          notificationServiceProvider.overrideWithValue(notifs),
        ],
        child: const MaterialApp(home: StudyScreen()),
      );

  testWidgets('Start menjadwalkan pengingat, End session membatalkannya', (tester) async {
    final notifs = _FakeNotificationService();
    await tester.pumpWidget(wrap(notifs));
    await tester.pumpAndSettle();

    await tester.tap(find.text('START'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(notifs.scheduledCount, 1);
    expect(notifs.cancelledCount, 0);

    await tester.tap(find.text('END SESSION'));
    await tester.pumpAndSettle();
    expect(notifs.cancelledCount, 1);
  });
}

class _EmptyTaskList extends TaskList {
  @override
  Future<List<Task>> build() async => [];
}

class _FakeSessionRepository extends SessionRepository {
  _FakeSessionRepository() : super(Dio());

  @override
  Future<List<StudySessionRecord>> fetchAll() async => [];

  @override
  Future<int> start({int? taskId, DateTime? plannedStart, DateTime? plannedEnd}) async => 1;

  @override
  Future<void> complete(int sessionId, String feedback, int actualMinutes) async {}
}

class _FakeNotificationService extends NotificationService {
  int scheduledCount = 0;
  int cancelledCount = 0;

  @override
  Future<void> scheduleSessionEndReminder(Duration after) async {
    scheduledCount++;
  }

  @override
  Future<void> cancelSessionEndReminder() async {
    cancelledCount++;
  }
}
