import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/form_fields.dart';
import '../data/auth_controller.dart';

/// Forced password change.
///
/// The server sets `must_change_password` when an account is created and on every
/// administrator reset, and `authenticate` now refuses every request except
/// `/auth/me`, `/auth/change-password` and `/auth/logout` while it is set. This
/// screen is the way out — the router sends the user here and keeps them here
/// until the new password is accepted.
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  /// Mirrors the server's rule in auth.routes.js so the user is told before the
  /// round trip rather than after it.
  String? _validateNew(String? value) {
    if (value == null || value.isEmpty) return 'Choose a new password';
    if (value.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(value)) return 'Include at least one letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'Include at least one digit';
    if (value == _currentController.text) return 'The new password must differ from the current one';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authControllerProvider.notifier).changePassword(
          currentPassword: _currentController.text,
          newPassword: _newController.text,
        );
    // On success the profile refreshes with mustChangePassword false and the
    // router moves on; a failure surfaces through auth.error.
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
                child: Material(
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  elevation: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [_header(auth), _form(auth)],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AuthState auth) => Container(
        width: double.infinity,
        color: AppColors.brand,
        padding: const EdgeInsets.fromLTRB(28, 26, 28, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.lock_reset_rounded, color: Colors.white, size: 22),
                SizedBox(width: Insets.sm),
                Text(
                  'Set a new password',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Insets.sm),
            Text(
              auth.user == null
                  ? 'Your password must be changed before you can continue.'
                  : '${auth.user!.fullName}, your password must be changed before you can '
                      'continue. Everything else stays locked until then.',
              style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.45),
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
                label: 'Current password',
                child: AppTextField(
                  controller: _currentController,
                  hintText: '••••••••',
                  prefixIcon: Icons.lock_outline_rounded,
                  obscureText: _obscure,
                  autofocus: true,
                  enabled: !auth.isBusy,
                  onChanged: (_) => ref.read(authControllerProvider.notifier).clearError(),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter the password you signed in with' : null,
                ),
              ),
              const SizedBox(height: Insets.lg),
              LabeledField(
                label: 'New password',
                child: AppTextField(
                  controller: _newController,
                  hintText: 'At least 8 characters, with a letter and a digit',
                  prefixIcon: Icons.key_outlined,
                  obscureText: _obscure,
                  enabled: !auth.isBusy,
                  onChanged: (_) => ref.read(authControllerProvider.notifier).clearError(),
                  validator: _validateNew,
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                      color: AppColors.muted,
                    ),
                    tooltip: _obscure ? 'Show passwords' : 'Hide passwords',
                  ),
                ),
              ),
              const SizedBox(height: Insets.lg),
              LabeledField(
                label: 'Confirm new password',
                child: AppTextField(
                  controller: _confirmController,
                  hintText: '••••••••',
                  prefixIcon: Icons.check_circle_outline_rounded,
                  obscureText: _obscure,
                  enabled: !auth.isBusy,
                  onChanged: (_) => ref.read(authControllerProvider.notifier).clearError(),
                  validator: (v) => v != _newController.text ? 'The two passwords do not match' : null,
                  onSubmitted: (_) => _submit(),
                ),
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
                      : const Text('Update password'),
                ),
              ),
              const SizedBox(height: Insets.md),
              Center(
                child: TextButton(
                  onPressed: auth.isBusy
                      ? null
                      : () => ref.read(authControllerProvider.notifier).logout(),
                  child: const Text('Sign out instead', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ],
          ),
        ),
      );
}
