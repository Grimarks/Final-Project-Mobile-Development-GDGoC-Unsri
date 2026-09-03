import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'colors.dart';

// 2 font aja: Space Grotesk buat display/heading/angka, Inter buat body & form
class AppText {
  const AppText._();

  static TextStyle display(double size, {FontWeight weight = FontWeight.w800, Color? color}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink,
        height: 1.15,
      );

  static TextStyle body(double size, {FontWeight weight = FontWeight.w500, Color? color}) =>
      GoogleFonts.inter(
        fontSize: size,
        fontWeight: weight,
        color: color ?? AppColors.ink,
        height: 1.45,
      );

  // label kapital, buat tombol/chip/judul seksi
  static TextStyle label(double size, {Color? color, FontWeight weight = FontWeight.w800}) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: 0.5,
        color: color ?? AppColors.ink,
      );
}
