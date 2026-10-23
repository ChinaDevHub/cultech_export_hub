import '../../../core/api/json.dart';
import '../../../core/models/shop_config.dart';

/// Reads a number that may arrive bare, as a list (its length) or as a map
/// (`{earned, pending}` → the first known key).
double? _flexNum(Object? v, [List<String> mapKeys = const ['total', 'earned', 'paid', 'value']]) {
  if (v is List) return v.length.toDouble();
  if (v is Map) return numOrNull(pick(asMap(v), mapKeys));
  return numOrNull(v);
}

String? _place(Json j) {
  final region = j['region'];
  final regionName = region is Map ? str(pick(asMap(region), ['az', 'name', 'en'])) : str(region);
  return str(pick(j, ['village', 'city', 'place'])) ?? regionName;
}

/// One of the coordinator's artisans.
class CoordArtisan {
  const CoordArtisan({
    required this.id,
    required this.name,
    this.phone,
    this.village,
    this.craft,
    this.avatar,
    this.color,
    this.sales = 0,
    this.earnings = 0,
  });

  final String id;
  final String name;
  final String? phone;
  final String? village;
  final Label? craft;
  final String? avatar;
  final String? color;
  final int sales;
  final double earnings;

  factory CoordArtisan.fromJson(Json j) => CoordArtisan(
    id: str(pick(j, ['id', 'artisanId'])) ?? '',
    name: str(pick(j, ['name', 'fullName'])) ?? '',
    phone: str(pick(j, ['phone', 'tel', 'whatsapp'])),
    village: _place(j),
    craft: Label.fromAny(pick(j, ['craft', 'craftId'])),
    avatar: str(pick(j, ['avatar', 'photo', 'image'])),
    color: str(j['color']),
    sales:
        _flexNum(
          pick(j, ['salesCount', 'soldCount', 'sales', 'sold', 'ordersCount', 'orders']),
        )?.round() ??
        0,
    earnings:
        _flexNum(
          pick(j, ['earningsAZN', 'earnedAZN', 'earnings', 'earned', 'income', 'revenue']),
        ) ??
        0,
  );
}

/// One item to pick up at a route stop (normally one order).
class CollectItem {
  const CollectItem({
    required this.orderId,
    required this.title,
    this.code,
    this.image,
    this.collected = false,
  });

  final String? orderId;
  final String title;
  final String? code;
  final String? image;
  final bool collected;

  static const _doneStatuses = {
    'collected',
    'picked_up',
    'pickedup',
    'shipped',
    'in_transit',
    'at_hub',
    'delivered',
  };

  factory CollectItem.fromJson(Json j, {String? fallbackOrderId}) {
    final status = str(j['status']);
    final product = asMap(j['product']);
    final order = j['order'];
    return CollectItem(
      orderId:
          str(j['orderId']) ??
          (order is Map ? str(asMap(order)['id']) : str(order)) ??
          fallbackOrderId ??
          str(j['id']),
      title:
          str(pick(j, ['titleAz', 'nameAz', 'title', 'productTitle', 'name'])) ??
          str(pick(product, ['nameAz', 'titleAz', 'title', 'name'])) ??
          'Məhsul',
      code: str(pick(j, ['handoverCode', 'code', 'dropCode', 'pickupCode'])),
      image: str(pick(j, ['image', 'productImage', 'photo'])) ?? str(pick(product, ['image'])),
      collected:
          boolOrNull(pick(j, ['collected', 'pickedUp', 'done'])) == true ||
          j['collectedAt'] != null ||
          (status != null && _doneStatuses.contains(status)),
    );
  }
}

/// A stop on the weekly collection route.
class RouteStop {
  const RouteStop({
    required this.artisanId,
    required this.artisanName,
    this.village,
    this.phone,
    this.avatar,
    this.color,
    this.items = const [],
  });

  final String? artisanId;
  final String artisanName;
  final String? village;
  final String? phone;
  final String? avatar;
  final String? color;
  final List<CollectItem> items;

  factory RouteStop.fromJson(Json j) {
    final a = asMap(j['artisan']);
    final orderIds = asList(pick(j, ['orderIds', 'orders'])).where((e) => e is! Map).map(str);
    final ids = orderIds.whereType<String>().toList();
    var rawItems = asMapList(pick(j, ['items', 'products', 'pickups']));
    if (rawItems.isEmpty) rawItems = asMapList(j['orders']);
    final items = <CollectItem>[
      for (var i = 0; i < rawItems.length; i++)
        CollectItem.fromJson(rawItems[i], fallbackOrderId: i < ids.length ? ids[i] : null),
    ];
    // Only order ids, no item details.
    if (items.isEmpty) {
      for (final id in ids) {
        items.add(CollectItem(orderId: id, title: 'Sifariş $id'));
      }
    }
    return RouteStop(
      artisanId: str(pick(a, ['id'])) ?? str(j['artisanId']),
      artisanName:
          str(pick(a, ['name', 'fullName'])) ?? str(pick(j, ['artisanName', 'name'])) ?? '',
      village: _place(a) ?? _place(j),
      phone: str(pick(a, ['phone', 'tel'])) ?? str(pick(j, ['phone', 'tel'])),
      avatar: str(pick(a, ['avatar', 'photo'])) ?? str(j['avatar']),
      color: str(a['color']) ?? str(j['color']),
      items: items,
    );
  }
}

/// A recent sale / order of one of the coordinator's artisans.
class RecentSale {
  const RecentSale({
    required this.id,
    required this.title,
    this.artisan,
    this.country,
    this.amount,
    this.status,
    this.statusLabel,
    this.image,
  });

  final String id;
  final String title;
  final String? artisan;
  final String? country;
  final double? amount;
  final String? status;
  final String? statusLabel;
  final String? image;

  static const _amountKeys = [
    'artisanAZN',
    'amountAZN',
    'totalAZN',
    'priceAZN',
    'amount',
    'total',
    'price',
  ];

  factory RecentSale.fromJson(Json j) {
    final a = j['artisan'];
    final c = j['country'];
    final amounts = asMap(j['amounts']);
    return RecentSale(
      id: str(pick(j, ['id', 'number', 'code'])) ?? '',
      title: str(pick(j, ['titleAz', 'nameAz', 'title', 'productTitle', 'name'])) ?? 'Məhsul',
      artisan: a is Map ? str(asMap(a)['name']) : (str(j['artisanName']) ?? str(a)),
      country: c is Map
          ? str(pick(asMap(c), ['nameAz', 'name', 'code']))
          : str(pick(j, ['countryNameAz', 'countryName', 'country'])),
      amount: numOrNull(pick(amounts, _amountKeys)) ?? numOrNull(pick(j, _amountKeys)),
      status: str(j['status']),
      statusLabel: str(pick(j, ['statusLabelAz', 'statusAz', 'statusLabel'])),
      image: str(pick(j, ['image', 'productImage', 'photo'])),
    );
  }
}

class CoordinatorDashboard {
  const CoordinatorDashboard({
    required this.artisans,
    required this.route,
    required this.recent,
    required this.summary,
  });

  final List<CoordArtisan> artisans;
  final List<RouteStop> route;
  final List<RecentSale> recent;
  final Json summary;

  int get artisanCount =>
      intOrNull(pick(summary, ['artisans', 'artisanCount', 'artisansCount'])) ?? artisans.length;

  int get salesCount =>
      intOrNull(pick(summary, ['salesCount', 'sales', 'ordersCount', 'orders', 'sold'])) ??
      artisans.fold<int>(0, (s, a) => s + a.sales);

  double get earnings =>
      numOrNull(
        pick(summary, ['earnings', 'earningsAZN', 'earned', 'earnedAZN', 'income', 'revenue']),
      ) ??
      artisans.fold<double>(0, (s, a) => s + a.earnings);

  int get toCollect =>
      intOrNull(pick(summary, ['toCollect', 'itemsToCollect', 'pickups', 'collect'])) ??
      route.fold<int>(0, (s, r) => s + r.items.where((i) => !i.collected).length);

  factory CoordinatorDashboard.fromJson(Json j) {
    final routeRaw = pick(j, ['route', 'weeklyRoute', 'collection', 'pickups', 'stops']);
    return CoordinatorDashboard(
      artisans: unwrapList(j['artisans'], ['artisans']).map(CoordArtisan.fromJson).toList(),
      route: unwrapList(routeRaw, ['stops', 'route']).map(RouteStop.fromJson).toList(),
      recent: unwrapList(pick(j, ['recentOrders', 'recentSales', 'recent', 'sales', 'orders']), [
        'orders',
        'sales',
      ]).map(RecentSale.fromJson).toList(),
      summary: asMap(pick(j, ['summary', 'stats', 'totals'])),
    );
  }
}

/// Result of `POST /coordinator/artisans`.
class NewArtisanResult {
  const NewArtisanResult({required this.name, this.phone, this.password, this.id});

  final String name;
  final String? phone;
  final String? password;
  final String? id;

  factory NewArtisanResult.fromJson(Json j, {required String name, required String phone}) {
    final a = asMap(j['artisan']);
    final user = asMap(j['user']);
    final creds = asMap(pick(j, ['credentials', 'login']));
    const pwKeys = ['password', 'tempPassword', 'generatedPassword', 'initialPassword', 'pin'];
    return NewArtisanResult(
      id: str(pick(a, ['id'])) ?? str(user['artisanId']) ?? str(j['id']),
      name: str(pick(a, ['name'])) ?? str(pick(user, ['name'])) ?? name,
      phone:
          str(pick(creds, ['phone', 'login'])) ??
          str(pick(a, ['phone'])) ??
          str(pick(user, ['phone'])) ??
          str(j['phone']) ??
          phone,
      password: str(pick(j, pwKeys)) ?? str(pick(creds, pwKeys)) ?? str(pick(a, pwKeys)),
    );
  }
}
