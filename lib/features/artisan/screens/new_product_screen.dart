import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/voice/voice_controller.dart';
import '../../../core/voice/voice_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/inputs.dart';
import '../../../router.dart';
import '../data/artisan_repository.dart';
import '../widgets/artisan_widgets.dart';

class NewProductScreen extends ConsumerStatefulWidget {
  const NewProductScreen({super.key});

  @override
  ConsumerState<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends ConsumerState<NewProductScreen> {
  final _transcript = TextEditingController();
  final _price = TextEditingController();
  final List<XFile> _images = [];
  bool _sending = false;
  bool _serverDone = false;

  @override
  void dispose() {
    _transcript.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _addPhotos() async {
    final picked = await pickImages(context, max: 4 - _images.length);
    if (picked.isEmpty) return;
    setState(() => _images.addAll(picked.take(4 - _images.length)));
  }

  Future<void> _send() async {
    if (_images.isEmpty) {
      showToast('Ən azı bir şəkil əlavə edin', kind: ToastKind.error, large: true);
      return;
    }
    if (_transcript.text.trim().isEmpty) {
      showToast('Məhsul haqqında danışın və ya yazın', kind: ToastKind.error, large: true);
      return;
    }
    await ref.read(voiceProvider).stop();
    setState(() {
      _sending = true;
      _serverDone = false;
    });
    try {
      final product = await ref
          .read(artisanRepoProvider)
          .createProduct(
            images: _images,
            transcript: _transcript.text,
            price: parsePrice(_price.text),
          );
      setState(() => _serverDone = true);
      ref.invalidate(dashboardProvider);
      // Let the last steps tick before moving on.
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (mounted) context.pushReplacement(Routes.ustaProduct(product.id));
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      showToast(azError(e), kind: ToastKind.error, large: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sending) return _ProgressView(done: _serverDone);
    return ArtisanPage(
      title: 'Yeni məhsul',
      onBack: () => context.canPop() ? context.pop() : context.go(Routes.usta),
      body: SingleChildScrollView(
        child: ArtisanColumn(
          children: [
            NumberedBlock(
              n: 1,
              title: 'Şəkil',
              child: PhotoPickerZone(
                files: _images,
                onAdd: _addPhotos,
                onRemove: (i) => setState(() => _images.removeAt(i)),
              ),
            ),
            const SizedBox(height: 16),
            NumberedBlock(
              n: 2,
              title: 'Məhsul haqqında danışın',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  NoteCard(
                    icon: Icons.record_voice_over_rounded,
                    background: AppColors.brandLight,
                    foreground: AppColors.brand,
                    iconSize: 26,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Deyin:',
                          style: AppText.body(17, weight: FontWeight.w800, color: AppColors.brand),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'nədən hazırlanıb · harada · ölçüsü · neçə günə · neçə manata',
                          style: AppText.body(17.5, weight: FontWeight.w600, color: AppColors.ink),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Məsələn: «Bu vazanı Şəkidə gildən hazırlamışam, hündürlüyü 30 santimetrdir, 5 günə hazırlanır, qiyməti 120 manatdır.»',
                          style: AppText.body(15.5, color: AppColors.ink2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  VoiceTextField(
                    controller: _transcript,
                    bigMic: true,
                    label: 'Sizin sözləriniz (düzəldə bilərsiniz)',
                    hint: 'Danışdıqlarınız burada yazılacaq. İstəsəniz özünüz də yaza bilərsiniz.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            NumberedBlock(
              n: 3,
              title: 'Qiymətiniz (AZN)',
              trailing: const AppBadge('istəyə görə', large: true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PriceInput(controller: _price),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome, color: AppColors.goldInk, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Boş qoysanız, süni intellekt qiymət təklif edəcək. Son qərar həmişə sizindir.',
                          style: AppText.aHint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppButton(
              label: 'Göndər — qalanını biz edirik',
              icon: Icons.send_rounded,
              size: BtnSize.xl,
              onPressed: _send,
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen "we're working" view with 5 animated steps.
class _ProgressView extends StatefulWidget {
  const _ProgressView({required this.done});

  final bool done;

  @override
  State<_ProgressView> createState() => _ProgressViewState();
}

class _ProgressViewState extends State<_ProgressView> {
  static const _steps = [
    (Icons.cloud_upload_rounded, 'Şəkillər yüklənir'),
    (Icons.graphic_eq_rounded, 'Səsiniz mətnə çevrilir'),
    (Icons.image_search_rounded, 'Şəkil analiz olunur'),
    (Icons.translate_rounded, 'İngilis dilində səhifə hazırlanır'),
    (Icons.sell_rounded, 'Qiymət tövsiyəsi hesablanır'),
  ];

  int _active = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      // Hold on the last step until the server answers.
      if (_active < _steps.length - 1) setState(() => _active++);
    });
  }

  @override
  void didUpdateWidget(_ProgressView old) {
    super.didUpdateWidget(old);
    if (widget.done) {
      _timer?.cancel();
      setState(() => _active = _steps.length);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.soft,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: AppLogo(size: 64, showText: false)),
                    const SizedBox(height: 20),
                    Text(
                      widget.done ? 'Hazırdır!' : 'Bir az gözləyin…',
                      textAlign: TextAlign.center,
                      style: AppText.aH1,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Qalanını biz edirik.',
                      textAlign: TextAlign.center,
                      style: AppText.aBody.copyWith(color: AppColors.ink2),
                    ),
                    const SizedBox(height: 28),
                    for (var i = 0; i < _steps.length; i++)
                      _StepLine(
                            icon: _steps[i].$1,
                            label: _steps[i].$2,
                            state: i < _active ? 2 : (i == _active ? 1 : 0),
                          )
                          .animate(target: i <= _active ? 1 : 0)
                          .fade(begin: .35, end: 1, duration: reduced ? 0.ms : 220.ms),
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

class _StepLine extends StatelessWidget {
  const _StepLine({required this.icon, required this.label, required this.state});

  final IconData icon;
  final String label;

  /// 0 todo, 1 active, 2 done.
  final int state;

  @override
  Widget build(BuildContext context) {
    final done = state == 2;
    final active = state == 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: active ? AppColors.brand : AppColors.line, width: active ? 2 : 1),
        boxShadow: active ? AppShadows.raised : AppShadows.small,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: done ? AppColors.okLight : (active ? AppColors.brandLight : AppColors.soft2),
              shape: BoxShape.circle,
            ),
            child: active
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                : Icon(
                    done ? Icons.check_rounded : icon,
                    color: done ? AppColors.ok : AppColors.muted,
                    size: 26,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: AppText.body(
                18,
                weight: state == 0 ? FontWeight.w600 : FontWeight.w800,
                color: state == 0 ? AppColors.muted : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
