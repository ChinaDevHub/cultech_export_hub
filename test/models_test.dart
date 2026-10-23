import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:cultech_export_hub/core/api/api_client.dart';
import 'package:cultech_export_hub/core/models/catalog.dart';
import 'package:cultech_export_hub/core/models/order.dart';
import 'package:cultech_export_hub/core/models/shop_config.dart';
import 'package:cultech_export_hub/core/providers.dart';
import 'package:cultech_export_hub/features/artisan/data/artisan_models.dart';

void main() {
  setUpAll(() => initializeDateFormatting());

  group('ShopConfig', () {
    final config = ShopConfig.fromJson({
      'currencies': {
        'USD': {'rate': 0.588, 'symbol': r'$', 'name': 'US dollar'},
        'EUR': {'rate': 0.54, 'symbol': '€', 'name': 'Euro'},
      },
      'countries': [
        {'code': 'DE', 'name': 'Germany', 'currency': 'EUR', 'market': 'EU'},
      ],
      'regions': [
        'Quba',
        {'id': 'sheki', 'en': 'Shaki', 'az': 'Şəki'},
      ],
      'crafts': [
        {'id': 'carpet', 'en': 'Carpet weaving', 'az': 'Xalçaçılıq'},
      ],
      'serviceFeeRate': 0.15,
    });

    test('parses currencies and always has AZN', () {
      expect(config.currency('EUR').rate, 0.54);
      expect(config.currencies.containsKey('AZN'), isTrue);
      expect(config.feePercent, 15);
    });

    test('labels accept strings or maps and resolve by any name', () {
      expect(config.region('Quba')?.az, 'Quba');
      expect(config.region('Shaki')?.az, 'Şəki');
      expect(config.resolveCraft(Label.fromAny('carpet'))?.of('az'), 'Xalçaçılıq');
      expect(config.country('DE')?.currency, 'EUR');
    });
  });

  group('Money', () {
    final config = ShopConfig.fromJson({
      'currencies': {
        'USD': {'rate': 0.5, 'symbol': r'$', 'name': 'US dollar'},
      },
    });

    test('converts AZN to the buyer currency', () {
      final money = Money(config, 'USD', 'en');
      expect(money(100), r'$50');
      expect(money(101), r'$50.50');
      expect(money.azn(120), '120 AZN');
    });
  });

  group('Catalog', () {
    test('variants keep their concept and never carry a cert', () {
      final item = CatalogItem.fromJson({
        'type': 'variant',
        'id': 'v1',
        'productId': 'p1',
        'title': 'Turquoise vase',
        'image': '/seed/vase.svg',
        'priceAZN': 135,
        'cert': 'verified',
        'concept': {'type': 'tint', 'color': '#2f6fb3'},
        'leadDays': 6,
      });
      expect(item.isVariant, isTrue);
      expect(item.cert, isNull);
      expect(item.concept?.type, 'tint');
      expect(item.leadDays, 6);
    });

    test('cert can be a status string or an object', () {
      expect(CertInfo.fromAny('verified').isVerified, isTrue);
      final c = CertInfo.fromAny({
        'status': 'verified',
        'number': 'AZ-CULT-1',
        'expert': {'name': 'Dr. L'},
      });
      expect(c.number, 'AZ-CULT-1');
      expect(c.expert, 'Dr. L');
      expect(CertInfo.fromAny(null).isVerified, isFalse);
    });

    test('product falls back to the artisan place and unwraps images', () {
      final p = Product.fromJson({
        'id': 'p1',
        'title': 'Vase',
        'images': ['/a.jpg'],
        'image': '/b.jpg',
        'artisan': {'id': 'a1', 'name': 'Gülarə Həsənova', 'village': 'Şəki', 'region': 'Shaki'},
        'variants': [
          {
            'id': 'v1',
            'priceAZN': 10,
            'concept': {'type': 'size', 'count': 3},
          },
        ],
      });
      expect(p.images, ['/a.jpg', '/b.jpg']);
      expect(p.place, 'Şəki, Shaki');
      expect(p.variants.single.image, '/a.jpg');
      expect(p.artisan?.initials, 'GH');
    });
  });

  group('Order', () {
    test('uses steps/stepIndex from the API', () {
      final o = Order.fromJson({
        'id': 'CH-1001',
        'status': 'at_hub',
        'steps': [
          {'key': 'new', 'label': 'Order placed'},
          {'key': 'awaiting_handover', 'label': 'Awaiting hand-over'},
          {'key': 'at_hub', 'label': 'At Baku hub'},
        ],
        'history': [
          {'status': 'new', 'label': 'Order placed', 'at': '2026-10-10T10:00:00Z'},
        ],
        'amounts': {'totalAZN': 200},
      });
      expect(o.stepIndex, 2);
      expect(o.steps[1].label, 'Awaiting hand-over');
      expect(o.amount(['totalAZN']), 200);
      expect(o.history.single.at, isNotNull);
    });

    test('quote computes a total when missing', () {
      final q = Quote.fromJson({'artisanAZN': 100, 'serviceFeeAZN': 15, 'shippingAZN': 40});
      expect(q.totalAZN, 155);
    });
  });

  group('Artisan models', () {
    test('price warning codes map to the soft Azerbaijani texts', () {
      expect(PriceWarning.fromAny('low')?.textAz, contains('Əminsiniz'));
      expect(PriceWarning.fromAny('high')?.level, 'high');
      expect(PriceWarning.fromAny(null), isNull);
      expect(PriceWarning.fromAny('Bu qiymət yüksəkdir.')?.textAz, 'Bu qiymət yüksəkdir.');
    });

    test('product stages and price source', () {
      final draft = ArtisanProduct.fromJson({
        'product': {
          'id': 'p1',
          'status': 'draft',
          'priceAZN': 60,
          'priceSource': 'voice',
          'range': {'min': 95, 'max': 185},
          'summaryAz': [
            'Material: gil',
            {'label': 'Yer', 'value': 'Şəki'},
          ],
          'variantConsent': null,
        },
      });
      expect(draft.isDraft, isTrue);
      expect(draft.variantConsent, isNull);
      expect(draft.priceSourceAz, 'Səsinizdən götürüldü');
      expect(draft.summaryAz, ['Material: gil', 'Yer: Şəki']);
      expect(draft.breakdown?.buyerPaysAZN, closeTo(69, 0.01));
    });

    test('only approved variants are listed, sorted by wants', () {
      final p = ArtisanProduct.fromJson({
        'id': 'p1',
        'status': 'published',
        'variants': [
          {'id': 'a', 'status': 'approved', 'wants': 1},
          {'id': 'b', 'status': 'declined', 'wants': 9},
          {'id': 'c', 'status': 'approved', 'wants': 5},
          {'id': 'd', 'status': 'suggested'},
        ],
      });
      expect(p.approvedVariants.map((v) => v.id), ['c', 'a']);
    });

    test('skills: own list vs full catalogue', () {
      final own = ArtisanDashboard.fromJson({
        'skills': [
          {'id': 'wheel', 'az': 'Dulus çarxı'},
        ],
      });
      expect(own.skills.single.active, isTrue);

      final catalogue = ArtisanDashboard.fromJson({
        'skills': ['wheel'],
        'skillOptions': [
          {'id': 'wheel', 'az': 'Dulus çarxı'},
          {'id': 'glaze', 'az': 'Şirələmə'},
        ],
      });
      expect(catalogue.skills.map((s) => (s.id, s.active)), [('wheel', true), ('glaze', false)]);
    });
  });

  group('media', () {
    test('relative paths get the API host, svg is detected', () {
      expect(mediaUrl('/seed/x.svg'), endsWith('/seed/x.svg'));
      expect(mediaUrl('https://cdn/x.jpg'), 'https://cdn/x.jpg');
      expect(isSvgPath('/seed/x.svg?v=2'), isTrue);
      expect(isSvgPath('/uploads/x.jpg'), isFalse);
    });
  });
}
