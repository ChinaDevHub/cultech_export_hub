import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import '../widgets/inputs.dart';
import 'voice_controller.dart';

/// Big round pomegranate mic button with a pulsing ring while recording.
class MicButton extends StatefulWidget {
  const MicButton({super.key, required this.listening, required this.onTap, this.size = 120});

  final bool listening;
  final VoidCallback onTap;
  final double size;

  @override
  State<MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<MicButton> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didUpdateWidget(MicButton old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  void _sync() {
    final animate = widget.listening && !AppMotion.reduced(context);
    if (animate && !_pulse.isAnimating) {
      _pulse.repeat();
    } else if (!animate && _pulse.isAnimating) {
      _pulse
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.size;
    return Semantics(
      button: true,
      label: widget.listening ? 'Dayandır' : 'Danış',
      child: SizedBox.square(
        dimension: s * 1.45,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (widget.listening)
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final v = _pulse.value;
                  return Container(
                    width: s * (1 + .42 * v),
                    height: s * (1 + .42 * v),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.accent.withValues(alpha: (1 - v) * .55),
                        width: 6,
                      ),
                    ),
                  );
                },
              ),
            Material(
              color: widget.listening ? AppColors.ink : AppColors.accent,
              shape: const CircleBorder(),
              elevation: 0,
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: widget.onTap,
                child: Ink(
                  width: s,
                  height: s,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withValues(alpha: .35),
                        blurRadius: s * .25,
                        offset: Offset(0, s * .08),
                        spreadRadius: -s * .08,
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
                    color: AppColors.white,
                    size: s * .45,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Mic + always-visible editable transcript field.
///
/// `bigMic` → the 120 px centred mic (new product screen); otherwise a
/// compact 64 px mic beside the label (revise / story fields).
class VoiceTextField extends ConsumerWidget {
  const VoiceTextField({
    super.key,
    required this.controller,
    this.label,
    this.hint,
    this.bigMic = false,
    this.minLines = 4,
    this.onChanged,
  });

  final TextEditingController controller;
  final String? label;
  final String? hint;
  final bool bigMic;
  final int minLines;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voice = ref.watch(voiceProvider);
    return ListenableBuilder(
      listenable: voice,
      builder: (context, _) {
        final listening = voice.isListeningTo(controller);
        final field = AppTextField(
          controller: controller,
          artisan: true,
          minLines: minLines,
          maxLines: 10,
          hint: hint,
          onChanged: onChanged,
          textCapitalization: TextCapitalization.sentences,
          keyboardType: TextInputType.multiline,
        );
        final status = listening
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Dinləyirəm… danışın',
                    style: AppText.body(17, weight: FontWeight.w700, color: AppColors.accent),
                  ),
                ],
              )
            : null;
        final hintText = voice.hint == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.keyboard_rounded, size: 20, color: AppColors.warn),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        voice.hint!,
                        style: AppText.body(15, weight: FontWeight.w600, color: AppColors.warn),
                      ),
                    ),
                  ],
                ),
              );

        if (bigMic) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: MicButton(listening: listening, onTap: () => voice.toggle(controller)),
              ),
              Center(
                child:
                    status ??
                    Text(
                      'Basın və danışın',
                      style: AppText.body(17, weight: FontWeight.w700, color: AppColors.ink2),
                    ),
              ),
              const SizedBox(height: 16),
              if (label != null) FieldLabel(label!, artisan: true),
              field,
              ?hintText,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (label != null) Text(label!, style: AppText.aLabel),
                      if (status != null) ...[const SizedBox(height: 4), status],
                    ],
                  ),
                ),
                MicButton(size: 60, listening: listening, onTap: () => voice.toggle(controller)),
              ],
            ),
            const SizedBox(height: 4),
            field,
            ?hintText,
          ],
        );
      },
    );
  }
}
