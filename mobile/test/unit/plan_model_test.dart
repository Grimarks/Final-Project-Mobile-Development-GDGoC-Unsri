import 'package:campusflow/features/planner/domain/plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planJson = {
    'generated_by': 'heuristic',
    'available_hours': 3.5,
    'open_task_count': 2,
    'blocks': [
      {
        'task_id': 1,
        'title': 'Problem Set 4',
        'course': 'CS 301',
        'color': '#4C6FFF',
        'start_time': '09:00',
        'end_time': '10:30',
        'duration_minutes': 90,
        'reason': 'prioritas high',
      },
    ],
  };

  test('StudyPlan.fromJson mengurai metadata dan blok', () {
    final plan = StudyPlan.fromJson(Map<String, dynamic>.from(planJson));

    expect(plan.generatedBy, 'heuristic');
    expect(plan.availableHours, 3.5);
    expect(plan.openTaskCount, 2);
    expect(plan.blocks, hasLength(1));
  });

  test('PlanBlock menyusun label waktu dan warna', () {
    final plan = StudyPlan.fromJson(Map<String, dynamic>.from(planJson));
    final block = plan.blocks.first;

    expect(block.timeLabel, '09:00–10:30');
    expect(block.durationMinutes, 90);
    expect(block.color, const Color(0xFF4C6FFF));
  });

  test('menerima plan kosong ketika tidak ada task terbuka', () {
    final plan = StudyPlan.fromJson({
      'generated_by': 'heuristic',
      'available_hours': 2.0,
      'open_task_count': 0,
      'blocks': <dynamic>[],
    });

    expect(plan.blocks, isEmpty);
  });

  group('AdjustPlanResult', () {
    test('fromJson mengurai plan baru saat penyesuaian berhasil', () {
      final result = AdjustPlanResult.fromJson({
        'generated_by': 'groq',
        'available_hours': 3.5,
        'open_task_count': 1,
        'blocks': <dynamic>[],
        'adjusted': true,
        'error': null,
      });

      expect(result.adjusted, isTrue);
      expect(result.error, isNull);
      expect(result.plan.generatedBy, 'groq');
    });

    test('fromJson mengurai plan lama + pesan error saat gagal', () {
      final result = AdjustPlanResult.fromJson({
        'generated_by': 'heuristic',
        'available_hours': 2.0,
        'open_task_count': 1,
        'blocks': <dynamic>[],
        'adjusted': false,
        'error': 'Groq gagal, jadwal lama tetap dipakai',
      });

      expect(result.adjusted, isFalse);
      expect(result.error, 'Groq gagal, jadwal lama tetap dipakai');
      expect(result.plan.generatedBy, 'heuristic');
    });
  });
}
