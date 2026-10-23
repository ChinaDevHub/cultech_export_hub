import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/models/shop_config.dart';
import '../../../core/providers.dart';
import '../../../core/widgets/badges.dart';
import '../../../core/widgets/common.dart';
import '../data/admin_models.dart';

/// Friendly message for any admin API failure.
String adminError(Object e) =>
    errorText(e, network: "Can't reach the server.", fallback: 'Something went wrong.');

/// Plain count, grouped like [formatAzn] so numbers read the same everywhere.
String formatCount(num v) => NumberFormat.decimalPatternDigits(
  locale: 'az',
  decimalDigits: v == v.roundToDouble() ? 0 : 1,
).format(v);

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// `18 Oct`.
String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// `18 Oct, 14:05`.
String shortDateTime(DateTime d) =>
    '${shortDate(d)}, ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Badge colour for an order status key.
BadgeVariant statusVariant(String status) {
  final s = status.toLowerCase();
  if (s.contains('cancel') || s.contains('refund') || s.contains('reject') || s.contains('fail')) {
    return BadgeVariant.danger;
  }
  if (s.contains('deliver') || s.contains('complete') || s == 'done') return BadgeVariant.ok;
  if (s.contains('new') || s.contains('pending') || s.contains('placed') || s.contains('paid')) {
    return BadgeVariant.pending;
  }
  return BadgeVariant.ready;
}

/// Terminal statuses are never reached via "Next".
bool isOffPathStatus(String key) {
  final s = key.toLowerCase();
  return s.contains('cancel') || s.contains('refund') || s.contains('reject') || s.contains('fail');
}

/// Certificate state as a badge.
AppBadge certBadge(String status) {
  final s = status.toLowerCase();
  if (s == 'verified' || s == 'approved' || s == 'issued') {
    return const AppBadge('Certified', variant: BadgeVariant.ok, icon: Icons.verified_rounded);
  }
  if (s == 'rejected') {
    return const AppBadge('Cert rejected', variant: BadgeVariant.danger, icon: Icons.block_rounded);
  }
  if (s == 'none' || s.isEmpty) return const AppBadge('No certificate');
  return const AppBadge(
    'Cert pending',
    variant: BadgeVariant.pending,
    icon: Icons.schedule_rounded,
  );
}

/// English label of a craft id (falls back to the id itself).
String craftName(ShopConfig config, String id) => config.craft(id)?.en ?? id;

String regionName(ShopConfig config, String id) => config.region(id)?.en ?? id;

String countryName(ShopConfig config, String code) => config.country(code)?.name ?? code;

/// Label of an order status from config, else a humanised key.
String statusLabelFor(ShopConfig config, String key) {
  for (final s in stepsFromLabels(config.statusLabels)) {
    if (s.key == key) return s.label;
  }
  return humanize(key);
}

/// Amount in [currency]; AZN uses the app's [formatAzn] style.
String formatMoney(num v, String currency) {
  if (currency.toUpperCase() == 'AZN') return formatAzn(v);
  return '${NumberFormat.decimalPatternDigits(locale: 'en_US', decimalDigits: 2).format(v)} $currency';
}

/// `12.5 %` / `40 %` — accepts fractions (0..1) or percentages.
String formatPercent(double v) {
  final pct = v <= 1 ? v * 100 : v;
  return '${pct.toStringAsFixed(pct < 10 && pct != pct.roundToDouble() ? 1 : 0)}%';
}
