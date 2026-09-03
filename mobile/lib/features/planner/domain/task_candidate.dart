// task/course usulan AI dari chat, belom kesimpen sampe user konfirmasi
class TaskCandidate {
  const TaskCandidate({
    required this.course,
    required this.title,
    this.type = 'assignment',
    this.difficulty = 'medium',
    this.dueDate,
  });

  final String course;
  final String title;
  final String type;
  final String difficulty;
  final DateTime? dueDate;

  // backend ngirim "YYYY-MM-DD" polos tanpa zona waktu, dianggep UTC bukan local
  // time biar tanggalnya gak geser sehari pas di-parse terus dibalikin lg
  static DateTime _parseAsUtc(String iso) {
    final normalized = iso.endsWith('Z') || iso.contains('+') ? iso : '${iso}Z';
    return DateTime.parse(normalized);
  }

  factory TaskCandidate.fromJson(Map<String, dynamic> json) => TaskCandidate(
        course: json['course'] as String,
        title: json['title'] as String,
        type: json['type'] as String? ?? 'assignment',
        difficulty: json['difficulty'] as String? ?? 'medium',
        dueDate: json['due_date'] == null
            ? null
            : _parseAsUtc(json['due_date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'course': course,
        'title': title,
        'type': type,
        'difficulty': difficulty,
        'due_date': dueDate?.toUtc().toIso8601String(),
      };
}
