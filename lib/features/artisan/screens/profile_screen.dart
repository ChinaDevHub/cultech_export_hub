import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/voice/voice_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../data/artisan_models.dart';
import '../data/artisan_repository.dart';
import '../widgets/artisan_widgets.dart';

class ArtisanProfileEditScreen extends ConsumerWidget {
  const ArtisanProfileEditScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    return dash.when(
      skipLoadingOnRefresh: true,
      loading: () => const SingleChildScrollView(
        child: ArtisanColumn(
          children: [
            Center(child: Skeleton(width: 128, height: 128, radius: 64)),
            SizedBox(height: 20),
            SkeletonList(count: 4, height: 64),
          ],
        ),
      ),
      error: (e, _) => ErrorState(
        message: azError(e),
        artisan: true,
        retryLabel: 'Yenidən cəhd et',
        onRetry: () => ref.invalidate(dashboardProvider),
      ),
      data: (d) => _ProfileForm(key: ValueKey(d.artisan.id), dashboard: d),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({super.key, required this.dashboard});

  final ArtisanDashboard dashboard;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _name = TextEditingController(text: widget.dashboard.artisan.name);
  late final _village = TextEditingController(text: widget.dashboard.artisan.village ?? '');
  late final _story = TextEditingController(
    text: widget.dashboard.artisan.storyAz ?? widget.dashboard.artisan.story ?? '',
  );
  Label? _region;
  XFile? _avatar;
  bool _saving = false;
  late List<Skill> _skills = widget.dashboard.skills;
  String? _skillBusy;

  @override
  void initState() {
    super.initState();
    final config = ref.read(configOrEmptyProvider);
    final r = widget.dashboard.artisan.region;
    _region = config.region(r) ?? (r == null ? null : Label(id: r, en: r, az: r));
  }

  @override
  void didUpdateWidget(_ProfileForm old) {
    super.didUpdateWidget(old);
    if (old.dashboard != widget.dashboard) _skills = widget.dashboard.skills;
  }

  @override
  void dispose() {
    _name.dispose();
    _village.dispose();
    _story.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final files = await pickImages(context, max: 1);
    if (files.isNotEmpty) setState(() => _avatar = files.first);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      showToast('Adınızı yazın', kind: ToastKind.error, large: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(artisanRepoProvider)
          .updateProfile(
            name: _name.text,
            region: _region?.id,
            village: _village.text,
            storyAz: _story.text,
            avatar: _avatar,
          );
      ref.invalidate(dashboardProvider);
      await ref.read(authProvider.notifier).refreshMe();
      showToast('Yadda saxlandı', kind: ToastKind.ok, large: true);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleSkill(Skill s) async {
    if (s.active) {
      final ok = await showConfirm(
        context,
        title: '«${s.az}» bacarığını silək?',
        message: 'Bu bacarıqla bağlı variantlar artıq təklif olunmayacaq.',
        confirmLabel: 'Bəli, sil',
        cancelLabel: 'Xeyr',
        confirmVariant: BtnVariant.danger,
        icon: Icons.remove_circle_outline_rounded,
        artisan: true,
      );
      if (!ok) return;
    }
    final next = [
      for (final k in _skills)
        if (k.id == s.id) Skill(id: k.id, az: k.az, active: !k.active) else k,
    ];
    final previous = _skills;
    setState(() {
      _skills = next;
      _skillBusy = s.id;
    });
    try {
      await ref
          .read(artisanRepoProvider)
          .updateSkills(next.where((k) => k.active).map((k) => k.id).toList());
      ref.invalidate(dashboardProvider);
    } catch (e) {
      if (mounted) setState(() => _skills = previous);
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _skillBusy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(configOrEmptyProvider);
    final a = widget.dashboard.artisan;
    return SingleChildScrollView(
      child: ArtisanColumn(
        children: [
          Text('Profil', style: AppText.aH1),
          const SizedBox(height: 18),
          Center(
            child: Semantics(
              button: true,
              label: 'Şəkli dəyiş',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _pickAvatar,
                child: Stack(
                  children: [
                    if (_avatar != null)
                      Container(
                        width: 128,
                        height: 128,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        clipBehavior: Clip.antiAlias,
                        child: PickedImage(_avatar!),
                      )
                    else
                      AppAvatar(name: a.name, image: a.avatar, color: a.color, size: 128),
                    const Positioned(
                      right: 2,
                      bottom: 2,
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.brand,
                        child: Icon(Icons.photo_camera_rounded, color: AppColors.white, size: 22),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Şəkli dəyişmək üçün basın', textAlign: TextAlign.center, style: AppText.aHint),
          const SizedBox(height: 20),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _name,
                  artisan: true,
                  label: 'Ad, soyad',
                  prefixIcon: Icons.badge_rounded,
                  textCapitalization: TextCapitalization.words,
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
                ),
                const SizedBox(height: 18),
                AppTextField(
                  controller: _village,
                  artisan: true,
                  label: 'Kənd və ya şəhər',
                  prefixIcon: Icons.home_work_rounded,
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 20),
                VoiceTextField(
                  controller: _story,
                  label: 'Hekayəniz',
                  hint: 'Sənəti kimdən öyrənmisiniz?',
                  minLines: 3,
                ),
                const SizedBox(height: 20),
                AppButton(
                  label: 'Yadda saxla',
                  icon: Icons.check_rounded,
                  size: BtnSize.xl,
                  variant: BtnVariant.ok,
                  loading: _saving,
                  onPressed: _save,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Bacarıqlarım', style: AppText.aH2),
                const SizedBox(height: 6),
                NoteCard(
                  icon: Icons.auto_awesome,
                  background: AppColors.conceptBg,
                  foreground: AppColors.concept,
                  child: Text(
                    'Süni intellekt yalnız bacardığınız variantları təklif edir.',
                    style: AppText.body(16, weight: FontWeight.w700, color: AppColors.concept),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Basın — əlavə edin və ya silin.', style: AppText.aHint),
                const SizedBox(height: 12),
                if (_skills.isEmpty)
                  Text('Bacarıqlar məhsullarınızdan avtomatik öyrənilir.', style: AppText.aHint)
                else
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final s in _skills)
                        Opacity(
                          opacity: _skillBusy == s.id ? .5 : 1,
                          child: AppChip(
                            label: s.az,
                            selected: s.active,
                            large: true,
                            icon: s.active ? null : Icons.add_rounded,
                            onTap: _skillBusy == null ? () => _toggleSkill(s) : null,
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          AppButton(
            label: 'Mağazada profilimə bax',
            icon: Icons.storefront_rounded,
            size: BtnSize.lg,
            variant: BtnVariant.soft,
            expand: true,
            onPressed: a.id.isEmpty ? null : () => context.go(Routes.artisan(a.id)),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Çıxış',
            icon: Icons.logout_rounded,
            size: BtnSize.lg,
            variant: BtnVariant.danger,
            expand: true,
            onPressed: () async {
              final ok = await showConfirm(
                context,
                title: 'Hesabdan çıxırsınız?',
                confirmLabel: 'Bəli, çıx',
                cancelLabel: 'Xeyr',
                confirmVariant: BtnVariant.danger,
                icon: Icons.logout_rounded,
                artisan: true,
              );
              if (ok) ref.read(authProvider.notifier).logout();
            },
          ),
        ],
      ),
    );
  }
}
