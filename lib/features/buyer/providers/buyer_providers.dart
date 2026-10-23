import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/json.dart';
import '../../../core/models/catalog.dart';
import '../../../core/models/order.dart';
import '../../../core/providers.dart';
import '../data/buyer_repository.dart';

class CatalogQueryNotifier extends Notifier<CatalogQuery> {
  @override
  CatalogQuery build() => const CatalogQuery();

  void update(CatalogQuery Function(CatalogQuery) f) => state = f(state);

  void reset() => state = const CatalogQuery();
}

final catalogQueryProvider = NotifierProvider<CatalogQueryNotifier, CatalogQuery>(
  CatalogQueryNotifier.new,
);

final catalogProvider = FutureProvider.autoDispose<CatalogPage>((ref) {
  final q = ref.watch(catalogQueryProvider);
  return ref.watch(buyerRepoProvider).products(q);
});

/// Unfiltered popular list for the hero collage.
final heroItemsProvider = FutureProvider<List<CatalogItem>>((ref) async {
  final page = await ref
      .watch(buyerRepoProvider)
      .products(const CatalogQuery(mode: 'ready', sort: 'popular'));
  return page.items.where((i) => i.image != null).take(3).toList();
});

final productProvider = FutureProvider.autoDispose.family<Product, String>(
  (ref, id) => ref.watch(buyerRepoProvider).product(id, lang: ref.watch(langProvider)),
);

final variantProvider = FutureProvider.autoDispose
    .family<({Variant variant, Product product}), String>(
      (ref, id) => ref.watch(buyerRepoProvider).variant(id),
    );

final artisansProvider = FutureProvider<List<Artisan>>(
  (ref) => ref.watch(buyerRepoProvider).artisans(),
);

final artisanProfileProvider = FutureProvider.autoDispose.family<ArtisanProfile, String>(
  (ref, id) => ref.watch(buyerRepoProvider).artisan(id),
);

final statsProvider = FutureProvider<Json>((ref) => ref.watch(buyerRepoProvider).stats());

final certificateProvider = FutureProvider.autoDispose.family<Certificate, String>(
  (ref, number) => ref.watch(buyerRepoProvider).certificate(number),
);

/// The thing being bought: a product or an approved variant.
class CheckoutItem {
  const CheckoutItem({
    required this.type,
    required this.id,
    required this.title,
    required this.image,
    required this.priceAZN,
    required this.concept,
    required this.leadDays,
    required this.artisan,
    required this.ready,
    required this.stock,
  });

  final String type;
  final String id;
  final String title;
  final String? image;
  final double priceAZN;
  final Concept? concept;
  final int? leadDays;
  final Artisan? artisan;
  final bool ready;
  final int? stock;

  bool get isVariant => type == 'variant';
}

final checkoutItemProvider = FutureProvider.autoDispose.family<CheckoutItem, (String, String)>((
  ref,
  key,
) async {
  final (type, id) = key;
  final repo = ref.watch(buyerRepoProvider);
  if (type == 'variant') {
    final r = await repo.variant(id);
    return CheckoutItem(
      type: 'variant',
      id: r.variant.id,
      title: r.variant.title.isNotEmpty ? r.variant.title : r.product.title,
      image: r.variant.image ?? r.product.image,
      priceAZN: r.variant.priceAZN,
      concept: r.variant.concept,
      leadDays: r.variant.leadDays,
      artisan: r.product.artisan,
      ready: true,
      stock: null,
    );
  }
  final p = await repo.product(id);
  return CheckoutItem(
    type: 'product',
    id: p.id,
    title: p.title,
    image: p.image,
    priceAZN: p.priceAZN,
    concept: null,
    leadDays: p.leadDays,
    artisan: p.artisan,
    ready: p.ready,
    stock: p.stock,
  );
});
