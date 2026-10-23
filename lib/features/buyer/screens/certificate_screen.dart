import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/order.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../providers/buyer_providers.dart';
import '../widgets/buyer_common.dart';

class CertificateScreen extends ConsumerWidget {
  const CertificateScreen({super.key, required this.number});

  final String number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final cert = ref.watch(certificateProvider(number));
    return BuyerPage(
      maxWidth: 760,
      children: [
        const SizedBox(height: 8),
        cert.when(
          loading: () => const Skeleton(height: 640, radius: 28),
          error: (e, _) => ErrorState(
            message: errorText(e, network: t('common.network'), fallback: t('common.error')),
            retryLabel: t('common.retry'),
            onRetry: () => ref.invalidate(certificateProvider(number)),
          ),
          data: (c) => _CertificateCard(cert: c),
        ),
      ],
    );
  }
}

class _CertificateCard extends ConsumerWidget {
  const _CertificateCard({required this.cert});

  final Certificate cert;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    final c = cert;
    final verified = c.status == 'verified' || c.status == 'approved';
    final craft = config.resolveCraft(Label.fromAny(c.craft))?.of(lang);
    final qrData = '${AppConfig.webBase}/#/cert/${c.number}';

    final facts = <(String, String?)>[
      (t('cert.artisan'), c.artisan?.name),
      (t('cert.place'), c.place),
      (t('cert.category'), c.category),
      (t('cert.craft'), craft),
      (
        t('cert.verifiedOn'),
        c.verifiedAt == null ? null : DateFormat.yMMMMd(lang).format(c.verifiedAt!),
      ),
      (t('cert.verifiedBy'), c.expert),
    ].where((f) => f.$2 != null && f.$2!.isNotEmpty).toList();

    // Gold double border.
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.gold, width: 2),
        boxShadow: AppShadows.raised,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 30, 22, 26),
        decoration: BoxDecoration(
          color: AppColors.goldLight.withValues(alpha: .35),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.gold.withValues(alpha: .6), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: _Seal(verified: verified)),
            const SizedBox(height: 16),
            Text(
              t('cert.heading').toUpperCase(),
              textAlign: TextAlign.center,
              style: AppText.body(
                12.5,
                weight: FontWeight.w800,
                color: AppColors.goldInk,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              t('cert.title'),
              textAlign: TextAlign.center,
              style: AppText.display(30, weight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(color: AppColors.line),
                ),
                child: SelectableText(c.number, style: AppText.mono(15)),
              ),
            ),
            if (!verified) ...[
              const SizedBox(height: 16),
              NoteCard(
                icon: Icons.hourglass_top_rounded,
                background: AppColors.warnLight,
                foreground: AppColors.warn,
                child: Text(
                  t('cert.notVerified'),
                  style: AppText.body(14.5, weight: FontWeight.w700, color: AppColors.warn),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (c.productImage != null) ...[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: NetImage(c.productImage, radius: AppRadii.card),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            if (c.productTitle != null)
              Text(
                c.productTitle!,
                textAlign: TextAlign.center,
                style: AppText.display(20, weight: FontWeight.w600),
              ),
            const SizedBox(height: 22),
            ResponsiveWrap(
              minItemWidth: 200,
              maxCols: 2,
              spacing: 10,
              children: [
                for (final (label, value) in facts)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: AppText.body(12, weight: FontWeight.w700, color: AppColors.muted),
                        ),
                        const SizedBox(height: 2),
                        Text(value!, style: AppText.body(15, weight: FontWeight.w800)),
                      ],
                    ),
                  ),
              ],
            ),
            if (c.history.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(t('cert.history'), style: AppText.h3),
              const SizedBox(height: 10),
              for (final e in c.history) _HistoryRow(event: e, lang: lang),
            ],
            const SizedBox(height: 24),
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.line),
                ),
                child: QrImageView(
                  data: qrData,
                  size: 148,
                  backgroundColor: AppColors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColors.ink,
                  ),
                  semanticsLabel: t('cert.scan'),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(t('cert.scan'), textAlign: TextAlign.center, style: AppText.caption),
            if (c.productId != null) ...[
              const SizedBox(height: 20),
              Center(
                child: AppButton(
                  label: t('cert.viewProduct'),
                  variant: BtnVariant.soft,
                  trailingIcon: Icons.arrow_forward_rounded,
                  onPressed: () => context.push(Routes.product(c.productId!)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Seal extends StatelessWidget {
  const _Seal({required this.verified});

  final bool verified;

  @override
  Widget build(BuildContext context) {
    final color = verified ? AppColors.ok : AppColors.warn;
    return Container(
      width: 96,
      height: 96,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: verified ? AppColors.okLight : AppColors.warnLight,
        border: Border.all(color: color.withValues(alpha: .35), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Icon(
          verified ? Icons.verified_rounded : Icons.hourglass_top_rounded,
          color: AppColors.white,
          size: 44,
        ),
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.event, required this.lang});

  final CertEvent event;
  final String lang;

  @override
  Widget build(BuildContext context) {
    final a = event.action.toLowerCase();
    final ok = a.contains('approv') || a.contains('verif') || a.contains('issued');
    final bad = a.contains('reject');
    final color = ok ? AppColors.ok : (bad ? AppColors.danger : AppColors.brand);
    final who = [event.by, event.specialty].whereType<String>().join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.verified_rounded : (bad ? Icons.cancel_rounded : Icons.history_rounded),
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.action.isEmpty
                        ? '—'
                        : event.action[0].toUpperCase() + event.action.substring(1),
                    style: AppText.body(14.5, weight: FontWeight.w800),
                  ),
                  if (who.isNotEmpty) Text(who, style: AppText.body(13, color: AppColors.ink2)),
                  if (event.note != null) Text(event.note!, style: AppText.caption),
                ],
              ),
            ),
            if (event.at != null)
              Text(DateFormat.yMMMd(lang).format(event.at!), style: AppText.caption),
          ],
        ),
      ),
    );
  }
}
