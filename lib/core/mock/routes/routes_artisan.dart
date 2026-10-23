import '../mock_core.dart';
import '../mock_db.dart';
import 'artisan/artisan_account.dart';
import 'artisan/artisan_orders.dart';
import 'artisan/artisan_products.dart';

/// Artisan app (`/artisan/*`): dashboard, product flow, orders, earnings,
/// notifications, profile and skills. Custom requests, tours and the academy
/// (`/artisan/requests*`, `/experiences*`, `/training`, `/courses`) belong to
/// the requests/experiences area.
void registerArtisanRoutes(MockRouter r) {
  registerArtisanAccountRoutes(r);
  registerArtisanProductRoutes(r);
  registerArtisanOrderRoutes(r);
}

/// Nothing to seed: the core seed already gives every artisan products,
/// orders and notifications.
void seedArtisan(MockDb db) {}
