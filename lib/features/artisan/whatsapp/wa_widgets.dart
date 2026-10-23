import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/voice/voice_controller.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/inputs.dart';
import 'wa_models.dart';

/// WhatsApp-style text: `*bold*` segments are rendered bold.
Widget waRich(String text, TextStyle style) {
  final spans = <TextSpan>[];
  final re = RegExp(r'\*([^*\n]+)\*');
  var last = 0;
  for (final m in re.allMatches(text)) {
    if (m.start > last) spans.add(TextSpan(text: text.substring(last, m.start)));
    spans.add(
      TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
    );
    last = m.end;
  }
  if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
  return Text.rich(TextSpan(style: style, children: spans));
}

// ───────────────────────────── Intro ─────────────────────────────

/// "WhatsApp ilə işləyin" explanation with the real bot flow.
class WaIntroCard extends StatelessWidget {
  const WaIntroCard({
    super.key,
    required this.open,
    required this.onToggle,
    this.phone,
    this.onChangePhone,
  });

  final bool open;
  final VoidCallback? onToggle;
  final String? phone;
  final VoidCallback? onChangePhone;

  static const steps = [
    'Məhsulun *şəklini* göndərin.',
    'Mətn yazın və ya *səsli mesaj* göndərin: nədir, harada hazırlanıb, qiyməti.',
    'Bot süni intellektlə *qaralama*, qiymət və tövsiyə olunan aralıq göndərir: '
        '*1* — təsdiq, *2* — düzəliş, və ya rəqəm yazıb qiyməti dəyişin.',
    'Bot soruşur: «Variantlara baxaq?» — *Bəli* və ya *Xeyr*.',
    'Hər variant üçün *Bəli / Xeyr* → qiymət → neçə günə hazır olar.',
  ];

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: const BoxDecoration(color: AppColors.waGreen, shape: BoxShape.circle),
          child: const Icon(Icons.chat_rounded, color: AppColors.white, size: 26),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('WhatsApp ilə işləyin', style: AppText.body(19, weight: FontWeight.w800)),
              Text(
                'Şəkil və səsli mesaj göndərin, qalanını bot edir.',
                style: AppText.body(15.5, color: AppColors.ink2, height: 1.35),
              ),
            ],
          ),
        ),
        if (onToggle != null)
          Icon(
            open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: AppColors.ink2,
            size: 32,
          ),
      ],
    );

    return AppCard(
      padding: const EdgeInsets.all(16),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (onToggle == null)
            header
          else
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
                onTap: onToggle,
                borderRadius: BorderRadius.circular(16),
                child: header,
              ),
            ),
          if (open) ...[
            const SizedBox(height: 14),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NumberBadge(i + 1, size: 32, color: AppColors.waHeader),
                    const SizedBox(width: 12),
                    Expanded(
                      child: waRich(
                        steps[i],
                        AppText.body(16.5, color: AppColors.ink, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            if (phone != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.phone_iphone_rounded, color: AppColors.ink2, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Nömrə: $phone',
                      style: AppText.body(16, weight: FontWeight.w700, color: AppColors.ink2),
                    ),
                  ),
                  if (onChangePhone != null)
                    AppButton(
                      label: 'Dəyiş',
                      variant: BtnVariant.ghost,
                      size: BtnSize.sm,
                      onPressed: onChangePhone,
                    ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

// ───────────────────────────── Phone frame ─────────────────────────────

/// Green header bar: bot avatar, name and "bot".
class WaHeaderBar extends StatelessWidget {
  const WaHeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.waHeader,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: AppColors.white, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: const AppLogo(size: 30, showText: false),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cultural Export Hub',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(17, weight: FontWeight.w800, color: AppColors.white),
                ),
                Text('bot', style: AppText.body(14, color: AppColors.white.withValues(alpha: .8))),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, color: AppColors.waGreen, size: 24),
        ],
      ),
    );
  }
}

/// "Bu gün" chip at the top of the conversation.
class WaDayChip extends StatelessWidget {
  const WaDayChip({super.key, this.label = 'Bu gün'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.white.withValues(alpha: .9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: AppShadows.small,
        ),
        child: Text(
          label,
          style: AppText.body(13.5, weight: FontWeight.w700, color: AppColors.ink2),
        ),
      ),
    );
  }
}

/// One chat bubble: outgoing (green, end) or incoming (white, start).
class WaBubble extends StatelessWidget {
  const WaBubble({
    super.key,
    required this.message,
    this.onButton,
    this.onRetry,
    this.buttonsEnabled = true,
  });

  final WaMessage message;
  final ValueChanged<String>? onButton;
  final VoidCallback? onRetry;
  final bool buttonsEnabled;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final out = m.outgoing;
    return LayoutBuilder(
      builder: (context, c) {
        final maxW = math.min(c.maxWidth * .84, 400.0);
        final imgW = math.min(maxW - 8, 280.0);
        const r = Radius.circular(14);
        const tail = Radius.circular(3);
        final hasText = m.text.isNotEmpty;

        final meta = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('HH:mm').format(m.at),
              style: AppText.body(12.5, color: AppColors.muted, height: 1.2),
            ),
            if (out) ...[
              const SizedBox(width: 4),
              switch (m.status) {
                WaStatus.sending => const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: AppColors.muted,
                ),
                WaStatus.sent => const Icon(
                  Icons.done_all_rounded,
                  size: 17,
                  color: AppColors.brand,
                ),
                WaStatus.failed => const Icon(
                  Icons.error_rounded,
                  size: 17,
                  color: AppColors.danger,
                ),
              },
            ],
          ],
        );

        final bubble = Container(
          margin: const EdgeInsets.symmetric(vertical: 3),
          padding: m.hasImages
              ? const EdgeInsets.fromLTRB(4, 4, 4, 6)
              : const EdgeInsets.fromLTRB(12, 8, 12, 6),
          decoration: BoxDecoration(
            color: out ? AppColors.waBubble : AppColors.white,
            borderRadius: BorderRadiusDirectional.only(
              topStart: out ? r : tail,
              topEnd: out ? tail : r,
              bottomStart: r,
              bottomEnd: r,
            ),
            boxShadow: AppShadows.small,
          ),
          // IntrinsicWidth: the bubble hugs its content while the time stamp
          // can still sit at the end edge.
          child: IntrinsicWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m.system)
                  Padding(
                    padding: EdgeInsets.fromLTRB(m.hasImages ? 8 : 0, m.hasImages ? 4 : 0, 0, 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.notifications_active_rounded,
                          size: 17,
                          color: AppColors.waHeader,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Bildiriş',
                          style: AppText.body(
                            13.5,
                            weight: FontWeight.w800,
                            color: AppColors.waHeader,
                          ),
                        ),
                      ],
                    ),
                  ),
                for (final f in m.files) _image(PickedImage(f), imgW),
                for (final u in m.imageUrls) _image(NetImage(u), imgW),
                if (hasText)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: m.hasImages ? 8 : 0),
                    child: waRich(m.text, AppText.body(17, color: AppColors.ink, height: 1.4)),
                  ),
                const SizedBox(height: 2),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: m.hasImages ? 6 : 0),
                  child: Align(alignment: AlignmentDirectional.centerEnd, child: meta),
                ),
              ],
            ),
          ),
        );

        return Align(
          alignment: out ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Column(
              crossAxisAlignment: out ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                bubble,
                if (m.buttons.isNotEmpty)
                  for (final b in m.buttons)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SizedBox(
                        width: maxW,
                        child: _BotButton(
                          label: b,
                          onTap: buttonsEnabled && onButton != null ? () => onButton!(b) : null,
                        ),
                      ),
                    ),
                if (m.status == WaStatus.failed && onRetry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, color: AppColors.danger),
                      label: Text(
                        'Göndərilmədi — yenidən göndər',
                        style: AppText.body(15, weight: FontWeight.w700, color: AppColors.danger),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _image(Widget child, double w) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(width: w, height: w * .75, child: child),
    ),
  );
}

class _BotButton extends StatelessWidget {
  const _BotButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.reply_rounded,
                size: 20,
                color: onTap == null ? AppColors.line2 : AppColors.waHeader,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppText.body(
                    16.5,
                    weight: FontWeight.w800,
                    color: onTap == null ? AppColors.muted : AppColors.waHeader,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Bot yazır…" bubble while waiting for the reply.
class WaTypingBubble extends StatelessWidget {
  const WaTypingBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: AppShadows.small,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.waHeader),
            ),
            const SizedBox(width: 10),
            Text(
              'Bot yazır…',
              style: AppText.body(16, weight: FontWeight.w600, color: AppColors.muted),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────────── Quick replies ─────────────────────────────

class WaQuickAction {
  const WaQuickAction(this.label, this.onTap, {this.icon});

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
}

/// Horizontal strip of pill buttons above the composer.
class WaQuickReplies extends StatelessWidget {
  const WaQuickReplies({super.key, required this.actions, this.enabled = true});

  final List<WaQuickAction> actions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.textScalerOf(context).scale(16.5) * 1.45 + 30;
    return SizedBox(
      height: math.max(h, 56),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final a = actions[i];
          final fg = enabled ? AppColors.waHeader : AppColors.muted;
          return Material(
            color: AppColors.white,
            shape: StadiumBorder(
              side: BorderSide(
                color: a.icon != null ? AppColors.waGreen : AppColors.line2,
                width: 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: enabled ? a.onTap : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (a.icon != null) ...[
                      Icon(a.icon, size: 20, color: fg),
                      const SizedBox(width: 6),
                    ],
                    Text(
                      a.label,
                      style: AppText.body(16.5, weight: FontWeight.w800, color: fg),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Thumbnails of images attached but not yet sent.
class WaPendingImages extends StatelessWidget {
  const WaPendingImages({super.key, required this.files, required this.onRemove});

  final List<XFile> files;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        itemCount: files.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => SizedBox.square(
          dimension: 72,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: PickedImage(files[i])),
              Positioned(
                top: 2,
                right: 2,
                child: RoundIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Şəkli sil',
                  background: AppColors.white,
                  size: 32,
                  onPressed: () => onRemove(i),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────── Composer ─────────────────────────────

/// Attach + text + mic in a white pill, round green send button.
class WaComposer extends ConsumerWidget {
  const WaComposer({
    super.key,
    required this.controller,
    required this.onSend,
    required this.onAttach,
    required this.canSend,
    this.sending = false,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool canSend;
  final bool sending;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: AppShadows.small,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    tooltip: 'Şəkil əlavə et',
                    onPressed: onAttach,
                    iconSize: 28,
                    padding: const EdgeInsets.all(12),
                    icon: const Icon(Icons.photo_camera_rounded, color: AppColors.ink2),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => onSend(),
                        style: AppText.body(18, weight: FontWeight.w500),
                        decoration: InputDecoration(
                          hintText: 'Mesaj yazın',
                          hintStyle: AppText.body(18, color: AppColors.muted),
                          filled: false,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: voice,
                    builder: (context, _) {
                      final listening = voice.isListeningTo(controller);
                      return IconButton(
                        tooltip: listening ? 'Dayandır' : 'Səslə yaz',
                        iconSize: 28,
                        padding: const EdgeInsets.all(12),
                        onPressed: () async {
                          await voice.toggle(controller);
                          if (voice.hint != null) showToast(voice.hint!, large: true);
                        },
                        icon: Icon(
                          listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                          color: listening ? AppColors.accent : AppColors.ink2,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 6),
          Semantics(
            button: true,
            label: 'Göndər',
            child: Material(
              color: canSend ? AppColors.waGreen : AppColors.line2,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: canSend ? onSend : null,
                child: SizedBox.square(
                  dimension: 56,
                  child: sending
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.6,
                            color: AppColors.white,
                          ),
                        )
                      : const Icon(Icons.send_rounded, color: AppColors.white, size: 26),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Phone entry ─────────────────────────────

/// Asks for the WhatsApp number when it cannot be found automatically.
class WaPhoneForm extends StatefulWidget {
  const WaPhoneForm({super.key, required this.onSubmit, this.initial, this.onCancel});

  final ValueChanged<String> onSubmit;
  final String? initial;
  final VoidCallback? onCancel;

  @override
  State<WaPhoneForm> createState() => _WaPhoneFormState();
}

class _WaPhoneFormState extends State<WaPhoneForm> {
  late final _c = TextEditingController(text: widget.initial ?? '');

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final v = _c.text.trim();
    if (v.replaceAll(RegExp(r'[^0-9]'), '').length < 7) {
      showToast('Telefon nömrəsini tam yazın', kind: ToastKind.error, large: true);
      return;
    }
    widget.onSubmit(v);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AppCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('WhatsApp nömrəniz', style: AppText.aH2),
              const SizedBox(height: 6),
              Text('Bot sizinlə bu nömrə ilə danışacaq.', style: AppText.aHint),
              const SizedBox(height: 16),
              AppTextField(
                controller: _c,
                artisan: true,
                hint: '+994 50 000 00 00',
                prefixIcon: Icons.phone_rounded,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              AppButton(
                label: 'Davam et',
                icon: Icons.arrow_forward_rounded,
                size: BtnSize.xl,
                onPressed: _submit,
              ),
              if (widget.onCancel != null) ...[
                const SizedBox(height: 8),
                AppButton(
                  label: 'Ləğv et',
                  variant: BtnVariant.ghost,
                  size: BtnSize.lg,
                  expand: true,
                  onPressed: widget.onCancel,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
