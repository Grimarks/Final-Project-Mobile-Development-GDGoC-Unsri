import 'package:campusflow/features/planner/domain/task_candidate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TaskCandidate', () {
    test('fromJson mengurai course, title, type, difficulty', () {
      final candidate = TaskCandidate.fromJson({
        'course': 'CS 301',
        'title': 'Latihan soal',
        'type': 'assignment',
        'difficulty': 'hard',
        'due_date': null,
      });

      expect(candidate.course, 'CS 301');
      expect(candidate.title, 'Latihan soal');
      expect(candidate.type, 'assignment');
      expect(candidate.difficulty, 'hard');
      expect(candidate.dueDate, isNull);
    });

    test('due_date tanpa penanda zona waktu diperlakukan sebagai UTC, bukan local time', () {
      // Backend (TaskCandidate di app/schemas/ai.py) mengirim "YYYY-MM-DDT00:00:00" polos.
      final candidate = TaskCandidate.fromJson({
        'course': 'CS 301',
        'title': 'Ringkasan materi',
        'due_date': '2026-09-09T00:00:00',
      });

      expect(candidate.dueDate!.isUtc, isTrue);
      expect(candidate.dueDate, DateTime.utc(2026, 9, 9));
    });

    test('toJson mengirim due_date UTC dengan akhiran Z, tanggal tidak bergeser', () {
      final candidate = TaskCandidate.fromJson({
        'course': 'CS 301',
        'title': 'Ringkasan materi',
        'due_date': '2026-09-09T00:00:00',
      });

      expect(candidate.toJson()['due_date'], '2026-09-09T00:00:00.000Z');
    });

    test('type dan difficulty default kalau tidak ada di JSON', () {
      final candidate = TaskCandidate.fromJson({'course': 'CS 301', 'title': 'X'});
      expect(candidate.type, 'assignment');
      expect(candidate.difficulty, 'medium');
    });
  });
}
