import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/colors.dart';

// value ini mesti sama persis sama Literal di backend, kalo beda ke-reject 422
class TaskType {
  static const assignment = 'assignment';
  static const exam = 'exam';
  static const quiz = 'quiz';
  static const all = [assignment, exam, quiz];
}

class Difficulty {
  static const easy = 'easy';
  static const medium = 'medium';
  static const hard = 'hard';
  static const all = [easy, medium, hard];
}

class TaskStatus {
  static const notStarted = 'not_started';
  static const inProgress = 'in_progress';
  static const done = 'done';
  static const all = [notStarted, inProgress, done];

  static String label(String status) => switch (status) {
        notStarted => 'Not Started',
        inProgress => 'In Progress',
        done => 'Done',
        _ => status,
      };
}

class Task {
  const Task({
    required this.id,
    required this.title,
    required this.type,
    required this.difficulty,
    required this.status,
    required this.progressPct,
    required this.priority,
    this.courseId,
    this.courseName,
    this.courseColorHex,
    this.dueDate,
  });

  final int id;
  final String title;
  final String type;
  final String difficulty;
  final String status;
  final int progressPct;

  // dihitung backend, client gak itung ulang
  final String priority;

  final int? courseId;
  final String? courseName;
  final String? courseColorHex;
  final DateTime? dueDate;

  Color get courseColor => AppColors.fromHex(courseColorHex);

  bool get isDone => status == TaskStatus.done;

  // format tanggal relatif: "Today, 6:00 PM" / "Tomorrow" / "Fri, Oct 24"
  String get dueLabel {
    final due = dueDate;
    if (due == null) return 'No deadline';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(due.year, due.month, due.day);
    final diff = target.difference(today).inDays;

    if (diff == 0) return 'Today, ${DateFormat('h:mm a').format(due)}';
    if (diff == 1) return 'Tomorrow';
    if (diff == -1) return 'Yesterday';
    if (diff < 0) return 'Overdue · ${DateFormat('MMM d').format(due)}';
    if (diff <= 6) return DateFormat('EEE, MMM d').format(due);
    return DateFormat('MMM d').format(due);
  }

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'] as int,
        title: json['title'] as String,
        type: json['type'] as String,
        difficulty: json['difficulty'] as String,
        status: json['status'] as String,
        progressPct: json['progress_pct'] as int? ?? 0,
        priority: json['priority'] as String? ?? 'low',
        courseId: json['course_id'] as int?,
        courseName: json['course_name'] as String?,
        courseColorHex: json['course_color'] as String?,
        dueDate: json['due_date'] == null
            ? null
            : DateTime.tryParse(json['due_date'] as String)?.toLocal(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'type': type,
        'difficulty': difficulty,
        'status': status,
        'progress_pct': progressPct,
        'priority': priority,
        'course_id': courseId,
        'course_name': courseName,
        'course_color': courseColorHex,
        'due_date': dueDate?.toUtc().toIso8601String(),
      };
}
