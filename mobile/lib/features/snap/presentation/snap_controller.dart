import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/notifications/notification_service.dart';
import '../../courses/data/course_repository.dart';
import '../../planner/data/planner_repository.dart';
import '../../planner/domain/task_candidate.dart';
import '../../tasks/data/task_repository.dart';
import '../data/snap_repository.dart';

enum SnapStatus { pick, reading, review, saving }

class SnapState {
  const SnapState({
    this.status = SnapStatus.pick,
    this.image,
    this.text,
    this.voice = false,
    this.transcript,
    this.candidates = const [],
    this.deselected = const {},
    this.error,
  });

  final SnapStatus status;
  final Uint8List? image; // foto yg lagi dibaca, buat preview
  final String? text; // atau teks yg di-paste
  final bool voice; // atau rekaman suara
  final String? transcript; // hasil Whisper, ditampilin di review
  final List<TaskCandidate> candidates;
  final Set<int> deselected;
  final String? error;

  int get selectedCount => candidates.length - deselected.length;

  SnapState copyWith({
    SnapStatus? status,
    List<TaskCandidate>? candidates,
    Set<int>? deselected,
    String? error,
  }) =>
      SnapState(
        status: status ?? this.status,
        image: image,
        text: text,
        voice: voice,
        transcript: transcript,
        candidates: candidates ?? this.candidates,
        deselected: deselected ?? this.deselected,
        error: error,
      );
}

// autoDispose: keluar layar Snap = mulai dari awal lagi
class SnapController extends AutoDisposeNotifier<SnapState> {
  @override
  SnapState build() => const SnapState();

  Future<void> extract({Uint8List? image, String? text}) async {
    state = SnapState(status: SnapStatus.reading, image: image, text: text);
    try {
      final candidates =
          await ref.read(snapRepositoryProvider).extract(image: image, text: text);
      state = state.copyWith(status: SnapStatus.review, candidates: candidates);
    } catch (e) {
      state = SnapState(image: image, text: text, error: e.toString());
    }
  }

  // input suara: rekaman dikirim ke Whisper, transkripnya ikut disimpen
  Future<void> extractVoice(Uint8List audio) async {
    state = const SnapState(status: SnapStatus.reading, voice: true);
    try {
      final result = await ref.read(snapRepositoryProvider).extractVoice(audio);
      state = SnapState(
        status: SnapStatus.review,
        voice: true,
        transcript: result.transcript,
        candidates: result.tasks,
      );
    } catch (e) {
      state = SnapState(voice: true, error: e.toString());
    }
  }

  void toggle(int index) {
    final next = Set<int>.from(state.deselected);
    if (!next.add(index)) next.remove(index); // tap kedua kali = pilih lagi
    state = state.copyWith(deselected: next);
  }

  // simpen yg masih dicentang, balikin jumlahnya (0 = gagal / gak ada yg dipilih)
  Future<int> save() async {
    final selected = [
      for (var i = 0; i < state.candidates.length; i++)
        if (!state.deselected.contains(i)) state.candidates[i],
    ];
    if (selected.isEmpty) return 0;
    state = state.copyWith(status: SnapStatus.saving);
    try {
      final created = await ref.read(plannerRepositoryProvider).confirmTasks(selected);
      // task dari foto juga dapet pengingat deadline, sama kayak yg dibikin manual
      final notifications = ref.read(notificationServiceProvider);
      for (final task in created.where((t) => t.dueDate != null)) {
        try {
          await notifications.scheduleTaskDueReminder(
            taskId: task.id,
            title: task.title,
            dueDate: task.dueDate!,
          );
        } catch (_) {}
      }
      // course baru (kalo ada) & task-nya mesti nongol di Tasks/Profile
      ref.invalidate(taskListProvider);
      ref.invalidate(courseListProvider);
      // jangan nyangkut di spinner "saving" kalo layarnya gak pindah
      state = state.copyWith(status: SnapStatus.review);
      return created.length;
    } catch (e) {
      state = state.copyWith(status: SnapStatus.review, error: e.toString());
      return 0;
    }
  }

  void reset() => state = const SnapState();
}

final snapControllerProvider =
    AutoDisposeNotifierProvider<SnapController, SnapState>(SnapController.new);
