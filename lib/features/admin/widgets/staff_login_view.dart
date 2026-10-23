import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers.dart';
import '../../../core/config.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../../router.dart' show Routes;

/// A debug-only shortcut that fills the form.
class DemoAccount {
  const DemoAccount(this.label, this.icon, this.email, this.password);

  final String label;
  final IconData icon;
  final String email;
  final String password;
}

/// Centred email + password card shared by the admin/expert and ministry
/// sign-in pages. Signs out again (with [deniedMessage]) when the account's
/// role fails [allowed]; otherwise goes to [landingOf].
class StaffLoginView extends ConsumerStatefulWidget {
  const StaffLoginView({
    super.key,
    required this.title,
    required this.subtitle,
    required this.allowed,
    required this.landingOf,
    required this.deniedMessage,
    this.emailHint = 'name@cultech.az',
    this.demoAccounts = const [],
  });

  final String title;
  final String subtitle;
  final bool Function(AuthState) allowed;
  final String Function(AuthState) landingOf;
  final String deniedMessage;
  final String emailHint;

  /// Only shown in debug builds.
  final List<DemoAccount> demoAccounts;

  @override
  ConsumerState<StaffLoginView> createState() => _StaffLoginViewState();
}

class _StaffLoginViewState extends ConsumerState<StaffLoginView> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _fillDemo(DemoAccount a) {
    setState(() {
      _email.text = a.email;
      _password.text = a.password;
    });
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      showToast('Enter your email and password', kind: ToastKind.error);
      return;
    }
    setState(() => _busy = true);
    final auth = ref.read(authProvider.notifier);
    try {
      final state = await auth.login(email, password);
      if (!widget.allowed(state)) {
        auth.logout();
        showToast(widget.deniedMessage, kind: ToastKind.error);
        return;
      }
      showToast(state.name.isEmpty ? 'Signed in' : 'Welcome, ${state.name}', kind: ToastKind.ok);
      if (mounted) context.go(widget.landingOf(state));
    } catch (e) {
      showToast(
        errorText(
          e,
          network: "Can't reach the server.",
          fallback: 'Sign-in failed. Check your email and password.',
        ),
        kind: ToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 480;
    return Scaffold(
      backgroundColor: AppColors.soft,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    padding: EdgeInsets.all(narrow ? 22 : 32),
                    child: AutofillGroup(child: _form(narrow)),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton.icon(
                      onPressed: () => context.go(Routes.home),
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back to the storefront'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _form(bool narrow) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(alignment: Alignment.centerLeft, child: AppLogo(size: 38, textSize: 16)),
        const SizedBox(height: 28),
        Text(widget.title, style: AppText.display(narrow ? 23 : 27, weight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(widget.subtitle, style: AppText.bodyS),
        const SizedBox(height: 26),
        AppTextField(
          controller: _email,
          label: 'Email',
          hint: widget.emailHint,
          prefixIcon: Icons.mail_outline_rounded,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email, AutofillHints.username],
        ),
        const SizedBox(height: 16),
        AppTextField(
          controller: _password,
          label: 'Password',
          hint: 'Your password',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: _obscure,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.password],
          onSubmitted: (_) => _submit(),
          suffix: IconButton(
            tooltip: _obscure ? 'Show password' : 'Hide password',
            onPressed: () => setState(() => _obscure = !_obscure),
            icon: Icon(
              _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              color: AppColors.muted,
              size: 20,
            ),
          ),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Sign in',
          icon: Icons.login_rounded,
          size: BtnSize.lg,
          expand: true,
          loading: _busy,
          onPressed: _busy ? null : _submit,
        ),
        if (AppConfig.showDemoAccounts && widget.demoAccounts.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Demo accounts',
            style: AppText.body(12.5, weight: FontWeight.w800, color: AppColors.muted),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in widget.demoAccounts)
                AppChip(label: a.label, icon: a.icon, onTap: () => _fillDemo(a)),
            ],
          ),
        ],
      ],
    );
  }
}
