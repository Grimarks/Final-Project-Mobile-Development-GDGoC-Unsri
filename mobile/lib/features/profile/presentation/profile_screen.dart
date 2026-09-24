import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_card.dart';
import '../../../core/widgets/brutal_text_field.dart';
import '../../../core/widgets/section_header.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/biometric_controller.dart';
import '../../courses/data/course_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).valueOrNull;
    final coursesAsync = ref.watch(courseListProvider);
    final biometric = ref.watch(biometricSettingProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
          children: [
            Text('Profile', style: AppText.display(24)),
            const SizedBox(height: 20),
            BrutalCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    alignment: Alignment.center,
                    decoration: Brutal.flat(fill: AppColors.accent),
                    child: Text(user?.initial ?? '?', style: AppText.display(20)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user?.name ?? 'Guest',
                            style: AppText.display(16, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(user?.email ?? '—',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.body(12,
                                weight: FontWeight.w600,
                                color: AppColors.inkMuted(0.55))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader('Courses'),
            const SizedBox(height: 12),
            coursesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.ink)),
              error: (error, _) => Text(error.toString(), style: AppText.body(12.5)),
              data: (courses) => Column(
                children: [
                  for (final course in courses) ...[
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                      decoration: Brutal.flat(),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: course.color,
                              border: Brutal.border(width: Brutal.borderWidthThin),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(course.name,
                                style: AppText.body(13.5, weight: FontWeight.w600)),
                          ),
                          GestureDetector(
                            onTap: () =>
                                ref.read(courseListProvider.notifier).remove(course.id),
                            child: Icon(Icons.close,
                                size: 18, color: AppColors.inkMuted(0.45)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  GestureDetector(
                    onTap: () => _showAddCourse(context, ref),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: Brutal.corner,
                        border: Border.all(
                            color: AppColors.inkMuted(0.5),
                            width: Brutal.borderWidthThin),
                      ),
                      child: Text('+ Add course',
                          style: AppText.body(12,
                              weight: FontWeight.w700,
                              color: AppColors.inkMuted(0.6))),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader('Materials'),
            const SizedBox(height: 12),
            BrutalCard(
              onTap: () => context.push('/materials'),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: Brutal.flat(fill: AppColors.accent),
                    child: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.ink),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Upload notes, get AI summaries & quizzes',
                        style: AppText.body(13, weight: FontWeight.w600)),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.inkMuted(0.5)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeader('Account'),
            const SizedBox(height: 12),
            BrutalCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _AccountRow(
                    label: 'Edit profile',
                    onTap: () => _showEditProfile(
                        context, ref, user?.name ?? '', user?.email ?? ''),
                  ),
                  Container(height: 1, color: AppColors.ink.withOpacity(0.12)),
                  _AccountRow(
                    label: 'Change password',
                    onTap: () => _showChangePassword(context, ref),
                  ),
                  Container(height: 1, color: AppColors.ink.withOpacity(0.12)),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('${biometricLabel()[0].toUpperCase()}${biometricLabel().substring(1)} login',
                              style: AppText.body(13.5, weight: FontWeight.w700)),
                        ),
                        biometric.when(
                          data: (enabled) => _BrutalSwitch(
                            value: enabled,
                            onChanged: (value) async {
                              try {
                                await ref
                                    .read(biometricSettingProvider.notifier)
                                    .toggle(value);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context)
                                    ..hideCurrentSnackBar()
                                    ..showSnackBar(
                                      SnackBar(
                                        backgroundColor: AppColors.danger,
                                        content: Text(
                                            e.toString().replaceFirst('Exception: ', ''),
                                            style: AppText.body(13, weight: FontWeight.w600)),
                                      ),
                                    );
                                }
                              }
                            },
                          ),
                          loading: () => const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink),
                          ),
                          error: (_, __) =>
                              const Icon(Icons.error_outline, size: 20, color: AppColors.danger),
                        ),
                      ],
                    ),
                  ),
                  if (biometric.valueOrNull == true) ...[
                    Container(height: 1, color: AppColors.ink.withOpacity(0.12)),
                    _AccountRow(
                      label: 'Lock app (unlock with ${biometricLabel()})',
                      onTap: () => ref.read(authControllerProvider.notifier).lock(),
                    ),
                  ],
                  Container(height: 1, color: AppColors.ink.withOpacity(0.12)),
                  _AccountRow(
                    label: 'Send test notification (5s)',
                    onTap: () async {
                      await ref
                          .read(notificationServiceProvider)
                          .scheduleTestNotification(const Duration(seconds: 5));
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.success,
                              content: Text('Notification scheduled in 5 seconds.',
                                  style: AppText.body(13, weight: FontWeight.w600)),
                            ),
                          );
                      }
                    },
                  ),
                  Container(height: 1, color: AppColors.ink.withOpacity(0.12)),
                  _AccountRow(
                    label: 'Log out',
                    color: AppColors.danger,
                    onTap: () => ref.read(authControllerProvider.notifier).logout(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.label, required this.onTap, this.color});

  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
        child: Text(label,
            style: AppText.body(13.5,
                weight: FontWeight.w700, color: color ?? AppColors.ink)),
      ),
    );
  }
}

// toggle brutalist, kotak siku + border, bukan pill material
class _BrutalSwitch extends StatelessWidget {
  const _BrutalSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: 46,
        height: 26,
        padding: const EdgeInsets.all(2),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? AppColors.primary : AppColors.surface,
          border: Brutal.border(width: Brutal.borderWidthThin),
        ),
        child: Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: value ? Colors.white : AppColors.ink,
            border: Brutal.border(width: 1),
          ),
        ),
      ),
    );
  }
}

Future<void> _showEditProfile(
    BuildContext context, WidgetRef ref, String currentName, String currentEmail) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withOpacity(0.55),
    builder: (_) => _EditProfileDialog(currentName: currentName, currentEmail: currentEmail),
  );
}

Future<void> _showChangePassword(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withOpacity(0.55),
    builder: (_) => const _ChangePasswordDialog(),
  );
}

class _EditProfileDialog extends ConsumerStatefulWidget {
  const _EditProfileDialog({required this.currentName, required this.currentEmail});

  final String currentName;
  final String currentEmail;

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  late final _name = TextEditingController(text: widget.currentName);
  late final _email = TextEditingController(text: widget.currentEmail);
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final email = _email.text.trim();
    if (name.isEmpty || email.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).updateProfile(name, email: email);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(e.toString(), style: AppText.body(13)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: Brutal.box(shadowOffset: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Edit Profile', style: AppText.display(19)),
                  const SizedBox(height: 16),
                  BrutalTextField(label: 'Name', controller: _name),
                  const SizedBox(height: 14),
                  BrutalTextField(
                    label: 'Email',
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: BrutalButton(
                          label: 'Cancel',
                          fill: AppColors.surface,
                          labelColor: AppColors.ink,
                          fontSize: 12,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: BrutalButton(
                          label: 'Save',
                          fontSize: 12,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(message, style: AppText.body(13)),
      ),
    );
  }

  Future<void> _save() async {
    if (_current.text.isEmpty || _next.text.isEmpty) {
      _showError('Isi semua field');
      return;
    }
    if (_next.text.length < 8) {
      _showError('Password baru minimal 8 karakter');
      return;
    }
    if (_next.text != _confirm.text) {
      _showError('Konfirmasi password tidak cocok');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(authControllerProvider.notifier).changePassword(
            currentPassword: _current.text,
            newPassword: _next.text,
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _showError(e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: Brutal.box(shadowOffset: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Change Password', style: AppText.display(19)),
                  const SizedBox(height: 16),
                  BrutalTextField(
                      label: 'Current password', controller: _current, obscure: true),
                  const SizedBox(height: 14),
                  BrutalTextField(
                      label: 'New password', controller: _next, obscure: true),
                  const SizedBox(height: 14),
                  BrutalTextField(
                      label: 'Confirm new password', controller: _confirm, obscure: true),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: BrutalButton(
                          label: 'Cancel',
                          fill: AppColors.surface,
                          labelColor: AppColors.ink,
                          fontSize: 12,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: BrutalButton(
                          label: 'Save',
                          fontSize: 12,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showAddCourse(BuildContext context, WidgetRef ref) {
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.ink.withOpacity(0.55),
    builder: (_) => const _AddCourseDialog(),
  );
}

class _AddCourseDialog extends ConsumerStatefulWidget {
  const _AddCourseDialog();

  @override
  ConsumerState<_AddCourseDialog> createState() => _AddCourseDialogState();
}

class _AddCourseDialogState extends ConsumerState<_AddCourseDialog> {
  final _name = TextEditingController();
  Color _color = AppColors.primary;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref
          .read(courseListProvider.notifier)
          .add(_name.text.trim(), AppColors.toHex(_color));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(e.toString(), style: AppText.body(13)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: Brutal.box(shadowOffset: 6),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Add Course', style: AppText.display(19)),
                  const SizedBox(height: 16),
                  BrutalTextField(
                      label: 'Name',
                      controller: _name,
                      hint: 'e.g. IF3110 — Basis Data'),
                  const SizedBox(height: 16),
                  Text('COLOR',
                      style: AppText.body(11, weight: FontWeight.w700)
                          .copyWith(letterSpacing: 0.5)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final color in AppColors.coursePalette) ...[
                        GestureDetector(
                          onTap: () => setState(() => _color = color),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: Brutal.corner,
                              border: Brutal.border(
                                width: _color == color ? 3 : 2,
                                color: _color == color
                                    ? AppColors.ink
                                    : AppColors.inkMuted(0.25),
                              ),
                              boxShadow: _color == color
                                  ? Brutal.shadow(offset: 2)
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: BrutalButton(
                          label: 'Cancel',
                          fill: AppColors.surface,
                          labelColor: AppColors.ink,
                          fontSize: 12,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: BrutalButton(
                          label: 'Save course',
                          fontSize: 12,
                          loading: _saving,
                          onPressed: _save,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
