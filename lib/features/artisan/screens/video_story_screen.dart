import 'dart:io' show File;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/voice/voice_controller.dart';
import '../../../core/voice/voice_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../router.dart';
import '../data/artisan_repository.dart';
import '../extras/extras_repository.dart';
import '../extras/extras_widgets.dart';
import '../widgets/artisan_widgets.dart';

enum _Phase { idle, uploading, processing }

/// "Video hekayə": record or pick a short making-of video, say what is
/// said in it, upload → the server adds English subtitles.
class VideoStoryScreen extends ConsumerStatefulWidget {
  const VideoStoryScreen({super.key, required this.productId});

  final String productId;

  @override
  ConsumerState<VideoStoryScreen> createState() => _VideoStoryScreenState();
}

class _VideoStoryScreenState extends ConsumerState<VideoStoryScreen> {
  final _transcript = TextEditingController();
  XFile? _video;
  VideoPlayerController? _player;
  bool _playerReady = false;
  bool _playerFailed = false;
  _Phase _phase = _Phase.idle;
  double _progress = 0;

  bool get _busy => _phase != _Phase.idle;

  @override
  void dispose() {
    _player?.dispose();
    _transcript.dispose();
    super.dispose();
  }

  void _back() {
    if (_busy) {
      showToast('Video yüklənir — bir az gözləyin', large: true);
      return;
    }
    context.canPop() ? context.pop() : context.go(Routes.usta);
  }

  Future<void> _chooseAndPick() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Video haradan?', style: AppText.aH2),
            const SizedBox(height: 18),
            AppButton(
              label: 'Video çək',
              icon: Icons.videocam_rounded,
              size: BtnSize.xl,
              onPressed: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            const SizedBox(height: 12),
            AppButton(
              label: 'Qalereyadan seç',
              icon: Icons.video_library_rounded,
              size: BtnSize.xl,
              variant: BtnVariant.outline,
              onPressed: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source != null) await _pick(source);
  }

  Future<void> _pick(ImageSource source) async {
    XFile? x;
    try {
      x = await ImagePicker().pickVideo(source: source, maxDuration: const Duration(minutes: 2));
    } catch (_) {
      showToast(
        source == ImageSource.camera
            ? 'Kamera açılmadı. Qalereyadan seçin.'
            : 'Video açılmadı. Yenidən cəhd edin.',
        kind: ToastKind.error,
        large: true,
      );
      return;
    }
    if (x == null || !mounted) return;
    await _setVideo(x);
  }

  Future<void> _setVideo(XFile x) async {
    final old = _player;
    // On web `XFile.path` is a blob URL; elsewhere it is a real file path.
    final c = kIsWeb
        ? VideoPlayerController.networkUrl(Uri.parse(x.path))
        : VideoPlayerController.file(File(x.path));
    setState(() {
      _video = x;
      _player = c;
      _playerReady = false;
      _playerFailed = false;
    });
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    try {
      await c.initialize();
      if (!mounted || _player != c) return;
      setState(() => _playerReady = true);
    } catch (_) {
      if (!mounted || _player != c) return;
      setState(() => _playerFailed = true);
    }
  }

  Future<void> _send() async {
    final video = _video;
    if (video == null) return;
    await ref.read(voiceProvider).stop();
    await _player?.pause();
    setState(() {
      _phase = _Phase.uploading;
      _progress = 0;
    });
    try {
      await ref
          .read(extrasRepoProvider)
          .uploadVideo(
            widget.productId,
            video: video,
            transcript: _transcript.text,
            onProgress: (p) {
              if (!mounted) return;
              setState(() {
                _progress = p;
                if (p >= 1) _phase = _Phase.processing;
              });
            },
          );
      ref.invalidate(dashboardProvider);
      ref.invalidate(artisanProductProvider(widget.productId));
      showToast('İngilis subtitrləri hazırdır', kind: ToastKind.ok, large: true);
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      _back();
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
      if (mounted) setState(() => _phase = _Phase.idle);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productName = ref.watch(artisanProductProvider(widget.productId)).value?.nameAz;
    return PopScope(
      canPop: !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) showToast('Video yüklənir — bir az gözləyin', large: true);
      },
      child: ArtisanPage(
        title: 'Video hekayə',
        onBack: _back,
        body: SingleChildScrollView(
          child: ArtisanColumn(
            children: [
              if (productName != null && productName.isNotEmpty) ...[
                Text('«$productName»', style: AppText.aH2),
                const SizedBox(height: 12),
              ],
              NoteCard(
                icon: Icons.subtitles_rounded,
                background: AppColors.brandLight,
                foreground: AppColors.brand,
                iconSize: 28,
                child: Text(
                  'Məhsulunuzu hazırlayarkən qısa video çəkin — '
                  'alıcılar ingilis subtitrləri ilə görəcək.',
                  style: AppText.body(17.5, weight: FontWeight.w700, color: AppColors.brand),
                ),
              ),
              const SizedBox(height: 18),
              if (_video == null) ..._pickButtons() else ..._preview(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _pickButtons() => [
    const InfoLine(icon: Icons.timer_rounded, text: '2 dəqiqəyə qədər', size: 17),
    const InfoLine(icon: Icons.back_hand_rounded, text: 'Əllərinizi və işinizi göstərin', size: 17),
    const InfoLine(icon: Icons.record_voice_over_rounded, text: 'Aydın və sakit danışın', size: 17),
    const SizedBox(height: 20),
    AppButton(
      label: 'Video çək',
      icon: Icons.videocam_rounded,
      size: BtnSize.xl,
      onPressed: () => _pick(ImageSource.camera),
    ),
    const SizedBox(height: 12),
    AppButton(
      label: 'Qalereyadan seç',
      icon: Icons.video_library_rounded,
      size: BtnSize.xl,
      variant: BtnVariant.outline,
      onPressed: () => _pick(ImageSource.gallery),
    ),
  ];

  List<Widget> _preview() => [
    AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(borderRadius: BorderRadius.circular(AppRadii.image), child: _playerView()),
          const SizedBox(height: 10),
          AppButton(
            label: 'Başqa video seç',
            icon: Icons.replay_rounded,
            size: BtnSize.lg,
            variant: BtnVariant.outline,
            expand: true,
            onPressed: _busy ? null : _chooseAndPick,
          ),
        ],
      ),
    ),
    const SizedBox(height: 20),
    AppCard(
      padding: const EdgeInsets.all(20),
      child: VoiceTextField(
        controller: _transcript,
        label: 'Videoda nə deyirsiniz?',
        hint: 'Danışdıqlarınızı deyin və ya yazın',
        minLines: 3,
      ),
    ),
    const SizedBox(height: 22),
    if (_busy)
      _uploadProgress()
    else
      AppButton(
        label: 'Göndər',
        icon: Icons.cloud_upload_rounded,
        size: BtnSize.xl,
        variant: BtnVariant.ok,
        onPressed: _send,
      ),
  ];

  Widget _playerView() {
    final c = _player;
    if (c == null || _playerFailed) {
      return Container(
        height: 180,
        color: AppColors.soft2,
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.movie_rounded, size: 52, color: AppColors.brand),
            const SizedBox(height: 8),
            Text('Video seçildi', style: AppText.aBodyStrong),
            if (_video != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _video!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.aHint,
                ),
              ),
          ],
        ),
      );
    }
    if (!_playerReady) {
      return Container(
        height: 240,
        color: AppColors.ink,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(color: AppColors.white),
      );
    }
    final ratio = c.value.aspectRatio > 0 ? c.value.aspectRatio : 16 / 9;
    return Container(
      color: AppColors.ink,
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 440),
        child: AspectRatio(
          aspectRatio: ratio,
          child: ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: c,
            builder: (context, v, _) => Semantics(
              button: true,
              label: v.isPlaying ? 'Dayandır' : 'Oynat',
              child: GestureDetector(
                onTap: () => v.isPlaying ? c.pause() : c.play(),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    VideoPlayer(c),
                    AnimatedOpacity(
                      opacity: v.isPlaying ? 0 : 1,
                      duration: AppMotion.of(context, AppMotion.base),
                      child: Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: AppColors.ink.withValues(alpha: .6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: AppColors.white,
                            size: 56,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: VideoProgressIndicator(
                        c,
                        allowScrubbing: true,
                        padding: const EdgeInsets.only(top: 12),
                        colors: VideoProgressColors(
                          playedColor: AppColors.brand,
                          bufferedColor: AppColors.white.withValues(alpha: .4),
                          backgroundColor: AppColors.white.withValues(alpha: .2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _uploadProgress() {
    final processing = _phase == _Phase.processing;
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 26,
                child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.brand),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  processing
                      ? 'Subtitrlər hazırlanır…'
                      : 'Yüklənir… ${(_progress * 100).clamp(0, 100).round()}%',
                  style: AppText.body(19, weight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          AppProgressBar(value: processing ? 1 : _progress, height: 14),
          const SizedBox(height: 10),
          Text('Səhifəni bağlamayın.', style: AppText.aHint),
        ],
      ),
    );
  }
}
