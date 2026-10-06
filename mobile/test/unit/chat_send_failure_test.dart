import 'package:campusflow/core/network/api_client.dart';
import 'package:campusflow/features/planner/data/planner_repository.dart';
import 'package:campusflow/features/planner/domain/chat_message.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pesan yang ditolak server (mis. 429 rate limit) belum tersimpan, jadi jangan
/// tetap dipajang di chat seolah sudah terkirim.
void main() {
  test('send gagal -> pesan user ditarik lagi & error ditampilkan', () async {
    final container = ProviderContainer(overrides: [
      plannerRepositoryProvider.overrideWithValue(_RateLimitedPlannerRepo()),
    ]);
    addTearDown(container.dispose);

    final sent = await container.read(chatControllerProvider.notifier).send('halo');

    expect(sent, isFalse);
    final state = container.read(chatControllerProvider);
    expect(state.messages, isEmpty);
    expect(state.error, contains('Coba lagi dalam'));
    expect(state.status, ChatStatus.idle);
  });
}

class _RateLimitedPlannerRepo extends PlannerRepository {
  _RateLimitedPlannerRepo() : super(Dio());

  @override
  Future<ChatReply> sendChatMessage(String message) async => throw ApiException(
      'Terlalu banyak permintaan AI. Coba lagi dalam 30 detik.',
      statusCode: 429);
}
