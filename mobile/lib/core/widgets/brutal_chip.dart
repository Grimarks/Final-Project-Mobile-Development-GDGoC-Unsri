import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/brutal_decorations.dart';
import '../theme/text_styles.dart';

// chip filter/pilihan. aktif = item penuh, gak aktif = putih doang
class BrutalChip extends StatelessWidget {
  const BrutalChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.expand = false,
    this.fontSize = 11,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool expand;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      alignment: expand ? Alignment.center : null,
      decoration: Brutal.flat(fill: selected ? AppColors.ink : AppColors.surface),
      child: Text(
        label.toUpperCase(),
        style: AppText.body(
          fontSize,
          weight: FontWeight.w700,
          color: selected ? AppColors.bg : AppColors.ink,
        ).copyWith(letterSpacing: 0.3),
      ),
    );
    final tappable = GestureDetector(onTap: onTap, child: chip);
    return expand ? Expanded(child: tappable) : tappable;
  }
}
