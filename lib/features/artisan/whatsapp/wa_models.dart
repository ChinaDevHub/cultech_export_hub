import 'package:image_picker/image_picker.dart';

import '../../../core/api/json.dart';

enum WaStatus { sending, sent, failed }

/// One chat line in the WhatsApp simulator.
class WaMessage {
  WaMessage({
    required this.id,
    required this.text,
    required this.outgoing,
    required this.at,
    this.files = const [],
    this.imageUrls = const [],
    this.buttons = const [],
    this.system = false,
    this.status = WaStatus.sent,
  });

  final String id;
  final String text;

  /// Sent by the artisan (green, end side). Otherwise the bot (white, start).
  final bool outgoing;
  final DateTime at;

  /// Images the artisan attached (shown from local bytes).
  final List<XFile> files;

  /// Images sent by the bot (backend paths / URLs).
  final List<String> imageUrls;

  /// Quick-reply buttons attached to a bot message.
  final List<String> buttons;

  /// A system notification from the outbox (order, payout…).
  final bool system;
  WaStatus status;

  bool get hasImages => files.isNotEmpty || imageUrls.isNotEmpty;

  static int _seq = 0;

  static String nextId() => 'wa${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  /// Parses a bot reply: a bare string or `{text, image?, images?, buttons?}`.
  static WaMessage? incoming(Object? v, {bool system = false, DateTime? at, String? id}) {
    if (v == null) return null;
    if (v is! Map) {
      final s = '$v'.trim();
      if (s.isEmpty) return null;
      return WaMessage(
        id: id ?? nextId(),
        text: s,
        outgoing: false,
        at: at ?? DateTime.now(),
        system: system,
      );
    }
    final j = asMap(v);
    final text = str(pick(j, ['text', 'body', 'message', 'caption', 'textAz'])) ?? '';
    final images = <String>[
      ?str(pick(j, ['image', 'imageUrl', 'media', 'mediaUrl', 'photo'])),
      ...asList(
        j['images'],
      ).map((e) => e is Map ? str(pick(asMap(e), ['url', 'src'])) : str(e)).whereType<String>(),
    ];
    final buttons = asList(pick(j, ['buttons', 'options', 'quickReplies', 'choices']))
        .map(
          (b) => b is Map ? str(pick(asMap(b), ['title', 'text', 'label', 'name', 'id'])) : str(b),
        )
        .whereType<String>()
        .toList();
    if (text.isEmpty && images.isEmpty) return null;
    return WaMessage(
      id: id ?? str(j['id']) ?? nextId(),
      text: text,
      outgoing: false,
      at: at ?? dateOrNull(pick(j, ['at', 'createdAt', 'time', 'sentAt'])) ?? DateTime.now(),
      imageUrls: images,
      buttons: buttons,
      system: system,
    );
  }

  /// `{replies: [...]}`, a bare list, or a single `{reply}` / `{text}`.
  static List<WaMessage> repliesFrom(Object? data) {
    List<dynamic> raw;
    if (data is List) {
      raw = data;
    } else {
      final j = asMap(data);
      raw = asList(pick(j, ['replies', 'messages', 'responses']));
      if (raw.isEmpty) {
        final single = pick(j, ['reply', 'text', 'message']);
        if (single != null) raw = [single];
      }
    }
    final now = DateTime.now();
    return [
      for (var i = 0; i < raw.length; i++)
        ?incoming(raw[i], at: now.add(Duration(milliseconds: i))),
    ];
  }
}

/// A notification read from `GET /whatsapp/outbox`.
class OutboxItem {
  const OutboxItem({required this.key, required this.message, this.rawAt});

  /// Stable identity used to skip messages already shown.
  final String key;
  final WaMessage message;

  /// The server's own `at` string, reused as the next `after`.
  final String? rawAt;
}

class OutboxPage {
  const OutboxPage({required this.items, this.cursor});

  final List<OutboxItem> items;

  /// Value to send as `after` next time (latest `at`, or a server cursor).
  final String? cursor;

  factory OutboxPage.fromAny(Object? data) {
    final j = data is Map ? asMap(data) : const <String, dynamic>{};
    final list = unwrapList(data, ['messages', 'outbox', 'notifications', 'items']);
    final items = <OutboxItem>[];
    String? latestRaw;
    DateTime? latest;
    for (final m in list) {
      final rawAt = str(pick(m, ['at', 'createdAt', 'time', 'sentAt']));
      final at = dateOrNull(rawAt);
      final msg = WaMessage.incoming(m, system: true, at: at ?? DateTime.now());
      if (rawAt != null && at != null && (latest == null || at.isAfter(latest))) {
        latest = at;
        latestRaw = rawAt;
      }
      if (msg == null) continue;
      final key = str(m['id']) ?? '${rawAt ?? ''}|${msg.text}';
      items.add(OutboxItem(key: key, message: msg, rawAt: rawAt));
    }
    final serverCursor = pick(j, ['cursor', 'now', 'last', 'after']);
    return OutboxPage(
      items: items,
      cursor: str(serverCursor is String ? serverCursor : null) ?? latestRaw,
    );
  }
}
