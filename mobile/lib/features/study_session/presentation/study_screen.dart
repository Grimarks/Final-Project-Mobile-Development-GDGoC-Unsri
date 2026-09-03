import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task.dart';
import '../data/session_repository.dart';

const _pomodoroMinutes = 25;
const _brickCount = 8;

class StudyScreen extends ConsumerStatefulWidget {
  const StudyScreen({super.key, this.taskId});

  // task spesifik yg mau dikerjain (dari tap kartu Home). null = ambil yg
  // prioritas tertinggi, kayak pas langsung buka tab Study
  final int? taskId;

  @override
  ConsumerState<StudyScreen> createState() => _StudyScreenState();
}

class _StudyScreenState extends ConsumerState<StudyScreen> {
  Timer? _timer;
  int _remaining = _pomodoroMinutes * 60;
  bool _running = false;
  bool _finished = false;
  int? _sessionId;
  Task? _task;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // kalo datang dari tap kartu Home (widget.taskId) pake itu, kalo engga ambil
  // yg prioritas tertinggi
  Task? _pickTask() {
    if (_task != null) return _task;
    final tasks = ref.read(taskListProvider).valueOrNull ?? const <Task>[];
    if (widget.taskId != null) {
      for (final t in tasks) {
        if (t.id == widget.taskId) return t;
      }
    }
    final open = tasks.where((t) => !t.isDone).toList();
    return open.isEmpty ? null : open.first;
  }

  Future<void> _start() async {
    final task = _pickTask();
    setState(() {
      _task = task;
      _running = true;
    });

    // sesi dicatet di backend pas mulai, ditutup pake feedback pas selesai
    try {
      _sessionId = await ref.read(sessionRepositoryProvider).start(
            taskId: task?.id,
            plannedStart: DateTime.now(),
            plannedEnd: DateTime.now().add(const Duration(minutes: _pomodoroMinutes)),
          );
    } catch (_) {
      _sessionId = null; // timer tetap jalan walau backend tidak terjangkau
    }

    // jaga2 kalo app di-background dan timer dart-nya gak sempet jalan.
    // dibatalin lagi begitu sesi kelar (natural/end/fast forward) biar gak dobel
    // sama layar feedback
    ref.read(notificationServiceProvider).scheduleSessionEndReminder(
          const Duration(minutes: _pomodoroMinutes),
        );

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        _finish();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _pause() {
    _timer?.cancel();
    setState(() => _running = false);
  }

  void _resume() {
    setState(() => _running = true);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remaining <= 1) {
        timer.cancel();
        _finish();
      } else {
        setState(() => _remaining--);
      }
    });
  }

  void _finish() {
    setState(() {
      _remaining = 0;
      _running = false;
      _finished = true;
    });
    ref.read(notificationServiceProvider).cancelSessionEndReminder();
  }

  void _end() {
    _timer?.cancel();
    _finish();
  }

  // percepet sesi (buat demo) tanpa nunggu 25 menit asli, maju 5 menit tiap tekan
  void _fastForward() {
    final next = _remaining - 5 * 60;
    if (next <= 0) {
      _timer?.cancel();
      _finish();
    } else {
      setState(() => _remaining = next);
    }
  }

  Future<void> _sendFeedback(String feedback) async {
    final elapsedMinutes = ((_pomodoroMinutes * 60 - _remaining) / 60).round();
    if (_sessionId != null) {
      try {
        await ref
            .read(sessionRepositoryProvider)
            .complete(_sessionId!, feedback, elapsedMinutes);
        ref.invalidate(studySessionListProvider); // biar streak di Home ikut update
      } catch (_) {
        // feedback gagal kekirim gapapa, jangan block user keluar layar
      }
    }
    // kelar sesi -> lempar ke checklist Tasks biar bisa langsung dicentang
    if (mounted) context.go('/tasks');
  }

  String get _clock {
    final minutes = (_remaining ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          child: _finished ? _feedbackView() : _timerView(),
        ),
      ),
    );
  }

  Widget _timerView() {
    final task = _pickTask();
    // progress-nya 8 balok terisi, bukan progress bar bulet
    final filled =
        ((_pomodoroMinutes * 60 - _remaining) / (_pomodoroMinutes * 60) * _brickCount)
            .floor();

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
        Text(_clock,
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
                label: _running ? 'Pause' : 'Start',
                fill: AppColors.surface,
                labelColor: AppColors.ink,
                fontSize: 12.5,
                onPressed: _running
                    ? _pause
                    : (_remaining == _pomodoroMinutes * 60 ? _start : _resume),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: BrutalButton(
                label: 'End session',
                fill: AppColors.danger,
                labelColor: AppColors.ink,
                fontSize: 12.5,
                onPressed: _end,
              ),
            ),
            const SizedBox(width: 10),
            _FastForwardButton(
              // nyala begitu sesi beneran dimulai, sebelum tekan Start ya mati
              enabled: _running || _remaining < _pomodoroMinutes * 60,
              onTap: _fastForward,
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
