class QuizQuestion {
  const QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctIndex;
  final String? explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) => QuizQuestion(
        question: json['question'] as String,
        options: (json['options'] as List<dynamic>).map((e) => e as String).toList(),
        correctIndex: json['correct_index'] as int,
        explanation: json['explanation'] as String?,
      );
}

class MaterialQuiz {
  const MaterialQuiz({
    required this.generatedBy,
    required this.materialId,
    required this.questions,
  });

  final String generatedBy;
  final int materialId;
  final List<QuizQuestion> questions;

  factory MaterialQuiz.fromJson(Map<String, dynamic> json) => MaterialQuiz(
        generatedBy: json['generated_by'] as String,
        materialId: json['material_id'] as int,
        questions: (json['questions'] as List<dynamic>)
            .map((e) => QuizQuestion.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
