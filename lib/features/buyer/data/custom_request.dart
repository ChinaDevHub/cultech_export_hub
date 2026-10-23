import '../../../core/api/json.dart';

class CustomMessage {
  const CustomMessage({
    required this.text,
    required this.fromBuyer,
    this.original,
    this.translated = true,
    this.at,
  });

  final String text;
  final bool fromBuyer;

  /// Text in the author's language when [text] is a translation.
  final String? original;
  final bool translated;
  final DateTime? at;

  factory CustomMessage.fromJson(Json j) {
    final from = (str(pick(j, ['from', 'author', 'role', 'sender'])) ?? '').toLowerCase();
    return CustomMessage(
      text: str(pick(j, ['textEn', 'text', 'message'])) ?? '',
      fromBuyer: from.contains('buyer') || from.contains('customer') || from == 'me',
      original: str(pick(j, ['original', 'textAz', 'source'])),
      translated: boolOrNull(j['translated']) ?? true,
      at: dateOrNull(pick(j, ['at', 'createdAt', 'date'])),
    );
  }
}

/// An artisan's answer to a custom request.
class CustomOffer {
  const CustomOffer({required this.priceAZN, this.leadDays, this.note});

  final double priceAZN;
  final int? leadDays;
  final String? note;

  static CustomOffer? fromAny(Object? v) {
    final j = asMap(v);
    final price = numOrNull(pick(j, ['priceAZN', 'price']));
    if (price == null) return null;
    return CustomOffer(
      priceAZN: price,
      leadDays: intOrNull(pick(j, ['leadDays', 'days'])),
      note: str(pick(j, ['noteEn', 'note'])),
    );
  }
}

/// Buyer's custom version request (4.6).
class CustomRequest {
  const CustomRequest({
    required this.id,
    required this.status,
    required this.productId,
    required this.productTitle,
    required this.productImage,
    required this.specs,
    required this.sample,
    required this.messages,
    required this.offer,
    required this.orderId,
    required this.quantity,
    required this.country,
    required this.raw,
  });

  final String id;

  /// `open` | `offered` | `declined` | `ordered` (tolerant).
  final String status;
  final String? productId;
  final String? productTitle;
  final String? productImage;

  /// Label → value pairs (size, colour, pattern, notes…).
  final List<(String, String)> specs;
  final String? sample;
  final List<CustomMessage> messages;
  final CustomOffer? offer;
  final String? orderId;
  final int quantity;
  final String? country;
  final Json raw;

  bool get isDeclined => status.contains('declin') || status.contains('reject');
  bool get isOrdered => status.contains('order') || status.contains('accept') || orderId != null;
  bool get hasOffer => offer != null && !isOrdered && !isDeclined;

  factory CustomRequest.fromJson(Json j) {
    final product = asMap(j['product']);
    final images = asStringList(product['images']);
    final color = j['color'];
    String? colorText;
    if (color is Map) {
      colorText = str(pick(asMap(color), ['en', 'name', 'id']));
    } else {
      colorText = str(pick(j, ['colorName', 'color', 'colorId']));
    }
    final specs = <(String, String)>[
      if (str(j['size']) != null) ('size', str(j['size'])!),
      ?(colorText == null ? null : ('color', colorText)),
      if (str(j['pattern']) != null) ('pattern', str(j['pattern'])!),
      if (str(pick(j, ['notesEn', 'notes'])) != null)
        ('notes', str(pick(j, ['notesEn', 'notes']))!),
    ];
    final offer = CustomOffer.fromAny(j['offer']) ?? CustomOffer.fromAny(j['quote']);
    final order = j['order'];
    return CustomRequest(
      id: str(j['id']) ?? '',
      status: (str(j['status']) ?? (offer != null ? 'offered' : 'open')).toLowerCase(),
      productId: str(product['id']) ?? str(j['productId']),
      productTitle: str(pick(product, ['title', 'name'])) ?? str(j['productTitle']),
      productImage: str(product['image']) ?? images.firstOrNull ?? str(j['image']),
      specs: specs,
      sample: str(pick(j, ['sample', 'sampleImage', 'sampleUrl'])),
      messages: asMapList(
        pick(j, ['messages', 'thread', 'chat']),
      ).map(CustomMessage.fromJson).toList(),
      offer: offer,
      orderId: order is Map ? str(asMap(order)['id']) : str(pick(j, ['orderId', 'order'])),
      quantity: intOr(pick(j, ['quantity', 'qty']), 1),
      country: str(j['country']),
      raw: j,
    );
  }
}
