import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/order.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/concept_visual.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../../../core/widgets/skeleton.dart';
import '../../../router.dart';
import '../data/artisan_models.dart';
import '../data/artisan_repository.dart';
import '../widgets/artisan_widgets.dart';
import '../widgets/notification_tile.dart';
import '../widgets/price_block.dart';

class ArtisanHomeScreen extends ConsumerWidget {
  const ArtisanHomeScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    ref.invalidate(dashboardProvider);
    ref.invalidate(artisanOrdersProvider);
    await ref.read(dashboardProvider.future);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    return dash.when(
      loading: () => const SingleChildScrollView(
        child: ArtisanColumn(
          children: [
            Skeleton(height: 80, radius: 22),
            SizedBox(height: 16),
            Skeleton(height: 72, radius: 22),
            SizedBox(height: 16),
            SkeletonList(count: 3, height: 120),
          ],
        ),
      ),
      error: (e, _) => ErrorState(
        message: azError(e),
        artisan: true,
        retryLabel: 'Yenidən cəhd et',
        onRetry: () => ref.invalidate(dashboardProvider),
      ),
      data: (d) => RefreshIndicator(
        color: AppColors.brand,
        onRefresh: () => _refresh(ref),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ArtisanColumn(
            children: [
              _Greeting(dashboard: d),
              const SizedBox(height: 18),
              AppButton(
                label: 'Yeni məhsul əlavə et',
                icon: Icons.add_a_photo_rounded,
                size: BtnSize.xl,
                onPressed: () => context.push(Routes.ustaNew),
              ),
              const SizedBox(height: 18),
              _Stats(dashboard: d),
              const _OrderAlerts(),
              ..._requestAlerts(context, d),
              ..._draftAlerts(context, d),
              const SizedBox(height: 28),
              SectionHeader(title: 'Məhsullarım', artisan: true),
              const SizedBox(height: 12),
              if (d.products.isEmpty)
                AppCard(
                  child: EmptyState(
                    artisan: true,
                    icon: Icons.photo_camera_rounded,
                    title: 'Hələ məhsulunuz yoxdur',
                    subtitle: 'Şəkil çəkin və danışın — qalanını biz edirik.',
                  ),
                )
              else
                for (final p in d.products) ...[
                  _ProductCard(product: p),
                  const SizedBox(height: 12),
                ],
              const SizedBox(height: 20),
              _NotificationsBlock(dashboard: d),
              const SizedBox(height: 24),
              _SkillsBlock(dashboard: d),
              const SizedBox(height: 24),
              const _WhatsAppCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Custom-order requests and guest bookings.
  List<Widget> _requestAlerts(BuildContext context, ArtisanDashboard d) {
    return [
      if (d.newRequests > 0) ...[
        const SizedBox(height: 12),
        AlertCard(
          title: '${d.newRequests} yeni fərdi sifariş sorğusu',
          body: 'Alıcı sizin işinizin xüsusi versiyasını istəyir.',
          icon: Icons.chat_bubble_rounded,
          bg: AppColors.conceptBg,
          fg: AppColors.concept,
          border: AppColors.conceptBorder,
          actionLabel: 'Sorğulara bax',
          onAction: () => context.go(Routes.ustaRequests),
        ),
      ],
      if (d.bookings > 0) ...[
        const SizedBox(height: 12),
        AlertCard(
          title: '${d.bookings} qonaq rezervasiyası',
          body: 'Qonaqlar emalatxananıza gəlmək istəyir.',
          icon: Icons.explore_rounded,
          bg: AppColors.brandLight,
          fg: AppColors.brand,
          actionLabel: 'Turlara bax',
          onAction: () => context.go(Routes.ustaTours),
        ),
      ],
    ];
  }

  List<Widget> _draftAlerts(BuildContext context, ArtisanDashboard d) {
    final drafts = d.products.where((p) => p.isDraft).toList();
    return [
      for (final p in drafts) ...[
        const SizedBox(height: 12),
        AlertCard(
          title: '«${p.nameAz}» təsdiqinizi gözləyir',
          body: 'Süni intellekt səhifəni hazırladı. Yoxlayın və qiyməti təsdiqləyin.',
          icon: Icons.fact_check_rounded,
          bg: AppColors.brandLight,
          fg: AppColors.brand,
          actionLabel: 'Yoxla',
          onAction: () => context.push(Routes.ustaProduct(p.id)),
        ),
      ],
    ];
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.dashboard});

  final ArtisanDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final a = dashboard.artisan;
    final first = a.name.split(' ').first;
    final sub = [a.craft?.az, a.village].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return Row(
      children: [
        AppAvatar(name: a.name, image: a.avatar, color: a.color, size: 64),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Salam, $first!', style: AppText.aH1),
              if (sub.isNotEmpty) Text(sub, style: AppText.aHint),
            ],
          ),
        ),
      ],
    );
  }
}

class _Stats extends ConsumerWidget {
  const _Stats({required this.dashboard});

  final ArtisanDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(artisanOrdersProvider).value;
    final open =
        dashboard.openOrders ??
        orders?.where((o) => !o.isDelivered && o.status != 'cancelled').length ??
        0;
    final tiles = [
      StatTile(
        label: 'Qazanılmış gəlir',
        value: formatAzn(dashboard.earned),
        icon: Icons.account_balance_wallet_rounded,
        filled: true,
        onTap: () => context.go(Routes.ustaOrders),
      ),
      StatTile(
        label: 'Gözlənilən ödəniş',
        value: formatAzn(dashboard.pending),
        icon: Icons.hourglass_top_rounded,
        onTap: () => context.go(Routes.ustaOrders),
      ),
      StatTile(
        label: '«Bunu istəyirəm»',
        value: '${dashboard.totalWants}',
        icon: Icons.favorite_rounded,
        accent: true,
      ),
      StatTile(
        label: 'Açıq sifariş',
        value: '$open',
        icon: Icons.local_shipping_rounded,
        onTap: () => context.go(Routes.ustaOrders),
      ),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final cols = c.maxWidth >= 560 ? 4 : 2;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [for (final t in tiles) SizedBox(width: w, child: t)],
        );
      },
    );
  }
}

/// Order-driven alerts: new made-to-order, sold & hand-over, in progress.
class _OrderAlerts extends ConsumerWidget {
  const _OrderAlerts();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(artisanOrdersProvider).value ?? const <Order>[];
    final alerts = <Widget>[];
    for (final o in orders) {
      final title = o.titleAz ?? o.title;
      if (o.status == 'new' && o.madeToOrder) {
        alerts.add(
          AlertCard(
            title: '«$title» üçün sifariş var!',
            body: o.countryName == null ? null : 'Alıcı: ${o.countryName}',
            icon: Icons.auto_awesome,
            bg: AppColors.conceptBg,
            fg: AppColors.concept,
            border: AppColors.conceptBorder,
            actionLabel: 'Sifarişə bax',
            onAction: () => context.go(Routes.ustaOrders),
          ),
        );
      } else if (_needsHandover(o)) {
        alerts.add(
          AlertCard(
            title: 'Satıldı! «$title» — zəhmət olmasa təhvil verin',
            icon: Icons.celebration_rounded,
            bg: AppColors.goldLight,
            fg: AppColors.goldInk,
            border: AppColors.gold,
            actionLabel: 'Necə təhvil verim?',
            onAction: () => context.go(Routes.ustaOrders),
          ),
        );
      } else if (o.status == 'artisan_making') {
        alerts.add(
          AlertCard(
            title: '«$title» hazırlanır',
            body: 'Hazır olanda şəklini yükləyin — alıcı görəcək.',
            icon: Icons.photo_camera_rounded,
            bg: AppColors.white,
            fg: AppColors.brand,
            border: AppColors.line,
            actionLabel: 'Şəkil yüklə',
            onAction: () => context.go(Routes.ustaOrders),
          ),
        );
      }
    }
    if (alerts.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in alerts) ...[const SizedBox(height: 12), a],
      ],
    );
  }
}

bool _needsHandover(Order o) =>
    o.handoverMethod == null &&
    (o.status == 'awaiting_handover' || (o.status == 'new' && !o.madeToOrder));

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final ArtisanProduct product;

  @override
  Widget build(BuildContext context) {
    final p = product;
    final certBadge = p.isDraft
        ? const AppBadge('Qaralama', variant: BadgeVariant.neutral, large: true)
        : p.cert.isVerified
        ? const AppBadge(
            'Sertifikatlı',
            variant: BadgeVariant.ok,
            icon: Icons.verified_rounded,
            large: true,
          )
        : const AppBadge(
            'Ekspert yoxlayır',
            variant: BadgeVariant.pending,
            icon: Icons.schedule_rounded,
            large: true,
          );
    final variants = p.approvedVariants;

    return AppCard(
      padding: const EdgeInsets.all(16),
      onTap: () => context.push(Routes.ustaProduct(p.id)),
      semanticLabel: p.nameAz,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ArtisanThumb(image: p.image, size: 88),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nameAz,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(19, weight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        certBadge,
                        if (!p.isDraft)
                          AppBadge(
                            p.sold ? 'Satıldı' : 'Satışdadır',
                            variant: p.sold ? BadgeVariant.gold : BadgeVariant.ready,
                            large: true,
                          ),
                      ],
                    ),
                    if (p.wants > 0) ...[
                      const SizedBox(height: 8),
                      WantsLabel('${p.wants} nəfər istəyir', size: 14.5, pill: true),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  p.priceAZN == null ? '—' : formatAzn(p.priceAZN),
                  style: AppText.display(28, weight: FontWeight.w800),
                ),
              ),
              if (!p.isDraft && !p.sold)
                AppButton(
                  label: 'Qiyməti dəyiş',
                  icon: Icons.edit_rounded,
                  variant: BtnVariant.soft,
                  onPressed: () => showPriceSheet(context, p),
                ),
            ],
          ),
          if (!p.isDraft) ...[
            const SizedBox(height: 10),
            AppButton(
              label: p.hasVideo ? 'Videonu dəyiş' : 'Video hekayə əlavə et',
              icon: Icons.videocam_rounded,
              variant: BtnVariant.outline,
              size: BtnSize.lg,
              expand: true,
              onPressed: () => context.push(Routes.ustaVideo(p.id)),
            ),
          ],
          if (variants.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 10),
            Text(
              'Sifarişlə hazırlanan versiyalar',
              style: AppText.body(15, weight: FontWeight.w800, color: AppColors.concept),
            ),
            const SizedBox(height: 8),
            for (final v in variants) _VariantRow(variant: v),
          ],
        ],
      ),
    );
  }
}

class _VariantRow extends StatelessWidget {
  const _VariantRow({required this.variant});

  final ArtisanVariant variant;

  @override
  Widget build(BuildContext context) {
    final v = variant;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox.square(
            dimension: 56,
            child: ConceptVisual(image: v.image, concept: v.concept, radius: 12, compact: true),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.nameAz,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(16.5, weight: FontWeight.w700),
                ),
                Text(
                  [
                    if (v.priceAZN != null) formatAzn(v.priceAZN),
                    if (v.leadDays != null) '${v.leadDays} gün',
                  ].join(' · '),
                  style: AppText.body(15, color: AppColors.ink2),
                ),
              ],
            ),
          ),
          if (v.wants > 0) WantsLabel('${v.wants}', size: 15, pill: true),
        ],
      ),
    );
  }
}

class _NotificationsBlock extends ConsumerWidget {
  const _NotificationsBlock({required this.dashboard});

  final ArtisanDashboard dashboard;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = dashboard.notifications.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Bildirişlər',
          artisan: true,
          action: dashboard.unread > 0
              ? AppButton(
                  label: 'Oxundu',
                  icon: Icons.done_all_rounded,
                  variant: BtnVariant.soft,
                  onPressed: () async {
                    try {
                      await ref.read(artisanRepoProvider).markNotificationsRead();
                      ref.invalidate(dashboardProvider);
                    } catch (e) {
                      showToast(azError(e), kind: ToastKind.error, large: true);
                    }
                  },
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          AppCard(child: Text('Hələ bildiriş yoxdur.', style: AppText.aHint))
        else
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  NotificationTile(item: items[i]),
                  if (i < items.length - 1) const Divider(indent: 16, endIndent: 16),
                ],
              ],
            ),
          ),
        if (dashboard.notifications.length > items.length) ...[
          const SizedBox(height: 10),
          AppButton(
            label: 'Bütün bildirişlər',
            variant: BtnVariant.ghost,
            trailingIcon: Icons.arrow_forward_rounded,
            onPressed: () => context.push(Routes.ustaNotifications),
          ),
        ],
      ],
    );
  }
}

class _SkillsBlock extends StatelessWidget {
  const _SkillsBlock({required this.dashboard});

  final ArtisanDashboard dashboard;

  @override
  Widget build(BuildContext context) {
    final skills = dashboard.skills.where((s) => s.active).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: 'Bacarıqlarım',
          artisan: true,
          action: AppButton(
            label: 'Dəyiş',
            icon: Icons.tune_rounded,
            variant: BtnVariant.soft,
            onPressed: () => context.go(Routes.ustaProfile),
          ),
        ),
        const SizedBox(height: 6),
        Text('Süni intellekt yalnız bacardığınız variantları təklif edir.', style: AppText.aHint),
        const SizedBox(height: 12),
        if (skills.isEmpty)
          Text('Hələ bacarıq qeyd olunmayıb.', style: AppText.aHint)
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final s in skills) AppChip(label: s.az, large: true)],
          ),
      ],
    );
  }
}

/// "WhatsApp ilə işləyin" — opens the in-app bot simulator.
class _WhatsAppCard extends StatelessWidget {
  const _WhatsAppCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push(Routes.ustaWhatsApp),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: const BoxDecoration(color: AppColors.waGreen, shape: BoxShape.circle),
            child: const Icon(Icons.chat_rounded, color: AppColors.white, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('WhatsApp ilə işləyin', style: AppText.body(19, weight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  'Şəkil və səsli mesaj göndərin — qalanını bot edir.',
                  style: AppText.body(15.5, color: AppColors.ink2),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 28),
        ],
      ),
    );
  }
}
