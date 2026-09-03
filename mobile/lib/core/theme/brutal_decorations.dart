import 'package:flutter/material.dart';

import 'colors.dart';

// style neo-brutalism yang dipake berkali-kali: border item solid + shadow keras
// tanpa blur + sudut nyaris siku
class Brutal {
  const Brutal._();

  static const double borderWidth = 3;
  static const double borderWidthThin = 2;
  static const double radius = 4;

  static BorderRadius get corner => BorderRadius.circular(radius);

  static Border border({double width = borderWidth, Color color = AppColors.ink}) =>
      Border.all(color: color, width: width);

  // blurRadius selalu 0, beda sama elevation material biasa
  static List<BoxShadow> shadow({double offset = 4, Color color = AppColors.ink}) => [
        BoxShadow(color: color, offset: Offset(offset, offset), blurRadius: 0),
      ];

  static BoxDecoration box({
    Color fill = AppColors.surface,
    double borderWidth = Brutal.borderWidth,
    double shadowOffset = 4,
    Color shadowColor = AppColors.ink,
    Border? customBorder,
  }) =>
      BoxDecoration(
        color: fill,
        border: customBorder ?? border(width: borderWidth),
        borderRadius: corner,
        boxShadow: shadowOffset > 0 ? shadow(offset: shadowOffset, color: shadowColor) : null,
      );

  // versi flat, border doang tanpa shadow — buat list item kecil
  static BoxDecoration flat({Color fill = AppColors.surface, double borderWidth = borderWidthThin}) =>
      BoxDecoration(
        color: fill,
        border: border(width: borderWidth),
        borderRadius: corner,
      );
}
