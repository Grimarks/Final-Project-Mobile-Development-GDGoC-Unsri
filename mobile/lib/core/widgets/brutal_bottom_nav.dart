import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/colors.dart';
import '../theme/brutal_decorations.dart';
import '../theme/text_styles.dart';

// bottom nav 5 tab: home, tasks, ai, study, profile. border atas doang, no elevation
class BrutalBottomNav extends StatelessWidget {
  const BrutalBottomNav({super.key, required this.currentPath});

  final String currentPath;

  static const _items = [
    ('/home', 'HOME', Icons.home_outlined),
    ('/tasks', 'TASKS', Icons.checklist_outlined),
    ('/planner', 'AI', Icons.bolt_outlined),
    ('/study', 'STUDY', Icons.timer_outlined),
    ('/profile', 'PROFILE', Icons.person_outline),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(color: AppColors.ink, width: Brutal.borderWidth),
        ),
      ),
      padding: const EdgeInsets.only(top: 9, bottom: 8, left: 6, right: 6),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final (path, label, icon) in _items)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.go(path),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 21, color: _colorFor(path)),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: AppText.body(10,
                            weight: FontWeight.w700, color: _colorFor(path)),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // tab aktif full item, yang lain redup 40%
  Color _colorFor(String path) =>
      currentPath == path ? AppColors.ink : AppColors.inkMuted(0.4);
}
