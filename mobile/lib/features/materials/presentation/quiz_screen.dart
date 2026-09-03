import 'package:flutter/material.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../domain/quiz.dart';

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.quiz});

  final MaterialQuiz quiz;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _index = 0;
  int? _selected;
  int _correctCount = 0;
  bool _finished = false;

  QuizQuestion get _question => widget.quiz.questions[_index];
  bool get _isLast => _index == widget.quiz.questions.length - 1;

  void _select(int optionIndex) {
    if (_selected != null) return; // udah dijawab, gaboleh ganti lagi
    setState(() {
      _selected = optionIndex;
      if (optionIndex == _question.correctIndex) _correctCount++;
    });
  }

  void _next() {
    if (_isLast) {
      setState(() => _finished = true);
      return;
    }
    setState(() {
      _index++;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        foregroundColor: AppColors.ink,
        title: Text('Quiz', style: AppText.display(18)),
      ),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: _finished ? _scoreView() : _questionView(),
        ),
      ),
    );
  }

  Widget _questionView() {
    final total = widget.quiz.questions.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUESTION ${_index + 1} OF $total',
            style: AppText.body(11, weight: FontWeight.w700, color: AppColors.inkMuted(0.55))
                .copyWith(letterSpacing: 0.5)),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var i = 0; i < total; i++) ...[
              Expanded(
                child: Container(
                  height: 6,
                  color: i <= _index ? AppColors.primary : AppColors.surface,
                  foregroundDecoration: BoxDecoration(border: Brutal.border(width: 1)),
                ),
              ),
              if (i != total - 1) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 22),
        Text(_question.question, style: AppText.display(18)),
        const SizedBox(height: 20),
        for (var i = 0; i < _question.options.length; i++) ...[
          _OptionTile(
            label: _question.options[i],
            state: _selected == null
                ? _OptionState.idle
                : i == _question.correctIndex
                    ? _OptionState.correct
                    : i == _selected
                        ? _OptionState.incorrect
                        : _OptionState.disabled,
            onTap: () => _select(i),
          ),
          const SizedBox(height: 10),
        ],
        if (_selected != null && (_question.explanation ?? '').isNotEmpty) ...[
          const SizedBox(height: 6),
          BrutalCard(
            fill: AppColors.accent,
            padding: const EdgeInsets.all(13),
            child: Text(_question.explanation!, style: AppText.body(12.5, weight: FontWeight.w600)),
          ),
        ],
        const Spacer(),
        if (_selected != null)
          BrutalButton(
            label: _isLast ? 'See results' : 'Next question',
            onPressed: _next,
          ),
      ],
    );
  }

  Widget _scoreView() {
    final total = widget.quiz.questions.length;
    final pct = total == 0 ? 0 : ((_correctCount / total) * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Text('Quiz complete', style: AppText.display(22)),
        const SizedBox(height: 24),
        Container(
          width: 140,
          height: 140,
          alignment: Alignment.center,
          decoration: Brutal.box(fill: AppColors.accent, shadowOffset: 5),
          child: Text('$pct%', style: AppText.display(38, weight: FontWeight.w900)),
        ),
        const SizedBox(height: 18),
        Text('$_correctCount out of $total correct',
            style: AppText.body(14, weight: FontWeight.w600, color: AppColors.inkMuted(0.65))),
        const SizedBox(height: 32),
        BrutalButton(
          label: 'Done',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

enum _OptionState { idle, correct, incorrect, disabled }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.state, required this.onTap});

  final String label;
  final _OptionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill = switch (state) {
      _OptionState.correct => AppColors.success,
      _OptionState.incorrect => AppColors.danger,
      _ => AppColors.surface,
    };
    return BrutalCard(
      fill: fill,
      shadowOffset: state == _OptionState.disabled ? 0 : 3,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.body(13.5, weight: FontWeight.w600))),
          if (state == _OptionState.correct) const Icon(Icons.check_circle, color: AppColors.ink, size: 18),
          if (state == _OptionState.incorrect) const Icon(Icons.cancel, color: AppColors.ink, size: 18),
        ],
      ),
    );
  }
}
