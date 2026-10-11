import 'package:flutter/material.dart';

import '../theme/brutal_decorations.dart';

// logo CampusFlow (sama dengan ikon app) dalam bingkai neo-brutalism.
// sumbernya branding/logo.svg -> assets/icon/app_icon.png
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 56});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: Brutal.box(shadowOffset: size / 14),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/icon/app_icon.png',
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        semanticLabel: 'CampusFlow',
      ),
    );
  }
}
