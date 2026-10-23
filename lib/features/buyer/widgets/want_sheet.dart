import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../data/buyer_repository.dart';

final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

bool isValidEmail(String v) => _emailRe.hasMatch(v.trim());

/// "I want this" sheet. Returns the new want count on success.
Future<int?> showWantSheet(
  BuildContext context, {
  required String itemType,
  required String itemId,
  required int currentWants,
}) {
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _WantSheet(itemType: itemType, itemId: itemId, currentWants: currentWants),
  );
}

class _WantSheet extends ConsumerStatefulWidget {
  const _WantSheet({required this.itemType, required this.itemId, required this.currentWants});

  final String itemType;
  final String itemId;
  final int currentWants;

  @override
  ConsumerState<_WantSheet> createState() => _WantSheetState();
}

class _WantSheetState extends ConsumerState<_WantSheet> {
  late final _email = TextEditingController(text: ref.read(emailMemoryProvider));
  final _form = GlobalKey<FormState>();
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = ref.read(tProvider);
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      final n = await ref
          .read(buyerRepoProvider)
          .want(itemType: widget.itemType, itemId: widget.itemId, email: _email.text);
      ref.read(emailMemoryProvider.notifier).remember(_email.text);
      final count = n ?? widget.currentWants + 1;
      if (mounted) Navigator.pop(context, count);
      showToast(t('want.thanks', {'n': count}), kind: ToastKind.ok);
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      showToast(
        errorText(e, network: t('common.network'), fallback: t('common.error')),
        kind: ToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(28, 0, 28, 30),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.accentLight,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.favorite_rounded, color: AppColors.accent, size: 32),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t('want.title'),
                    textAlign: TextAlign.center,
                    style: AppText.display(26, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(t('want.body'), textAlign: TextAlign.center, style: AppText.bodyS),
                  const SizedBox(height: 20),
                  AppTextField(
                    controller: _email,
                    label: t('want.email'),
                    hint: 'you@example.com',
                    prefixIcon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (v) => isValidEmail(v ?? '') ? null : t('common.invalidEmail'),
                  ),
                  const SizedBox(height: 18),
                  AppButton(
                    label: t('want.submit'),
                    icon: Icons.notifications_active_rounded,
                    variant: BtnVariant.accent,
                    size: BtnSize.lg,
                    expand: true,
                    loading: _sending,
                    onPressed: _submit,
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
