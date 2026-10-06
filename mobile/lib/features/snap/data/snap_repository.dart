import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

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

  // input suara: rekaman -> Whisper di backend -> usulan task. transkripnya ikut
  // dibalikin biar user liat AI dengernya apa
  Future<({String transcript, List<TaskCandidate> tasks})> extractVoice(Uint8List audio) async {
    try {
      final form = FormData.fromMap({
        'audio': MultipartFile.fromBytes(audio, filename: 'voice.m4a'),
      });
      final resp = await _dio.post(
        '/ai/snap/voice',
        data: form,
        options: Options(receiveTimeout: const Duration(seconds: 90)),
      );
      final data = resp.data as Map<String, dynamic>;
      return (
        transcript: data['transcript'] as String? ?? '',
        tasks: (data['tasks'] as List<dynamic>)
            .map((e) => TaskCandidate.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
    } on DioException catch (e) {
      throw toApiException(e);
    }
  }
}

final snapRepositoryProvider = Provider<SnapRepository>((ref) {
  ref.watch(currentUserIdProvider); // ganti akun -> dibikin ulang
  return SnapRepository(ref.watch(apiClientProvider));
});

// dipisah jadi provider biar widget test bisa nge-fake kamera/galeri/mic
final imagePickerProvider = Provider<ImagePicker>((ref) => ImagePicker());
final audioRecorderFactoryProvider = Provider<AudioRecorder Function()>((ref) => AudioRecorder.new);
