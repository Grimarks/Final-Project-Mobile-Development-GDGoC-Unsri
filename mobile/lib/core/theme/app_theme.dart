import 'package:flutter/material.dart';

import 'colors.dart';
import 'text_styles.dart';

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      surface: AppColors.surface,
      error: AppColors.danger,
    ),
    // ripple/elevation material dimatiin, ngerusak tampilan brutalist nya.
    // efek tekan udah ditangani sendiri di BrutalButton
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.bg,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: AppText.display(20),
      iconTheme: const IconThemeData(color: AppColors.ink),
    ),
  );
}
