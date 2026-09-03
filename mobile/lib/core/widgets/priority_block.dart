import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/brutal_decorations.dart';
import '../theme/text_styles.dart';

// blok prioritas warna solid, bukan badge pastel. high=merah, medium=oren, low=ijo
class PriorityBlock extends StatelessWidget {
  const PriorityBlock({super.key, required this.priority, this.fontSize = 9.5});

  final String priority;
  final double fontSize;

  static Color colorFor(String priority) {
    switch (priority) {
      case 'high':
        return AppColors.danger;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorFor(priority),
        border: Brutal.border(width: Brutal.borderWidthThin),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(priority.toUpperCase(), style: AppText.label(fontSize)),
    );
  }
}
