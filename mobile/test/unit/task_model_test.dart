import 'package:campusflow/core/theme/colors.dart';
import 'package:campusflow/features/tasks/domain/task.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Task.fromJson', () {
    test('memetakan seluruh field dari respons backend', () {
      final task = Task.fromJson({
        'id': 1,
        'title': 'Problem Set 4',
        'type': 'assignment',
        'difficulty': 'hard',
        'status': 'not_started',
        'progress_pct': 25,
        'priority': 'high',
        'course_id': 3,
        'course_name': 'CS 301',
        'course_color': '#FF8A3D',
        'due_date': '2026-10-24T10:00:00Z',
      });

      expect(task.id, 1);
      expect(task.title, 'Problem Set 4');
      expect(task.priority, 'high');
      expect(task.courseName, 'CS 301');
      expect(task.courseColor, const Color(0xFFFF8A3D));
      expect(task.isDone, isFalse);
    });

    test('menerima task tanpa course dan tanpa deadline', () {
      final task = Task.fromJson({
        'id': 2,
        'title': 'Baca jurnal',
        'type': 'quiz',
        'difficulty': 'easy',
        'status': 'done',
        'progress_pct': 100,
        'priority': 'low',
        'course_id': null,
        'course_name': null,
        'course_color': null,
        'due_date': null,
      });

      expect(task.isDone, isTrue);
      expect(task.dueLabel, 'No deadline');
      expect(task.courseColor, AppColors.primary); // fallback warna
    });
  });

  group('dueLabel', () {
    String labelFor(DateTime due) => Task.fromJson({
          'id': 1,
          'title': 'x',
          'type': 'assignment',
          'difficulty': 'medium',
          'status': 'not_started',
          'progress_pct': 0,
          'priority': 'low',
          'due_date': due.toUtc().toIso8601String(),
        }).dueLabel;

    test('hari ini ditandai "Today"', () {
      final now = DateTime.now();
      expect(labelFor(DateTime(now.year, now.month, now.day, 18, 0)),
          startsWith('Today'));
    });

    test('besok ditandai "Tomorrow"', () {
      expect(labelFor(DateTime.now().add(const Duration(days: 1))), 'Tomorrow');
    });

    test('yang sudah lewat ditandai "Overdue"', () {
      expect(labelFor(DateTime.now().subtract(const Duration(days: 5))),
          startsWith('Overdue'));
    });
  });

  group('AppColors.fromHex', () {
    test('mengurai hex valid', () {
      expect(AppColors.fromHex('#4C6FFF'), const Color(0xFF4C6FFF));
      expect(AppColors.fromHex('3DDC84'), const Color(0xFF3DDC84));
    });

    test('jatuh ke fallback untuk input tidak valid', () {
      expect(AppColors.fromHex('bukan-warna'), AppColors.primary);
      expect(AppColors.fromHex(null), AppColors.primary);
    });

    test('toHex adalah kebalikan dari fromHex', () {
      expect(AppColors.toHex(const Color(0xFFFFD23F)), '#FFD23F');
    });
  });
}
