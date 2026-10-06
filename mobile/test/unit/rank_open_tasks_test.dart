import 'package:campusflow/features/tasks/domain/task.dart';
import 'package:flutter_test/flutter_test.dart';

Task _task(int id, String priority, {String status = 'not_started', String? due}) =>
    Task.fromJson({
      'id': id,
      'title': 'Task $id',
      'type': 'assignment',
      'difficulty': 'medium',
      'status': status,
      'progress_pct': 0,
      'priority': priority,
      'due_date': due,
    });

/// Today's Focus & tab Study wajib ngambil task paling penting, bukan id terkecil.
void main() {
  test('urut prioritas, lalu deadline terdekat, task done dibuang', () {
    final ranked = rankOpenTasks([
      _task(1, 'low'),
      _task(2, 'high', due: '2026-10-20T10:00:00Z'),
      _task(3, 'high', status: 'done'),
      _task(4, 'medium'),
      _task(5, 'high', due: '2026-10-10T10:00:00Z'),
      _task(6, 'high'),
    ]);
    expect(ranked.map((t) => t.id), [5, 2, 6, 4, 1]);
  });
}
