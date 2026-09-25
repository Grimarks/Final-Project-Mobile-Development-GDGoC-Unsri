import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/ai_tag.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/priority_block.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../planner/data/planner_repository.dart';
import '../../planner/domain/plan.dart';
import '../../study_session/data/session_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final tasksAsync = ref.watch(taskListProvider);
    final todayPlan = ref.watch(todayPlanProvider).valueOrNull;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppColors.ink,
          onRefresh: () {
            ref.invalidate(todayPlanProvider);
            return ref.refresh(taskListProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            children: [
              _Greeting(name: user?.firstName ?? 'there', initial: user?.initial ?? '?'),
              const SizedBox(height: 20),
              _AiBanner(
                openCount: tasksAsync.valueOrNull?.where((t) => !t.isDone).length ?? 0,
              ),
              const SizedBox(height: 20),
              _StatsRow(
                tasks: tasksAsync.valueOrNull ?? const [],
                streak: ref.watch(studyStreakProvider),
              ),
              if (todayPlan != null && todayPlan.blocks.isNotEmpty) ...[
                const SizedBox(height: 24),
                SectionHeader("Today's Plan · ${todayPlan.windowLabel ?? ''}"),
                const SizedBox(height: 12),
                for (final block in todayPlan.blocks) ...[
                  _PlanRow(block: block),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 24),
              const SectionHeader("Today's Focus"),
              const SizedBox(height: 12),
              tasksAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator(color: AppColors.ink)),
                ),
                error: (error, _) => _ErrorBox(message: error.toString()),
                data: (tasks) {
                  final focus = tasks.where((t) => !t.isDone).take(3).toList();
                  if (focus.isEmpty) return const _EmptyState();
                  return Column(
                    children: [
                      for (final task in focus) ...[
                        _FocusCard(task: task),
                        const SizedBox(height: 10),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name, required this.initial});

  final String name;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hi, $name', style: AppText.display(24)),
              const SizedBox(height: 2),
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: AppText.body(12,
                    weight: FontWeight.w600, color: AppColors.inkMuted(0.55)),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: Brutal.flat(fill: AppColors.accent),
          child: Text(initial, style: AppText.display(16)),
        ),
      ],
    );
  }
}

// banner kuning + pita "AI" miring, ini pintu masuk ke Plan My Day
class _AiBanner extends StatelessWidget {
  const _AiBanner({required this.openCount});

  final int openCount;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: Brutal.box(fill: AppColors.accent),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 6),
              Text(
                openCount == 0
                    ? 'No open tasks right now'
                    : 'You have $openCount open ${openCount == 1 ? 'task' : 'tasks'}',
                style: AppText.display(17),
              ),
              const SizedBox(height: 6),
              Text(
                "Let AI build today's study schedule based on your deadlines and available hours.",
                style: AppText.body(13, color: AppColors.inkMuted(0.75)),
              ),
              const SizedBox(height: 14),
              BrutalButton(
                label: 'Plan my day →',
                expand: false,
                fill: AppColors.ink,
                labelColor: AppColors.accent,
                shadowColor: AppColors.ink.withOpacity(0.35),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                onPressed: () => context.go('/planner'),
              ),
            ],
          ),
        ),
        const Positioned(left: 16, top: -14, child: AiTag(rotated: true)),
      ],
    );
  }
}

// satu sesi dari plan yg udah di-accept
class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.block});

  final PlanBlock block;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      shadowOffset: 3,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 92,
            child: Text(block.timeLabel, style: AppText.display(12, weight: FontWeight.w700)),
          ),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: block.color,
              border: Brutal.border(width: 1.5),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              block.course != null ? '${block.title} · ${block.course}' : block.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(12.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.tasks, required this.streak});

  final List<Task> tasks;
  final int streak;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final dueToday = tasks
        .where((t) =>
            !t.isDone &&
            t.dueDate != null &&
            t.dueDate!.isBefore(DateTime(now.year, now.month, now.day + 1)))
        .length;
    final done = tasks.where((t) => t.isDone).length;
    final pct = tasks.isEmpty ? 0 : ((done / tasks.length) * 100).round();

    Widget stat(String value, String label, Color color) => Expanded(
          child: BrutalCard(
            shadowOffset: 3,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Column(
              children: [
                Text(value,
                    style: AppText.display(24, weight: FontWeight.w900, color: color)),
                const SizedBox(height: 3),
                Text(
                  label.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: AppText.body(9.5,
                          weight: FontWeight.w700, color: AppColors.inkMuted(0.6))
                      .copyWith(letterSpacing: 0.3),
                ),
              ],
            ),
          ),
        );

    return Row(
      children: [
        stat('$dueToday', 'Due today', AppColors.danger),
        const SizedBox(width: 8),
        stat('$done', 'Completed', AppColors.success),
        const SizedBox(width: 8),
        stat('$pct%', 'Progress', AppColors.primary),
        const SizedBox(width: 8),
        stat('$streak', 'Day streak', AppColors.warning),
      ],
    );
  }
}

class _FocusCard extends ConsumerWidget {
  const _FocusCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BrutalCard(
      // tap kartunya (bukan checkbox) -> langsung mulai sesi fokus task ini
      onTap: () => context.go('/study?taskId=${task.id}'),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(taskListProvider.notifier).toggleDone(task),
            child: Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: task.isDone ? AppColors.success : AppColors.surface,
                border: Brutal.border(width: Brutal.borderWidthThin),
                borderRadius: BorderRadius.circular(3),
              ),
              child: task.isDone
                  ? const Icon(Icons.check, size: 14, color: AppColors.ink)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.display(14, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${task.courseName ?? 'No course'} · ${task.dueLabel}',
                  style: AppText.body(11.5,
                      weight: FontWeight.w600, color: AppColors.inkMuted(0.55)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          PriorityBlock(priority: task.priority),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Text('Add your first task to get started.',
            style: AppText.body(13,
                weight: FontWeight.w600, color: AppColors.inkMuted(0.5))),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return BrutalCard(
      fill: AppColors.danger,
      padding: const EdgeInsets.all(16),
      child: Text(message, style: AppText.body(13, weight: FontWeight.w600)),
    );
  }
}
