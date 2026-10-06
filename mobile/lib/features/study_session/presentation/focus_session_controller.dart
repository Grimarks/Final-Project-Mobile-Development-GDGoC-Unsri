import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task.dart';
import '../data/session_repository.dart';

const pomodoroDuration = Duration(minutes: 25);

// state sesi pomodoro. sisa waktu diitung dari jam selesai (endsAt), bukan
// dikurangin tiap detik — timer dart berhenti pas app di-background, jadi
// kalo ngitung mundur manual waktunya molor
class FocusSessionState {
  const FocusSessionState({
    this.task,
    this.sessionId,
    this.endsAt,
    this.pausedRemaining = pomodoroDuration,
    this.started = false,
    this.finished = false,
  });

  final Task? task;
  final int? sessionId;
  final DateTime? endsAt; // != null = lagi jalan
  final Duration pausedRemaining; // sisa waktu pas di-pause / pas selesai
  final bool started;
  final bool finished;

  bool get running => endsAt != null && !finished;

  Duration remaining([DateTime? now]) {
    final end = endsAt;
    if (end == null || finished) return pausedRemaining;
    final left = end.difference(now ?? DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  FocusSessionState copyWith({
    int? sessionId,
    DateTime? endsAt,
    bool clearEndsAt = false,
    Duration? pausedRemaining,
    bool? finished,
  }) =>
      FocusSessionState(
        task: task,
        sessionId: sessionId ?? this.sessionId,
        endsAt: clearEndsAt ? null : (endsAt ?? this.endsAt),
        pausedRemaining: pausedRemaining ?? this.pausedRemaining,
        started: started,
        finished: finished ?? this.finished,
      );
}

// sengaja gak autoDispose: pindah tab di tengah sesi, sesinya tetep jalan
class FocusSessionController extends Notifier<FocusSessionState> {
  @override
  FocusSessionState build() {
    ref.watch(currentUserIdProvider); // ganti akun -> sesi lama dibuang
    return const FocusSessionState();
  }

  NotificationService get _notifs => ref.read(notificationServiceProvider);

  Future<void> start(Task? task) async {
    if (state.started) return;
    final now = DateTime.now();
    state = FocusSessionState(task: task, endsAt: now.add(pomodoroDuration), started: true);

    // jaga2 kalo app di-background, notif "kelar" tetep nongol
    _notifs.scheduleSessionEndReminder(pomodoroDuration);

    if (task != null) {
      // gagal update status gapapa, sesinya tetep jalan
      ref.read(taskListProvider.notifier).markInProgress(task).catchError((_) {});
    }

    // sesi dicatet di backend pas mulai, ditutup pake feedback pas selesai
    try {
      final id = await ref.read(sessionRepositoryProvider).start(
            taskId: task?.id,
            plannedStart: now,
            plannedEnd: now.add(pomodoroDuration),
          );
      if (state.started) state = state.copyWith(sessionId: id);
    } catch (_) {
      // backend gak kejangkau: timer tetep jalan, cuma gak kerekam
    }
  }

  void pause() {
    if (!state.running) return;
    state = state.copyWith(clearEndsAt: true, pausedRemaining: state.remaining());
    // lagi di-pause, jangan sampe notif "sesi kelar" nongol duluan
    _notifs.cancelSessionEndReminder();
  }

  void resume() {
    if (!state.started || state.running || state.finished) return;
    final left = state.pausedRemaining;
    state = state.copyWith(endsAt: DateTime.now().add(left));
    _notifs.scheduleSessionEndReminder(left);
  }

  // percepet sesi (buat demo) tanpa nunggu 25 menit asli, maju 5 menit tiap tekan
  void fastForward() {
    if (!state.started || state.finished) return;
    final next = state.remaining() - const Duration(minutes: 5);
    if (next <= Duration.zero) {
      finish(timeUp: true);
    } else if (state.running) {
      state = state.copyWith(endsAt: DateTime.now().add(next));
      _notifs.scheduleSessionEndReminder(next); // notif ikut dimajuin
    } else {
      state = state.copyWith(pausedRemaining: next);
    }
  }

  // dipanggil layar tiap detik & pas app balik dari background
  void tick() {
    if (state.running && state.remaining() == Duration.zero) finish(timeUp: true);
  }

  // timeUp = waktunya abis (natural / fast forward), selain itu End session lebih awal
  void finish({bool timeUp = false}) {
    if (!state.started || state.finished) return;
    state = state.copyWith(
      clearEndsAt: true,
      pausedRemaining: timeUp ? Duration.zero : state.remaining(),
      finished: true,
    );
    _notifs.cancelSessionEndReminder();
  }

  Future<void> sendFeedback(String feedback) async {
    final sessionId = state.sessionId;
    final elapsedMinutes = (pomodoroDuration - state.pausedRemaining).inSeconds / 60;
    state = const FocusSessionState(); // siap buat sesi berikutnya
    if (sessionId == null) return;
    try {
      await ref
          .read(sessionRepositoryProvider)
          .complete(sessionId, feedback, elapsedMinutes.round());
      ref.invalidate(studySessionListProvider); // biar streak di Home ikut update
    } catch (_) {
      // feedback gagal kekirim gapapa, jangan block user keluar layar
    }
  }
}

final focusSessionProvider =
    NotifierProvider<FocusSessionController, FocusSessionState>(FocusSessionController.new);
