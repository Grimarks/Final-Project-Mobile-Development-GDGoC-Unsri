import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task.dart';
import 'focus_session_controller.dart';

const _brickCount = 8;

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key, this.taskId});

  // task spesifik yg mau dikerjain (dari tap kartu Home). null = ambil yg
  // prioritas tertinggi, kayak pas langsung buka tab Study
  final int? taskId;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

// state sesinya ada di focusSessionProvider (gak ilang pas pindah tab), layar
// ini cuma nge-refresh tampilan tiap detik
class _StudyScreenState extends ConsumerState<StudyScreen> with WidgetsBindingObserver {
  Timer? _ticker;

  FocusSessionController get _session => ref.read(focusSessionProvider.notifier);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!ref.read(focusSessionProvider).running) return;
      _session.tick();
      setState(() {}); // jam di layar diitung ulang dari endsAt
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // balik dari background: langsung cek, siapa tau sesinya udah kelar
    if (state == AppLifecycleState.resumed) _session.tick();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  // sesi lagi jalan -> task sesi itu. kalo belom mulai: dari tap kartu Home
  // (widget.taskId), kalo engga yg prioritas tertinggi
  Task? _pickTask() {
    final session = ref.read(focusSessionProvider);
    if (session.started) return session.task;
    final tasks = ref.read(taskListProvider).valueOrNull ?? const <Task>[];
    if (widget.taskId != null) {
      for (final t in tasks) {
        if (t.id == widget.taskId) return t;
      }
    }
    final open = rankOpenTasks(tasks);
    return open.isEmpty ? null : open.first;
  }

  Future<void> _sendFeedback(String feedback) async {
    await _session.sendFeedback(feedback);
    // kelar sesi -> lempar ke checklist Tasks biar bisa langsung dicentang
    if (mounted) context.go('/tasks');
  }

  String _clock(Duration remaining) {
    final total = remaining.inSeconds;
    final minutes = (total ~/ 60).toString().padLeft(2, '0');
    final seconds = (total % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: ref.watch(focusSessionProvider).finished ? _feedbackView() : _timerView(),
        ),
      ),
    );
  }

  Widget _timerView() {
    final session = ref.watch(focusSessionProvider);
    ref.watch(taskListProvider); // preview task ikut update pas list dimuat
    final task = _pickTask();
    final remaining = session.remaining();
    final total = pomodoroDuration.inSeconds;
    // progress-nya 8 balok terisi, bukan progress bar bulet
    final filled = ((total - remaining.inSeconds) / total * _brickCount).floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BrutalCard(
          shadowOffset: 3,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(width: 4, height: 22, color: task?.courseColor ?? AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  task == null
                      ? 'No open task — add one first'
                      : '${task.title} · ${task.courseName ?? 'No course'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.display(13, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 36),
        Text(_clock(remaining),
            textAlign: TextAlign.center,
            style: AppText.display(72, weight: FontWeight.w900)
                .copyWith(letterSpacing: -1)),
        const SizedBox(height: 6),
        Text('FOCUS SESSION',
            textAlign: TextAlign.center,
            style: AppText.body(11.5,
                    weight: FontWeight.w700, color: AppColors.inkMuted(0.55))
                .copyWith(letterSpacing: 1)),
        const SizedBox(height: 32),
        Row(
          children: [
            for (var i = 0; i < _brickCount; i++) ...[
              Expanded(
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: i < filled ? AppColors.primary : AppColors.surface,
                    border: Brutal.border(width: Brutal.borderWidthThin),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (i != _brickCount - 1) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 40),
        Row(
          children: [
            Expanded(
              child: BrutalButton(
                label: session.running ? 'Pause' : (session.started ? 'Resume' : 'Start'),
                fill: AppColors.surface,
                labelColor: AppColors.ink,
                fontSize: 12.5,
                onPressed: session.running
                    ? _session.pause
                    : (session.started ? _session.resume : () => _session.start(task)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BrutalButton(
                label: 'End session',
                fill: AppColors.danger,
                labelColor: AppColors.ink,
                fontSize: 12.5,
                // sebelum Start gak ada sesi yg bisa diakhiri
                onPressed: session.started ? _session.finish : null,
              ),
            ),
            const SizedBox(width: 10),
            _FastForwardButton(
              // nyala begitu sesi beneran dimulai, sebelum tekan Start ya mati
              enabled: session.started,
              onTap: _session.fastForward,
            ),
          ],
        ),
      ],
    );
  }

  Widget _feedbackView() {
    Widget option(String label, String value, Color color, IconData icon) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: BrutalCard(
            fill: color,
            padding: const EdgeInsets.all(15),
            onTap: () => _sendFeedback(value),
            child: Row(
              children: [
                Icon(icon, size: 28, color: AppColors.ink),
                const SizedBox(width: 14),
                Text(label, style: AppText.display(15, weight: FontWeight.w700)),
              ],
            ),
          ),
        );

    return Column(
      children: [
        const SizedBox(height: 20),
        Text('Session complete', style: AppText.display(21)),
        const SizedBox(height: 8),
        Text('How did that focus session feel?',
            style: AppText.body(13, color: AppColors.inkMuted(0.65))),
        const SizedBox(height: 26),
        option('EASY', 'easy', AppColors.success, Icons.sentiment_satisfied_outlined),
        option('NORMAL', 'normal', AppColors.accent, Icons.sentiment_neutral_outlined),
        option('DIFFICULT', 'hard', AppColors.danger,
            Icons.sentiment_dissatisfied_outlined),
      ],
    );
  }
}

// tombol kecil buat percepet sesi (demo/testing), abu2 & mati sblm sesi mulai
// biar gak bikin sesi kosong tanpa task/record backend
class _FastForwardButton extends StatelessWidget {
  const _FastForwardButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 46,
        height: 46,
        alignment: Alignment.center,
        decoration: Brutal.box(
          fill: enabled ? AppColors.accent : AppColors.surface,
          shadowOffset: enabled ? 3 : 0,
        ),
        child: Icon(Icons.fast_forward,
            size: 20, color: enabled ? AppColors.ink : AppColors.inkMuted(0.35)),
      ),
    );
  }
}
