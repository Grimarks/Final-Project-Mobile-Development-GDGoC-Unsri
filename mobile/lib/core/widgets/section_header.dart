import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';

// judul seksi + garis tipis manjang di sampingnya
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title.toUpperCase(), style: AppText.label(13)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 2, color: AppColors.ink.withOpacity(0.15))),
      ],
    );
  }
}
