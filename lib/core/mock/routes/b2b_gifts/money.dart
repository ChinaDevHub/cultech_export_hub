import '../../mock_pricing.dart';

/// Money lines of a group order (gift boxes or B2B). All AZN.
///
/// Reads top to bottom like the buyer's summary:
/// `subtotal − savings + boxFee + logoFee + serviceFee + shipping = total`.
class GroupMoney {
  const GroupMoney({
    required this.subtotal,
    required this.savings,
    this.boxFee = 0,
    this.logoFee = 0,
    required this.serviceFee,
    required this.shipping,
  });

  /// List price of everything, before the volume discount.
  final double subtotal;
  final double savings;

  /// Packaging for all boxes (gift boxes only).
  final double boxFee;

  /// One-time logo printing (gift boxes only).
  final double logoFee;
  final double serviceFee;

  /// ONE consolidated shipment for the whole group.
  final double shipping;

  /// What the artisans share (list price minus the volume discount).
  double get itemsNet => MockPricing.round2(subtotal - savings);

  double get total => MockPricing.round2(itemsNet + boxFee + logoFee + serviceFee + shipping);

  /// Fraction 0..1 (e.g. 0.15) actually saved.
  double get discount => subtotal <= 0 ? 0 : (savings / subtotal);

  /// The `groups[].amounts` record.
  Map<String, dynamic> toAmounts() => {
    'subtotalAZN': subtotal,
    'savingsAZN': savings,
    'boxFeeAZN': boxFee,
    'logoFeeAZN': logoFee,
    'serviceFeeAZN': serviceFee,
    'shippingAZN': shipping,
    'totalAZN': total,
  };

  /// Gift boxes: [boxes] boxes of [boxPrice] each (sum of the pieces).
  factory GroupMoney.gift({
    required double boxPrice,
    required double boxFeePerBox,
    required double logoFee,
    required int boxes,
    required bool logo,
    required String? country,
  }) {
    final subtotal = MockPricing.round2(boxPrice * boxes);
    final savings = MockPricing.round2(subtotal * MockPricing.tierOff(boxes));
    final net = MockPricing.round2(subtotal - savings);
    return GroupMoney(
      subtotal: subtotal,
      savings: savings,
      boxFee: MockPricing.round2(boxFeePerBox * boxes),
      logoFee: logo ? MockPricing.round2(logoFee) : 0,
      serviceFee: MockPricing.round2(net * MockPricing.feeRate),
      shipping: shippingFor(country, boxes),
    );
  }

  /// A negotiated total [offer] (shipping + 15 % fee included): the artisans'
  /// share is whatever is left, shown as savings against the list price.
  factory GroupMoney.fromOffer({
    required double offer,
    required double listTotal,
    required String? country,
    required int pieces,
  }) {
    var ship = shippingFor(country, pieces);
    if (offer - ship < offer * 0.3) ship = MockPricing.round2(offer * 0.1);
    final net = MockPricing.round2(((offer - ship) / (1 + MockPricing.feeRate)).clamp(0, offer));
    final service = MockPricing.round2(offer - ship - net);
    final subtotal = listTotal > net ? listTotal : net;
    return GroupMoney(
      subtotal: subtotal,
      savings: MockPricing.round2(subtotal - net),
      serviceFee: service < 0 ? 0 : service,
      shipping: ship,
    );
  }
}

/// Shipping from the Baku hub for [pieces] pieces in one consolidated
/// shipment: the base rate of the destination plus a mild weight surcharge.
double shippingFor(String? country, int pieces) {
  final base = MockPricing.shippingAZN(country);
  final extra = (pieces - 1).clamp(0, 40) * 0.025;
  return MockPricing.round2(base * (1 + extra));
}

/// Splits [total] over [weights] in whole cents; the last share takes the
/// rounding remainder so the parts always add up to [total].
List<double> allocate(double total, List<double> weights) {
  if (weights.isEmpty) return const [];
  final cents = (total * 100).round();
  final sum = weights.fold<double>(0, (a, b) => a + b);
  final out = <double>[];
  var used = 0;
  for (var i = 0; i < weights.length; i++) {
    final int share;
    if (i == weights.length - 1) {
      share = cents - used;
    } else if (sum <= 0) {
      share = cents ~/ weights.length;
    } else {
      share = (cents * weights[i] / sum).round();
    }
    used += share;
    out.add(share / 100);
  }
  return out;
}
