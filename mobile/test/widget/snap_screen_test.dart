import 'dart:typed_data';

import 'package:campusflow/core/network/api_client.dart';
import 'package:campusflow/core/notifications/notification_service.dart';
import 'package:campusflow/features/planner/data/planner_repository.dart';
import 'package:campusflow/features/planner/domain/task_candidate.dart';
import 'package:campusflow/features/snap/data/snap_repository.dart';
import 'package:campusflow/features/snap/presentation/snap_screen.dart';
import 'package:campusflow/features/tasks/domain/task.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Snap & Go lewat jalur "Paste text": AI (di-fake) ngusulin task, user bisa
/// uncheck, terus yg dicentang aja yg dikirim ke confirmTasks.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // dialog paste ngambil isi clipboard pas dibuka
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.getData') {
        return {'text': 'Kuis Basis Data Rabu depan, laporan modul 3 besok'};
      }
      return null;
    });
  });

  Widget wrap(_FakeSnapRepository snap, _FakePlannerRepository planner) => ProviderScope(
        overrides: [
          snapRepositoryProvider.overrideWithValue(snap),
          plannerRepositoryProvider.overrideWithValue(planner),
          notificationServiceProvider.overrideWithValue(_SilentNotifications()),
        ],
        child: const MaterialApp(home: SnapScreen()),
      );

  Future<void> pasteAndRead(WidgetTester tester) async {
    await tester.tap(find.text('Paste text'));
    await tester.pumpAndSettle();
    // isi clipboard langsung kepasang
    expect(find.text('Kuis Basis Data Rabu depan, laporan modul 3 besok'), findsOneWidget);
    await tester.tap(find.text('READ WITH AI'));
    await tester.pumpAndSettle();
  }

  testWidgets('paste teks -> review -> yg dicentang aja yang disimpan', (tester) async {
    final snap = _FakeSnapRepository();
    final planner = _FakePlannerRepository();
    await tester.pumpWidget(wrap(snap, planner));
    await pasteAndRead(tester);

    expect(snap.lastText, 'Kuis Basis Data Rabu depan, laporan modul 3 besok');
    expect(find.text('Found 2 tasks'), findsOneWidget);
    expect(find.text('Kuis normalisasi'), findsOneWidget);

    await tester.tap(find.text('Laporan modul 3')); // uncheck
    await tester.pumpAndSettle();
    expect(find.text('ADD 1 TO TASKS'), findsOneWidget);

    await tester.ensureVisible(find.text('ADD 1 TO TASKS'));
    await tester.tap(find.text('ADD 1 TO TASKS'));
    await tester.pumpAndSettle();
    expect(planner.confirmed.map((c) => c.title), ['Kuis normalisasi']);
  });

  testWidgets('AI tidak tersedia -> pesan error tampil, balik ke pilihan sumber',
      (tester) async {
    final snap = _FakeSnapRepository(error: ApiException('AI sedang tidak tersedia'));
    await tester.pumpWidget(wrap(snap, _FakePlannerRepository()));
    await pasteAndRead(tester);

    expect(find.text('AI sedang tidak tersedia'), findsOneWidget);
    expect(find.text('Take a photo'), findsOneWidget);
  });
}

class _FakeSnapRepository extends SnapRepository {
  _FakeSnapRepository({this.error}) : super(Dio());

  final Object? error;
  String? lastText;

  @override
  Future<List<TaskCandidate>> extract({Uint8List? image, String? text}) async {
    lastText = text;
    if (error != null) throw error!;
    return const [
      TaskCandidate(course: 'Basis Data', title: 'Kuis normalisasi', type: 'quiz'),
      TaskCandidate(course: 'Basis Data', title: 'Laporan modul 3'),
    ];
  }
}

class _FakePlannerRepository extends PlannerRepository {
  _FakePlannerRepository() : super(Dio());

  final confirmed = <TaskCandidate>[];

  @override
  Future<List<Task>> confirmTasks(List<TaskCandidate> tasks) async {
    confirmed.addAll(tasks);
    return [];
  }
}

class _SilentNotifications extends NotificationService {
  @override
  Future<void> scheduleTaskDueReminder({
    required int taskId,
    required String title,
    required DateTime dueDate,
  }) async {}
}
