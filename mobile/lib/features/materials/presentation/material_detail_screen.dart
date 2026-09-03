import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/ai_tag.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../data/material_repository.dart';
import '../domain/material_item.dart';
import '../domain/summary.dart';
import 'quiz_screen.dart';

class MaterialDetailScreen extends ConsumerStatefulWidget {
  const MaterialDetailScreen({super.key, required this.material});

  final MaterialItem material;

  @override
  ConsumerState<MaterialDetailScreen> createState() => _MaterialDetailScreenState();
}

class _MaterialDetailScreenState extends ConsumerState<MaterialDetailScreen> {
  MaterialSummary? _summary;
  bool _summarizing = false;
  bool _generatingQuiz = false;
  String? _error;

  Future<void> _summarize() async {
    setState(() {
      _summarizing = true;
      _error = null;
    });
    try {
      final summary =
          await ref.read(materialRepositoryProvider).summarize(widget.material.id);
      if (mounted) setState(() => _summary = summary);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _summarizing = false);
    }
  }

  Future<void> _generateQuiz() async {
    setState(() {
      _generatingQuiz = true;
      _error = null;
    });
    try {
      final quiz =
          await ref.read(materialRepositoryProvider).generateQuiz(widget.material.id);
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => QuizScreen(quiz: quiz)),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _generatingQuiz = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final material = widget.material;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text(material.filename,
            maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.display(16)),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null) ...[
                BrutalCard(
                  fill: AppColors.danger,
                  padding: const EdgeInsets.all(14),
                  child: Text(_error!, style: AppText.body(12.5, weight: FontWeight.w600)),
                ),
                const SizedBox(height: 14),
              ],
              if (!material.hasExtractableText)
                BrutalCard(
                  fill: AppColors.warning,
                  padding: const EdgeInsets.all(14),
                  child: Text(
                    "This PDF has no extractable text (likely a scanned document) — "
                    "AI summary/quiz will be generic, not based on its real content.",
                    style: AppText.body(12.5, weight: FontWeight.w600),
                  ),
                )
              else ...[
                Text('PREVIEW', style: AppText.body(11, weight: FontWeight.w700).copyWith(letterSpacing: 0.5)),
                const SizedBox(height: 8),
                BrutalCard(
                  child: Text(material.preview, style: AppText.body(13, color: AppColors.inkMuted(0.75))),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: BrutalButton(
                      label: 'Summarize',
                      fill: AppColors.surface,
                      labelColor: AppColors.ink,
                      fontSize: 12.5,
                      loading: _summarizing,
                      onPressed: _summarize,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: BrutalButton(
                      label: 'Generate quiz',
                      fill: AppColors.ink,
                      labelColor: AppColors.accent,
                      fontSize: 12.5,
                      loading: _generatingQuiz,
                      onPressed: _generateQuiz,
                    ),
                  ),
                ],
              ),
              if (_summary != null) ...[
                const SizedBox(height: 22),
                Row(
                  children: [
                    Text('Summary', style: AppText.display(16)),
                    const SizedBox(width: 8),
                    const AiTag(),
                  ],
                ),
                const SizedBox(height: 10),
                BrutalCard(child: Text(_summary!.summary, style: AppText.body(13.5))),
                if (_summary!.keyPoints.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text('KEY POINTS',
                      style: AppText.body(11, weight: FontWeight.w700).copyWith(letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  for (final point in _summary!.keyPoints) ...[
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 7),
                          width: 6,
                          height: 6,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(point, style: AppText.body(13))),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
