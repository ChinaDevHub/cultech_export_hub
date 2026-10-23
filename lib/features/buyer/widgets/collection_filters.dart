import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/strings.dart';
import '../../../core/providers.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/inputs.dart';
import '../providers/buyer_providers.dart';

/// Search, ready/made-to-order segmented control and dropdown filters.
class CollectionFilters extends ConsumerStatefulWidget {
  const CollectionFilters({super.key});

  @override
  ConsumerState<CollectionFilters> createState() => _CollectionFiltersState();
}

class _CollectionFiltersState extends ConsumerState<CollectionFilters> {
  late final _search = TextEditingController(text: ref.read(catalogQueryProvider).q);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    setState(() {}); // toggles the clear button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(catalogQueryProvider.notifier).update((q) => q.copyWith(q: v));
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(tProvider);
    final lang = ref.watch(langProvider);
    final config = ref.watch(configOrEmptyProvider);
    final q = ref.watch(catalogQueryProvider);
    final notifier = ref.read(catalogQueryProvider.notifier);

    // Keep the field in sync when filters are reset elsewhere.
    ref.listen(catalogQueryProvider, (prev, next) {
      if (next.q.isEmpty && prev?.q.isNotEmpty == true && _search.text.isNotEmpty) {
        _search.clear();
        setState(() {});
      }
    });

    final pills = [
      FilterPill<String>(
        label: t('filter.craft'),
        anyLabel: t('filter.any'),
        value: q.craft,
        options: [for (final c in config.crafts) (c.id, c.of(lang))],
        onChanged: (v) => notifier.update((s) => s.copyWith(craft: () => v)),
      ),
      FilterPill<String>(
        label: t('filter.region'),
        anyLabel: t('filter.any'),
        value: q.region,
        options: [for (final r in config.regions) (r.id, r.of(lang))],
        onChanged: (v) => notifier.update((s) => s.copyWith(region: () => v)),
      ),
      FilterPill<String>(
        label: t('filter.cert'),
        anyLabel: t('filter.any'),
        value: q.cert,
        options: [('verified', t('filter.verified')), ('pending', t('filter.pending'))],
        onChanged: (v) => notifier.update((s) => s.copyWith(cert: () => v)),
      ),
      FilterPill<String>(
        label: t('filter.sort'),
        value: q.sort,
        options: [
          ('popular', t('sort.popular')),
          ('newest', t('sort.newest')),
          ('priceAsc', t('sort.priceAsc')),
          ('priceDesc', t('sort.priceDesc')),
        ],
        onChanged: (v) => notifier.update((s) => s.copyWith(sort: v ?? 'popular')),
        icon: Icons.swap_vert_rounded,
      ),
    ];

    final search = AppTextField(
      controller: _search,
      hint: t('col.search'),
      prefixIcon: Icons.search_rounded,
      textInputAction: TextInputAction.search,
      onChanged: _onSearch,
      onSubmitted: (v) {
        _debounce?.cancel();
        notifier.update((s) => s.copyWith(q: v));
      },
      suffix: _search.text.isEmpty
          ? null
          : IconButton(
              tooltip: t('common.close'),
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                _search.clear();
                _debounce?.cancel();
                notifier.update((s) => s.copyWith(q: ''));
              },
            ),
    );

    final segmented = AppSegmented<String>(
      value: q.mode,
      options: [
        ('all', t('col.mode.all')),
        ('ready', t('col.mode.ready')),
        ('custom', t('col.mode.custom')),
      ],
      onChanged: (v) => notifier.update((s) => s.copyWith(mode: v)),
    );

    return LayoutBuilder(
      builder: (context, c) {
        final wide = c.maxWidth >= 860;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              Row(
                children: [
                  Expanded(child: search),
                  const SizedBox(width: 16),
                  segmented,
                ],
              )
            else ...[
              search,
              const SizedBox(height: 12),
              Align(alignment: Alignment.centerLeft, child: segmented),
            ],
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              child: Row(
                children: [
                  for (final p in pills) ...[p, const SizedBox(width: 8)],
                  if (q.isFiltered)
                    AppButton(
                      label: t('col.reset'),
                      icon: Icons.restart_alt_rounded,
                      variant: BtnVariant.ghost,
                      size: BtnSize.sm,
                      onPressed: () {
                        _search.clear();
                        notifier.reset();
                      },
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Pill that opens a menu; selected state uses brand tint.
class FilterPill<T> extends StatelessWidget {
  const FilterPill({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.anyLabel,
    this.icon,
  });

  final String label;
  final T? value;
  final List<(T, String)> options;
  final ValueChanged<T?> onChanged;

  /// When set, an "Any" entry clears the filter.
  final String? anyLabel;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    String? selectedLabel;
    for (final (v, l) in options) {
      if (v == value) selectedLabel = l;
    }
    final active = anyLabel != null && value != null;
    return PopupMenuButton<Object>(
      tooltip: label,
      position: PopupMenuPosition.under,
      onSelected: (v) => onChanged(v == _Any.instance ? null : v as T),
      itemBuilder: (_) => [
        if (anyLabel != null) PopupMenuItem<Object>(value: _Any.instance, child: Text(anyLabel!)),
        for (final (v, l) in options)
          PopupMenuItem<Object>(
            value: v,
            child: Row(
              children: [
                Expanded(child: Text(l)),
                if (v == value) const Icon(Icons.check_rounded, size: 18, color: AppColors.brand),
              ],
            ),
          ),
      ],
      child: AnimatedContainer(
        duration: AppMotion.of(context, AppMotion.fast),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: active ? AppColors.brandLight : AppColors.white,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: active ? AppColors.brand : AppColors.line2, width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: AppColors.ink2),
              const SizedBox(width: 6),
            ],
            Text(
              selectedLabel == null || (anyLabel != null && value == null)
                  ? label
                  : '$label: $selectedLabel',
              style: AppText.body(
                13.5,
                weight: FontWeight.w700,
                color: active ? AppColors.brand : AppColors.ink,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: active ? AppColors.brand : AppColors.ink2,
            ),
          ],
        ),
      ),
    );
  }
}

class _Any {
  const _Any._();
  static const instance = _Any._();
}
