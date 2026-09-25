import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/study_session_record.dart';

class SessionRepository {
  SessionRepository(this._dio);

  final Dio _dio;

  Future<List<StudySessionRecord>> fetchAll() async {
    try {
      final resp = await _dio.get('/study-sessions');
      return (resp.data as List<dynamic>)
          .map((e) => StudySessionRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<int> start({int? taskId, DateTime? plannedStart, DateTime? plannedEnd}) async {
    try {
      final resp = await _dio.post('/study-sessions', data: {
        'task_id': taskId,
        'planned_start': plannedStart?.toUtc().toIso8601String(),
        'planned_end': plannedEnd?.toUtc().toIso8601String(),
      });
      return resp.data['id'] as int;
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // feedback: easy | normal | hard, dipake planner selanjutnya buat nyesuain durasi
  Future<void> complete(int sessionId, String feedback, int actualMinutes) async {
    try {
      await _dio.patch('/study-sessions/$sessionId/complete', data: {
        'feedback': feedback,
        'actual_duration': actualMinutes,
      });
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final sessionRepositoryProvider =
    Provider<SessionRepository>((ref) {
  ref.watch(currentUserIdProvider); // ganti akun -> data dimuat ulang
  return SessionRepository(ref.watch(apiClientProvider));
});

final studySessionListProvider =
    FutureProvider<List<StudySessionRecord>>((ref) => ref.watch(sessionRepositoryProvider).fetchAll());

// jumlah hari beruntun sampe hari ini, buat di Home
final studyStreakProvider = Provider<int>((ref) {
  final sessions = ref.watch(studySessionListProvider).valueOrNull ?? const [];
  return computeStreak(sessions);
});
