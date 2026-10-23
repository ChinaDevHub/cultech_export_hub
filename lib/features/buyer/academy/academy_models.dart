import '../../../core/api/json.dart';
import '../../../core/models/shop_config.dart';

int? _count(Object? v) {
  if (v is List) return v.length;
  return intOrNull(v);
}

String? _place(Json j) {
  final region = j['region'];
  final regionName = region is Map ? str(pick(asMap(region), ['az', 'name', 'en'])) : str(region);
  return str(pick(j, ['village', 'city', 'place'])) ?? regionName;
}

/// The master artisan teaching a programme.
class Mentor {
  const Mentor({required this.name, this.avatar, this.color, this.village, this.craft});

  final String name;
  final String? avatar;
  final String? color;
  final String? village;
  final Label? craft;

  factory Mentor.fromJson(Json j) => Mentor(
    name: str(pick(j, ['name', 'fullName'])) ?? 'Usta',
    avatar: str(pick(j, ['avatar', 'photo', 'image'])),
    color: str(j['color']),
    village: _place(j),
    craft: Label.fromAny(pick(j, ['craft', 'craftId'])),
  );
}

/// An academy programme (course) run by a master artisan.
class Programme {
  const Programme({
    required this.id,
    required this.title,
    required this.description,
    required this.mentor,
    required this.free,
    this.price,
    this.weeks,
    this.seats,
    this.applicants = 0,
    this.craft,
    this.village,
  });

  final String id;
  final String title;
  final String description;
  final Mentor mentor;
  final bool free;
  final double? price;
  final int? weeks;
  final int? seats;
  final int applicants;
  final Label? craft;
  final String? village;

  factory Programme.fromJson(Json j) {
    final mentor = Mentor.fromJson(asMap(pick(j, ['mentor', 'artisan', 'master', 'teacher'])));
    final price = numOrNull(pick(j, ['priceAZN', 'price', 'feeAZN', 'fee', 'cost']));
    return Programme(
      id: str(pick(j, ['id', 'courseId', 'slug'])) ?? '',
      title: str(pick(j, ['titleAz', 'title', 'nameAz', 'name'])) ?? 'Proqram',
      description:
          str(pick(j, ['descriptionAz', 'description', 'summaryAz', 'summary', 'about'])) ?? '',
      mentor: mentor,
      free: boolOrNull(pick(j, ['free', 'isFree'])) ?? (price == null || price == 0),
      price: price,
      weeks: intOrNull(pick(j, ['weeks', 'durationWeeks', 'duration'])),
      seats: intOrNull(pick(j, ['seats', 'capacity', 'places', 'spots'])),
      applicants:
          _count(
            pick(j, [
              'applicants',
              'applicantsCount',
              'applicationsCount',
              'applications',
              'applied',
            ]),
          ) ??
          0,
      craft: Label.fromAny(pick(j, ['craft', 'craftId'])) ?? mentor.craft,
      village: str(j['village']) ?? mentor.village,
    );
  }
}
