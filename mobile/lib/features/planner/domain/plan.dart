import 'package:flutter/material.dart';

import '../../../core/theme/colors.dart';

class PlanBlock {
  const PlanBlock({
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    this.taskId,
    this.course,
    this.colorHex = '#4C6FFF',
    this.reason,
  });

  final String title;
  final String startTime; // "09:00"
  final String endTime;
  final int durationMinutes;
  final int? taskId;
  final String? course;
  final String colorHex;
  final String? reason;

  Color get color => AppColors.fromHex(colorHex);

  String get timeLabel => '$startTime–$endTime';

  factory PlanBlock.fromJson(Map<String, dynamic> json) => PlanBlock(
        title: json['title'] as String,
        startTime: json['start_time'] as String,
        endTime: json['end_time'] as String,
        durationMinutes: json['duration_minutes'] as int,
        taskId: json['task_id'] as int?,
        course: json['course'] as String?,
        colorHex: json['color'] as String? ?? '#4C6FFF',
        reason: json['reason'] as String?,
      );
}

class StudyPlan {
  const StudyPlan({
    required this.generatedBy,
    required this.availableHours,
    required this.openTaskCount,
    required this.blocks,
  });

  // "groq" kalo dari LLM, "heuristic" kalo fallback lokal — ditampilin apa
  // adanya biar user tau asal jadwalnya
  final String generatedBy;
  final double availableHours;
  final int openTaskCount;
  final List<PlanBlock> blocks;

  factory StudyPlan.fromJson(Map<String, dynamic> json) => StudyPlan(
        generatedBy: json['generated_by'] as String,
        availableHours: (json['available_hours'] as num).toDouble(),
        openTaskCount: json['open_task_count'] as int,
        blocks: (json['blocks'] as List<dynamic>)
            .map((e) => PlanBlock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// hasil adjust plan: `plan` jadwal baru kalo `adjusted` true, atau jadwal lama
// apa adanya kalo groq gagal (liat `error`)
class AdjustPlanResult {
  const AdjustPlanResult({required this.plan, required this.adjusted, this.error});

  final StudyPlan plan;
  final bool adjusted;
  final String? error;

  factory AdjustPlanResult.fromJson(Map<String, dynamic> json) => AdjustPlanResult(
        plan: StudyPlan.fromJson(json),
        adjusted: json['adjusted'] as bool,
        error: json['error'] as String?,
      );
}
