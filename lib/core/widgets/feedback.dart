import 'package:flutter/material.dart';

import '../theme/text_styles.dart';
import '../theme/tokens.dart';
import 'app_button.dart';

/// Global messenger so toasts can be shown from anywhere.
final rootMessengerKey = GlobalKey<ScaffoldMessengerState>();

enum ToastKind { info, ok, error }

/// Dark ink pill (green for ok, red for error), rounded 16, bold.
void showToast(String message, {ToastKind kind = ToastKind.info, bool large = false}) {
  final messenger = rootMessengerKey.currentState;
  if (messenger == null) return;
  final bg = switch (kind) {
    ToastKind.ok => AppColors.ok,
    ToastKind.error => AppColors.danger,
    ToastKind.info => AppColors.ink,
  };
  final icon = switch (kind) {
    ToastKind.ok => Icons.check_circle_rounded,
    ToastKind.error => Icons.error_rounded,
    ToastKind.info => Icons.info_rounded,
  };
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        backgroundColor: bg,
        duration: Duration(milliseconds: kind == ToastKind.error ? 4500 : 3200),
        content: Row(
          children: [
            Icon(icon, color: AppColors.white, size: large ? 26 : 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppText.body(
                  large ? 17 : 15,
                  weight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
}

/// Confirmation dialog. Returns true when [confirmLabel] is pressed.
Future<bool> showConfirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  BtnVariant confirmVariant = BtnVariant.brand,
  IconData? icon,
  Color iconColor = AppColors.warn,
  Color iconBg = AppColors.warnLight,
  bool artisan = false,
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (icon != null) ...[
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                    child: Icon(icon, color: iconColor, size: 32),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                textAlign: TextAlign.center,
                style: artisan ? AppText.aH2 : AppText.display(24, weight: FontWeight.w700),
              ),
              if (message != null) ...[
                const SizedBox(height: 10),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: artisan ? AppText.aBody.copyWith(color: AppColors.ink2) : AppText.bodyS,
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                label: confirmLabel,
                variant: confirmVariant,
                size: artisan ? BtnSize.xl : BtnSize.lg,
                expand: true,
                onPressed: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: 10),
              AppButton(
                label: cancelLabel,
                variant: BtnVariant.outline,
                size: artisan ? BtnSize.xl : BtnSize.lg,
                expand: true,
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return res ?? false;
}
