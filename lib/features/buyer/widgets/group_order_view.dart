import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/config.dart';
import '../../../core/i18n/strings.dart';
import '../../../core/models/order.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/bars.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/images.dart';
import '../../../router.dart';
import '../phase2/phase2_models.dart';
import '../phase2/phase2_widgets.dart';

/// Renders a group order (`GR-…`: gift boxes / B2B) from `/groups/track`.
class GroupOrderView extends ConsumerWidget {
  const GroupOrderView({super.key, required this.data, required this.email, this.onAnother});

  final Map<String, dynamic> data;
  final String email;
  final VoidCallback? onAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final g = GroupOrder.fromJson(data);
    final hasMessage = g.logo != null || (g.message ?? '').isNotEmpty;
    final hasQr = g.isGift && g.id.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(group: g, email: email),
        if (hasMessage || hasQr) ...[
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final message = hasMessage ? _MessageCard(group: g) : null;
              final qr = hasQr ? _QrCard(groupId: g.id) : null;
              if (message != null && qr != null && c.maxWidth >= 760) {
                // No IntrinsicHeight: the QR card uses a LayoutBuilder.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: message),
                    const SizedBox(width: 16),
                    Expanded(child: qr),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ?message,
                  if (message != null && qr != null) const SizedBox(height: 16),
                  ?qr,
                ],
              );
            },
          ),
        ],
        if (g.orders.isNotEmpty) ...[
          const SizedBox(height: 16),
          _ItemsCard(orders: g.orders, email: email),
        ],
        if (g.makers.isNotEmpty) ...[
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CardTitle(icon: Icons.people_alt_rounded, title: t('group.makers')),
                const SizedBox(height: 14),
                MakersWrap(makers: g.makers),
              ],
            ),
          ),
        ],
        if (!g.amounts.isEmpty || g.address != null) ...[
          const SizedBox(height: 16),
          _TotalsCard(group: g),
        ],
        if (onAnother != null) ...[
          const SizedBox(height: 20),
          AppButton(
            label: t('tr.another'),
            icon: Icons.search_rounded,
            variant: BtnVariant.outline,
            expand: true,
            onPressed: onAnother,
          ),
        ],
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.group, required this.email});

  final GroupOrder group;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final g = group;
    final typeLabel = g.isGift
        ? t('group.type.gift')
        : (g.isB2b ? t('group.type.b2b') : t('group.type.group'));
    final title = g.boxName.orNull(lang) ?? g.company ?? typeLabel;
    final pct = (g.progress * 100).round();
    final details = [
      if (g.boxes != null) t('group.boxes', {'n': g.boxes}),
      if (g.createdAt != null) t('group.placedOn', {'date': formatDate(g.createdAt!, lang)}),
      if (email.isNotEmpty) email,
    ];

    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconCircle(
                icon: g.isGift ? Icons.card_giftcard_rounded : Icons.business_center_rounded,
                color: g.isGift ? AppColors.accent : AppColors.brand,
                background: g.isGift ? AppColors.accentLight : AppColors.brandLight,
                size: 52,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (g.id.isNotEmpty)
                      Text(g.id, style: AppText.mono(13, color: AppColors.muted)),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(21, weight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        AppBadge(
                          typeLabel,
                          variant: g.isGift ? BadgeVariant.accent : BadgeVariant.neutral,
                        ),
                        StatusBadge(status: g.status, label: g.statusLabel),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Text(t('tr.progress'), style: AppText.label)),
              Text(t('group.pct', {'p': pct}), style: AppText.price(15, color: AppColors.brand)),
            ],
          ),
          const SizedBox(height: 8),
          AppProgressBar(value: g.progress),
          if (g.orders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              t('group.delivered', {'n': g.deliveredCount, 'total': g.orders.length}),
              style: AppText.caption,
            ),
          ],
          if (details.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(details.join(' · '), style: AppText.caption),
          ],
        ],
      ),
    );
  }
}

class _MessageCard extends ConsumerWidget {
  const _MessageCard({required this.group});

  final GroupOrder group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final g = group;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (g.logo != null) ...[
                Container(
                  width: 64,
                  height: 64,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: NetImage(g.logo, fit: BoxFit.contain, semanticLabel: g.company),
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('group.cardMessage'), style: AppText.caption),
                    if (g.company != null)
                      Text(g.company!, style: AppText.body(16, weight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          if ((g.message ?? '').isNotEmpty) ...[
            const SizedBox(height: 14),
            const Icon(Icons.format_quote_rounded, color: AppColors.gold, size: 28),
            Text(
              g.message!,
              style: AppText.display(
                18,
                weight: FontWeight.w500,
                style: FontStyle.italic,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _QrCard extends ConsumerWidget {
  const _QrCard({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final url = '${AppConfig.webBase}/#${Routes.box(groupId)}';
    final qr = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: QrImageView(
        data: url,
        size: 132,
        backgroundColor: AppColors.white,
        eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppColors.ink),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.ink,
        ),
        semanticsLabel: t('group.qr.title'),
      ),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(t('group.qr.title'), style: AppText.h3),
        const SizedBox(height: 6),
        Text(t('group.qr.sub'), style: AppText.bodyS),
        const SizedBox(height: 14),
        AppButton(
          label: t('group.qr.open'),
          variant: BtnVariant.soft,
          size: BtnSize.sm,
          trailingIcon: Icons.arrow_forward_rounded,
          onPressed: () => context.push(Routes.box(groupId)),
        ),
      ],
    );
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 420) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(child: qr),
                const SizedBox(height: 16),
                text,
              ],
            );
          }
          return Row(
            children: [
              qr,
              const SizedBox(width: 18),
              Expanded(child: text),
            ],
          );
        },
      ),
    );
  }
}

class _ItemsCard extends ConsumerWidget {
  const _ItemsCard({required this.orders, required this.email});

  final List<Order> orders;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    var pieces = 0;
    for (final o in orders) {
      pieces += o.qty;
    }
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(
            icon: Icons.inventory_2_outlined,
            title: t('group.items'),
            trailing: Text(t('group.pieces', {'n': pieces}), style: AppText.caption),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < orders.length; i++) ...[
            if (i > 0) const Divider(),
            _OrderLine(order: orders[i], email: email),
          ],
        ],
      ),
    );
  }
}

class _OrderLine extends ConsumerWidget {
  const _OrderLine({required this.order, required this.email});

  final Order order;
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final o = order;
    final artisan = artisanOf(o.raw['artisan']);
    final title = o.title.isNotEmpty ? o.title : t('tr.order', {'id': o.id});
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ThumbRow(
        image: o.realPhoto ?? o.image,
        title: title,
        subtitle: [
          t('group.qty', {'n': o.qty}),
          if (artisan != null) artisan.name,
          if (o.id.isNotEmpty) o.id,
        ].join(' · '),
        bottom: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: StatusBadge(status: o.status, label: o.statusLabel),
          ),
        ),
        trailing: o.id.isEmpty || email.isEmpty
            ? null
            : const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      ),
    );
    if (o.id.isEmpty || email.isEmpty) return row;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.push(Routes.trackOrder(o.id, email)),
      child: row,
    );
  }
}

class _TotalsCard extends ConsumerWidget {
  const _TotalsCard({required this.group});

  final GroupOrder group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final g = group;
    final b = g.amounts;
    final paid =
        g.isPaid ?? (b.paid != null && b.total != null && b.paid! >= b.total! - 0.01 ? true : null);
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CardTitle(
            icon: Icons.receipt_long_rounded,
            title: t('group.totals'),
            trailing: paid == true
                ? AppBadge(t('tr.paid'), variant: BadgeVariant.ok, icon: Icons.check_rounded)
                : null,
          ),
          const SizedBox(height: 10),
          BreakdownLines(
            breakdown: b,
            showPaid: true,
            shippingLabel: g.orders.length > 1 ? t('group.shippingConsolidated') : null,
          ),
          if (g.address != null) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),
            Text(t('tr.shipTo'), style: AppText.label),
            const SizedBox(height: 4),
            Text(g.address!, style: AppText.bodyS),
          ],
        ],
      ),
    );
  }
}
