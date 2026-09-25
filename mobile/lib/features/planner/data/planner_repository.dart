import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/notifications/notification_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../courses/data/course_repository.dart';
import '../../tasks/data/task_repository.dart';
import '../../tasks/domain/task.dart';
import '../domain/chat_message.dart';
import '../domain/plan.dart';
import '../domain/task_candidate.dart';

class PlannerRepository {
  PlannerRepository(this._dio);

  final Dio _dio;

  // opsi 1: random plan, cuma butuh jam luang. course, jam mulai, sama
  // kegiatannya diacak backend — gak nyomot dari task yg udah ada
  Future<StudyPlan> generateRandom({required double availableHours}) async {
    try {
      final resp = await _dio.post('/ai/plan/random', data: {'available_hours': availableHours});
      return StudyPlan.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // plan terakhir yg bakal diubah sama Adjust, null kalo belom pernah generate
  Future<StudyPlan?> activePlan() async {
    try {
      final resp = await _dio.get('/ai/plan/active');
      final data = resp.data;
      return data is Map<String, dynamic> ? StudyPlan.fromJson(data) : null;
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // opsi 2: sesuaikan plan aktif pake instruksi bebas. 404 (belum ada plan) tetep
  // dilempar sbg ApiException
  Future<AdjustPlanResult> adjustPlan(String instruction) async {
    try {
      final resp = await _dio.post('/ai/plan/adjust', data: {'instruction': instruction});
      return AdjustPlanResult.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // opsi 3: susun plan dari histori chat
  Future<StudyPlan> planFromChat() async {
    try {
      final resp = await _dio.post('/ai/plan/from-chat');
      return StudyPlan.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // accept = semua blok disambungin ke task beneran (yg belom ada dibikinin)
  Future<StudyPlan> acceptPlan(int planId) async {
    try {
      final resp = await _dio.post('/ai/plan/$planId/accept');
      return StudyPlan.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // plan yg udah di-accept buat hari ini, null kalo belom ada
  Future<StudyPlan?> todayPlan() async {
    try {
      final resp = await _dio.get('/ai/plan/today');
      final data = resp.data;
      return data is Map<String, dynamic> ? StudyPlan.fromJson(data) : null;
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<ChatReply> sendChatMessage(String message) async {
    try {
      final resp = await _dio.post('/ai/chat/message', data: {'message': message});
      return ChatReply.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // usulin course/task dari chat, belom disimpen
  Future<List<TaskCandidate>> extractTasksFromChat() async {
    try {
      final resp = await _dio.post('/ai/chat/extract-tasks');
      final data = resp.data as Map<String, dynamic>;
      return (data['tasks'] as List<dynamic>)
          .map((e) => TaskCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // simpen task/course yg udah dikonfirmasi user, ini juga bakal nongol di Tasks
  // tab biasa, gak cuma sekali pake buat plan ini doang
  Future<List<Task>> confirmTasks(List<TaskCandidate> tasks) async {
    try {
      final resp = await _dio.post('/ai/chat/confirm-tasks', data: {
        'tasks': tasks.map((t) => t.toJson()).toList(),
      });
      return (resp.data as List<dynamic>)
          .map((e) => Task.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<List<ChatMessage>> chatHistory() async {
    try {
      final resp = await _dio.get('/ai/chat/history');
      return (resp.data as List<dynamic>)
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> clearChatHistory() async {
    try {
      await _dio.delete('/ai/chat/history');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final plannerRepositoryProvider =
    Provider<PlannerRepository>((ref) {
  ref.watch(currentUserIdProvider); // ganti akun -> data dimuat ulang
  return PlannerRepository(ref.watch(apiClientProvider));
});

// jam mulai tiap sesi (hari ini) dari "HH:MM"
List<PlanSessionReminder> planSessionReminders(StudyPlan plan, DateTime today) {
  final reminders = <PlanSessionReminder>[];
  for (final block in plan.blocks) {
    final parts = block.startTime.split(':');
    final hour = int.tryParse(parts.first);
    final minute = parts.length > 1 ? int.tryParse(parts[1]) : null;
    if (hour == null || minute == null) continue;
    reminders.add(PlanSessionReminder(
      title: block.title,
      start: DateTime(today.year, today.month, today.day, hour, minute),
      timeLabel: block.course != null ? '${block.timeLabel} · ${block.course}' : block.timeLabel,
    ));
  }
  return reminders;
}

// notif gagal (izin ditolak dll) jangan sampe bikin accept plan ikut gagal
Future<void> _schedulePlanReminders(NotificationService notifications, StudyPlan plan) async {
  try {
    await notifications.schedulePlanSessionReminders(planSessionReminders(plan, DateTime.now()));
  } catch (_) {}
}

final activePlanProvider = FutureProvider.autoDispose<StudyPlan?>(
    (ref) => ref.watch(plannerRepositoryProvider).activePlan());

final todayPlanProvider =
    FutureProvider<StudyPlan?>((ref) => ref.watch(plannerRepositoryProvider).todayPlan());

// accept plan yg lagi diliat, terus bersihin semua state planner biar pas dibuka
// lagi gak nongol plan lama yg masih bisa di-Adjust/Accept
Future<StudyPlan> acceptPlanAndReset(WidgetRef ref, StudyPlan plan) async {
  final accepted = await ref.read(plannerRepositoryProvider).acceptPlan(plan.planId!);
  await _schedulePlanReminders(ref.read(notificationServiceProvider), accepted);
  ref.invalidate(taskListProvider);
  ref.invalidate(courseListProvider);
  ref.invalidate(todayPlanProvider);
  ref.invalidate(randomPlanControllerProvider);
  ref.invalidate(adjustPlanControllerProvider);
  ref.invalidate(activePlanProvider);
  ref.read(chatControllerProvider.notifier).clearPlan();
  ref.read(plannerModeProvider.notifier).reset();
  return accepted;
}

// mode yg dipilih user di AI Planner. none = masih di kartu pilihan
enum PlannerMode { none, random, adjust, chat }

class PlannerModeController extends Notifier<PlannerMode> {
  @override
  PlannerMode build() {
    ref.watch(currentUserIdProvider);
    return PlannerMode.none;
  }

  void select(PlannerMode mode) => state = mode;

  void reset() => state = PlannerMode.none;
}

final plannerModeProvider =
    NotifierProvider<PlannerModeController, PlannerMode>(PlannerModeController.new);

// --- 1. random plan: tanya jam luang, generate ---
enum RandomPlanPhase { askingHours, generating, generated }

class RandomPlanState {
  const RandomPlanState({
    this.phase = RandomPlanPhase.askingHours,
    this.plan,
    this.error,
    this.availableHours = 2,
  });

  final RandomPlanPhase phase;
  final StudyPlan? plan;
  final String? error;
  final double availableHours;

  RandomPlanState copyWith({
    RandomPlanPhase? phase,
    StudyPlan? plan,
    String? error,
    double? availableHours,
  }) =>
      RandomPlanState(
        phase: phase ?? this.phase,
        plan: plan ?? this.plan,
        error: error,
        availableHours: availableHours ?? this.availableHours,
      );
}

class RandomPlanController extends Notifier<RandomPlanState> {
  @override
  RandomPlanState build() {
    ref.watch(currentUserIdProvider);
    return const RandomPlanState();
  }

  void setHours(double hours) => state = state.copyWith(availableHours: hours);

  Future<void> generate() async {
    state = state.copyWith(phase: RandomPlanPhase.generating);
    try {
      final plan = await ref
          .read(plannerRepositoryProvider)
          .generateRandom(availableHours: state.availableHours);
      state = state.copyWith(phase: RandomPlanPhase.generated, plan: plan);
    } catch (e) {
      state = state.copyWith(phase: RandomPlanPhase.askingHours, error: e.toString());
    }
  }
}

final randomPlanControllerProvider =
    NotifierProvider<RandomPlanController, RandomPlanState>(RandomPlanController.new);

// --- 2. adjust plan aktif pake instruksi bebas ---
enum AdjustPlanPhase { input, submitting, result, noActivePlan }

class AdjustPlanState {
  const AdjustPlanState({
    this.phase = AdjustPlanPhase.input,
    this.result,
    this.error,
  });

  final AdjustPlanPhase phase;
  final AdjustPlanResult? result;
  final String? error;

  AdjustPlanState copyWith({
    AdjustPlanPhase? phase,
    AdjustPlanResult? result,
    String? error,
  }) =>
      AdjustPlanState(
        phase: phase ?? this.phase,
        result: result ?? this.result,
        error: error,
      );
}

class AdjustPlanController extends Notifier<AdjustPlanState> {
  @override
  AdjustPlanState build() {
    ref.watch(currentUserIdProvider);
    return const AdjustPlanState();
  }

  Future<void> submit(String instruction) async {
    state = state.copyWith(phase: AdjustPlanPhase.submitting, error: null);
    try {
      final result = await ref.read(plannerRepositoryProvider).adjustPlan(instruction);
      ref.invalidate(activePlanProvider); // plan aktif-nya udah ganti
      state = state.copyWith(phase: AdjustPlanPhase.result, result: result);
    } on ApiException catch (e) {
      // 404 = belom pernah generate plan -> tawarin pindah ke opsi random
      state = e.statusCode == 404
          ? state.copyWith(phase: AdjustPlanPhase.noActivePlan, error: e.message)
          : state.copyWith(phase: AdjustPlanPhase.input, error: e.message);
    } catch (e) {
      state = state.copyWith(phase: AdjustPlanPhase.input, error: e.toString());
    }
  }

  // balik ke form input, buat nyesuain lagi abis liat hasil
  void reset() => state = const AdjustPlanState();
}

final adjustPlanControllerProvider =
    NotifierProvider<AdjustPlanController, AdjustPlanState>(AdjustPlanController.new);

// --- 3. chat multi-turn + generate plan dari chat ---
enum ChatStatus { idle, sending, extracting, generatingPlan }

class ChatState {
  const ChatState({
    this.messages = const [],
    this.status = ChatStatus.idle,
    this.loadingHistory = true,
    this.error,
    this.plan,
    this.reviewCandidates = const [],
    this.deselectedIndices = const {},
  });

  final List<ChatMessage> messages;
  final ChatStatus status;
  final bool loadingHistory;
  final String? error;
  final StudyPlan? plan;

  // task/course usulan AI dari chat, nunggu dikonfirmasi user dulu sblm disimpen.
  // kalo gak kosong berarti munculin panel review dulu, bukan langsung generate
  final List<TaskCandidate> reviewCandidates;
  final Set<int> deselectedIndices;

  // minimal 1x tuker chat (user+AI) baru tombol generate nongol
  bool get canGeneratePlan => messages.length >= 2;

  ChatState copyWith({
    List<ChatMessage>? messages,
    ChatStatus? status,
    bool? loadingHistory,
    String? error,
    StudyPlan? plan,
    List<TaskCandidate>? reviewCandidates,
    Set<int>? deselectedIndices,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        status: status ?? this.status,
        loadingHistory: loadingHistory ?? this.loadingHistory,
        error: error,
        plan: plan ?? this.plan,
        reviewCandidates: reviewCandidates ?? this.reviewCandidates,
        deselectedIndices: deselectedIndices ?? this.deselectedIndices,
      );
}

class ChatController extends Notifier<ChatState> {
  @override
  ChatState build() {
    ref.watch(currentUserIdProvider);
    return const ChatState();
  }

  Future<void> loadHistory() async {
    state = state.copyWith(loadingHistory: true);
    try {
      final history = await ref.read(plannerRepositoryProvider).chatHistory();
      state = state.copyWith(messages: history, loadingHistory: false);
    } catch (e) {
      state = state.copyWith(loadingHistory: false, error: e.toString());
    }
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.status == ChatStatus.sending) return;
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(role: 'user', content: trimmed)],
      status: ChatStatus.sending,
    );
    try {
      final reply = await ref.read(plannerRepositoryProvider).sendChatMessage(trimmed);
      state = state.copyWith(
        messages: [...state.messages, ChatMessage(role: 'assistant', content: reply.reply)],
        status: ChatStatus.idle,
      );
    } catch (e) {
      state = state.copyWith(status: ChatStatus.idle, error: e.toString());
    }
  }

  // cek dulu chat nyebut course/task baru gak sblm generate. kalo ada munculin
  // review panel, kalo gak ada langsung generate dari task yg udah ada
  Future<void> generatePlan() async {
    state = state.copyWith(status: ChatStatus.extracting, error: null);
    try {
      final candidates = await ref.read(plannerRepositoryProvider).extractTasksFromChat();
      if (candidates.isEmpty) {
        await _generatePlanFromExistingTasks();
      } else {
        state = state.copyWith(
          status: ChatStatus.idle,
          reviewCandidates: candidates,
          deselectedIndices: const {},
        );
      }
    } catch (e) {
      state = state.copyWith(status: ChatStatus.idle, error: e.toString());
    }
  }

  void toggleCandidate(int index) {
    final next = Set<int>.from(state.deselectedIndices);
    if (!next.add(index)) next.remove(index); // tap kedua kali = pilih lagi
    state = state.copyWith(deselectedIndices: next);
  }

  // simpen task yg masih dicentang, terus generate plan dari situ + task lama
  Future<void> confirmCandidatesAndGenerate() async {
    final selected = [
      for (var i = 0; i < state.reviewCandidates.length; i++)
        if (!state.deselectedIndices.contains(i)) state.reviewCandidates[i],
    ];
    if (selected.isNotEmpty) {
      state = state.copyWith(status: ChatStatus.generatingPlan, error: null);
      try {
        final created = await ref.read(plannerRepositoryProvider).confirmTasks(selected);
        // task dari AI juga dapet pengingat deadline, sama kayak yg dibikin manual
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
        // task/course baru harus nongol juga di Tasks/Profile, gak cuma di sini doang
        ref.invalidate(taskListProvider);
        ref.invalidate(courseListProvider);
      } catch (e) {
        state = state.copyWith(status: ChatStatus.idle, error: e.toString());
        return;
      }
    }
    await _generatePlanFromExistingTasks();
  }

  // user skip usulan AI, generate biasa dari task lama aja
  Future<void> skipReview() async {
    state = state.copyWith(reviewCandidates: const [], deselectedIndices: const {});
    await _generatePlanFromExistingTasks();
  }

  // batal, balik ke chat tanpa generate apa2
  void cancelReview() =>
      state = state.copyWith(reviewCandidates: const [], deselectedIndices: const {});

  Future<void> _generatePlanFromExistingTasks() async {
    state = state.copyWith(status: ChatStatus.generatingPlan, error: null);
    try {
      final plan = await ref.read(plannerRepositoryProvider).planFromChat();
      state = state.copyWith(
        status: ChatStatus.idle,
        plan: plan,
        reviewCandidates: const [],
        // "0 blocks" jangan cuma pesen generik, kasih tau kenapa (AI gak nemu
        // matkul/tugas konkret di chat atau task yg ada)
        error: plan.blocks.isEmpty
            ? "Couldn't find a specific course or task to schedule. Try mentioning a "
                'course name and what you need to do in the chat, then generate again.'
            : null,
      );
    } catch (e) {
      state = state.copyWith(status: ChatStatus.idle, error: e.toString());
    }
  }

  void clearPlan() => state = ChatState(
        messages: state.messages,
        loadingHistory: state.loadingHistory,
      );

  Future<void> startOver() async {
    try {
      await ref.read(plannerRepositoryProvider).clearChatHistory();
    } catch (_) {
      // gagal juga gapapa, state lokal tetep dibersihin
    }
    state = const ChatState(loadingHistory: false);
  }
}

final chatControllerProvider = NotifierProvider<ChatController, ChatState>(ChatController.new);
