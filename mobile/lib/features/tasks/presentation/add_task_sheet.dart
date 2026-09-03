import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_chip.dart';
import '../../../core/widgets/brutal_text_field.dart';
import '../../courses/data/course_repository.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';

Future<void> showAddTaskSheet(BuildContext context) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withOpacity(0.55),
    builder: (_) => const _AddTaskDialog(),
  );
}

class _AddTaskDialog extends ConsumerStatefulWidget {
  const _AddTaskDialog();

  @override
  ConsumerState<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends ConsumerState<_AddTaskDialog> {
  final _title = TextEditingController();
  int? _courseId;
  String _type = TaskType.assignment;
  String _difficulty = Difficulty.medium;
  DateTime? _dueDate;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      // default jam 23:59 biar deadline "hari ini" gak langsung lewat
      setState(() => _dueDate = DateTime(picked.year, picked.month, picked.day, 23, 59));
    }
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Judul task belum diisi', style: AppText.body(13)),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(taskListProvider.notifier).add(
            title: _title.text.trim(),
            courseId: _courseId,
            type: _type,
            difficulty: _difficulty,
            dueDate: _dueDate,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(e.toString(), style: AppText.body(13)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(courseListProvider).valueOrNull ?? const [];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, maxHeight: 620),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: Brutal.box(shadowOffset: 6),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Add Task', style: AppText.display(19)),
                    const SizedBox(height: 16),
                    _FieldLabel('Course'),
                    if (courses.isEmpty)
                      Text(
                        'Belum ada mata kuliah — tambahkan dulu di tab Profile.',
                        style: AppText.body(11.5, color: AppColors.inkMuted(0.6)),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final course in courses)
                            BrutalChip(
                              label: course.name,
                              selected: _courseId == course.id,
                              onTap: () => setState(() => _courseId = course.id),
                            ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    BrutalTextField(
                        label: 'Title', controller: _title, hint: 'e.g. Read Chapter 5'),
                    const SizedBox(height: 14),
                    _FieldLabel('Type'),
                    Row(
                      children: [
                        for (final type in TaskType.all) ...[
                          BrutalChip(
                            label: type,
                            expand: true,
                            fontSize: 10.5,
                            selected: _type == type,
                            onTap: () => setState(() => _type = type),
                          ),
                          if (type != TaskType.all.last) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Due date'),
                    GestureDetector(
                      onTap: _pickDate,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: Brutal.flat(),
                        child: Text(
                          _dueDate == null
                              ? 'Select a date'
                              : DateFormat('EEE, MMM d yyyy').format(_dueDate!),
                          style: AppText.body(13,
                              color: _dueDate == null
                                  ? AppColors.inkMuted(0.4)
                                  : AppColors.ink),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _FieldLabel('Difficulty'),
                    Row(
                      children: [
                        for (final level in Difficulty.all) ...[
                          BrutalChip(
                            label: level,
                            expand: true,
                            selected: _difficulty == level,
                            onTap: () => setState(() => _difficulty = level),
                          ),
                          if (level != Difficulty.all.last) const SizedBox(width: 6),
                        ],
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: BrutalButton(
                            label: 'Cancel',
                            fill: AppColors.surface,
                            labelColor: AppColors.ink,
                            fontSize: 12,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: BrutalButton(
                            label: 'Save task',
                            fontSize: 12,
                            loading: _saving,
                            onPressed: _save,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text.toUpperCase(),
        style: AppText.body(11, weight: FontWeight.w700).copyWith(letterSpacing: 0.5),
      ),
    );
  }
}
