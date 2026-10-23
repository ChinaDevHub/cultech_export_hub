import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_client.dart';
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
import '../../../router.dart';
import '../widgets/artisan_widgets.dart';

class ArtisanRegisterScreen extends ConsumerStatefulWidget {
  const ArtisanRegisterScreen({super.key});

  @override
  ConsumerState<ArtisanRegisterScreen> createState() => _ArtisanRegisterScreenState();
}

class _ArtisanRegisterScreenState extends ConsumerState<ArtisanRegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _village = TextEditingController();
  final _story = TextEditingController();
  Label? _region;
  Label? _craft;

  /// `female` | `male` (the ministry statistics report women's share).
  String? _gender;
  XFile? _avatar;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _phone, _password, _village, _story]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) => (v == null || v.trim().isEmpty) ? 'Bu xananı doldurun' : null;

  Future<void> _pickAvatar() async {
    final files = await pickImages(context, max: 1);
    if (files.isNotEmpty) setState(() => _avatar = files.first);
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) {
      showToast('Zəhmət olmasa boş xanaları doldurun', kind: ToastKind.error, large: true);
      return;
    }
    setState(() => _loading = true);
    try {
      final form = FormData.fromMap({
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'region': _region?.id ?? '',
        'village': _village.text.trim(),
        'craft': _craft?.id ?? '',
        'storyAz': _story.text.trim(),
        'gender': ?_gender,
      });
      if (_avatar != null) {
        form.files.add(MapEntry('avatar', await ApiClient.imageFile(_avatar!)));
      }
      await ref
          .read(authProvider.notifier)
          .registerArtisan(form, phone: _phone.text.trim(), password: _password.text);
      showToast('Xoş gəldiniz! Qeydiyyat tamamlandı.', kind: ToastKind.ok, large: true);
      if (mounted) context.go(Routes.usta);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configOrEmptyProvider);
    return ArtisanPage(
      title: 'Usta kimi qeydiyyat',
      onBack: () => context.go(Routes.ustaLogin),
      body: SingleChildScrollView(
        child: ArtisanColumn(
          children: [
            Form(
              key: _form,
              child: AppCard(
                padding: const EdgeInsets.all(22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Semantics(
                        button: true,
                        label: 'Şəkil əlavə et',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: _pickAvatar,
                          child: Stack(
                            children: [
                              Container(
                                width: 112,
                                height: 112,
                                decoration: const BoxDecoration(
                                  color: AppColors.brandLight,
                                  shape: BoxShape.circle,
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: _avatar == null
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 56,
                                        color: AppColors.brand,
                                      )
                                    : PickedImage(_avatar!),
                              ),
                              const Positioned(
                                right: 0,
                                bottom: 0,
                                child: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: AppColors.brand,
                                  child: Icon(
                                    Icons.photo_camera_rounded,
                                    color: AppColors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text('Şəkil (istəyə görə)', textAlign: TextAlign.center, style: AppText.aHint),
                    const SizedBox(height: 20),
                    AppTextField(
                      controller: _name,
                      artisan: true,
                      label: 'Adınız və soyadınız',
                      prefixIcon: Icons.badge_rounded,
                      textCapitalization: TextCapitalization.words,
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
                      validator: _required,
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _password,
                      artisan: true,
                      label: 'Parol',
                      prefixIcon: Icons.lock_rounded,
                      obscureText: true,
                      helper: 'Ən azı 6 simvol',
                      validator: (v) =>
                          (v ?? '').length < 6 ? 'Parol ən azı 6 simvol olmalıdır' : null,
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
                      validatorMessage: 'Bölgəni seçin',
                    ),
                    const SizedBox(height: 18),
                    AppTextField(
                      controller: _village,
                      artisan: true,
                      label: 'Kənd və ya şəhər',
                      prefixIcon: Icons.home_work_rounded,
                      textCapitalization: TextCapitalization.words,
                      validator: _required,
                    ),
                    const SizedBox(height: 18),
                    AppSelect<String>(
                      label: 'Cins',
                      hint: 'Seçin',
                      artisan: true,
                      icon: Icons.wc_rounded,
                      options: const ['female', 'male'],
                      value: _gender,
                      labelOf: (g) => g == 'female' ? 'Qadın' : 'Kişi',
                      onChanged: (g) => setState(() => _gender = g),
                      validatorMessage: 'Cinsi seçin',
                    ),
                    const SizedBox(height: 18),
                    AppSelect<Label>(
                      label: 'Sənət növü',
                      hint: 'Sənətinizi seçin',
                      artisan: true,
                      icon: Icons.handyman_rounded,
                      options: config.crafts,
                      value: _craft,
                      labelOf: (l) => l.az,
                      onChanged: (l) => setState(() => _craft = l),
                      validatorMessage: 'Sənət növünü seçin',
                    ),
                    const SizedBox(height: 22),
                    VoiceTextField(
                      controller: _story,
                      label: 'Qısa hekayəniz',
                      hint: 'Sənəti kimdən öyrənmisiniz? Neçə ildir məşğulsunuz?',
                      minLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 22),
            AppButton(
              label: 'Qeydiyyatdan keç',
              icon: Icons.check_rounded,
              size: BtnSize.xl,
              loading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
