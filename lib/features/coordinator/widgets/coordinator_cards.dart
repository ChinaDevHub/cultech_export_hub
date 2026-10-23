import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/api/json.dart';
import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/feedback.dart';
import '../../../core/widgets/images.dart';
import '../data/coordinator_models.dart';

/// Opens the phone dialer for [phone].
Future<void> callPhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  var ok = false;
  try {
    ok = await launchUrl(Uri(scheme: 'tel', path: cleaned));
  } catch (_) {}
  if (!ok) showToast('Zəng etmək alınmadı: $phone', kind: ToastKind.error, large: true);
}

/// Icon + text line (village, phone…) that wraps instead of overflowing.
class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 20, color: AppColors.muted),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text, style: AppText.body(16.5, color: AppColors.ink2)),
        ),
      ],
    );
  }
}

// ───────────────────────────── Route ─────────────────────────────

/// One numbered stop of the weekly collection route.
class RouteStopCard extends StatelessWidget {
  const RouteStopCard({
    super.key,
    required this.number,
    required this.stop,
    required this.isCollected,
    required this.busyOrderId,
    required this.onCollect,
  });

  final int number;
  final RouteStop stop;
  final bool Function(CollectItem item) isCollected;
  final String? busyOrderId;
  final ValueChanged<String> onCollect;

  @override
  Widget build(BuildContext context) {
    final allDone = stop.items.isNotEmpty && stop.items.every(isCollected);
    return AppCard(
      padding: const EdgeInsets.all(18),
      borderColor: allDone ? AppColors.ok : AppColors.line,
      borderWidth: allDone ? 2 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              NumberBadge(number, size: 48, color: allDone ? AppColors.ok : AppColors.brand),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stop.artisanName.isEmpty ? 'Usta' : stop.artisanName,
                      style: AppText.body(20, weight: FontWeight.w800, height: 1.25),
                    ),
                    if (stop.village != null) ...[
                      const SizedBox(height: 4),
                      _InfoLine(icon: Icons.place_rounded, text: stop.village!),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (stop.phone != null) ...[
            const SizedBox(height: 14),
            AppButton(
              label: stop.phone!,
              icon: Icons.phone_rounded,
              variant: BtnVariant.soft,
              size: BtnSize.lg,
              expand: true,
              semanticLabel: 'Zəng et: ${stop.phone}',
              onPressed: () => callPhone(stop.phone!),
            ),
          ],
          const SizedBox(height: 14),
          if (stop.items.isEmpty)
            Text('Bu ünvanda götürüləcək məhsul yoxdur.', style: AppText.aHint)
          else
            for (var i = 0; i < stop.items.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _CollectItemTile(
                item: stop.items[i],
                collected: isCollected(stop.items[i]),
                busy: busyOrderId != null && busyOrderId == stop.items[i].orderId,
                disabled: busyOrderId != null,
                onCollect: onCollect,
              ),
            ],
        ],
      ),
    );
  }
}

class _CollectItemTile extends StatelessWidget {
  const _CollectItemTile({
    required this.item,
    required this.collected,
    required this.busy,
    required this.disabled,
    required this.onCollect,
  });

  final CollectItem item;
  final bool collected;
  final bool busy;
  final bool disabled;
  final ValueChanged<String> onCollect;

  @override
  Widget build(BuildContext context) {
    final code = item.code;
    return AnimatedContainer(
      duration: AppMotion.of(context),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: collected ? AppColors.okLight : AppColors.soft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: collected ? AppColors.ok : AppColors.line, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (item.image != null) ...[
                SizedBox.square(dimension: 56, child: NetImage(item.image, radius: 12)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(18, weight: FontWeight.w800, height: 1.3),
                ),
              ),
            ],
          ),
          if (code != null) ...[
            const SizedBox(height: 12),
            Text('Təhvil kodu', style: AppText.aHint),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: collected ? AppColors.ok : AppColors.line2, width: 1.5),
              ),
              alignment: Alignment.center,
              child: Semantics(
                label: 'Təhvil kodu ${code.split('').join(' ')}',
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(code, style: AppText.mono(40, weight: FontWeight.w800)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (collected)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.ok, size: 30),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Götürüldü',
                    style: AppText.body(19, weight: FontWeight.w800, color: AppColors.ok),
                  ),
                ),
              ],
            )
          else
            AppButton(
              label: 'Götürdüm',
              icon: Icons.inventory_rounded,
              size: BtnSize.xl,
              variant: BtnVariant.ok,
              loading: busy,
              onPressed: item.orderId == null || disabled ? null : () => onCollect(item.orderId!),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Artisans ─────────────────────────────

class CoordArtisanCard extends ConsumerWidget {
  const CoordArtisanCard({
    super.key,
    required this.artisan,
    required this.onAddProduct,
    required this.onOpenPanel,
  });

  final CoordArtisan artisan;
  final VoidCallback onAddProduct;
  final VoidCallback onOpenPanel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final a = artisan;
    final config = ref.watch(configOrEmptyProvider);
    final craft = config.resolveCraft(a.craft)?.az;
    final sub = [a.village, craft].whereType<String>().where((s) => s.isNotEmpty).join(' · ');
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AppAvatar(name: a.name, image: a.avatar, color: a.color, size: 60),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.name.isEmpty ? 'Usta' : a.name,
                      style: AppText.body(20, weight: FontWeight.w800, height: 1.25),
                    ),
                    if (sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(sub, style: AppText.aHint),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppBadge(
                '${a.sales} satış',
                variant: BadgeVariant.ready,
                icon: Icons.shopping_bag_rounded,
                large: true,
              ),
              AppBadge(
                formatAzn(a.earnings),
                variant: BadgeVariant.ok,
                icon: Icons.account_balance_wallet_rounded,
                large: true,
              ),
            ],
          ),
          if (a.phone != null) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: AppButton(
                label: a.phone!,
                icon: Icons.phone_rounded,
                variant: BtnVariant.ghost,
                semanticLabel: 'Zəng et: ${a.phone}',
                onPressed: () => callPhone(a.phone!),
              ),
            ),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: 'Onun adından məhsul əlavə et',
            icon: Icons.add_a_photo_rounded,
            size: BtnSize.xl,
            onPressed: a.id.isEmpty ? null : onAddProduct,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Panelinə keç',
            icon: Icons.dashboard_rounded,
            trailingIcon: Icons.arrow_forward_rounded,
            size: BtnSize.xl,
            variant: BtnVariant.outline,
            onPressed: a.id.isEmpty ? null : onOpenPanel,
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── Recent sales ─────────────────────────────

const _statusAz = {
  'new': 'Yeni',
  'pending': 'Gözləyir',
  'paid': 'Ödənilib',
  'awaiting_handover': 'Təhvil gözləyir',
  'artisan_making': 'Hazırlanır',
  'photo_uploaded': 'Şəkil yükləndi',
  'collected': 'Götürüldü',
  'picked_up': 'Götürüldü',
  'at_hub': 'Anbardadır',
  'shipped': 'Yoldadır',
  'in_transit': 'Yoldadır',
  'delivered': 'Çatdırıldı',
  'cancelled': 'Ləğv edildi',
  'canceled': 'Ləğv edildi',
};

BadgeVariant _statusVariant(String? s) => switch (s) {
  'delivered' => BadgeVariant.ok,
  'cancelled' || 'canceled' => BadgeVariant.danger,
  'new' || 'awaiting_handover' => BadgeVariant.gold,
  'artisan_making' || 'photo_uploaded' || 'pending' => BadgeVariant.pending,
  _ => BadgeVariant.ready,
};

class RecentSalesList extends ConsumerWidget {
  const RecentSalesList({super.key, required this.sales});

  final List<RecentSale> sales;

  String _label(RecentSale s, ShopConfig config) {
    final status = s.status;
    if (status != null) {
      if (_statusAz[status] case final known?) return known;
      final raw = config.statusLabels[status];
      if (raw is Map) {
        if (str(pick(asMap(raw), ['az', 'labelAz'])) case final az?) return az;
      }
    }
    return s.statusLabel ?? status ?? '—';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(configOrEmptyProvider);
    return AppCard(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < sales.length; i++) ...[
            if (i > 0) const Divider(indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: _SaleRow(sale: sales[i], statusLabel: _label(sales[i], config)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SaleRow extends StatelessWidget {
  const _SaleRow({required this.sale, required this.statusLabel});

  final RecentSale sale;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final s = sale;
    final sub = [s.artisan, s.country].whereType<String>().where((e) => e.isNotEmpty).join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (s.image != null) ...[
          SizedBox.square(dimension: 56, child: NetImage(s.image, radius: 12)),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.body(17.5, weight: FontWeight.w800, height: 1.3),
              ),
              if (sub.isNotEmpty) Text(sub, style: AppText.body(15.5, color: AppColors.ink2)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (s.amount != null)
                    Text(formatAzn(s.amount), style: AppText.price(19, color: AppColors.ok)),
                  AppBadge(statusLabel, variant: _statusVariant(s.status), large: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
