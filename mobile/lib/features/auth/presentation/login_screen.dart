import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brutal_decorations.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/brutal_button.dart';
import '../../../core/widgets/brutal_text_field.dart';
import 'auth_controller.dart';
import 'biometric_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _isRegister = false;
  // dipencet "Use password instead" -> paksa munculin form biasa walau
  // biometricGateProvider maunya digerbang
  bool _skipBiometricGate = false;
  // flag eksplisit biar snackbar "Account created" cuma muncul abis beneran
  // register, bukan ke-trigger tiap cold start (build() authControllerProvider
  // juga lewat loading->data(null) pas belum login sama sekali)
  bool _justSubmittedRegister = false;

  // syarat kuat kayak password mobile banking, mesti sama persis sama backend
  // (app/schemas/auth.py) biar gak beda validasi
  static final _strongPassword =
      RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[^A-Za-z0-9]).{8,}$');

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _showSnack(String message, {required bool danger}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: danger ? AppColors.danger : AppColors.success,
          content: Text(message, style: AppText.body(13, weight: FontWeight.w600)),
        ),
      );
  }

  Future<void> _submit() async {
    final controller = ref.read(authControllerProvider.notifier);
    if (_isRegister) {
      if (!_strongPassword.hasMatch(_password.text)) {
        _showSnack(
          'Password must have upper & lowercase letters, a number, and a symbol (e.g. !@#\$%).',
          danger: true,
        );
        return;
      }
      if (_password.text != _confirmPassword.text) {
        _showSnack('Password confirmation does not match.', danger: true);
        return;
      }
      _justSubmittedRegister = true;
      await controller.register(_name.text.trim(), _email.text.trim(), _password.text);
    } else {
      await controller.login(_email.text.trim(), _password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    // error backend munculin snackbar, jangan ditelen diem-diem
    ref.listen(authControllerProvider, (previous, next) {
      if (next.hasError && !next.isLoading) {
        _justSubmittedRegister = false;
        _showSnack(next.error.toString(), danger: true);
      } else if (_justSubmittedRegister && !next.isLoading && !next.hasError) {
        // baru aja submit register dan gak error -> sukses, balik ke tab Log In
        _justSubmittedRegister = false;
        setState(() {
          _isRegister = false;
          _password.clear();
          _confirmPassword.clear();
        });
        _showSnack('Account created — log in to continue.', danger: false);
      }
    });

    final gate = ref.watch(biometricGateProvider);

    return Scaffold(
      body: SafeArea(
        child: !_skipBiometricGate && gate.valueOrNull == true
            ? _BiometricGateView(
                onUsePassword: () => setState(() => _skipBiometricGate = true),
              )
            : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('CampusFlow',
                  style: AppText.display(36, weight: FontWeight.w900)
                      .copyWith(letterSpacing: -0.5)),
              const SizedBox(height: 10),
              // garis kuning tebal di bawah wordmark
              Container(
                width: 56,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  border: Brutal.border(width: Brutal.borderWidthThin),
                ),
              ),
              const SizedBox(height: 14),
              Text('Your AI-powered academic planner.',
                  style: AppText.body(14, color: AppColors.inkMuted(0.65))),
              const SizedBox(height: 28),
              _AuthTabs(
                isRegister: _isRegister,
                onChanged: (value) => setState(() => _isRegister = value),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(22),
                decoration: Brutal.box(),
                child: Column(
                  children: [
                    if (_isRegister) ...[
                      BrutalTextField(
                          label: 'Full name', controller: _name, hint: 'Darrell Satriano'),
                      const SizedBox(height: 14),
                    ],
                    BrutalTextField(
                      label: 'Email',
                      controller: _email,
                      hint: 'nama@student.unsri.ac.id',
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),
                    BrutalTextField(
                      label: 'Password',
                      controller: _password,
                      hint: _isRegister
                          ? 'Min 8 chars, upper/lowercase, number & symbol'
                          : 'minimal 8 karakter',
                      obscure: true,
                    ),
                    if (_isRegister) ...[
                      const SizedBox(height: 14),
                      BrutalTextField(
                        label: 'Confirm password',
                        controller: _confirmPassword,
                        hint: 'Re-enter your password',
                        obscure: true,
                      ),
                    ],
                    const SizedBox(height: 20),
                    BrutalButton(
                      label: _isRegister ? 'Create account' : 'Log in',
                      loading: auth.isLoading,
                      onPressed: _submit,
                      fontSize: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _isRegister = !_isRegister),
                  child: RichText(
                    text: TextSpan(
                      style: AppText.body(13, color: AppColors.inkMuted(0.65)),
                      children: [
                        TextSpan(
                            text: _isRegister
                                ? 'Already have an account? '
                                : 'New to CampusFlow? '),
                        TextSpan(
                          text: _isRegister ? 'Log in' : 'Create account',
                          style: AppText.body(13, weight: FontWeight.w700).copyWith(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

// gerbang Face ID, muncul ganti form login kalo ada sesi tersimpen + Face ID nyala
class _BiometricGateView extends ConsumerStatefulWidget {
  const _BiometricGateView({required this.onUsePassword});

  final VoidCallback onUsePassword;

  @override
  ConsumerState<_BiometricGateView> createState() => _BiometricGateViewState();
}

class _BiometricGateViewState extends ConsumerState<_BiometricGateView> {
  bool _authenticating = false;

  Future<void> _unlock() async {
    setState(() => _authenticating = true);
    final ok =
        await ref.read(biometricServiceProvider).authenticate(reason: 'Buka CampusFlow');
    if (!ok) {
      if (mounted) setState(() => _authenticating = false);
      return;
    }

    final restored = await ref.read(authControllerProvider.notifier).restoreSession();
    if (!mounted) return;
    if (restored) return; // isLoggedInProvider otomatis pindah ke /home lewat GoRouter

    // token udah expired -> Face ID gabisa dipake lagi, suruh login manual
    // (jangan gagal diem2 aja)
    setState(() => _authenticating = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text('Session expired — please log in again.',
              style: AppText.body(13, weight: FontWeight.w600)),
        ),
      );
    widget.onUsePassword();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 100, 24, 40),
      child: Column(
        children: [
          Text('CampusFlow',
              style:
                  AppText.display(36, weight: FontWeight.w900).copyWith(letterSpacing: -0.5)),
          const SizedBox(height: 10),
          Container(
            width: 56,
            height: 8,
            decoration: BoxDecoration(
              color: AppColors.accent,
              border: Brutal.border(width: Brutal.borderWidthThin),
            ),
          ),
          const SizedBox(height: 60),
          Container(
            width: 84,
            height: 84,
            alignment: Alignment.center,
            decoration: Brutal.box(fill: AppColors.accent),
            child: const Icon(Icons.face_retouching_natural, size: 40, color: AppColors.ink),
          ),
          const SizedBox(height: 22),
          Text('Welcome back', style: AppText.display(19)),
          const SizedBox(height: 8),
          Text('Unlock with Face ID to continue',
              textAlign: TextAlign.center,
              style: AppText.body(13, color: AppColors.inkMuted(0.65))),
          const SizedBox(height: 32),
          BrutalButton(
            label: 'Unlock with Face ID',
            loading: _authenticating,
            onPressed: _unlock,
            fontSize: 13,
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: widget.onUsePassword,
            child: Text(
              'Use password instead',
              style: AppText.body(13, weight: FontWeight.w700, color: AppColors.inkMuted(0.6))
                  .copyWith(decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}

// 2 tab nyatu dalam 1 kotak berbingkai, dipisah garis
class _AuthTabs extends StatelessWidget {
  const _AuthTabs({required this.isRegister, required this.onChanged});

  final bool isRegister;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, bool active, VoidCallback onTap, {bool divider = false}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: active ? AppColors.ink : AppColors.surface,
              border: divider
                  ? Border(left: BorderSide(color: AppColors.ink, width: Brutal.borderWidth))
                  : null,
            ),
            child: Text(
              label,
              style: AppText.label(13, color: active ? AppColors.bg : AppColors.ink),
            ),
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: Brutal.corner,
      child: Container(
        decoration: BoxDecoration(border: Brutal.border(), borderRadius: Brutal.corner),
        child: Row(
          children: [
            tab('LOG IN', !isRegister, () => onChanged(false)),
            tab('REGISTER', isRegister, () => onChanged(true), divider: true),
          ],
        ),
      ),
    );
  }
}
