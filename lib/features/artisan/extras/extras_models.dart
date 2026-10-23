import 'package:intl/intl.dart';

import '../../../core/api/json.dart';

/// Models for the artisan "extras" screens (requests, earnings, tours,
/// training). The backend shapes are only partly known, so every reader is
/// tolerant: several key spellings, nested or flat objects, bare or wrapped
/// lists.

String? _id(Json j) => str(pick(j, ['id', '_id', 'uuid', 'code', 'number']));

String _plain(num v) => v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(2);

/// Label-ish values can be a plain string or `{az, en, name}`.
String? _labelAz(Object? v) {
  if (v == null) return null;
  if (v is Map) {
    final m = asMap(v);
    return str(pick(m, ['az', 'nameAz', 'labelAz', 'titleAz', 'name', 'label', 'en', 'id']));
  }
  if (v is List) {
    final parts = v.map(_labelAz).whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(', ');
  }
  return str(v);
}

/// Joins parts that may be strings or lists into lines.
List<String> _lines(Object? v) {
  if (v == null) return const [];
  if (v is List) {
    return v
        .map((e) {
          if (e is Map) {
            final m = asMap(e);
            final label = str(pick(m, ['labelAz', 'label', 'key', 'title']));
            final value = str(pick(m, ['valueAz', 'value', 'textAz', 'text']));
            if (label != null && value != null) return '$label: $value';
            return value ?? label;
          }
          return str(e);
        })
        .whereType<String>()
        .toList();
  }
  final s = str(v);
  if (s == null) return const [];
  return s.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
}

// ───────────────────────────── Requests ─────────────────────────────

enum RequestStatus { open, quoted, accepted, declined }

RequestStatus _requestStatus(String? s) {
  final v = (s ?? '').toLowerCase();
  if (v.contains('declin') || v.contains('reject') || v.contains('cancel') || v == 'closed') {
    return RequestStatus.declined;
  }
  if (v.contains('accept') ||
      v.contains('paid') ||
      v.contains('order') ||
      v.contains('confirm') ||
      v == 'won' ||
      v == 'done') {
    return RequestStatus.accepted;
  }
  if (v.contains('quot') || v.contains('offer') || v.contains('sent') || v == 'answered') {
    return RequestStatus.quoted;
  }
  return RequestStatus.open;
}

class RequestMessage {
  const RequestMessage({required this.text, required this.mine, this.at, this.translated = false});

  final String text;

  /// True when written by the artisan (or the coordinator for them).
  final bool mine;
  final DateTime? at;

  /// The text shown is a translation of the buyer's original.
  final bool translated;

  static RequestMessage? fromAny(Object? v) {
    if (v is String) return v.trim().isEmpty ? null : RequestMessage(text: v, mine: false);
    final j = asMap(v);
    final from = (str(pick(j, ['from', 'role', 'sender', 'author', 'by', 'side'])) ?? '')
        .toLowerCase();
    final mine =
        from.contains('artisan') ||
        from.contains('usta') ||
        from.contains('seller') ||
        from.contains('coordinator') ||
        boolOrNull(pick(j, ['mine', 'fromArtisan'])) == true;
    final az = str(pick(j, ['textAz', 'az', 'messageAz', 'translatedAz', 'translationAz']));
    final original = str(pick(j, ['text', 'message', 'body', 'original']));
    final text = az ?? original;
    if (text == null) return null;
    return RequestMessage(
      text: text,
      mine: mine,
      at: dateOrNull(pick(j, ['at', 'createdAt', 'time', 'date', 'sentAt'])),
      translated: !mine && az != null && original != null && az != original,
    );
  }
}

class RequestQuote {
  const RequestQuote({this.price, this.leadDays, this.note});

  final double? price;
  final int? leadDays;
  final String? note;

  static RequestQuote? fromAny(Object? v) {
    final j = asMap(v);
    final price = numOrNull(pick(j, ['price', 'priceAZN', 'amount', 'amountAZN', 'artisanAZN']));
    final days = intOrNull(pick(j, ['leadDays', 'days', 'leadTime']));
    if (price == null && days == null) return null;
    return RequestQuote(
      price: price,
      leadDays: days,
      note: str(pick(j, ['noteAz', 'note', 'message', 'comment'])),
    );
  }
}

/// A buyer's custom-order request, as seen by the artisan (Azerbaijani side).
class CustomRequest {
  const CustomRequest({
    required this.id,
    required this.status,
    required this.productName,
    required this.productImage,
    required this.buyerFirstName,
    required this.country,
    required this.summary,
    required this.details,
    required this.notes,
    required this.sampleImage,
    required this.messages,
    required this.quote,
    required this.createdAt,
  });

  final String id;
  final RequestStatus status;
  final String? productName;
  final String? productImage;
  final String? buyerFirstName;
  final String? country;

  /// Ready-made Azerbaijani summary lines (`summaryAz`).
  final List<String> summary;

  /// (label, value) pairs built from size/colour/pattern/quantity.
  final List<(String, String)> details;
  final String? notes;
  final String? sampleImage;
  final List<RequestMessage> messages;
  final RequestQuote? quote;
  final DateTime? createdAt;

  bool get isOpen => status == RequestStatus.open;

  factory CustomRequest.fromJson(Json raw) {
    final j = unwrap(raw, 'request');
    final product = asMap(pick(j, ['product', 'item']));
    final buyer = asMap(pick(j, ['buyer', 'customer', 'client']));
    // Request details may be flat or nested under one of these keys.
    final spec = <String, dynamic>{
      ...j,
      ...asMap(j['details']),
      ...asMap(j['spec']),
      ...asMap(j['specs']),
      ...asMap(j['wants']),
      ...asMap(j['options']),
    };

    final images = asStringList(product['images']);
    final buyerName = str(
      pick(buyer, ['firstName', 'name', 'fullName']) ??
          pick(j, ['buyerFirstName', 'buyerName', 'customerName', 'name']),
    );
    final countryRaw =
        pick(buyer, ['countryNameAz', 'countryName', 'country']) ??
        pick(j, ['countryNameAz', 'countryName', 'buyerCountry', 'country']);

    final details = <(String, String)>[];
    void add(String label, List<String> keys) {
      final v = _labelAz(pick(spec, keys));
      if (v != null) details.add((label, v));
    }

    add('Ölçü', ['sizeAz', 'size', 'dimensions']);
    add('Rəng', ['colorAz', 'colourAz', 'colorNameAz', 'colorName', 'color', 'colour', 'colors']);
    add('Naxış', ['patternAz', 'pattern', 'motif']);
    add('Material', ['materialAz', 'material']);
    add('Say', ['quantity', 'qty', 'count', 'pieces']);
    final budget = numOrNull(pick(spec, ['budgetAZN', 'budget']));
    if (budget != null) {
      details.add(('Büdcə', '${_plain(budget)} AZN'));
    } else {
      add('Büdcə', ['budgetAz', 'budget']);
    }
    final deadline = dateOrNull(pick(spec, ['deadline', 'neededBy', 'dueDate']));
    if (deadline != null) {
      details.add(('Nə vaxta', DateFormat('d MMMM yyyy', 'az').format(deadline)));
    } else {
      add('Nə vaxta', ['deadlineAz', 'deadline', 'neededBy']);
    }

    final quote = RequestQuote.fromAny(
      pick(j, ['quote', 'offer', 'artisanQuote']) ??
          {
            if (j['quotePrice'] != null) 'price': j['quotePrice'],
            if (j['quotedPrice'] != null) 'price': j['quotedPrice'],
            if (j['quoteLeadDays'] != null) 'leadDays': j['quoteLeadDays'],
          },
    );

    var status = _requestStatus(str(pick(j, ['status', 'state'])));
    if (status == RequestStatus.open && quote != null && j['status'] == null) {
      status = RequestStatus.quoted;
    }

    return CustomRequest(
      id: _id(j) ?? '',
      status: status,
      productName: str(
        pick(product, ['nameAz', 'titleAz', 'name', 'title']) ??
            pick(j, ['productNameAz', 'productTitleAz', 'productName', 'productTitle', 'title']),
      ),
      productImage:
          str(product['image']) ??
          images.firstOrNull ??
          str(pick(j, ['productImage', 'productPhoto', 'image'])),
      buyerFirstName: buyerName?.trim().split(RegExp(r'\s+')).first,
      country: _labelAz(countryRaw),
      summary: _lines(pick(j, ['summaryAz', 'requestAz', 'descriptionAz', 'summary'])),
      details: details,
      notes: str(pick(spec, ['notesAz', 'noteAz', 'commentAz', 'notes', 'note', 'comment'])),
      sampleImage: str(
        pick(j, ['sampleImage', 'sample', 'referenceImage', 'reference', 'attachment', 'photo']),
      ),
      messages: asList(
        pick(j, ['messages', 'thread', 'chat', 'conversation']),
      ).map(RequestMessage.fromAny).whereType<RequestMessage>().toList(),
      quote: quote,
      createdAt: dateOrNull(pick(j, ['createdAt', 'at', 'date'])),
    );
  }
}

// ───────────────────────────── Earnings ─────────────────────────────

enum PayoutStage { awaitingDelivery, deposit, awaitingPayout, paid }

class EarningItem {
  const EarningItem({
    required this.orderId,
    required this.title,
    required this.image,
    required this.amount,
    required this.stage,
    required this.payoutRef,
    required this.date,
  });

  final String orderId;
  final String title;
  final String? image;
  final double amount;
  final PayoutStage stage;
  final String? payoutRef;
  final DateTime? date;

  /// [forced] is used when the API groups items by payout stage.
  factory EarningItem.fromJson(Json j, {PayoutStage? forced}) {
    final order = asMap(j['order']);
    final product = asMap(pick(j, ['product', 'item']));
    final payout = asMap(j['payout']);
    final orderStatus = (str(pick(j, ['orderStatus'])) ?? str(order['status']) ?? str(j['status']))
        ?.toLowerCase();
    final payoutStatus = (str(pick(j, ['payoutStatus', 'payoutState'])) ?? str(payout['status']))
        ?.toLowerCase();
    final explicit = (str(pick(j, ['stage', 'bucket', 'kind', 'state'])) ?? '').toLowerCase();
    final ref = str(
      pick(j, ['poRef', 'payoutRef', 'payoutReference', 'poNumber', 'po', 'reference']) ??
          pick(payout, ['ref', 'poRef', 'reference', 'number', 'id']),
    );
    final paidAt = dateOrNull(pick(j, ['paidAt', 'paidOutAt'])) ?? dateOrNull(payout['paidAt']);

    bool any(String? s, List<String> needles) => s != null && needles.any(s.contains);
    // "paid" but not "unpaid", "deposit_paid", "awaiting_paid"…
    bool paidWord(String? s) =>
        any(s, ['paid']) && !any(s, ['unpaid', 'not_paid', 'deposit', 'await', 'pending']);

    PayoutStage stage;
    if (forced != null) {
      stage = forced;
    } else if (paidWord(explicit) ||
        paidWord(payoutStatus) ||
        any(payoutStatus, ['complete', 'done', 'sent', 'transferred']) ||
        paidAt != null ||
        orderStatus == 'paid_out') {
      stage = PayoutStage.paid;
    } else if (any(explicit, ['deposit']) ||
        boolOrNull(pick(j, ['depositPaid', 'deposit'])) == true ||
        any(orderStatus, ['deposit']) ||
        str(j['paymentType'])?.toLowerCase() == 'deposit') {
      stage = PayoutStage.deposit;
    } else if (any(explicit, ['payout', 'payable', 'due', 'pending', 'delivered']) ||
        any(orderStatus, ['delivered', 'completed'])) {
      stage = PayoutStage.awaitingPayout;
    } else if (orderStatus == null &&
        any(payoutStatus, ['pending', 'payable', 'due', 'await', 'ready'])) {
      stage = PayoutStage.awaitingPayout;
    } else {
      stage = PayoutStage.awaitingDelivery;
    }
    // A deposit order that has been delivered is simply awaiting payout.
    if (stage == PayoutStage.deposit && any(orderStatus, ['delivered', 'completed'])) {
      stage = PayoutStage.awaitingPayout;
    }

    final images = asStringList(product['images']);
    return EarningItem(
      orderId:
          str(pick(j, ['orderId', 'orderNumber', 'orderCode'])) ??
          str(pick(order, ['id', 'number', 'code'])) ??
          _id(j) ??
          '',
      title:
          str(
            pick(j, ['titleAz', 'productNameAz', 'nameAz', 'title', 'productTitle', 'name']) ??
                pick(product, ['nameAz', 'titleAz', 'name', 'title']) ??
                pick(order, ['titleAz', 'title']),
          ) ??
          'Sifariş',
      image:
          str(pick(j, ['image', 'productImage', 'photo'])) ??
          str(product['image']) ??
          images.firstOrNull ??
          str(order['image']),
      amount: numOr(
        pick(j, [
              'artisanAZN',
              'amountAZN',
              'amount',
              'youReceive',
              'payoutAZN',
              'earningAZN',
              'priceAZN',
            ]) ??
            pick(payout, ['amountAZN', 'amount']) ??
            pick(asMap(order['amounts']), ['artisanAZN', 'artisan']),
      ),
      stage: stage,
      payoutRef: ref,
      date: dateOrNull(pick(j, ['date', 'createdAt', 'at', 'deliveredAt'])),
    );
  }
}

class EarningsData {
  const EarningsData({
    required this.earned,
    required this.paid,
    required this.awaitingPayout,
    required this.inTransit,
    required this.items,
  });

  final double earned;
  final double paid;
  final double awaitingPayout;
  final double inTransit;
  final List<EarningItem> items;

  factory EarningsData.fromJson(Object? data) {
    final j = asMap(data);
    final items = unwrapList(data, [
      'orders',
      'items',
      'earnings',
      'list',
      'entries',
    ]).map(EarningItem.fromJson).toList();
    if (items.isEmpty) {
      // Some shapes group the list by stage: `{paid: [...], pending: [...]}`.
      const groups = [
        ('paid', PayoutStage.paid),
        ('awaitingPayout', PayoutStage.awaitingPayout),
        ('pending', PayoutStage.awaitingPayout),
        ('deposit', PayoutStage.deposit),
        ('deposits', PayoutStage.deposit),
        ('inTransit', PayoutStage.awaitingDelivery),
        ('upcoming', PayoutStage.awaitingDelivery),
      ];
      for (final (key, stage) in groups) {
        items.addAll(asMapList(j[key]).map((e) => EarningItem.fromJson(e, forced: stage)));
      }
    }
    final s = j['summary'] is Map
        ? asMap(j['summary'])
        : (j['totals'] is Map ? asMap(j['totals']) : j);

    double sum(Iterable<PayoutStage> stages) =>
        items.where((i) => stages.contains(i.stage)).fold<double>(0, (a, i) => a + i.amount);

    final paid =
        numOrNull(pick(s, ['paid', 'paidAZN', 'paidOut', 'paidOutAZN'])) ?? sum([PayoutStage.paid]);
    final awaiting =
        numOrNull(
          pick(s, ['awaitingPayout', 'pendingPayout', 'payable', 'pending', 'pendingAZN', 'due']),
        ) ??
        sum([PayoutStage.awaitingPayout]);
    final transit =
        numOrNull(
          pick(s, ['inTransit', 'inTransitAZN', 'transit', 'upcoming', 'awaitingDelivery']),
        ) ??
        sum([PayoutStage.awaitingDelivery, PayoutStage.deposit]);
    final earned =
        numOrNull(pick(s, ['earned', 'earnedAZN', 'total', 'totalAZN', 'lifetime'])) ??
        paid + awaiting;

    return EarningsData(
      earned: earned,
      paid: paid,
      awaitingPayout: awaiting,
      inTransit: transit,
      items: items,
    );
  }
}

// ───────────────────────────── Tours ─────────────────────────────

class Booking {
  const Booking({
    required this.name,
    required this.people,
    required this.date,
    required this.phone,
    required this.email,
    required this.experienceId,
  });

  final String name;
  final int people;
  final DateTime? date;
  final String? phone;
  final String? email;
  final String? experienceId;

  factory Booking.fromJson(Json j) {
    final guest = asMap(pick(j, ['guest', 'buyer', 'customer']));
    return Booking(
      name:
          str(pick(j, ['name', 'guestName', 'buyerName', 'fullName'])) ??
          str(pick(guest, ['name', 'fullName'])) ??
          'Qonaq',
      people: intOr(pick(j, ['people', 'guests', 'count', 'seats', 'persons', 'qty']), 1),
      date: dateOrNull(pick(j, ['date', 'day', 'slot', 'when'])),
      phone: str(pick(j, ['phone', 'tel', 'mobile'])) ?? str(guest['phone']),
      email: str(j['email']) ?? str(guest['email']),
      experienceId: str(pick(j, ['experienceId', 'experience', 'tourId'])),
    );
  }
}

class Experience {
  const Experience({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.price,
    required this.hours,
    required this.maxPeople,
    required this.dates,
    required this.bookings,
  });

  final String id;

  /// `masterclass` | `visit`.
  final String type;
  final String title;
  final String? description;
  final double? price;
  final double? hours;
  final int? maxPeople;
  final List<DateTime> dates;
  final List<Booking> bookings;

  bool get isMasterclass => type != 'visit';

  int get bookedPeople => bookings.fold<int>(0, (s, b) => s + b.people);

  factory Experience.fromJson(Json raw, {List<Booking> extraBookings = const []}) {
    final j = unwrap(raw, 'experience');
    final type = (str(pick(j, ['type', 'kind', 'format'])) ?? 'masterclass').toLowerCase();
    final dates =
        asList(pick(j, ['dates', 'slots', 'days', 'schedule']))
            .map(
              (d) => d is Map
                  ? dateOrNull(pick(asMap(d), ['date', 'at', 'day', 'start']))
                  : dateOrNull(d),
            )
            .whereType<DateTime>()
            .toList()
          ..sort();
    return Experience(
      id: _id(j) ?? '',
      type: type.contains('visit') || type.contains('workshop_visit') || type.contains('tour')
          ? 'visit'
          : 'masterclass',
      title: str(pick(j, ['titleAz', 'title', 'nameAz', 'name'])) ?? 'Tur',
      description: str(pick(j, ['descriptionAz', 'description', 'textAz'])),
      price: numOrNull(pick(j, ['priceAZN', 'price', 'pricePerPerson', 'priceAzn'])),
      hours: numOrNull(pick(j, ['durationH', 'hours', 'duration', 'durationHours'])),
      maxPeople: intOrNull(pick(j, ['maxPeople', 'capacity', 'maxGuests', 'seats'])),
      dates: dates,
      bookings: [
        ...asMapList(pick(j, ['bookings', 'reservations', 'guests'])).map(Booking.fromJson),
        ...extraBookings,
      ],
    );
  }

  /// `GET /artisan/experiences` → experiences, with bookings either nested or
  /// as a separate top-level list keyed by `experienceId`.
  static List<Experience> listFrom(Object? data) {
    final j = asMap(data);
    final loose = asMapList(pick(j, ['bookings', 'reservations'])).map(Booking.fromJson).toList();
    return unwrapList(data, ['experiences', 'items', 'tours']).map((e) {
      final id = _id(unwrap(e, 'experience'));
      return Experience.fromJson(
        e,
        extraBookings: id == null ? const [] : loose.where((b) => b.experienceId == id).toList(),
      );
    }).toList();
  }
}

// ───────────────────────────── Training ─────────────────────────────

class Lesson {
  const Lesson({
    required this.key,
    required this.title,
    required this.steps,
    this.intro,
    this.image,
  });

  final String key;
  final String title;
  final String? intro;
  final List<String> steps;
  final String? image;

  static Lesson? fromAny(Object? v) {
    final j = asMap(v);
    final title = str(pick(j, ['titleAz', 'title', 'nameAz', 'name']));
    if (title == null) return null;
    final steps = _lines(pick(j, ['stepsAz', 'steps', 'tipsAz', 'tips', 'points']));
    final body = str(pick(j, ['bodyAz', 'textAz', 'contentAz', 'body', 'text', 'content']));
    return Lesson(
      key: (str(pick(j, ['key', 'icon', 'id', 'slug'])) ?? title).toLowerCase(),
      title: title,
      intro: steps.isEmpty ? null : body,
      steps: steps.isEmpty ? _lines(body) : steps,
      image: str(pick(j, ['image', 'photo', 'cover'])),
    );
  }
}

class Applicant {
  const Applicant({
    required this.name,
    required this.age,
    required this.phone,
    required this.message,
    required this.at,
  });

  final String name;
  final int? age;
  final String? phone;
  final String? message;
  final DateTime? at;

  factory Applicant.fromJson(Json j) => Applicant(
    name: str(pick(j, ['name', 'fullName', 'studentName'])) ?? 'Şagird',
    age: intOrNull(j['age']),
    phone: str(pick(j, ['phone', 'tel', 'mobile', 'contact'])),
    message: str(pick(j, ['messageAz', 'message', 'note', 'motivation', 'text'])),
    at: dateOrNull(pick(j, ['createdAt', 'at', 'date'])),
  );
}

class Programme {
  const Programme({
    required this.id,
    required this.title,
    required this.description,
    required this.weeks,
    required this.seats,
    required this.free,
    required this.applicants,
  });

  final String id;
  final String title;
  final String? description;
  final int? weeks;
  final int? seats;
  final bool free;
  final List<Applicant> applicants;

  factory Programme.fromJson(Json raw) {
    final j = unwrap(raw, 'course');
    final price = numOrNull(pick(j, ['priceAZN', 'price', 'fee']));
    return Programme(
      id: _id(j) ?? '',
      title: str(pick(j, ['titleAz', 'title', 'nameAz', 'name'])) ?? 'Proqram',
      description: str(pick(j, ['descriptionAz', 'description'])),
      weeks: intOrNull(pick(j, ['weeks', 'durationWeeks', 'duration'])),
      seats: intOrNull(pick(j, ['seats', 'capacity', 'places', 'maxStudents'])),
      free: boolOrNull(pick(j, ['free', 'isFree'])) ?? (price == null || price == 0),
      applicants: asMapList(
        pick(j, ['applicants', 'applications', 'students', 'enrollments']),
      ).map(Applicant.fromJson).toList(),
    );
  }
}

class TrainingData {
  const TrainingData({required this.lessons, required this.programmes});

  final List<Lesson> lessons;

  /// Null when the training payload did not include programmes at all.
  final List<Programme>? programmes;

  factory TrainingData.fromJson(Object? data) {
    if (data is List) {
      return TrainingData(
        lessons: data.map(Lesson.fromAny).whereType<Lesson>().toList(),
        programmes: null,
      );
    }
    final j = asMap(data);
    final lessons = asList(
      pick(j, ['lessons', 'tips', 'guides', 'modules', 'items']),
    ).map(Lesson.fromAny).whereType<Lesson>().toList();
    final rawProgrammes = pick(j, [
      'courses',
      'programs',
      'programmes',
      'myCourses',
      'apprenticeships',
    ]);
    return TrainingData(
      lessons: lessons,
      programmes: rawProgrammes is List
          ? asMapList(rawProgrammes).map(Programme.fromJson).toList()
          : null,
    );
  }
}
