import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'images.dart';

/// Chat bubble: mine = teal with white text (end side), other = soft2
/// (start side). 18 radius with a small tail corner.
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    required this.mine,
    this.author,
    this.time,
    this.note,
    this.image,
    this.large = false,
  });

  final String text;
  final bool mine;
  final String? author;
  final String? time;

  /// Small line under the bubble, e.g. "auto-translated" / "not translated".
  final String? note;
  final String? image;

  /// Artisan screens use bigger text.
  final bool large;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(18);
    const tail = Radius.circular(4);
    final bg = mine ? AppColors.brand : AppColors.soft2;
    final fg = mine ? AppColors.white : AppColors.ink;
    return Align(
      alignment: mine ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (author != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3, left: 6, right: 6),
                  child: Text(
                    author!,
                    style: AppText.body(12, weight: FontWeight.w700, color: AppColors.muted),
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: large ? 12 : 10),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadiusDirectional.only(
                    topStart: r,
                    topEnd: r,
                    bottomStart: mine ? r : tail,
                    bottomEnd: mine ? tail : r,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (image != null) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(width: 200, height: 150, child: NetImage(image)),
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(text, style: AppText.body(large ? 17.5 : 15, color: fg, height: 1.4)),
                    if (time != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        time!,
                        style: AppText.body(
                          11,
                          color: mine ? AppColors.white.withValues(alpha: .75) : AppColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (note != null)
                Padding(
                  padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
                  child: Text(note!, style: AppText.body(11.5, color: AppColors.muted)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field + round send button.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSend,
    required this.hint,
    this.sending = false,
    this.large = false,
    this.leading,
  });

  final Future<void> Function(String text) onSend;
  final String hint;
  final bool sending;
  final bool large;

  /// Optional extra button (attach image, mic…).
  final Widget? leading;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _c.text.trim();
    if (text.isEmpty || widget.sending) return;
    await widget.onSend(text);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.large ? 56.0 : 48.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (widget.leading != null) ...[widget.leading!, const SizedBox(width: 8)],
        Expanded(
          child: TextField(
            controller: _c,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _send(),
            style: AppText.body(widget.large ? 18 : 15.5, weight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: widget.hint,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.line2, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.line2, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: widget.hint,
          child: Material(
            color: AppColors.brand,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: widget.sending ? null : _send,
              child: SizedBox.square(
                dimension: size,
                child: widget.sending
                    ? const Padding(
                        padding: EdgeInsets.all(14),
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.white),
                      )
                    : Icon(Icons.send_rounded, color: AppColors.white, size: size * .45),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
