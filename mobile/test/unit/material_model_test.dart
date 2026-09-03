import 'package:campusflow/features/materials/domain/material_item.dart';
import 'package:campusflow/features/materials/domain/quiz.dart';
import 'package:campusflow/features/materials/domain/summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MaterialItem', () {
    test('fromJson mengurai seluruh field', () {
      final item = MaterialItem.fromJson({
        'id': 1,
        'filename': 'notes.pdf',
        'course_id': 3,
        'uploaded_at': '2026-09-02T10:00:00+00:00',
        'text_length': 1200,
        'preview': 'Ini adalah preview materi...',
      });

      expect(item.id, 1);
      expect(item.filename, 'notes.pdf');
      expect(item.courseId, 3);
      expect(item.textLength, 1200);
      expect(item.hasExtractableText, isTrue);
    });

    test('hasExtractableText false kalau text_length 0 (PDF hasil scan)', () {
      final item = MaterialItem.fromJson({
        'id': 2,
        'filename': 'scanned.pdf',
        'course_id': null,
        'uploaded_at': '2026-09-02T10:00:00+00:00',
        'text_length': 0,
        'preview': '',
      });

      expect(item.hasExtractableText, isFalse);
      expect(item.courseId, isNull);
    });
  });

  group('MaterialSummary', () {
    test('fromJson mengurai summary dan key_points', () {
      final summary = MaterialSummary.fromJson({
        'generated_by': 'groq',
        'material_id': 1,
        'summary': 'Ringkasan materi.',
        'key_points': ['Poin 1', 'Poin 2'],
      });

      expect(summary.generatedBy, 'groq');
      expect(summary.keyPoints, ['Poin 1', 'Poin 2']);
    });
  });

  group('MaterialQuiz', () {
    test('fromJson mengurai daftar pertanyaan', () {
      final quiz = MaterialQuiz.fromJson({
        'generated_by': 'heuristic',
        'material_id': 1,
        'questions': [
          {
            'question': 'Apa itu variabel?',
            'options': ['A', 'B', 'C', 'D'],
            'correct_index': 1,
            'explanation': 'Penjelasan singkat.',
          },
        ],
      });

      expect(quiz.questions, hasLength(1));
      expect(quiz.questions.single.correctIndex, 1);
      expect(quiz.questions.single.options, hasLength(4));
    });
  });
}
