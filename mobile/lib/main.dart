import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/local_cache.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCache.init(); // buka box Hive sebelum widget pertama dibangun
  runApp(const ProviderScope(child: CampusFlowApp()));
}

class CampusFlowApp extends ConsumerWidget {
  const CampusFlowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'CampusFlow',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
