import '../../../core/api/json.dart';
import '../../../core/models/catalog.dart';
import 'admin_models.dart';

// Operations payloads (customs, B2B, payouts). Same rule as admin_models:
// read several candidate keys, never crash on a missing field.

// ───────────────────────────── Customs invoice ─────────────────────────────

/// A party on the invoice (exporter / consignee).
class InvoiceParty {
  const InvoiceParty({required this.name, required this.lines});

  final String name;

  /// Address, country, phone, email, tax id… already formatted.
  final List<String> lines;

  static InvoiceParty? fromAny(Object? v) {
    if (v is Map) {
      final j = asMap(v);
      final name = str(pick(j, ['name', 'company', 'companyName', 'fullName', 'title']));
      final address = j['address'];
      final lines = <String>[
        if (address is Map)
          asMap(address).values.whereType<Object>().map((e) => '$e').join(', ')
        else
          ?str(address),
        ?str(pick(j, ['street', 'line1'])),
        ?[
          str(pick(j, ['city', 'village'])),
          str(pick(j, ['zip', 'postcode', 'postalCode'])),
        ].whereType<String>().join(' ').nullIfEmpty,
        ?labelText(pick(j, ['country', 'countryName', 'countryCode'])),
        if (str(pick(j, ['taxId', 'tin', 'voen', 'vat', 'eori'])) case final t?) 'Tax ID: $t',
        if (str(pick(j, ['phone', 'tel'])) case final t?) 'Phone: $t',
        ?str(j['email']),
      ].where((l) => l.trim().isNotEmpty).toList();
      if (name == null && lines.isEmpty) return null;
      return InvoiceParty(name: name ?? '—', lines: lines);
    }
    final s = v is String ? str(v) : null;
    return s == null ? null : InvoiceParty(name: s, lines: const []);
  }
}

class InvoiceLine {
  const InvoiceLine({
    required this.description,
    this.hsCode,
    this.origin,
    this.material,
    required this.qty,
    this.unitValue,
    this.value,
    this.weightKg,
  });

  final String description;
  final String? hsCode;
  final String? origin;
  final String? material;
  final int qty;
  final double? unitValue;
  final double? value;
  final double? weightKg;

  factory InvoiceLine.fromJson(Json j) {
    final qty = intOr(pick(j, ['qty', 'quantity', 'units', 'count']), 1);
    final unit = numOrNull(
      pick(j, ['unitValue', 'unitPrice', 'unitPriceAZN', 'priceAZN', 'price']),
    );
    return InvoiceLine(
      description:
          str(pick(j, ['description', 'descriptionEn', 'title', 'name', 'goods', 'item'])) ??
          'Handmade item',
      hsCode: str(pick(j, ['hsCode', 'hs', 'hsCodeNumber', 'tariffCode', 'hts'])),
      origin: labelText(pick(j, ['origin', 'countryOfOrigin', 'originCountry'])),
      material: str(pick(j, ['material', 'materials', 'composition'])),
      qty: qty,
      unitValue: unit,
      value:
          numOrNull(pick(j, ['value', 'totalValue', 'total', 'valueAZN', 'amount', 'lineTotal'])) ??
          (unit == null ? null : unit * qty),
      weightKg: numOrNull(pick(j, ['weightKg', 'weight', 'netWeightKg', 'grossWeightKg'])),
    );
  }
}

/// `GET /admin/orders/:id/customs` — a commercial invoice.
class CustomsInvoice {
  const CustomsInvoice({
    required this.number,
    required this.date,
    required this.exporter,
    required this.consignee,
    required this.lines,
    required this.currency,
    required this.totalValue,
    required this.totalWeightKg,
    required this.origin,
    required this.facts,
    required this.declaration,
  });

  final String? number;
  final DateTime? date;
  final InvoiceParty? exporter;
  final InvoiceParty? consignee;
  final List<InvoiceLine> lines;
  final String currency;
  final double? totalValue;
  final double? totalWeightKg;
  final String origin;

  /// Remaining labelled scalars (incoterm, reason for export, carrier…).
  final List<(String, String)> facts;
  final String? declaration;

  static const _consumed = {
    'invoice', 'customs', 'number', 'invoiceNumber', 'invoiceNo', 'id', 'date', 'issuedAt', //
    'createdAt', 'exporter', 'seller', 'shipper', 'from', 'sender', 'consignee', 'buyer',
    'importer', 'to', 'shipTo', 'recipient', 'items', 'lines', 'goods', 'products', 'currency',
    'totalValue', 'total', 'value', 'totalAZN', 'declaredValue', 'weightKg', 'weight',
    'grossWeightKg', 'totalWeightKg', 'origin', 'countryOfOrigin', 'declaration', 'statement',
    'certification', 'description', 'hsCode', 'qty', 'quantity', 'unitValue', 'unitPrice',
  };

  factory CustomsInvoice.fromJson(Json data) {
    var j = unwrap(data, 'invoice');
    if (j['customs'] is Map) j = asMap(j['customs']);
    var lines = asMapList(
      pick(j, ['items', 'lines', 'goods', 'products']),
    ).map(InvoiceLine.fromJson).toList();
    if (lines.isEmpty && pick(j, ['description', 'hsCode', 'qty', 'quantity']) != null) {
      lines = [InvoiceLine.fromJson(j)];
    }
    final origin =
        labelText(pick(j, ['origin', 'countryOfOrigin'])) ??
        lines.map((l) => l.origin).whereType<String>().firstOrNull ??
        'Azerbaijan';
    final facts = <(String, String)>[
      for (final e in j.entries)
        if (!_consumed.contains(e.key) && (e.value is String || e.value is num || e.value is bool))
          if (str(e.value) case final v?) (humanize(e.key), v),
      for (final e in j.entries)
        if (!_consumed.contains(e.key) && e.value is Map)
          if (labelText(e.value) case final v?) (humanize(e.key), v),
    ];
    return CustomsInvoice(
      number: str(pick(j, ['number', 'invoiceNumber', 'invoiceNo', 'id'])),
      date: dateOrNull(pick(j, ['date', 'issuedAt', 'createdAt'])),
      exporter: InvoiceParty.fromAny(pick(j, ['exporter', 'seller', 'shipper', 'from', 'sender'])),
      consignee: InvoiceParty.fromAny(
        pick(j, ['consignee', 'buyer', 'importer', 'to', 'shipTo', 'recipient']),
      ),
      lines: lines,
      currency: str(j['currency']) ?? 'AZN',
      totalValue:
          numOrNull(pick(j, ['totalValue', 'total', 'declaredValue', 'totalAZN', 'value'])) ??
          (lines.any((l) => l.value != null)
              ? lines.fold<double>(0, (s, l) => s + (l.value ?? 0))
              : null),
      totalWeightKg:
          numOrNull(pick(j, ['totalWeightKg', 'grossWeightKg', 'weightKg', 'weight'])) ??
          (lines.any((l) => l.weightKg != null)
              ? lines.fold<double>(0, (s, l) => s + (l.weightKg ?? 0) * l.qty)
              : null),
      origin: origin,
      facts: facts,
      declaration: str(pick(j, ['declaration', 'statement', 'certification'])),
    );
  }
}

// ───────────────────────────── B2B ─────────────────────────────

class QuoteLine {
  const QuoteLine({required this.title, required this.qty, this.image, this.priceAZN});

  final String title;
  final int qty;
  final String? image;
  final double? priceAZN;

  factory QuoteLine.fromJson(Json j) {
    final product = asMap(j['product']);
    return QuoteLine(
      title:
          str(pick(j, ['title', 'titleEn', 'name', 'productTitle'])) ??
          str(pick(product, ['title', 'name'])) ??
          'Item',
      qty: intOr(pick(j, ['qty', 'quantity', 'units', 'count']), 1),
      image:
          str(pick(j, ['image', 'photo'])) ??
          str(product['image']) ??
          asStringList(product['images']).firstOrNull,
      priceAZN: numOrNull(pick(j, ['priceAZN', 'unitPriceAZN', 'price'])),
    );
  }
}

/// A B2B quote request (`GET /admin/quotes`).
class AdminQuote {
  const AdminQuote({
    required this.id,
    required this.company,
    required this.contactName,
    required this.contactLines,
    required this.lines,
    required this.requestedQty,
    required this.note,
    required this.status,
    required this.offerPriceAZN,
    required this.offerNote,
    required this.createdAt,
    required this.deadline,
  });

  final String id;
  final String company;
  final String? contactName;

  /// Email, phone, country — already formatted.
  final List<String> contactLines;
  final List<QuoteLine> lines;
  final int requestedQty;
  final String? note;
  final String status;
  final double? offerPriceAZN;
  final String? offerNote;
  final DateTime? createdAt;
  final DateTime? deadline;

  /// Closed quotes no longer take offers.
  bool get isClosed {
    final s = status.toLowerCase();
    return s.contains('accept') ||
        s.contains('declin') ||
        s.contains('reject') ||
        s.contains('closed') ||
        s.contains('ordered') ||
        s.contains('cancel');
  }

  factory AdminQuote.fromJson(Json j) {
    final contact = j['contact'] is Map ? asMap(j['contact']) : const <String, dynamic>{};
    final companyRaw = j['company'];
    final company = companyRaw is Map ? asMap(companyRaw) : const <String, dynamic>{};
    final offer = j['offer'] is Map ? asMap(j['offer']) : const <String, dynamic>{};
    var lines = asMapList(pick(j, ['lines', 'items', 'products'])).map(QuoteLine.fromJson).toList();
    if (lines.isEmpty && (j['product'] is Map || j['productTitle'] != null)) {
      lines = [QuoteLine.fromJson(j)];
    }
    final requested = intOrNull(pick(j, ['requestedQty', 'qty', 'quantity', 'totalQty']));
    return AdminQuote(
      id: str(pick(j, ['id', 'number', 'code'])) ?? '',
      company:
          (companyRaw is Map ? str(pick(company, ['name', 'title'])) : str(companyRaw)) ??
          str(pick(j, ['companyName', 'businessName'])) ??
          'Company',
      contactName:
          str(pick(contact, ['name', 'fullName'])) ?? str(pick(j, ['contactName', 'name'])),
      contactLines: [
        ?(str(pick(contact, ['email'])) ?? str(j['email'])),
        ?(str(pick(contact, ['phone', 'tel'])) ?? str(j['phone'])),
        ?(labelText(pick(contact, ['country'])) ??
            labelText(company['country']) ??
            labelText(j['country'])),
      ],
      lines: lines,
      requestedQty: requested ?? lines.fold(0, (s, l) => s + l.qty),
      note: str(pick(j, ['note', 'message', 'comment', 'details', 'requirements'])),
      status: str(j['status']) ?? 'new',
      offerPriceAZN:
          numOrNull(pick(offer, ['priceAZN', 'price', 'totalAZN'])) ??
          numOrNull(pick(j, ['offerPriceAZN', 'offeredPriceAZN'])),
      offerNote: str(pick(offer, ['note', 'message'])) ?? str(j['offerNote']),
      createdAt: dateOrNull(pick(j, ['createdAt', 'date', 'at'])),
      deadline: dateOrNull(pick(j, ['deadline', 'neededBy', 'deliveryDate'])),
    );
  }
}

/// A bulk / gift group order (`GET /admin/groups`).
class AdminGroup {
  const AdminGroup({
    required this.id,
    required this.type,
    required this.company,
    required this.itemsCount,
    required this.totalAZN,
    required this.status,
    required this.progress,
    required this.progressLabel,
  });

  final String id;

  /// `gift` | `b2b` (as sent).
  final String type;
  final String? company;
  final int itemsCount;
  final double? totalAZN;
  final String status;

  /// 0..1, null when unknown.
  final double? progress;
  final String? progressLabel;

  bool get isGift => type.toLowerCase().contains('gift');

  factory AdminGroup.fromJson(Json j) {
    final companyRaw = j['company'];
    final items = j['items'];
    double? progress;
    String? progressLabel;
    final p = numOrNull(pick(j, ['progress', 'progressPct', 'percent']));
    if (p != null) {
      progress = p > 1 ? p / 100 : p;
    } else {
      for (final (done, target) in const [
        ('done', 'target'),
        ('completed', 'total'),
        ('paidCount', 'count'),
        ('joined', 'target'),
        ('delivered', 'itemsCount'),
        ('collectedAZN', 'targetAZN'),
      ]) {
        final d = numOrNull(j[done]);
        final t = numOrNull(j[target]);
        if (d != null && t != null && t > 0) {
          progress = d / t;
          progressLabel = '${d.round()} / ${t.round()}';
          break;
        }
      }
    }
    return AdminGroup(
      id: str(pick(j, ['id', 'number', 'code'])) ?? '',
      type: str(pick(j, ['type', 'kind'])) ?? 'b2b',
      company: companyRaw is Map
          ? str(pick(asMap(companyRaw), ['name', 'title']))
          : (str(companyRaw) ?? str(pick(j, ['companyName', 'organizer', 'ownerName']))),
      itemsCount:
          intOrNull(pick(j, ['itemsCount', 'itemCount', 'qty', 'quantity'])) ??
          (items is List
              ? asMapList(items).fold<int>(0, (s, m) => s + intOr(pick(m, ['qty', 'quantity']), 1))
              : intOr(items)),
      totalAZN: numOrNull(pick(j, ['totalAZN', 'total', 'amountAZN', 'valueAZN'])),
      status: str(j['status']) ?? 'open',
      progress: progress?.clamp(0.0, 1.0).toDouble(),
      progressLabel: progressLabel,
    );
  }
}

// ───────────────────────────── Payouts ─────────────────────────────

/// What an artisan is owed and has been paid (`GET /admin/payouts`).
class PayoutRow {
  const PayoutRow({
    required this.artisanId,
    required this.artisan,
    required this.payableAZN,
    required this.paidOutAZN,
    required this.deliveredOrders,
    required this.lastRef,
    required this.lastAt,
  });

  final String artisanId;
  final Artisan artisan;
  final double payableAZN;
  final double paidOutAZN;
  final int? deliveredOrders;
  final String? lastRef;
  final DateTime? lastAt;

  String get name => artisan.name;

  factory PayoutRow.fromJson(Json j) {
    final a = j['artisan'] is Map ? {...j, ...asMap(j['artisan'])} : j;
    final artisan = Artisan.fromJson(a);
    final last = pick(j, ['lastPayout', 'last', 'latestPayout']);
    final lastMap = last is Map ? asMap(last) : const <String, dynamic>{};
    final history = asMapList(pick(j, ['payouts', 'history']));
    final latest = lastMap.isNotEmpty ? lastMap : (history.isEmpty ? null : history.last);
    return PayoutRow(
      artisanId:
          str(pick(j, ['artisanId'])) ??
          (j['artisan'] is Map ? str(asMap(j['artisan'])['id']) : null) ??
          artisan.id,
      artisan: artisan,
      payableAZN: numOr(pick(j, ['payableAZN', 'payable', 'dueAZN', 'balanceAZN', 'owedAZN'])),
      paidOutAZN: numOr(pick(j, ['paidOutAZN', 'paidAZN', 'paidOut', 'totalPaidAZN'])),
      deliveredOrders: intOrNull(pick(j, ['deliveredOrders', 'deliveredCount', 'orders'])),
      lastRef:
          str(pick(j, ['lastRef', 'lastPayoutRef', 'lastReference'])) ??
          (latest == null ? null : str(pick(latest, ['reference', 'ref', 'poNumber', 'id']))) ??
          (last is String ? last : null),
      lastAt:
          dateOrNull(pick(j, ['lastPayoutAt', 'lastPaidAt'])) ??
          (latest == null ? null : dateOrNull(pick(latest, ['at', 'date', 'createdAt']))),
    );
  }
}
