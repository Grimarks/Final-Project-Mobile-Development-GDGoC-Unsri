import 'package:campusflow/features/auth/domain/user.dart';
import 'package:campusflow/features/auth/presentation/auth_controller.dart';
import 'package:campusflow/features/courses/data/course_repository.dart';
import 'package:campusflow/features/planner/data/planner_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ganti akun harus bikin data & state planner dimuat ulang, bukan nyisa punya
/// akun sebelumnya.
void main() {
  test('ganti user -> repository dibuat ulang & state planner direset', () async {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_FakeAuth.new),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    final repoA = container.read(courseRepositoryProvider);
    container.read(plannerModeProvider.notifier).select(PlannerMode.chat);
    expect(container.read(plannerModeProvider), PlannerMode.chat);

    (container.read(authControllerProvider.notifier) as _FakeAuth).become(2);

    expect(identical(container.read(courseRepositoryProvider), repoA), isFalse);
    expect(container.read(plannerModeProvider), PlannerMode.none);
  });

  test('user yang sama (misal unlock Face ID) tidak mereset state', () async {
    final container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith(_FakeAuth.new),
    ]);
    addTearDown(container.dispose);
    await container.read(authControllerProvider.future);

    container.read(plannerModeProvider.notifier).select(PlannerMode.adjust);
    (container.read(authControllerProvider.notifier) as _FakeAuth).become(1);

    expect(container.read(plannerModeProvider), PlannerMode.adjust);
  });
}

class _FakeAuth extends AuthController {
  @override
  Future<AppUser?> build() async => _user(1);

  void become(int id) => state = AsyncValue.data(_user(id));

  static AppUser _user(int id) =>
      AppUser.fromJson({'id': id, 'name': 'User $id', 'email': 'u$id@unsri.ac.id'});
}
