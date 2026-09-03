import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/brutal_decorations.dart';

// kartu dasar, border + shadow keras. semua kartu di app pake ini biar
// gak hardcode border/shadow di tiap layar
class BrutalCard extends StatelessWidget {
  const BrutalCard({
    super.key,
    required this.child,
    this.fill = AppColors.surface,
    this.padding = const EdgeInsets.all(13),
    this.shadowOffset = 4,
    this.onTap,
    this.leftStripe,
  });

  final Widget child;
  final Color fill;
  final EdgeInsets padding;
  final double shadowOffset;
  final VoidCallback? onTap;

  // garis warna matkul di kiri kartu task
  final Color? leftStripe;

  @override
  Widget build(BuildContext context) {
    final decoration = Brutal.box(fill: fill, shadowOffset: shadowOffset).copyWith(
      border: leftStripe == null
          ? Brutal.border()
          : Border(
              top: BorderSide(color: AppColors.ink, width: Brutal.borderWidth),
              right: BorderSide(color: AppColors.ink, width: Brutal.borderWidth),
              bottom: BorderSide(color: AppColors.ink, width: Brutal.borderWidth),
              left: BorderSide(color: leftStripe!, width: 6),
            ),
      // border beda warna per sisi gabisa dikasih borderRadius (flutter error),
      // makanya versi leftStripe mesti kotak siku aja
      borderRadius: leftStripe == null ? null : BorderRadius.zero,
    );

    final card = Container(padding: padding, decoration: decoration, child: child);
    return onTap == null ? card : GestureDetector(onTap: onTap, child: card);
  }
}
