import 'package:flutter/material.dart';

// sumber warna tunggal, sesuai Design.md
class AppColors {
  const AppColors._();

  static const Color bg = Color(0xFFF5F1E8); // warm off-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF0D0D0D); // teks + SEMUA border
  static const Color primary = Color(0xFF4C6FFF); // electric blue
  static const Color accent = Color(0xFFFFD23F); // kuning — penanda AI
  static const Color danger = Color(0xFFFF4C4C);
  static const Color success = Color(0xFF3DDC84);
  static const Color warning = Color(0xFFFF8A3D);

  // teks sekunder tetep ink + opacity, bukan abu2 baru
  static Color inkMuted([double opacity = 0.55]) => ink.withOpacity(opacity);

  // pilihan warna buat matkul

  static const List<Color> coursePalette = [
    primary,
    accent,
    danger,
    success,
    warning,
  ];

  static Color fromHex(String? hex, {Color fallback = primary}) {
    if (hex == null) return fallback;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length != 6) return fallback;
    final value = int.tryParse(cleaned, radix: 16);
    return value == null ? fallback : Color(0xFF000000 | value);
  }

  static String toHex(Color color) =>
      '#${color.value.toRadixString(16).substring(2).toUpperCase()}';
}
