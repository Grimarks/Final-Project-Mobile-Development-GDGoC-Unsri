import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/home_screen.dart';
import '../../features/materials/presentation/materials_screen.dart';
import '../../features/planner/presentation/planner_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/study_session/presentation/study_screen.dart';
import '../../features/tasks/presentation/tasks_screen.dart';
import '../widgets/brutal_bottom_nav.dart';

// router tunggal, redirect ngikutin authControllerProvider — jadi logout
// otomatis balik ke /login tanpa perlu navigasi manual
final appRouterProvider = Provider<GoRouter>((ref) {
  final navigatorKey = GlobalKey<NavigatorState>();

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/login',
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final loggedIn = ref.read(isLoggedInProvider);
      final atLogin = state.matchedLocation == '/login';

      if (!loggedIn) return atLogin ? null : '/login';
      if (atLogin) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      // biar bottom nav-nya nempel terus di semua tab utama
      ShellRoute(
        builder: (context, state, child) => _NavShell(state: state, child: child),
        routes: [
          GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
          GoRoute(path: '/tasks', builder: (_, __) => const TasksScreen()),
          GoRoute(path: '/planner', builder: (_, __) => const PlannerScreen()),
          GoRoute(
            path: '/study',
            // ada ?taskId=<id> -> mulai sesi task itu (dari tap kartu Home)
            // gaada -> ambil task terbuka prioritas tertinggi (tab Study langsung)
            builder: (_, state) => StudyScreen(
              taskId: int.tryParse(state.uri.queryParameters['taskId'] ?? ''),
            ),
          ),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          // ini bukan tab bottom nav, masuknya dari kartu "Materials" di Profile
          GoRoute(path: '/materials', builder: (_, __) => const MaterialsScreen()),
        ],
      ),
    ],
  );
});

class _NavShell extends StatelessWidget {
  const _NavShell({required this.state, required this.child});

  final GoRouterState state;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: BrutalBottomNav(currentPath: state.matchedLocation),
    );
  }
}

// nyambungin riverpod ke go_router biar redirect ke-refresh tiap status login berubah
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(isLoggedInProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}
