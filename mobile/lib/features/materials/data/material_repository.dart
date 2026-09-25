import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/material_item.dart';
import '../domain/quiz.dart';
import '../domain/summary.dart';

class MaterialRepository {
  MaterialRepository(this._dio);

  final Dio _dio;

  Future<List<MaterialItem>> fetchAll() async {
    try {
      final resp = await _dio.get('/materials');
      return (resp.data as List<dynamic>)
          .map((e) => MaterialItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<MaterialItem> upload({
    required String filePath,
    required String filename,
    int? courseId,
  }) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: filename),
        if (courseId != null) 'course_id': courseId,
      });
      final resp = await _dio.post('/materials/upload', data: form);
      return MaterialItem.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int materialId) async {
    try {
      await _dio.delete('/materials/$materialId');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  // selalu generate ulang, bukan ambil hasil lama — biar jelas ini beneran manggil
  // groq baru, bukan cache diem2
  Future<MaterialSummary> summarize(int materialId) async {
    try {
      final resp = await _dio.post('/ai/materials/$materialId/summarize');
      return MaterialSummary.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<MaterialQuiz> generateQuiz(int materialId) async {
    try {
      final resp = await _dio.post('/ai/materials/$materialId/quiz');
      return MaterialQuiz.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final materialRepositoryProvider =
    Provider<MaterialRepository>((ref) {
  ref.watch(currentUserIdProvider); // ganti akun -> data dimuat ulang
  return MaterialRepository(ref.watch(apiClientProvider));
});

class MaterialList extends AsyncNotifier<List<MaterialItem>> {
  @override
  Future<List<MaterialItem>> build() => ref.watch(materialRepositoryProvider).fetchAll();

  Future<void> upload({required String filePath, required String filename, int? courseId}) async {
    await ref
        .read(materialRepositoryProvider)
        .upload(filePath: filePath, filename: filename, courseId: courseId);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(int id) async {
    await ref.read(materialRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final materialListProvider =
    AsyncNotifierProvider<MaterialList, List<MaterialItem>>(MaterialList.new);
