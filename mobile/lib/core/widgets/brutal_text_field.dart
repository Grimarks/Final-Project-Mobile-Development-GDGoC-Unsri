import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/brutal_decorations.dart';
import '../theme/text_styles.dart';

// input dgn label kapital kecil di atas, kotaknya berbingkai
class BrutalTextField extends StatelessWidget {
  const BrutalTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.keyboardType,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final TextInputType? keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: AppText.body(11, weight: FontWeight.w700).copyWith(letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: Brutal.flat(),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: AppText.body(14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppText.body(14, color: AppColors.inkMuted(0.4)),
              border: InputBorder.none,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ),
      ],
    );
  }
}
