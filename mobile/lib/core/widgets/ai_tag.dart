import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/brutal_decorations.dart';
import '../theme/text_styles.dart';

// label "AI" kuning/item, biar keliatan mana konten buatan mesin mana input sendiri
class AiTag extends StatelessWidget {
  const AiTag({super.key, this.rotated = false});

  final bool rotated;

  @override
  Widget build(BuildContext context) {
    final tag = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: rotated ? AppColors.ink : AppColors.accent,
        border: rotated ? null : Brutal.border(width: Brutal.borderWidthThin),
        borderRadius: BorderRadius.circular(rotated ? 2 : 3),
        boxShadow: rotated
            ? [BoxShadow(color: AppColors.ink.withOpacity(0.4), offset: const Offset(2, 2))]
            : null,
      ),
      child: Text(
        'AI',
        style: AppText.label(rotated ? 11 : 9,
            color: rotated ? AppColors.accent : AppColors.ink),
      ),
    );

    // versi miring buat pita di pojok banner
    return rotated ? Transform.rotate(angle: -0.087, child: tag) : tag;
  }
}
