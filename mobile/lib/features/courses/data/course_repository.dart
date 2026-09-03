import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../domain/course.dart';

class CourseRepository {
  CourseRepository(this._dio);

  final Dio _dio;

  Future<List<Course>> fetchAll() async {
    try {
      final resp = await _dio.get('/courses');
      return (resp.data as List<dynamic>)
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<Course> create({required String name, required String colorHex}) async {
    try {
      final resp = await _dio.post('/courses', data: {'name': name, 'color': colorHex});
      return Course.fromJson(resp.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }

  Future<void> delete(int id) async {
    try {
      await _dio.delete('/courses/$id');
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final courseRepositoryProvider =
    Provider<CourseRepository>((ref) => CourseRepository(ref.watch(apiClientProvider)));

class CourseList extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() => ref.watch(courseRepositoryProvider).fetchAll();

  Future<void> add(String name, String colorHex) async {
    await ref.read(courseRepositoryProvider).create(name: name, colorHex: colorHex);
    ref.invalidateSelf();
    await future;
  }

  Future<void> remove(int id) async {
    await ref.read(courseRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final courseListProvider =
    AsyncNotifierProvider<CourseList, List<Course>>(CourseList.new);
