// 1 pesan chat AI Planner. role cuma 'user' atau 'assistant'
class ChatMessage {
  const ChatMessage({required this.role, required this.content, this.createdAt});

  final String role;
  final String content;
  final DateTime? createdAt;

  bool get isUser => role == 'user';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        role: json['role'] as String,
        content: json['content'] as String,
        createdAt:
            json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      );
}

// balesan 1 putaran chat dari backend
class ChatReply {
  const ChatReply({required this.reply, required this.generatedBy});

  final String reply;
  final String generatedBy;

  factory ChatReply.fromJson(Map<String, dynamic> json) => ChatReply(
        reply: json['reply'] as String,
        generatedBy: json['generated_by'] as String,
      );
}
