import 'package:campusflow/features/planner/domain/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatMessage', () {
    test('fromJson mengurai role, content, dan created_at', () {
      final msg = ChatMessage.fromJson({
        'role': 'user',
        'content': 'Aku ada 2 jam luang',
        'created_at': '2026-09-02T10:00:00Z',
      });

      expect(msg.role, 'user');
      expect(msg.content, 'Aku ada 2 jam luang');
      expect(msg.isUser, isTrue);
      expect(msg.createdAt, DateTime.parse('2026-09-02T10:00:00Z'));
    });

    test('isUser false untuk role assistant', () {
      final msg = ChatMessage.fromJson({
        'role': 'assistant',
        'content': 'Oke, dicatat.',
        'created_at': null,
      });

      expect(msg.isUser, isFalse);
      expect(msg.createdAt, isNull);
    });
  });

  group('ChatReply', () {
    test('fromJson mengurai reply dan generated_by', () {
      final reply = ChatReply.fromJson({'reply': 'Halo!', 'generated_by': 'heuristic'});

      expect(reply.reply, 'Halo!');
      expect(reply.generatedBy, 'heuristic');
    });
  });
}
