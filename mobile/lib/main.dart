import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/network/api_client.dart';
import 'core/network/local_cache.dart';
import 'core/notifications/notification_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalCache.init(); // buka box Hive sebelum widget pertama dibangun
  final container = ProviderContainer();
  // minta izin notif sekali di awal, gak di-await biar gak nahan frame pertama
  container.read(notificationServiceProvider).init();
  // server gratisan (Render) tidur kalo lama nganggur & butuh ±1 menit buat bangun.
  // colek dari sekarang, biar pas user kelar ngetik login server-nya udah melek
  container.read(apiClientProvider).get<dynamic>('/health').ignore();
  runApp(UncontrolledProviderScope(container: container, child: const CampusFlowApp()));
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
