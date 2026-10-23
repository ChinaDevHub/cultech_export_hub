import '../api/json.dart';
import 'catalog.dart';

class Quote {
  const Quote({
    required this.artisanAZN,
    required this.serviceFeeAZN,
    required this.shippingAZN,
    required this.totalAZN,
    required this.feeRate,
  });

  final double artisanAZN;
  final double serviceFeeAZN;
  final double shippingAZN;
  final double totalAZN;
  final double feeRate;

  factory Quote.fromJson(Json data) {
    final j = unwrap(data, 'quote');
    final artisan = numOr(pick(j, ['artisanAZN', 'priceAZN', 'artisan']));
    final fee = numOr(pick(j, ['serviceFeeAZN', 'feeAZN', 'serviceFee']));
    final ship = numOr(pick(j, ['shippingAZN', 'shipping']));
    return Quote(
      artisanAZN: artisan,
      serviceFeeAZN: fee,
      shippingAZN: ship,
      totalAZN: numOrNull(pick(j, ['totalAZN', 'total'])) ?? artisan + fee + ship,
      feeRate: numOr(pick(j, ['feeRate', 'serviceFeeRate']), 0.15),
    );
  }
}

/// Payment state of an order (deposit orders pay 30 % first).
class OrderPayment {
  const OrderPayment({required this.status, this.paidAZN, this.totalAZN, this.depositPct});

  /// e.g. `paid`, `deposit_paid`, `pending`.
  final String status;
  final double? paidAZN;
  final double? totalAZN;
  final double? depositPct;

  double? get balanceAZN => (paidAZN != null && totalAZN != null)
      ? (totalAZN! - paidAZN!).clamp(0, double.infinity)
      : null;

  bool get hasBalance => (balanceAZN ?? 0) > 0.5;

  static OrderPayment? fromAny(Object? v) {
    final j = asMap(v);
    if (j.isEmpty) return null;
    final d = numOrNull(j['depositPct']);
    return OrderPayment(
      status: str(j['status']) ?? '',
      paidAZN: numOrNull(pick(j, ['paidAZN', 'paid'])),
      totalAZN: numOrNull(pick(j, ['totalAZN', 'total'])),
      depositPct: d == null ? null : (d > 1 ? d / 100 : d),
    );
  }
}

/// Carrier tracking once the order has shipped.
class Shipment {
  const Shipment({this.carrier, this.number, this.url});

  final String? carrier;
  final String? number;
  final String? url;

  static Shipment? fromAny(Object? v) {
    final j = asMap(v);
    if (j.isEmpty) return null;
    final carrier = j['carrier'];
    final s = Shipment(
      carrier: carrier is Map ? str(pick(asMap(carrier), ['name', 'id'])) : str(carrier),
      number: str(pick(j, ['number', 'trackingNumber', 'code'])),
      url: str(pick(j, ['url', 'trackingUrl', 'link'])),
    );
    return s.number == null && s.url == null ? null : s;
  }
}

class OrderStep {
  const OrderStep(this.key, this.label);
  final String key;
  final String label;
}

class OrderEvent {
  const OrderEvent({required this.status, required this.label, this.at});
  final String status;
  final String label;
  final DateTime? at;
}

/// Order as returned by `/orders/track` (buyer) and `/artisan/orders`.
class Order {
  const Order({
    required this.id,
    required this.title,
    required this.image,
    required this.status,
    required this.statusLabel,
    required this.steps,
    required this.stepIndex,
    required this.history,
    required this.amounts,
    required this.realPhoto,
    required this.cert,
    required this.leadDays,
    required this.estimatedDelivery,
    required this.address,
    required this.concept,
    required this.itemType,
    required this.qty,
    required this.raw,
    this.payment,
    this.tracking,
  });

  final OrderPayment? payment;
  final Shipment? tracking;
  final String id;
  final String title;
  final String? image;
  final String status;
  final String? statusLabel;
  final List<OrderStep> steps;
  final int stepIndex;
  final List<OrderEvent> history;
  final Json amounts;
  final String? realPhoto;
  final CertInfo? cert;
  final int? leadDays;
  final DateTime? estimatedDelivery;
  final String? address;
  final Concept? concept;
  final String itemType;
  final int qty;
  final Json raw;

  bool get isVariant => itemType == 'variant' || concept != null;
  bool get isDelivered => status == 'delivered';

  double? amount(List<String> keys) => numOrNull(pick(amounts, keys));

  factory Order.fromJson(Json j) {
    final steps = asList(j['steps']).map((s) {
      if (s is Map) {
        final m = asMap(s);
        final key = str(pick(m, ['key', 'status', 'id'])) ?? '';
        return OrderStep(key, str(pick(m, ['label', 'labelAz', 'title'])) ?? key);
      }
      return OrderStep('$s', '$s');
    }).toList();
    final address = j['address'];
    return Order(
      id: str(pick(j, ['id', 'number', 'code'])) ?? '',
      title: str(pick(j, ['title', 'productTitle', 'name'])) ?? '',
      image: str(pick(j, ['image', 'productImage', 'photo'])),
      status: str(j['status']) ?? 'new',
      statusLabel: str(pick(j, ['statusLabel', 'statusLabelAz'])),
      steps: steps,
      stepIndex: intOrNull(j['stepIndex']) ?? steps.indexWhere((s) => s.key == str(j['status'])),
      history: asMapList(j['history'])
          .map(
            (h) => OrderEvent(
              status: str(h['status']) ?? '',
              label: str(pick(h, ['label', 'labelAz'])) ?? str(h['status']) ?? '',
              at: dateOrNull(pick(h, ['at', 'date', 'createdAt'])),
            ),
          )
          .toList(),
      amounts: j['amounts'] is Map ? asMap(j['amounts']) : j,
      realPhoto: str(j['realPhoto']),
      cert: j['cert'] == null ? null : CertInfo.fromAny(j['cert']),
      leadDays: intOrNull(j['leadDays']),
      estimatedDelivery: dateOrNull(j['estimatedDelivery']),
      address: address is Map
          ? asMap(address).values.whereType<Object>().map((e) => '$e').join(', ')
          : str(address),
      concept: Concept.fromAny(j['concept']),
      itemType: str(j['itemType']) ?? (j['concept'] != null ? 'variant' : 'product'),
      qty: intOr(j['qty'], 1),
      raw: j,
      payment: OrderPayment.fromAny(j['payment']),
      tracking: Shipment.fromAny(j['tracking']),
    );
  }
}

class Certificate {
  const Certificate({
    required this.number,
    required this.status,
    required this.category,
    required this.verifiedAt,
    required this.expert,
    required this.productTitle,
    required this.productImage,
    required this.productId,
    required this.artisan,
    required this.place,
    required this.craft,
    this.history = const [],
  });

  final List<CertEvent> history;
  final String number;
  final String status;
  final String? category;
  final DateTime? verifiedAt;
  final String? expert;
  final String? productTitle;
  final String? productImage;
  final String? productId;
  final Artisan? artisan;
  final String? place;
  final Object? craft;

  factory Certificate.fromJson(Json data, String number) {
    final j = asMap(data);
    final c = j['certificate'] is Map
        ? asMap(j['certificate'])
        : (j['cert'] is Map ? asMap(j['cert']) : j);
    final product = asMap(j['product']);
    final cert = CertInfo.fromAny(c);
    final artisan = Artisan.fromAny(pick(j, ['artisan'])) ?? Artisan.fromAny(product['artisan']);
    final place = pick(c, ['place']) ?? pick(product, ['place']);
    final images = asStringList(product['images']);
    return Certificate(
      number: cert.number ?? number,
      status: str(c['status']) ?? 'verified',
      category: cert.category,
      verifiedAt: cert.verifiedAt,
      expert: cert.expert,
      productTitle: str(pick(product, ['title', 'name'])) ?? str(c['title']),
      productImage: str(product['image']) ?? images.firstOrNull ?? str(c['image']),
      productId: str(product['id']) ?? str(c['productId']),
      artisan: artisan,
      place: place is Map
          ? [
              str(asMap(place)['village']),
              str(asMap(place)['region']),
            ].whereType<String>().join(', ')
          : str(place) ?? artisan?.place,
      craft: pick(product, ['craft']) ?? c['craft'] ?? artisan?.craft?.id,
      history: cert.history.isNotEmpty
          ? cert.history
          : asMapList(j['history']).map(CertEvent.fromJson).toList(),
    );
  }
}
