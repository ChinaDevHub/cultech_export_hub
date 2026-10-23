/// Pricing rules of the mock backend (all amounts in AZN).
///
/// * The artisan always receives exactly their own price.
/// * The buyer pays price + 15 % service fee + international shipping.
/// * AI only recommends a range; warnings are soft.
abstract final class MockPricing {
  static const feeRate = 0.15;
  static const depositPct = 0.3;

  /// Shipping from the Baku hub per destination (AZN, per order).
  static const _shipping = {
    'DE': 45.0,
    'FR': 48.0,
    'GB': 52.0,
    'US': 72.0,
    'TR': 30.0,
    'RU': 34.0,
    'AE': 40.0,
    'AZ': 8.0,
  };

  static double shippingAZN(String? country) => _shipping[(country ?? '').toUpperCase()] ?? 55.0;

  /// Volume tiers for B2B / gift boxes: `min` pieces → `off` fraction.
  static const tiers = [
    {'min': 5, 'off': 0.10},
    {'min': 10, 'off': 0.15},
    {'min': 25, 'off': 0.20},
  ];

  static double tierOff(int qty) {
    var off = 0.0;
    for (final t in tiers) {
      if (qty >= (t['min'] as int) && (t['off'] as double) > off) off = t['off'] as double;
    }
    return off;
  }

  static double round2(num v) => (v * 100).round() / 100;

  /// Checkout quote for [qty] pieces at [unitAZN] each.
  static Map<String, dynamic> quote({
    required num unitAZN,
    required int qty,
    required String? country,
    double extraAZN = 0,
  }) {
    final artisan = round2(unitAZN * qty + extraAZN);
    final fee = round2(artisan * feeRate);
    final ship = shippingAZN(country);
    return {
      'artisanAZN': artisan,
      'serviceFeeAZN': fee,
      'shippingAZN': ship,
      'totalAZN': round2(artisan + fee + ship),
      'qty': qty,
      'feeRate': feeRate,
    };
  }

  /// What the artisan sees: they receive their price; the buyer pays more.
  static Map<String, dynamic> breakdown(num priceAZN, {String country = 'DE'}) {
    final q = quote(unitAZN: priceAZN, qty: 1, country: country);
    return {
      'artisanAZN': q['artisanAZN'],
      'serviceFeeAZN': q['serviceFeeAZN'],
      'shippingAZN': q['shippingAZN'],
      'totalAZN': q['totalAZN'],
      'buyerPaysAZN': q['totalAZN'],
    };
  }

  // ── AI price recommendation (simulated market data) ──
  static const _base = {
    'carpet': [900.0, 2200.0],
    'kelaghayi': [60.0, 180.0],
    'copper': [120.0, 420.0],
    'ceramics': [60.0, 200.0],
    'wood': [50.0, 170.0],
  };

  /// Recommended range for a craft; longer lead times nudge it up.
  static Map<String, dynamic> range(String? craftId, {int? days}) {
    final b = _base[craftId] ?? const [80.0, 260.0];
    final f = 1 + ((days ?? 5).clamp(1, 120) - 5) * 0.004;
    final min = (b[0] * f / 5).round() * 5;
    final max = (b[1] * f / 5).round() * 5;
    return {
      'min': min,
      'max': max,
      'reasonAz':
          'Oxşar əl işləri xarici bazarda $min–$max AZN aralığında satılır. '
          'Material, ölçü və hazırlanma müddəti nəzərə alınıb.',
    };
  }

  /// Soft warning text (Azerbaijani) or null. Never blocks.
  static String? warning(num? price, Map<String, dynamic>? range) {
    if (price == null || range == null) return null;
    final min = (range['min'] as num).toDouble();
    final max = (range['max'] as num).toDouble();
    if (price < min * 0.7) return 'Bu qiymət oxşar məhsullardan xeyli aşağıdır. Əminsiniz?';
    if (price > max * 1.3) return 'Bu qiymətlə satış daha uzun çəkə bilər.';
    return null;
  }

  /// Pulls a price out of free text: "120 manat", "qiyməti 85", "150 AZN", "₼200".
  static double? extractPrice(String text) {
    final t = text.toLowerCase();
    final patterns = [
      RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:manat|azn|₼|man\b)'),
      RegExp(r'(?:qiym[əe]ti?|qiymət|price|manat)\D{0,12}(\d+(?:[.,]\d+)?)'),
      RegExp(r'(?:azn|₼)\s*(\d+(?:[.,]\d+)?)'),
    ];
    for (final p in patterns) {
      final m = p.firstMatch(t);
      if (m != null) {
        final v = double.tryParse(m.group(1)!.replaceAll(',', '.'));
        if (v != null && v > 0) return v;
      }
    }
    return null;
  }

  /// "5 günə", "3 ay" → days.
  static int? extractDays(String text) {
    final t = text.toLowerCase();
    final d = RegExp(r'(\d+)\s*(?:gün|gun|day)').firstMatch(t);
    if (d != null) return int.tryParse(d.group(1)!);
    final w = RegExp(r'(\d+)\s*(?:həftə|hefte|week)').firstMatch(t);
    if (w != null) return (int.tryParse(w.group(1)!) ?? 1) * 7;
    final m = RegExp(r'(\d+)\s*(?:ay\b|month)').firstMatch(t);
    if (m != null) return (int.tryParse(m.group(1)!) ?? 1) * 30;
    return null;
  }
}
