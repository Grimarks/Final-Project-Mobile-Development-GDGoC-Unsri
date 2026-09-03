class MaterialItem {
  const MaterialItem({
    required this.id,
    required this.filename,
    required this.uploadedAt,
    required this.textLength,
    required this.preview,
    this.courseId,
  });

  final int id;
  final String filename;
  final int? courseId;
  final DateTime uploadedAt;
  final int textLength;
  final String preview;

  // pdf hasil scan (gaada layer teks) bikin extracted_text kosong, jadi jangan
  // janjiin ringkasan/kuis yang bener
  bool get hasExtractableText => textLength > 0;

  factory MaterialItem.fromJson(Map<String, dynamic> json) => MaterialItem(
        id: json['id'] as int,
        filename: json['filename'] as String,
        courseId: json['course_id'] as int?,
        uploadedAt: DateTime.parse(json['uploaded_at'] as String),
        textLength: json['text_length'] as int,
        preview: json['preview'] as String,
      );
}
