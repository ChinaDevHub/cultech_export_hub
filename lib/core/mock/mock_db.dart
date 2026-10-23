import 'mock_seed.dart';

/// In-memory "database" behind the mock backend. Everything is plain JSON
/// maps so handlers can return them (or views built from them) directly.
///
/// ── Record schemas (internal; views in mock_views.dart / mock_orders.dart
///    turn them into the API shapes the app reads) ──
///
/// users[]      {id, role: artisan|coordinator|b2b|admin|expert|ministry, name,
///               login (phone for artisan/coordinator, email otherwise), password,
///               artisanId?, company?, country?, specialty?: [craftId…] (experts)}
///              Token = `mock-<userId>` (stateless, survives app restarts).
/// artisans[]   {id, name, phone, village, region (en name), regionId, craft{id,en,az},
///               craftId, color (#hex), avatar (path|null), story (en), storyAz,
///               gender: female|male, skills[{id,en,az}], coordinatorId?, createdAt}
/// products[]   {id, artisanId, status: draft|published, hidden: bool, craftId,
///               title (en), titleAz, description, story, patternMeaning, history,
///               material, color, tags[], images[] (paths), priceAZN, priceSource,
///               leadDays, stock, ready, place, wants, variantConsent (null|bool),
///               summaryAz[], transcript, video: {url, subtitles[]}|null,
///               cert: {status: pending|verified|rejected, number?, category?,
///                      verifiedAt?, expertId?, suggestedCategory, history[{action,by,specialty,note,at}]},
///               createdAt}
/// variants[]   {id, productId, status: suggested|approved|declined, hidden: bool,
///               nameAz, title (en), concept{type,…}, priceAZN?, leadDays?, wants,
///               reasonEn, reasonAz, hint{min,max,mid,leadDays}}
/// orders[]     {id (CH-1001), itemType: product|variant|custom, itemId, artisanId,
///               qty, name, email, country (code), address, status, history[{status,at}],
///               createdAt, deposit: bool, paidAZN, amounts{artisanAZN,serviceFeeAZN,
///               shippingAZN,totalAZN}, handoverCode, handoverMethod (null|post|pickup),
///               handoverDeadline, collected: bool, realPhoto?, tracking?{carrier,number,url},
///               groupId?, customRequestId?, custom?{title,image,priceAZN,leadDays},
///               payoutRef?}
/// notifications[] {id, artisanId, textAz, type, read, at}
/// wants[]      {itemType, itemId, email, at}
///
/// Area-owned collections (`db.coll(name)`), shared schemas:
///
/// 'groups'      {id (GR-2001), type: gift|b2b, email, company?, name, country, address,
///                message?, logo? (path), boxId?, boxes?, orderIds[] (child orders live in
///                db.orders with groupId), amounts{subtotalAZN, savingsAZN, boxFeeAZN,
///                logoFeeAZN, serviceFeeAZN, shippingAZN, totalAZN}, paidAZN, quoteId?, createdAt}
///                Group status/progress are DERIVED from the child orders.
/// 'quotes'      {id (Q-3001), email, company, name, lines[{itemType,itemId,qty}], country,
///                note, status: requested|offered|accepted|declined,
///                offer?{priceAZN, note, leadDays, at}, groupId?, createdAt}
/// 'requests'    custom-order requests {id (R-501), productId, buyer{name,email,country}, size,
///                colorId, pattern, notes, quantity, sample?, status: open|offered|declined|ordered,
///                messages[{from: buyer|artisan, text (English), textAz, at, translated}],
///                offer?{priceAZN, leadDays, note}, orderId?, createdAt}
/// 'experiences' {id, artisanId, type: visit|masterclass, titleAz, title, descriptionAz,
///                description, priceAZN (per person), durationH, maxPeople, images[],
///                dates[{date (yyyy-mm-dd), seats}]}
/// 'bookings'    {id, experienceId, name, email, phone, date, people, totalAZN, createdAt}
/// 'courses'     academy programmes {id, artisanId (mentor), title, description, weeks, seats,
///                free, priceAZN?, craftId}
/// 'applications' {id, courseId, name, phone, age, message, createdAt}
/// 'payouts'     {id (PO-…), artisanId, amountAZN, orderIds[], at}. An order is PAYABLE when
///                delivered and has no `payoutRef`; paying out sets `payoutRef` on its orders.
/// 'giftBoxes'   {id, name, tagline, description, items[{productId,qty}], priceAZN, boxFeeAZN,
///                logoFeeAZN}
class MockDb {
  MockDb._();

  static final MockDb instance = MockDb._();

  bool _seeded = false;

  /// Seeds core data + every area (once). Called by `MockServer.init`; kept
  /// out of the constructor so seeders can safely use `MockDb.instance`.
  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    seedCore(this);
    for (final s in areaSeeders) {
      s(this);
    }
  }

  final List<Map<String, dynamic>> users = [];
  final List<Map<String, dynamic>> artisans = [];
  final List<Map<String, dynamic>> products = [];
  final List<Map<String, dynamic>> variants = [];
  final List<Map<String, dynamic>> orders = [];
  final List<Map<String, dynamic>> notifications = [];
  final List<Map<String, dynamic>> wants = [];

  /// Area-owned collections: `db.coll('groups')` creates/returns a list.
  final Map<String, List<Map<String, dynamic>>> extra = {};

  /// Area-owned key/value state (e.g. WhatsApp sessions).
  final Map<String, Object?> state = {};

  final Map<String, int> _seq = {};

  List<Map<String, dynamic>> coll(String name) => extra.putIfAbsent(name, () => []);

  /// Wipes and re-seeds (used by tests / a hidden "reset demo" action).
  void reset() {
    users.clear();
    artisans.clear();
    products.clear();
    variants.clear();
    orders.clear();
    notifications.clear();
    wants.clear();
    extra.clear();
    state.clear();
    _seq.clear();
    _seeded = false;
    ensureSeeded();
  }

  /// Area seeders registered by `MockServer.init` (re-run on [reset]).
  final List<void Function(MockDb)> areaSeeders = [];

  // ── ids ──
  /// `nextId('p')` → `p9`, counting up from [start] the first time.
  String nextId(String prefix, {int start = 1}) {
    final n = (_seq[prefix] ?? start - 1) + 1;
    _seq[prefix] = n;
    return '$prefix$n';
  }

  /// Order-style ids: `nextCode('CH-', 1001)` → `CH-1008`.
  String nextCode(String prefix, int start) {
    final n = (_seq[prefix] ?? start - 1) + 1;
    _seq[prefix] = n;
    return '$prefix$n';
  }

  /// Keeps counters ahead of ids that were seeded by hand.
  void bumpCounter(String prefix, int atLeast) {
    final cur = _seq[prefix] ?? 0;
    if (atLeast > cur) _seq[prefix] = atLeast;
  }

  // ── lookups ──
  Map<String, dynamic>? userById(String? id) => id == null
      ? null
      : users.cast<Map<String, dynamic>?>().firstWhere((u) => u!['id'] == id, orElse: () => null);

  Map<String, dynamic>? userForToken(String? token) {
    if (token == null || !token.startsWith('mock-')) return null;
    return userById(token.substring(5));
  }

  Map<String, dynamic>? userByLogin(String login) {
    final l = login.replaceAll(' ', '').toLowerCase();
    for (final u in users) {
      if ('${u['login']}'.replaceAll(' ', '').toLowerCase() == l) return u;
    }
    return null;
  }

  Map<String, dynamic>? artisanById(String? id) => id == null
      ? null
      : artisans.cast<Map<String, dynamic>?>().firstWhere(
          (a) => a!['id'] == id,
          orElse: () => null,
        );

  Map<String, dynamic>? productById(String? id) => id == null
      ? null
      : products.cast<Map<String, dynamic>?>().firstWhere(
          (p) => p!['id'] == id,
          orElse: () => null,
        );

  Map<String, dynamic>? variantById(String? id) => id == null
      ? null
      : variants.cast<Map<String, dynamic>?>().firstWhere(
          (v) => v!['id'] == id,
          orElse: () => null,
        );

  Map<String, dynamic>? orderById(String? id) {
    if (id == null) return null;
    final up = id.trim().toUpperCase();
    for (final o in orders) {
      if ('${o['id']}'.toUpperCase() == up) return o;
    }
    return null;
  }

  Map<String, dynamic>? expertById(String? id) {
    final u = userById(id);
    return u != null && u['role'] == 'expert' ? u : null;
  }

  List<Map<String, dynamic>> productsOf(String artisanId) =>
      products.where((p) => p['artisanId'] == artisanId).toList();

  List<Map<String, dynamic>> variantsOf(String productId) =>
      variants.where((v) => v['productId'] == productId).toList();

  List<Map<String, dynamic>> ordersOf(String artisanId) =>
      orders.where((o) => o['artisanId'] == artisanId).toList();

  // ── time ──
  String now() => DateTime.now().toUtc().toIso8601String();
  String daysAgo(num d) =>
      DateTime.now().toUtc().subtract(Duration(minutes: (d * 1440).round())).toIso8601String();
  String daysAhead(num d) =>
      DateTime.now().toUtc().add(Duration(minutes: (d * 1440).round())).toIso8601String();

  // ── notifications (Azerbaijani; mirrored to WhatsApp server-side in the real app) ──
  void notify(String artisanId, String textAz, {String type = 'info'}) {
    notifications.insert(0, {
      'id': nextId('n', start: 1000),
      'artisanId': artisanId,
      'textAz': textAz,
      'type': type,
      'read': false,
      'at': now(),
    });
  }
}
