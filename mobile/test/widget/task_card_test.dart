import 'package:campusflow/core/widgets/priority_block.dart';
import 'package:campusflow/features/tasks/data/task_repository.dart';
import 'package:campusflow/features/tasks/domain/task.dart';
import 'package:campusflow/features/tasks/presentation/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test ini merender TasksScreen dengan provider yang di-override,
/// jadi tidak ada panggilan HTTP sungguhan.
void main() {
  testWidgets('daftar task menampilkan judul, mata kuliah, dan blok prioritas',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskListProvider.overrideWith(_FakeTaskList.new),
        ],
        child: MaterialApp(home: const TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Problem Set 4'), findsOneWidget);
    expect(find.text('CS 301'), findsOneWidget);
    expect(find.byType(PriorityBlock), findsOneWidget);
    expect(find.text('HIGH'), findsOneWidget);
  });

  testWidgets('menampilkan jumlah task di header', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [taskListProvider.overrideWith(_FakeTaskList.new)],
        child: MaterialApp(home: const TasksScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 tasks'), findsOneWidget);
  });
}

class _FakeTaskList extends TaskList {
  @override
  Future<List<Task>> build() async => [
        Task.fromJson({
          'id': 1,
          'title': 'Problem Set 4',
          'type': 'assignment',
          'difficulty': 'hard',
          'status': 'not_started',
          'progress_pct': 0,
          'priority': 'high',
          'course_id': 1,
          'course_name': 'CS 301',
          'course_color': '#4C6FFF',
          'due_date': null,
        }),
      ];
}
