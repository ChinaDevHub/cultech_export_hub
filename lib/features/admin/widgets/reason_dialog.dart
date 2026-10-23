import 'package:flutter/material.dart';

import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/inputs.dart';

/// Asks for a required reason (e.g. why a certificate is rejected).
/// Returns the trimmed text, or null when cancelled.
Future<String?> showReasonDialog(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = 'Reject',
  String hint = 'What should the artisan change?',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) =>
        _ReasonDialog(title: title, message: message, confirmLabel: confirmLabel, hint: hint),
  );
}

class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.hint,
  });

  final String title;
  final String? message;
  final String confirmLabel;
  final String hint;

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ctrl.text.trim().isNotEmpty;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: const BoxDecoration(
                    color: AppColors.dangerLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded, color: AppColors.danger, size: 28),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: AppText.display(23, weight: FontWeight.w700),
              ),
              if (widget.message != null) ...[
                const SizedBox(height: 8),
                Text(widget.message!, textAlign: TextAlign.center, style: AppText.bodyS),
              ],
              const SizedBox(height: 20),
              AppTextField(
                controller: _ctrl,
                label: 'Reason',
                hint: widget.hint,
                minLines: 3,
                maxLines: 5,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 22),
              AppButton(
                label: widget.confirmLabel,
                icon: Icons.close_rounded,
                variant: BtnVariant.danger,
                size: BtnSize.lg,
                expand: true,
                onPressed: ready ? _submit : null,
              ),
              const SizedBox(height: 10),
              AppButton(
                label: 'Cancel',
                variant: BtnVariant.outline,
                size: BtnSize.lg,
                expand: true,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
