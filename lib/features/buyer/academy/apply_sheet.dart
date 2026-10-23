import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import 'academy_models.dart';
import 'academy_repository.dart';

/// "Müraciət et" form for one programme; shows a success state in place.
Future<void> showApplySheet(BuildContext context, Programme programme) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _ApplySheet(programme: programme),
  );
}

class _ApplySheet extends ConsumerStatefulWidget {
  const _ApplySheet({required this.programme});

  final Programme programme;

  @override
  ConsumerState<_ApplySheet> createState() => _ApplySheetState();
}

class _ApplySheetState extends ConsumerState<_ApplySheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  bool _sending = false;
  bool _done = false;

  @override
  void dispose() {
    for (final c in [_name, _age, _phone, _message]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Bu xananı doldurun' : null;

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(academyRepoProvider)
          .apply(
            widget.programme.id,
            name: _name.text,
            phone: _phone.text,
            age: int.parse(_age.text.trim()),
            message: _message.text,
          );
      ref.invalidate(academyProgrammesProvider);
      if (mounted) setState(() => _done = true);
    } catch (e) {
      showToast(academyError(e), kind: ToastKind.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: AnimatedSwitcher(
              duration: AppMotion.of(context),
              child: _done ? _success(context) : _formView(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final p = widget.programme;
    return Row(
      children: [
        AppAvatar(name: p.mentor.name, image: p.mentor.avatar, color: p.mentor.color, size: 52),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(p.title, style: AppText.display(22, weight: FontWeight.w700)),
              Text('Usta: ${p.mentor.name}', style: AppText.bodyS),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formView(BuildContext context) {
    return Form(
      key: _form,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          const SizedBox(height: 20),
          AppTextField(
            controller: _name,
            label: 'Adınız və soyadınız',
            prefixIcon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.name],
            validator: _required,
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _age,
            label: 'Yaşınız',
            hint: 'Məsələn, 19',
            prefixIcon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              if (n == null) return 'Yaşınızı yazın';
              if (n < 10 || n > 99) return 'Yaşı düzgün yazın';
              return null;
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _phone,
            label: 'Telefon',
            hint: '+994 50 000 00 00',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.telephoneNumber],
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]'))],
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
              return digits.length < 7 ? 'Telefon nömrəsini tam yazın' : null;
            },
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _message,
            label: 'Mesaj (istəyə görə)',
            hint: 'Niyə bu sənəti öyrənmək istəyirsiniz?',
            minLines: 3,
            maxLines: 6,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
          ),
          const SizedBox(height: 22),
          AppButton(
            label: 'Müraciəti göndər',
            icon: Icons.send_rounded,
            size: BtnSize.lg,
            expand: true,
            loading: _sending,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  Widget _success(BuildContext context) {
    final p = widget.programme;
    return Column(
      key: const ValueKey('done'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.okLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.ok, size: 40),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Müraciətiniz göndərildi!',
          textAlign: TextAlign.center,
          style: AppText.display(26, weight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        Text(
          '«${p.title}» proqramı üzrə ${p.mentor.name} və komandamız '
          'tezliklə ${_phone.text.trim()} nömrəsi ilə sizinlə əlaqə saxlayacaq.',
          textAlign: TextAlign.center,
          style: AppText.body(16, color: AppColors.ink2),
        ),
        const SizedBox(height: 24),
        AppButton(
          label: 'Bağla',
          variant: BtnVariant.outline,
          size: BtnSize.lg,
          expand: true,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }
}
