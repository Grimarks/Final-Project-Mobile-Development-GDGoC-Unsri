import 'package:campusflow/features/study_session/domain/study_session_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 9, 3);

  StudySessionRecord doneOn(DateTime day) =>
      StudySessionRecord(completed: true, plannedStart: day);

  test('kosong -> streak 0', () {
    expect(computeStreak(const [], now: today), 0);
  });

  test('sesi tidak completed tidak dihitung', () {
    final sessions = [
      StudySessionRecord(completed: false, plannedStart: today),
    ];
    expect(computeStreak(sessions, now: today), 0);
  });

  test('belajar hari ini saja -> streak 1', () {
    final sessions = [doneOn(today)];
    expect(computeStreak(sessions, now: today), 1);
  });

  test('3 hari berturut-turut sampai hari ini -> streak 3', () {
    final sessions = [
      doneOn(today),
      doneOn(today.subtract(const Duration(days: 1))),
      doneOn(today.subtract(const Duration(days: 2))),
    ];
    expect(computeStreak(sessions, now: today), 3);
  });

  test('belum belajar hari ini tapi kemarin jalan -> tetap dihitung dari kemarin', () {
    final sessions = [
      doneOn(today.subtract(const Duration(days: 1))),
      doneOn(today.subtract(const Duration(days: 2))),
    ];
    expect(computeStreak(sessions, now: today), 2);
  });

  test('ada jeda (bolong kemarin) -> streak putus, cuma hitung hari ini', () {
    final sessions = [
      doneOn(today),
      doneOn(today.subtract(const Duration(days: 2))), // kemarin bolong
    ];
    expect(computeStreak(sessions, now: today), 1);
  });

  test('tidak belajar hari ini maupun kemarin -> streak 0', () {
    final sessions = [doneOn(today.subtract(const Duration(days: 3)))];
    expect(computeStreak(sessions, now: today), 0);
  });

  test('beberapa sesi di hari yang sama tetap dihitung satu hari', () {
    final sessions = [
      doneOn(DateTime(2026, 9, 3, 9)),
      doneOn(DateTime(2026, 9, 3, 15)),
    ];
    expect(computeStreak(sessions, now: today), 1);
  });
}
