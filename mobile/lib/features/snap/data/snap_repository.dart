import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../planner/domain/task_candidate.dart';

// Snap & Go: kirim foto / teks pengumuman, dapet usulan task (belom disimpen).
// simpennya pake confirmTasks di PlannerRepository, endpoint-nya sama kayak chat
class SnapRepository {
  SnapRepository(this._dio);

  final Dio _dio;

  Future<List<TaskCandidate>> extract({Uint8List? image, String? text}) async {
    try {
      final form = FormData.fromMap({
        if (image != null) 'image': MultipartFile.fromBytes(image, filename: 'snap.jpg'),
        if (text != null && text.trim().isNotEmpty) 'text': text.trim(),
      });
      final resp = await _dio.post(
        '/ai/snap/extract',
        data: form,
        // model vision kadang lebih lama dari chat biasa
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      final data = resp.data as Map<String, dynamic>;
      return (data['tasks'] as List<dynamic>)
          .map((e) => TaskCandidate.fromJson(e as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final snapRepositoryProvider = Provider<SnapRepository>((ref) {
  ref.watch(currentUserIdProvider); // ganti akun -> dibikin ulang
  return SnapRepository(ref.watch(apiClientProvider));
});

// dipisah jadi provider biar widget test bisa nge-fake kamera/galeri
final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());
