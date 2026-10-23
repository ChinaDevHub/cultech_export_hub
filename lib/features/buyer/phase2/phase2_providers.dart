import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import 'phase2_models.dart';
import 'phase2_repository.dart';

// ── Gift boxes ──

final giftsProvider = FutureProvider.autoDispose<GiftsData>(
  (ref) => ref.watch(phase2RepoProvider).gifts(),
);

final groupStoryProvider = FutureProvider.autoDispose.family<GroupStory, String>(
  (ref, id) => ref.watch(phase2RepoProvider).groupStory(id),
);

// ── Experiences ──

typedef ExpFilter = ({String? type, String? region});

final experiencesProvider = FutureProvider.autoDispose.family<List<Experience>, ExpFilter>(
  (ref, f) => ref.watch(phase2RepoProvider).experiences(type: f.type, region: f.region),
);

// ── B2B ──

/// Re-fetched whenever the signed-in account changes.
final b2bCatalogProvider = FutureProvider<List<B2bItem>>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  return ref.watch(phase2RepoProvider).b2bCatalog();
});

final b2bOrdersProvider = FutureProvider<List<B2bOrder>>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  return ref.watch(phase2RepoProvider).b2bOrders();
});

final b2bQuotesProvider = FutureProvider<List<B2bQuote>>((ref) {
  ref.watch(authProvider.select((a) => a.token));
  return ref.watch(phase2RepoProvider).b2bQuotes();
});

enum B2bTab { catalog, orders, quotes }

class B2bTabNotifier extends Notifier<B2bTab> {
  @override
  B2bTab build() => B2bTab.catalog;

  void set(B2bTab tab) => state = tab;
}

final b2bTabProvider = NotifierProvider<B2bTabNotifier, B2bTab>(B2bTabNotifier.new);

/// The business cart: `itemType:itemId` → line (insertion ordered).
class B2bCart extends Notifier<Map<String, B2bLine>> {
  @override
  Map<String, B2bLine> build() {
    // A different account starts with an empty cart.
    ref.watch(authProvider.select((a) => a.token));
    return const {};
  }

  int qtyOf(B2bItem item) => state[item.key]?.qty ?? 0;

  void setQty(B2bItem item, int qty) {
    final next = {...state};
    if (qty <= 0) {
      next.remove(item.key);
    } else {
      next[item.key] = B2bLine(item, qty);
    }
    state = next;
  }

  void clear() => state = const {};
}

final b2bCartProvider = NotifierProvider<B2bCart, Map<String, B2bLine>>(B2bCart.new);
