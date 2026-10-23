import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/inputs.dart';
import '../phase2/b2b_catalog.dart';
import '../phase2/b2b_landing.dart';
import '../phase2/b2b_lists.dart';
import '../phase2/b2b_sheets.dart';
import '../phase2/phase2_providers.dart';
import '../phase2/phase2_widgets.dart';
import '../widgets/buyer_common.dart';

/// "For business" (`/business`): landing + sign-in for guests, the B2B
/// workspace (catalog · orders · quotes) for business accounts.
class BusinessScreen extends ConsumerWidget {
  const BusinessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isB2b = ref.watch(authProvider.select((a) => a.isB2b));
    return isB2b ? const _Workspace() : const B2bLanding();
  }
}

class _Workspace extends ConsumerWidget {
  const _Workspace();

  Future<void> _refresh(WidgetRef ref, B2bTab tab) async {
    switch (tab) {
      case B2bTab.catalog:
        ref.invalidate(b2bCatalogProvider);
        await ref.read(b2bCatalogProvider.future);
      case B2bTab.orders:
        ref.invalidate(b2bOrdersProvider);
        await ref.read(b2bOrdersProvider.future);
      case B2bTab.quotes:
        ref.invalidate(b2bQuotesProvider);
        await ref.read(b2bQuotesProvider.future);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final tab = ref.watch(b2bTabProvider);
    final cartEmpty = ref.watch(b2bCartProvider.select((c) => c.isEmpty));
    final showCart = tab == B2bTab.catalog && !cartEmpty;

    return Column(
      children: [
        Expanded(
          child: BuyerPage(
            showBack: false,
            onRefresh: () => _refresh(ref, tab),
            children: [
              const _Header(),
              const SizedBox(height: 20),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AppSegmented<B2bTab>(
                  value: tab,
                  options: [
                    (B2bTab.catalog, t('b2b.tab.catalog')),
                    (B2bTab.orders, t('b2b.tab.orders')),
                    (B2bTab.quotes, t('b2b.tab.quotes')),
                  ],
                  onChanged: (v) => ref.read(b2bTabProvider.notifier).set(v),
                ),
              ),
              const SizedBox(height: 20),
              switch (tab) {
                B2bTab.catalog => const B2bCatalogTab(),
                B2bTab.orders => const B2bOrdersTab(),
                B2bTab.quotes => const B2bQuotesTab(),
              },
            ],
          ),
        ),
        if (showCart) const B2bCartBar(),
      ],
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header();

  void _signOut(WidgetRef ref) {
    ref.read(b2bTabProvider.notifier).set(B2bTab.catalog);
    ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(tProvider);
    final auth = ref.watch(authProvider);
    final company = auth.company ?? auth.name;
    final details = [
      if (auth.company != null && auth.name.isNotEmpty) auth.name,
      ?b2bEmail(auth),
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.soft,
        borderRadius: BorderRadius.circular(AppRadii.panel),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 520;
          return Row(
            children: [
              const IconCircle(icon: Icons.business_center_rounded, size: 52),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('b2b.account'), style: AppText.caption),
                    Text(
                      company.isEmpty ? t('b2b.tab.catalog') : company,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.display(narrow ? 21 : 26, weight: FontWeight.w700),
                    ),
                    if (details.isNotEmpty)
                      Text(
                        details,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.caption,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (narrow)
                RoundIconButton(
                  icon: Icons.logout_rounded,
                  tooltip: t('b2b.signOut'),
                  size: 48,
                  onPressed: () => _signOut(ref),
                )
              else
                AppButton(
                  label: t('b2b.signOut'),
                  icon: Icons.logout_rounded,
                  variant: BtnVariant.outline,
                  onPressed: () => _signOut(ref),
                ),
            ],
          );
        },
      ),
    );
  }
}
