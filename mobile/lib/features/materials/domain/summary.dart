class MaterialSummary {
  const MaterialSummary({
    required this.generatedBy,
    required this.materialId,
    required this.summary,
    required this.keyPoints,
  });

  final String generatedBy;
  final int materialId;
  final String summary;
  final List<String> keyPoints;

  factory MaterialSummary.fromJson(Map<String, dynamic> json) => MaterialSummary(
        generatedBy: json['generated_by'] as String,
        materialId: json['material_id'] as int,
        summary: json['summary'] as String,
        keyPoints: (json['key_points'] as List<dynamic>).map((e) => e as String).toList(),
      );
}
