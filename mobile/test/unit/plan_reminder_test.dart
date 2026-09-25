import 'package:campusflow/features/planner/data/planner_repository.dart';
import 'package:campusflow/features/planner/domain/plan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pengingat sesi plan dijadwalkan di jam mulai tiap blok hari itu', () {
    const plan = StudyPlan(
      generatedBy: 'random',
      availableHours: 2,
      openTaskCount: 0,
      blocks: [
        PlanBlock(title: 'Latihan soal Fisika', course: 'Fisika', startTime: '10:00',
            endTime: '11:00', durationMinutes: 60),
        PlanBlock(title: 'Baca materi Kimia', startTime: '11:15', endTime: '12:00',
            durationMinutes: 45),
      ],
    );

    final reminders = planSessionReminders(plan, DateTime(2026, 9, 26, 7));

    expect(reminders.map((r) => r.start), [
      DateTime(2026, 9, 26, 10, 0),
      DateTime(2026, 9, 26, 11, 15),
    ]);
    expect(reminders.first.timeLabel, '10:00–11:00 · Fisika');
    expect(reminders.last.title, 'Baca materi Kimia');
  });
}
