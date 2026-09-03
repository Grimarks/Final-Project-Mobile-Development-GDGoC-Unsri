// riwayat sesi pomodoro, cuma field yg kepake buat hitung streak di Home
class StudySessionRecord {
  const StudySessionRecord({required this.completed, this.plannedStart});

  final bool completed;
  final DateTime? plannedStart;

  factory StudySessionRecord.fromJson(Map<String, dynamic> json) => StudySessionRecord(
        completed: json['completed'] as bool,
        plannedStart: json['planned_start'] == null
            ? null
            : DateTime.parse(json['planned_start'] as String).toLocal(),
      );
}

// hitung berapa hari beruntun ada minimal 1 sesi selesai. kalo belom belajar
// hari ini, itung dari kemarin dulu — biar streak gak keliatan putus pas pagi
int computeStreak(List<StudySessionRecord> sessions, {DateTime? now}) {
  final days = sessions
      .where((s) => s.completed && s.plannedStart != null)
      .map((s) => DateTime(s.plannedStart!.year, s.plannedStart!.month, s.plannedStart!.day))
      .toSet();
  if (days.isEmpty) return 0;

  final today = now ?? DateTime.now();
  var cursor = DateTime(today.year, today.month, today.day);
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}
