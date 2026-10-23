import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/config.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../widgets/buyer_common.dart';
import '../widgets/want_sheet.dart';
import 'phase2_widgets.dart';

/// "For business" landing for guests: benefits + sign in / create account.
class B2bLanding extends ConsumerWidget {
  const B2bLanding({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final wide = MediaQuery.sizeOf(context).width >= 960;
    final intro = PageIntro(
      icon: Icons.business_center_rounded,
      eyebrow: t('b2b.eyebrow'),
      title: t('b2b.title'),
      accent: t('b2b.titleAccent'),
      subtitle: t('b2b.sub'),
    );
    return BuyerPage(
      children: [
        const SizedBox(height: 8),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 11,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [intro, const SizedBox(height: 28), const _Benefits()],
                ),
              ),
              const SizedBox(width: 40),
              const Expanded(flex: 9, child: _AuthCard()),
            ],
          )
        else ...[
          intro,
          const SizedBox(height: 24),
          const _Benefits(),
          const SizedBox(height: 24),
          const _AuthCard(),
        ],
      ],
    );
  }
}

class _Benefits extends ConsumerWidget {
  const _Benefits();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final tiers = ref.watch(configOrEmptyProvider).tiers;
    final tiles = [
      (
        Icons.sell_rounded,
        t('b2b.benefit.volume.t'),
        t('b2b.benefit.volume.d'),
        tiers.isEmpty
            ? null
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final x in tiers)
                    AppBadge(
                      t('group.tier', {'n': x.min, 'p': x.percent}),
                      variant: BadgeVariant.gold,
                    ),
                ],
              ),
      ),
      (Icons.local_shipping_rounded, t('b2b.benefit.ship.t'), t('b2b.benefit.ship.d'), null),
      (Icons.request_quote_rounded, t('b2b.benefit.quote.t'), t('b2b.benefit.quote.d'), null),
      (Icons.replay_rounded, t('b2b.benefit.reorder.t'), t('b2b.benefit.reorder.d'), null),
    ];
    return ResponsiveWrap(
      minItemWidth: 250,
      maxCols: 2,
      spacing: 14,
      children: [
        for (final (icon, title, desc, extra) in tiles)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.soft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconCircle(icon: icon, size: 44),
                const SizedBox(height: 12),
                Text(title, style: AppText.body(16, weight: FontWeight.w800, height: 1.25)),
                const SizedBox(height: 4),
                Text(desc, style: AppText.body(13.5, color: AppColors.muted, height: 1.45)),
                if (extra != null) ...[const SizedBox(height: 10), extra],
              ],
            ),
          ),
      ],
    );
  }
}

class _AuthCard extends ConsumerStatefulWidget {
  const _AuthCard();

  @override
  ConsumerState<_AuthCard> createState() => _AuthCardState();
}

class _AuthCardState extends ConsumerState<_AuthCard> {
  static const _demoEmail = 'b2b@hotel-berlin.example';
  static const _demoPassword = 'b2b123';

  int _mode = 0;
  bool _busy = false;
  bool _showPassword = false;

  final _loginForm = GlobalKey<FormState>();
  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();

  final _regForm = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  String? _country;
  Label? _type;

  @override
  void initState() {
    super.initState();
    _country = ref.read(sharedPrefsProvider).getString(countryPrefKey);
  }

  @override
  void dispose() {
    for (final c in [_loginEmail, _loginPassword, _company, _name, _email, _password, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fail(Object e) {
    final t = ref.read(tProvider);
    showToast(
      errorText(e, network: t('common.network'), fallback: t('common.error')),
      kind: ToastKind.error,
    );
  }

  Future<void> _login() async {
    final t = ref.read(tProvider);
    if (!(_loginForm.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    try {
      final auth = ref.read(authProvider.notifier);
      final res = await auth.login(_loginEmail.text, _loginPassword.text);
      if (res.role != 'b2b') {
        auth.logout();
        showToast(t('b2b.notBusiness'), kind: ToastKind.error);
        return;
      }
      showToast(t('b2b.welcome', {'name': res.company ?? res.name}), kind: ToastKind.ok);
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    final t = ref.read(tProvider);
    if (!(_regForm.currentState?.validate() ?? false) || _country == null) return;
    setState(() => _busy = true);
    try {
      final res = await ref.read(authProvider.notifier).registerB2b({
        'company': _company.text.trim(),
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'password': _password.text,
        'country': _country,
        'type': _type?.id,
        'phone': _phone.text.trim(),
      });
      showToast(
        t('b2b.welcome', {'name': res.company ?? _company.text.trim()}),
        kind: ToastKind.ok,
      );
    } catch (e) {
      _fail(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t('b2b.auth.title'), style: AppText.h3),
          const SizedBox(height: 4),
          Text(t('b2b.auth.sub'), style: AppText.bodyS),
          const SizedBox(height: 18),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppSegmented<int>(
              value: _mode,
              options: [(0, t('b2b.signIn')), (1, t('b2b.register'))],
              onChanged: (v) => setState(() => _mode = v),
            ),
          ),
          const SizedBox(height: 20),
          AnimatedSize(
            duration: AppMotion.of(context, AppMotion.base),
            curve: AppMotion.curve,
            alignment: AlignmentDirectional.topStart,
            child: _mode == 0 ? _signIn(t) : _registerForm(t),
          ),
        ],
      ),
    );
  }

  Widget _signIn(S t) {
    return Form(
      key: _loginForm,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _loginEmail,
              label: t('b2b.workEmail'),
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email, AutofillHints.username],
              textInputAction: TextInputAction.next,
              validator: (v) => isValidEmail(v ?? '') ? null : t('common.invalidEmail'),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _loginPassword,
              label: t('b2b.password'),
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.password],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _login(),
              suffix: _VisibilityToggle(
                visible: _showPassword,
                tooltip: t('b2b.showPassword'),
                onTap: () => setState(() => _showPassword = !_showPassword),
              ),
              validator: (v) => (v ?? '').isEmpty ? t('common.required') : null,
            ),
            const SizedBox(height: 18),
            AppButton(
              label: t('b2b.signInCta'),
              icon: Icons.login_rounded,
              size: BtnSize.lg,
              expand: true,
              loading: _busy,
              onPressed: _login,
            ),
            if (AppConfig.showDemoAccounts) ...[
              const SizedBox(height: 14),
              Center(
                child: AppChip(
                  label: t('b2b.demo', {'email': _demoEmail}),
                  icon: Icons.bolt_rounded,
                  onTap: () => setState(() {
                    _loginEmail.text = _demoEmail;
                    _loginPassword.text = _demoPassword;
                  }),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _registerForm(S t) {
    final config = ref.watch(configOrEmptyProvider);
    final lang = ref.watch(langProvider);
    String? required(String? v) => (v == null || v.trim().isEmpty) ? t('common.required') : null;
    return Form(
      key: _regForm,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _company,
              label: t('gifts.company'),
              prefixIcon: Icons.apartment_rounded,
              autofillHints: const [AutofillHints.organizationName],
              textCapitalization: TextCapitalization.words,
              validator: required,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _name,
              label: t('b2b.contactName'),
              prefixIcon: Icons.person_outline_rounded,
              autofillHints: const [AutofillHints.name],
              textCapitalization: TextCapitalization.words,
              validator: required,
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _email,
              label: t('b2b.workEmail'),
              prefixIcon: Icons.mail_outline_rounded,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              validator: (v) => isValidEmail(v ?? '') ? null : t('common.invalidEmail'),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: _password,
              label: t('b2b.password'),
              prefixIcon: Icons.lock_outline_rounded,
              obscureText: !_showPassword,
              autofillHints: const [AutofillHints.newPassword],
              helper: t('b2b.passwordHint'),
              suffix: _VisibilityToggle(
                visible: _showPassword,
                tooltip: t('b2b.showPassword'),
                onTap: () => setState(() => _showPassword = !_showPassword),
              ),
              validator: (v) => (v ?? '').length < 6 ? t('b2b.passwordShort') : null,
            ),
            const SizedBox(height: 14),
            AppSelect<Country>(
              label: t('co.country'),
              hint: t('co.selectCountry'),
              icon: Icons.public_rounded,
              options: config.countries,
              value: config.country(_country),
              labelOf: (c) => c.name,
              onChanged: (c) => setState(() => _country = c.code),
              validatorMessage: t('co.selectCountry'),
            ),
            if (config.b2bTypes.isNotEmpty) ...[
              const SizedBox(height: 14),
              AppSelect<Label>(
                label: t('b2b.type'),
                hint: t('b2b.typeHint'),
                icon: Icons.category_outlined,
                options: config.b2bTypes,
                value: _type,
                labelOf: (l) => l.of(lang),
                onChanged: (l) => setState(() => _type = l),
              ),
            ],
            const SizedBox(height: 14),
            AppTextField(
              controller: _phone,
              label: t('b2b.phoneOptional'),
              prefixIcon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            const SizedBox(height: 18),
            AppButton(
              label: t('b2b.registerCta'),
              icon: Icons.business_center_rounded,
              size: BtnSize.lg,
              expand: true,
              loading: _busy,
              onPressed: _register,
            ),
          ],
        ),
      ),
    );
  }
}

class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({required this.visible, required this.tooltip, required this.onTap});

  final bool visible;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onTap,
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColors.muted,
      ),
    );
  }
}
