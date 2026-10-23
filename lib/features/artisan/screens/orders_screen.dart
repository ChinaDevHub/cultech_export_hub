import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../../../core/widgets/order_stepper.dart';
import '../../../core/widgets/skeleton.dart';
import '../data/artisan_models.dart';
import '../data/artisan_repository.dart';
import '../widgets/artisan_widgets.dart';

class ArtisanOrdersScreen extends ConsumerWidget {
  const ArtisanOrdersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(artisanOrdersProvider);
    final dash = ref.watch(dashboardProvider).value;
    return orders.when(
      skipLoadingOnRefresh: true,
      loading: () => const SingleChildScrollView(
        child: ArtisanColumn(
          children: [
            Skeleton(height: 110, radius: 22),
            SizedBox(height: 16),
            SkeletonList(count: 3, height: 180),
          ],
        ),
      ),
      error: (e, _) => ErrorState(
        message: azError(e),
        artisan: true,
        retryLabel: 'Yenidən cəhd et',
        onRetry: () => ref.invalidate(artisanOrdersProvider),
      ),
      data: (list) {
        final sorted = [...list]..sort((a, b) => _priority(a).compareTo(_priority(b)));
        final earned =
            dash?.earned ??
            list.where((o) => o.isDelivered).fold<double>(0, (s, o) => s + (o.artisanAZN ?? 0));
        final pending =
            dash?.pending ??
            list.where((o) => !o.isDelivered).fold<double>(0, (s, o) => s + (o.artisanAZN ?? 0));
        return RefreshIndicator(
          color: AppColors.brand,
          onRefresh: () async {
            ref.invalidate(artisanOrdersProvider);
            ref.invalidate(dashboardProvider);
            await ref.read(artisanOrdersProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ArtisanColumn(
              children: [
                Text('Sifarişlər', style: AppText.aH1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        label: 'Qazanılmış',
                        value: formatAzn(earned),
                        icon: Icons.account_balance_wallet_rounded,
                        filled: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        label: 'Gözlənilən',
                        value: formatAzn(pending),
                        icon: Icons.hourglass_top_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (sorted.isEmpty)
                  const AppCard(
                    child: EmptyState(
                      artisan: true,
                      icon: Icons.local_shipping_outlined,
                      title: 'Hələ sifariş yoxdur',
                      subtitle: 'Sifariş gələndə burada və bildirişlərdə görəcəksiniz.',
                    ),
                  )
                else
                  for (final o in sorted) ...[_OrderCard(order: o), const SizedBox(height: 14)],
              ],
            ),
          ),
        );
      },
    );
  }

  /// Orders needing action first.
  static int _priority(Order o) {
    if (o.status == 'new') return 0;
    if (o.status == 'awaiting_handover' && o.handoverMethod == null) return 1;
    if (o.status == 'artisan_making') return 2;
    if (o.isDelivered) return 9;
    return 5;
  }
}

class _OrderCard extends ConsumerStatefulWidget {
  const _OrderCard({required this.order});

  final Order order;

  @override
  ConsumerState<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends ConsumerState<_OrderCard> {
  String? _busy;

  Future<void> _run(String key, Future<void> Function() action, String ok) async {
    setState(() => _busy = key);
    try {
      await action();
      ref.invalidate(artisanOrdersProvider);
      ref.invalidate(dashboardProvider);
      showToast(ok, kind: ToastKind.ok, large: true);
    } catch (e) {
      showToast(azError(e), kind: ToastKind.error, large: true);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _uploadPhoto() async {
    final files = await pickImages(context, max: 1);
    if (files.isEmpty) return;
    await _run(
      'photo',
      () => ref.read(artisanRepoProvider).uploadOrderPhoto(widget.order.id, files.first),
      'Şəkil yükləndi — alıcı görəcək',
    );
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.order;
    final title = o.titleAz ?? o.title;
    final thumbImage = o.realPhoto ?? o.image;
    final showConcept = o.isVariant && o.realPhoto == null;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 84,
                child: showConcept
                    ? ConceptVisual(
                        image: thumbImage,
                        concept: o.concept,
                        radius: 14,
                        compact: true,
                      )
                    : NetImage(thumbImage, radius: 14),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(18.5, weight: FontWeight.w800, height: 1.25),
                    ),
                    const SizedBox(height: 4),
                    if (o.countryName != null)
                      Row(
                        children: [
                          const Icon(Icons.public_rounded, size: 18, color: AppColors.ink2),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              o.countryName!,
                              style: AppText.body(
                                16,
                                weight: FontWeight.w600,
                                color: AppColors.ink2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    Text('Sifariş ${o.id}', style: AppText.body(15, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    AppBadge(o.statusLabel ?? o.status, variant: _badgeOf(o), large: true),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (o.artisanAZN != null)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: 'Siz alacaqsınız: ',
                    style: AppText.body(17, weight: FontWeight.w600, color: AppColors.ink2),
                  ),
                  TextSpan(
                    text: formatAzn(o.artisanAZN),
                    style: AppText.price(20, color: AppColors.ok),
                  ),
                ],
              ),
            ),
          if (o.steps.isNotEmpty) ...[
            const SizedBox(height: 12),
            SegmentProgress(total: o.steps.length, done: o.stepIndex),
          ],
          const SizedBox(height: 16),
          _action(o, title),
        ],
      ),
    );
  }

  BadgeVariant _badgeOf(Order o) {
    if (o.isDelivered) return BadgeVariant.ok;
    if (o.status == 'new') return o.madeToOrder ? BadgeVariant.concept : BadgeVariant.gold;
    if (o.status == 'awaiting_handover') return BadgeVariant.gold;
    if (o.status == 'artisan_making' || o.status == 'photo_uploaded') return BadgeVariant.pending;
    return BadgeVariant.ready;
  }

  Widget _action(Order o, String title) {
    final repo = ref.read(artisanRepoProvider);

    // Made-to-order: new → accept.
    if (o.status == 'new' && o.madeToOrder) {
      return _ColoredBlock(
        bg: AppColors.conceptBg,
        border: AppColors.conceptBorder,
        children: [
          Text(
            '«$title» üçün sifariş var.',
            style: AppText.body(19, weight: FontWeight.w800, color: AppColors.concept),
          ),
          if (o.leadDays != null) ...[
            const SizedBox(height: 4),
            Text('Hazırlama müddəti: ${o.leadDays} gün.', style: AppText.aBody),
          ],
          const SizedBox(height: 14),
          AppButton(
            label: 'Sifarişi qəbul edirəm',
            icon: Icons.handshake_rounded,
            size: BtnSize.xl,
            variant: BtnVariant.ok,
            loading: _busy == 'accept',
            onPressed: _busy != null
                ? null
                : () => _run(
                    'accept',
                    () => repo.acceptOrder(o.id),
                    'Sifariş qəbul edildi. Uğurlar!',
                  ),
          ),
        ],
      );
    }

    // Making → upload the real photo.
    if (o.status == 'artisan_making') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: 'Hazır məhsulun şəklini yüklə',
            icon: Icons.photo_camera_rounded,
            size: BtnSize.xl,
            loading: _busy == 'photo',
            onPressed: _busy != null ? null : _uploadPhoto,
          ),
          const SizedBox(height: 8),
          Text(
            'Alıcı bu şəkli göndərilmədən əvvəl görəcək.',
            textAlign: TextAlign.center,
            style: AppText.aHint,
          ),
        ],
      );
    }

    if (o.status == 'photo_uploaded') {
      return _ColoredBlock(
        bg: AppColors.brandLight,
        children: [
          Row(
            children: [
              if (o.realPhoto != null) ...[
                SizedBox.square(dimension: 64, child: NetImage(o.realPhoto, radius: 12)),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Text(
                  'Şəkil yükləndi. Ekspert yoxlayır — sonra təhvil verəcəksiniz.',
                  style: AppText.body(17, weight: FontWeight.w700, color: AppColors.brand),
                ),
              ),
            ],
          ),
        ],
      );
    }

    final awaiting = o.status == 'awaiting_handover' || (o.status == 'new' && !o.madeToOrder);
    if (awaiting && o.handoverMethod == null) {
      return _HandoverCard(
        title: title,
        code: o.handoverCode,
        busy: _busy,
        onChoose: (method) => _run(
          method,
          () => repo.handover(o.id, method),
          method == 'post' ? 'Yadda saxlandı: poçta aparacaqsınız' : 'Kuryer gəlib götürəcək',
        ),
      );
    }

    if (awaiting && o.handoverMethod != null) {
      final post = o.handoverMethod == 'post';
      return _ColoredBlock(
        bg: AppColors.okLight,
        children: [
          Row(
            children: [
              Icon(
                post ? Icons.markunread_mailbox_rounded : Icons.local_shipping_rounded,
                color: AppColors.ok,
                size: 28,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  post ? 'Poçt şöbəsinə aparacaqsınız' : 'Kuryer gəlib götürəcək',
                  style: AppText.body(18.5, weight: FontWeight.w800, color: AppColors.ok),
                ),
              ),
            ],
          ),
          if (o.handoverCode != null) ...[
            const SizedBox(height: 10),
            Text('Təhvil kodunuz:', style: AppText.aBody),
            const SizedBox(height: 4),
            Text(
              o.handoverCode!,
              style: AppText.mono(32, color: AppColors.ink, weight: FontWeight.w800),
            ),
          ],
          if (o.handoverDeadline != null) ...[
            const SizedBox(height: 6),
            Text(
              'Son tarix: ${azDate(o.handoverDeadline, withTime: false)}',
              style: AppText.body(16, weight: FontWeight.w700, color: AppColors.ink2),
            ),
          ],
        ],
      );
    }

    // Later stages: just a calm status line.
    return Row(
      children: [
        Icon(
          o.isDelivered ? Icons.verified_rounded : Icons.flight_takeoff_rounded,
          color: o.isDelivered ? AppColors.ok : AppColors.brand,
          size: 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            o.isDelivered
                ? 'Çatdırıldı. Ödəniş hesabınıza köçürülür.'
                : (o.statusLabel ?? 'Sifariş yoldadır'),
            style: AppText.body(17, weight: FontWeight.w700, color: AppColors.ink2),
          ),
        ),
      ],
    );
  }
}

class _ColoredBlock extends StatelessWidget {
  const _ColoredBlock({required this.bg, required this.children, this.border});

  final Color bg;
  final Color? border;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: border == null ? null : Border.all(color: border!, width: 2),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }
}

/// Gold "Sold! please hand over within 3 days" card with the drop-off code.
class _HandoverCard extends StatelessWidget {
  const _HandoverCard({
    required this.title,
    required this.code,
    required this.busy,
    required this.onChoose,
  });

  final String title;
  final String? code;
  final String? busy;
  final ValueChanged<String> onChoose;

  @override
  Widget build(BuildContext context) {
    final bullet = AppText.body(18, weight: FontWeight.w600, height: 1.45);
    return _ColoredBlock(
      bg: AppColors.goldLight,
      border: AppColors.gold,
      children: [
        Text('«$title» satıldı! 🎉', style: AppText.display(24, weight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text('Zəhmət olmasa 3 gün ərzində təhvil verin:', style: AppText.aBodyStrong),
        const SizedBox(height: 10),
        Text('•  Ən yaxın poçt şöbəsinə aparın — təhvil kodunuz:', style: bullet),
        if (code != null) ...[
          const SizedBox(height: 10),
          DashedFrame(
            color: AppColors.gold,
            radius: 18,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              alignment: Alignment.center,
              child: Semantics(
                label: 'Təhvil kodu ${code!.split('').join(' ')}',
                child: Text(code!, style: AppText.mono(44, weight: FontWeight.w800)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        Text('•  və ya «Gəlib götürsünlər» düyməsini basın.', style: bullet),
        const SizedBox(height: 16),
        AppButton(
          label: '📮 Poçta aparacağam',
          size: BtnSize.xl,
          loading: busy == 'post',
          onPressed: busy != null ? null : () => onChoose('post'),
        ),
        const SizedBox(height: 10),
        AppButton(
          label: '🚚 Gəlib götürsünlər',
          size: BtnSize.xl,
          variant: BtnVariant.outline,
          loading: busy == 'pickup',
          onPressed: busy != null ? null : () => onChoose('pickup'),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Icon(Icons.info_outline_rounded, size: 18, color: AppColors.goldInk),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Ölkə daxilində göndərmə pulsuzdur — platforma ödəyir.',
                style: AppText.body(15, weight: FontWeight.w600, color: AppColors.goldInk),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
