import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../../router.dart';
import '../widgets/artisan_widgets.dart';

class ArtisanLoginScreen extends ConsumerStatefulWidget {
  const ArtisanLoginScreen({super.key});

  @override
  ConsumerState<ArtisanLoginScreen> createState() => _ArtisanLoginScreenState();
}

class _ArtisanLoginScreenState extends ConsumerState<ArtisanLoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _hidden = true;
  bool _loading = false;

  static const _demo = [
    ('Gülarə · keramika', '+994501110001'),
    ('Əli · xalça', '+994501110002'),
    ('Rəşid · mis', '+994501110004'),
    ('Nüsrət · ağac', '+994501110005'),
    ('Koordinator', '+994501110009'),
  ];

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_phone.text.trim().isEmpty || _password.text.isEmpty) {
      showToast('Telefon və parolu yazın', kind: ToastKind.error, large: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final auth = await ref.read(authProvider.notifier).login(_phone.text, _password.text);
      if (!auth.isArtisan && !auth.isCoordinator) {
        ref.read(authProvider.notifier).logout();
        showToast('Bu hesab usta hesabı deyil', kind: ToastKind.error, large: true);
      } else if (mounted) {
        // Coordinators land on their own dashboard.
        context.go(auth.isCoordinator ? Routes.coordinator : Routes.usta);
      }
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.soft,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: AppButton(
                        label: 'Mağaza',
                        icon: Icons.arrow_back_rounded,
                        variant: BtnVariant.ghost,
                        onPressed: () => context.go(Routes.home),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Center(child: AppLogo(size: 64, showText: false)),
                    const SizedBox(height: 20),
                    Text('Xoş gəlmisiniz!', textAlign: TextAlign.center, style: AppText.aH1),
                    const SizedBox(height: 8),
                    Text(
                      'Telefon nömrənizi və parolunuzu yazın.',
                      textAlign: TextAlign.center,
                      style: AppText.aBody.copyWith(color: AppColors.ink2),
                    ),
                    const SizedBox(height: 28),
                    AppCard(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextField(
                            controller: _phone,
                            artisan: true,
                            label: 'Telefon',
                            hint: '+994 50 111 00 01',
                            prefixIcon: Icons.phone_rounded,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.telephoneNumber],
                          ),
                          const SizedBox(height: 18),
                          AppTextField(
                            controller: _password,
                            artisan: true,
                            label: 'Parol',
                            hint: '••••••',
                            prefixIcon: Icons.lock_rounded,
                            obscureText: _hidden,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _login(),
                            suffix: IconButton(
                              tooltip: _hidden ? 'Parolu göstər' : 'Parolu gizlət',
                              icon: Icon(
                                _hidden ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                                size: 26,
                              ),
                              onPressed: () => setState(() => _hidden = !_hidden),
                            ),
                          ),
                          const SizedBox(height: 24),
                          AppButton(
                            label: 'Daxil ol',
                            icon: Icons.login_rounded,
                            size: BtnSize.xl,
                            loading: _loading,
                            onPressed: _login,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppButton(
                      label: 'Usta kimi qeydiyyat',
                      icon: Icons.person_add_alt_1_rounded,
                      variant: BtnVariant.outline,
                      size: BtnSize.lg,
                      expand: true,
                      onPressed: () => context.go(Routes.ustaRegister),
                    ),
                    if (AppConfig.showDemoAccounts) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Demo hesablar', style: AppText.aLabel),
                            const SizedBox(height: 4),
                            Text('Basın — məlumatlar avtomatik yazılacaq.', style: AppText.aHint),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final (label, phone) in _demo)
                                  AppChip(
                                    label: label,
                                    large: true,
                                    icon: Icons.person_rounded,
                                    onTap: () => setState(() {
                                      _phone.text = phone;
                                      _password.text = 'demo123';
                                    }),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
