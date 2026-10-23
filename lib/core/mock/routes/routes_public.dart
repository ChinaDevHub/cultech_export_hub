import '../mock_core.dart';
import '../mock_db.dart';
import 'public/public_catalog.dart';
import 'public/public_orders.dart';

/// Public / buyer area: storefront reads (config, stats, products, variants,
/// artisans, certificates, "I want this") and checkout (quote, orders, balance,
/// tracking). See CONTRACT.md "Public / buyer".
void registerPublicRoutes(MockRouter r) {
  registerCatalogRoutes(r);
  registerOrderRoutes(r);
}

/// Nothing extra to seed: the demo catalogue, orders and certificates come from
/// the core seed.
void seedPublic(MockDb db) {}
