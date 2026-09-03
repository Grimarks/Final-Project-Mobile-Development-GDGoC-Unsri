import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/brutal_chip.dart';
import '../../../core/widgets/priority_block.dart';
import '../data/task_repository.dart';
import '../domain/task.dart';
import 'add_task_sheet.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(taskListProvider);
    final filter = ref.watch(taskFilterProvider);
    final grouped = ref.watch(groupedTasksProvider);
    final visibleCount = ref.watch(filteredTasksProvider).length;

    return Scaffold(
      floatingActionButton: _AddTaskFab(
        onTap: () => showAddTaskSheet(context),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tasks', style: AppText.display(24)),
                  const SizedBox(height: 2),
                  Text('$visibleCount tasks',
                      style: AppText.body(12,
                          weight: FontWeight.w600, color: AppColors.inkMuted(0.55))),
                  const SizedBox(height: 16),
                  _FilterRow(
                    active: filter,
                    onSelect: (value) =>
                        ref.read(taskFilterProvider.notifier).state = value,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: tasksAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator(color: AppColors.ink)),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(error.toString(),
                        textAlign: TextAlign.center, style: AppText.body(13)),
                  ),
                ),
                data: (_) {
                  if (grouped.isEmpty) {
                    return Center(
                      child: Text('No tasks match this filter.',
                          style: AppText.body(13,
                              weight: FontWeight.w600,
                              color: AppColors.inkMuted(0.5))),
                    );
                  }
                  return RefreshIndicator(
                    color: AppColors.ink,
                    onRefresh: () async => ref.refresh(taskListProvider.future),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      children: [
                        for (final entry in grouped.entries) ...[
                          _CourseGroup(
                              courseName: entry.key, tasks: entry.value),
                          const SizedBox(height: 22),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.active, required this.onSelect});

  final String? active;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    // null = "All", selain itu mesti cocok sama status di backend
    const options = <String?>[null, ...TaskStatus.all];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final option in options) ...[
            BrutalChip(
              label: option == null ? 'All' : TaskStatus.label(option),
              selected: active == option,
              onTap: () => onSelect(option),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _CourseGroup extends StatelessWidget {
  const _CourseGroup({required this.courseName, required this.tasks});

  final String courseName;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final color = tasks.first.courseColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                border: Brutal.border(width: Brutal.borderWidthThin),
              ),
            ),
            const SizedBox(width: 8),
            Text(courseName, style: AppText.display(13, weight: FontWeight.w700)),
            const SizedBox(width: 8),
            Expanded(
                child: Container(height: 1, color: AppColors.ink.withOpacity(0.2))),
          ],
        ),
        const SizedBox(height: 10),
        for (final task in tasks) ...[
          _TaskCard(task: task),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BrutalCard(
      shadowOffset: 3,
      padding: const EdgeInsets.all(12),
      leftStripe: task.courseColor,
      onTap: () => ref.read(taskListProvider.notifier).toggleDone(task),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(13.5, weight: FontWeight.w700).copyWith(
                    decoration: task.isDone ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // chip tipe task, kotak kecil berbingkai
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.bg,
                        border: Brutal.border(width: 1.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Text(task.type.toUpperCase(),
                          style: AppText.body(9, weight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 6),
                    Text(task.dueLabel,
                        style: AppText.body(11,
                            weight: FontWeight.w600,
                            color: AppColors.inkMuted(0.55))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PriorityBlock(priority: task.priority, fontSize: 9),
        ],
      ),
    );
  }
}

// fab kotak 54x54 + shadow keras, bukan FAB bundar material
class _AddTaskFab extends StatelessWidget {
  const _AddTaskFab({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: Brutal.box(fill: AppColors.primary),
        child: Text('+',
            style: AppText.display(26,
                weight: FontWeight.w900, color: Colors.white)),
      ),
    );
  }
}
