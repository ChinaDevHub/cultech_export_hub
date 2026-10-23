import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/voice/voice_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../../artisan/widgets/artisan_widgets.dart';
import '../data/coordinator_models.dart';
import '../data/coordinator_repository.dart';

/// Opens the "new artisan" form. Returns true when an artisan was created.
Future<bool> showNewArtisanSheet(BuildContext context) async {
  final res = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const _NewArtisanSheet(),
  );
  return res ?? false;
}

class _NewArtisanSheet extends ConsumerStatefulWidget {
  const _NewArtisanSheet();

  @override
  ConsumerState<_NewArtisanSheet> createState() => _NewArtisanSheetState();
}

class _NewArtisanSheetState extends ConsumerState<_NewArtisanSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _village = TextEditingController();
  final _story = TextEditingController();
  Label? _region;
  Label? _craft;
  String _gender = 'female';
  XFile? _photo;
  bool _loading = false;
  NewArtisanResult? _result;

  @override
  void dispose() {
    for (final c in [_name, _phone, _village, _story]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Bu xananı doldurun' : null;

  Future<void> _pickPhoto() async {
    final files = await pickImages(context, max: 1);
    if (files.isNotEmpty && mounted) setState(() => _photo = files.first);
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      showToast('Zəhmət olmasa boş xanaları doldurun', kind: ToastKind.error, large: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(coordinatorRepoProvider)
          .registerArtisan(
            name: _name.text,
            phone: _phone.text,
            region: _region?.id ?? '',
            village: _village.text,
            craft: _craft?.id ?? '',
            gender: _gender,
            story: _story.text,
            photo: _photo,
          );
      ref.invalidate(coordinatorDashboardProvider);
      if (mounted) setState(() => _result = res);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: AnimatedSwitcher(
              duration: AppMotion.of(context),
              child: _result == null
                  ? _buildForm(context)
                  : _SuccessView(
                      key: const ValueKey('done'),
                      result: _result!,
                      onDone: () => Navigator.pop(context, true),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final config = ref.watch(configOrEmptyProvider);
    return Form(
      key: _form,
      child: Column(
        key: const ValueKey('form'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Yeni usta qeydiyyatı', style: AppText.aH2),
          const SizedBox(height: 6),
          Text('Ustanın məlumatlarını yazın. Parolu sistem özü yaradacaq.', style: AppText.aHint),
          const SizedBox(height: 20),
          Center(
            child: _PhotoPicker(photo: _photo, onTap: _pickPhoto),
          ),
          const SizedBox(height: 6),
          Text('Şəkil (istəyə görə)', textAlign: TextAlign.center, style: AppText.aHint),
          const SizedBox(height: 20),
          AppTextField(
            controller: _name,
            artisan: true,
            label: 'Ad və soyad',
            prefixIcon: Icons.badge_rounded,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: _required,
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: _phone,
            artisan: true,
            label: 'Telefon',
            hint: '+994 50 000 00 00',
            prefixIcon: Icons.phone_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ()-]'))],
            validator: _required,
          ),
          const SizedBox(height: 18),
          AppSelect<Label>(
            label: 'Bölgə',
            hint: 'Bölgəni seçin',
            artisan: true,
            icon: Icons.map_rounded,
            options: config.regions,
            value: _region,
            labelOf: (l) => l.az,
            onChanged: (l) => setState(() => _region = l),
            validatorMessage: config.regions.isEmpty ? null : 'Bölgəni seçin',
          ),
          const SizedBox(height: 18),
          AppTextField(
            controller: _village,
            artisan: true,
            label: 'Kənd',
            prefixIcon: Icons.home_work_rounded,
            textCapitalization: TextCapitalization.words,
            validator: _required,
          ),
          const SizedBox(height: 18),
          AppSelect<Label>(
            label: 'Sənət növü',
            hint: 'Sənəti seçin',
            artisan: true,
            icon: Icons.handyman_rounded,
            options: config.crafts,
            value: _craft,
            labelOf: (l) => l.az,
            onChanged: (l) => setState(() => _craft = l),
            validatorMessage: config.crafts.isEmpty ? null : 'Sənət növünü seçin',
          ),
          const SizedBox(height: 18),
          const FieldLabel('Cins', artisan: true),
          _GenderChoice(value: _gender, onChanged: (g) => setState(() => _gender = g)),
          const SizedBox(height: 22),
          VoiceTextField(
            controller: _story,
            label: 'Qısa hekayə',
            hint: 'Sənəti kimdən öyrənib? Neçə ildir məşğuldur?',
            minLines: 3,
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Qeydiyyatdan keçir',
            icon: Icons.person_add_alt_1_rounded,
            size: BtnSize.xl,
            loading: _loading,
            onPressed: _submit,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Ləğv et',
            size: BtnSize.xl,
            variant: BtnVariant.outline,
            onPressed: _loading ? null : () => Navigator.pop(context, false),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({required this.photo, required this.onTap});

  final XFile? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Şəkil əlavə et',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Stack(
          children: [
            Container(
              width: 104,
              height: 104,
              decoration: const BoxDecoration(color: AppColors.brandLight, shape: BoxShape.circle),
              clipBehavior: Clip.antiAlias,
              child: photo == null
                  ? const Icon(Icons.person_rounded, size: 52, color: AppColors.brand)
                  : PickedImage(photo!),
            ),
            const Positioned(
              right: 0,
              bottom: 0,
              child: CircleAvatar(
                radius: 19,
                backgroundColor: AppColors.brand,
                child: Icon(Icons.photo_camera_rounded, color: AppColors.white, size: 19),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Two big tiles: Qadın / Kişi.
class _GenderChoice extends StatelessWidget {
  const _GenderChoice({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget tile(String id, String label, IconData icon) {
      final selected = value == id;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          label: label,
          child: InkWell(
            onTap: () => onChanged(id),
            borderRadius: BorderRadius.circular(AppRadii.inputArtisan),
            child: AnimatedContainer(
              duration: AppMotion.of(context, AppMotion.fast),
              constraints: const BoxConstraints(minHeight: 62),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.brandLight : AppColors.white,
                borderRadius: BorderRadius.circular(AppRadii.inputArtisan),
                border: Border.all(color: selected ? AppColors.brand : AppColors.line2, width: 2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    selected ? Icons.check_circle_rounded : icon,
                    color: selected ? AppColors.brand : AppColors.muted,
                    size: 26,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      label,
                      style: AppText.body(
                        19,
                        weight: FontWeight.w800,
                        color: selected ? AppColors.brand : AppColors.ink,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tile('female', 'Qadın', Icons.woman_rounded),
        const SizedBox(width: 12),
        tile('male', 'Kişi', Icons.man_rounded),
      ],
    );
  }
}

/// Shows the generated password once, big, with a copy button.
class _SuccessView extends StatelessWidget {
  const _SuccessView({super.key, required this.result, required this.onDone});

  final NewArtisanResult result;
  final VoidCallback onDone;

  Future<void> _copy() async {
    final text = [
      if (result.phone != null) 'Telefon: ${result.phone}',
      if (result.password != null) 'Parol: ${result.password}',
    ].join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    showToast('Kopyalandı', kind: ToastKind.ok, large: true);
  }

  @override
  Widget build(BuildContext context) {
    final password = result.password;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 76,
            height: 76,
            decoration: const BoxDecoration(color: AppColors.okLight, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, color: AppColors.ok, size: 44),
          ),
        ),
        const SizedBox(height: 14),
        Text('${result.name} qeydiyyatdan keçdi!', textAlign: TextAlign.center, style: AppText.aH2),
        const SizedBox(height: 20),
        if (password != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.goldLight,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.gold, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.key_rounded, color: AppColors.goldInk, size: 28),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Bu parolu ustaya verin',
                        style: AppText.body(19, weight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  alignment: Alignment.center,
                  child: Semantics(
                    label: 'Parol ${password.split('').join(' ')}',
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SelectableText(
                        password,
                        style: AppText.mono(44, weight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
                if (result.phone != null) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.phone_rounded, color: AppColors.ink2, size: 24),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(text: 'Giriş üçün telefon: ', style: AppText.aBody),
                              TextSpan(
                                text: result.phone,
                                style: AppText.mono(19, weight: FontWeight.w800),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'Parol yalnız indi göstərilir — yazıb saxlayın.',
                  style: AppText.body(15.5, weight: FontWeight.w600, color: AppColors.goldInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Kopyala',
            icon: Icons.copy_rounded,
            size: BtnSize.xl,
            variant: BtnVariant.dark,
            onPressed: _copy,
          ),
        ] else
          NoteCard(
            icon: Icons.info_rounded,
            background: AppColors.brandLight,
            foreground: AppColors.brand,
            child: Text(
              'Usta əlavə olundu. Giriş üçün telefon: ${result.phone ?? '—'}',
              style: AppText.body(17, weight: FontWeight.w700, color: AppColors.brand),
            ),
          ),
        const SizedBox(height: 10),
        AppButton(
          label: 'Hazırdır',
          icon: Icons.check_rounded,
          size: BtnSize.xl,
          variant: BtnVariant.outline,
          onPressed: onDone,
        ),
      ],
    );
  }
}
