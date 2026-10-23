import '../mock_core.dart';
import '../mock_db.dart';
import 'b2b_gifts/b2b.dart';
import 'b2b_gifts/gifts.dart';
import 'b2b_gifts/seed.dart';

/// Gift boxes, group orders and B2B (spec 4.4 / 4.5).
///
/// * Gift boxes: `GET /gifts`, `POST /gifts/quote`, `POST /gifts/order`,
///   `GET /groups/:id/story` (the QR inside the box), `GET /groups/track`.
/// * B2B (role `b2b`): `/b2b/catalog`, `/b2b/price`, `/b2b/orders`
///   (+ `/:id/reorder`), `/b2b/quotes` (+ `/:id/accept`).
///
/// Owns the shared collections `giftBoxes`, `groups` and `quotes`; child
/// orders of a group live in `db.orders` with `groupId`.
void registerB2bGiftsRoutes(MockRouter r) {
  registerGiftRoutes(r);
  registerB2bRoutes(r);
}

void seedB2bGifts(MockDb db) => seedGiftsAndB2b(db);
