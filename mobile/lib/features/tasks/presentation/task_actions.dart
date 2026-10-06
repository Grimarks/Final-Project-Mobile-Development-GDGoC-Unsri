import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_button.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import 'add_task_sheet.dart';

void _snack(BuildContext context, String message, {Color? color, SnackBarAction? action}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: color ?? AppColors.ink,
        content: Text(message,
            style: AppText.body(13, color: color == null ? AppColors.surface : AppColors.ink)),
        action: action,
      ),
    );
}

// centang/uncentang + snackbar UNDO, biar salah tap gak permanen
Future<void> toggleTaskWithUndo(BuildContext context, WidgetRef ref, Task task) async {
  final notifier = ref.read(taskListProvider.notifier);
  try {
    await notifier.toggleDone(task);
  } catch (e) {
    if (context.mounted) _snack(context, e.toString(), color: AppColors.danger);
    return;
  }
  if (!context.mounted) return;
  _snack(
    context,
    task.isDone ? '"${task.title}" dibuka lagi' : '"${task.title}" selesai',
    action: SnackBarAction(
      label: 'UNDO',
      textColor: AppColors.accent,
      // toggle lagi pake status setelah toggle pertama, jadi balik ke semula
      onPressed: () => notifier
          .toggleDone(Task.fromJson({
            ...task.toJson(),
            'status': task.isDone ? TaskStatus.notStarted : TaskStatus.done,
          }))
          .catchError((_) {}),
    ),
  );
}

// menu titik tiga di kartu task: edit / hapus
Future<void> showTaskActions(BuildContext context, WidgetRef ref, Task task) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: Brutal.box(shadowOffset: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.display(16, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            BrutalButton(
              label: 'Edit task',
              fill: AppColors.surface,
              labelColor: AppColors.ink,
              fontSize: 12,
              onPressed: () => Navigator.of(sheetContext).pop('edit'),
            ),
            const SizedBox(height: 10),
            BrutalButton(
              label: 'Delete task',
              fill: AppColors.danger,
              fontSize: 12,
              onPressed: () => Navigator.of(sheetContext).pop('delete'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted) return;
  if (action == 'edit') {
    await showAddTaskSheet(context, task: task);
  } else if (action == 'delete') {
    await _confirmDelete(context, ref, task);
  }
}

Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Task task) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: AppColors.ink.withOpacity(0.55),
    builder: (dialogContext) => Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: Brutal.box(shadowOffset: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Delete task?', style: AppText.display(19)),
                  const SizedBox(height: 12),
                  Text('"${task.title}" will be deleted permanently.',
                      style: AppText.body(12.5,
                          weight: FontWeight.w600, color: AppColors.inkMuted(0.65))),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: BrutalButton(
                          label: 'Cancel',
                          fill: AppColors.surface,
                          labelColor: AppColors.ink,
                          fontSize: 12,
                          onPressed: () => Navigator.of(dialogContext).pop(false),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: BrutalButton(
                          label: 'Delete',
                          fill: AppColors.danger,
                          fontSize: 12,
                          onPressed: () => Navigator.of(dialogContext).pop(true),
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
  if (confirmed != true) return;
  try {
    await ref.read(taskListProvider.notifier).remove(task.id);
  } catch (e) {
    if (context.mounted) _snack(context, e.toString(), color: AppColors.danger);
  }
}
