import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/form_fields.dart';
import '../data/auth_controller.dart';

/// The single sign-in screen from the deck: CNH mark, credentials, and a note
/// that the role decides everything that follows.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _remember = true;

  @override
  void initState() {
    super.initState();
    // Pre-fill the last username so a shared shop-floor tablet needs one field.
    final remembered = ref.read(authRepositoryProvider).rememberedUsername;
    if (remembered != null) _usernameController.text = remembered;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).login(
          username: _usernameController.text,
          password: _passwordController.text,
          remember: _remember,
        );
    // The router redirects on success; a failure surfaces through auth.error.
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.loginTop, AppColors.loginMid, AppColors.loginEnd],
            stops: [0.0, 0.6, 1.0],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Insets.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 410),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Material(
                      borderRadius: BorderRadius.circular(16),
                      clipBehavior: Clip.antiAlias,
                      elevation: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [_header(), _form(auth)],
                      ),
                    ),
                    const SizedBox(height: Insets.xl),
                    Text(
                      '${AppConfig.appName} · ${AppConfig.plantName}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Built by ${AppConfig.vendor}',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() => Container(
        width: double.infinity,
        color: AppColors.navBg,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 26),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'CNH',
                style: TextStyle(
                  color: AppColors.navBg,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  fontSize: 24,
                ),
              ),
            ),
            const SizedBox(height: Insets.md),
            const Text(
              'Tool Management System',
              style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 3),
            Text(
              'PUNE PLANT · SECURE LOGIN',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 11,
                letterSpacing: 1.4,
              ),
            ),
          ],
        ),
      );

  Widget _form(AuthState auth) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (auth.error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.redSoft,
                    border: Border.all(color: const Color(0xFFF0C4C4)),
                    borderRadius: BorderRadius.circular(Insets.radiusSm),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.redInk),
                      const SizedBox(width: Insets.sm),
                      Expanded(
                        child: Text(
                          auth.error!,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.redInk,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: Insets.lg),
              ],
              LabeledField(
                label: 'Username',
                child: AppTextField(
                  controller: _usernameController,
                  hintText: 'e.g. rahul.k',
                  prefixIcon: Icons.person_outline_rounded,
                  autofocus: true,
                  enabled: !auth.isBusy,
                  onChanged: (_) => ref.read(authControllerProvider.notifier).clearError(),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
                  onSubmitted: (_) => _submit(),
                ),
              ),
              const SizedBox(height: Insets.lg),
              LabeledField(
                label: 'Password',
                child: AppTextField(
                  controller: _passwordController,
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  enabled: !auth.isBusy,
                  onChanged: (_) => ref.read(authControllerProvider.notifier).clearError(),
                  validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  onSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                  ),
                ),
              ),
              const SizedBox(height: Insets.md),
              Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: Checkbox(
                      value: _remember,
                      onChanged: auth.isBusy ? null : (v) => setState(() => _remember = v ?? true),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                  const SizedBox(width: Insets.sm),
                  const Text(
                    'Remember my username on this device',
                    style: TextStyle(fontSize: 12.5, color: AppColors.label),
                  ),
                ],
              ),
              const SizedBox(height: Insets.xl),
              SizedBox(
                height: 46,
                child: FilledButton(
                  onPressed: auth.isBusy ? null : _submit,
                  child: auth.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Sign In', style: TextStyle(fontSize: 14.5)),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 17),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              Text(
                'Your role decides which of the nine modules you see.\n'
                'Contact the tool room administrator for access changes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.muted,
                  height: 1.5,
                  letterSpacing: context.isMobile ? 0 : 0.1,
                ),
              ),
            ],
          ),
        ),
      );
}
