import 'mock_core.dart';
import 'mock_db.dart';
import 'routes/routes_admin_ministry.dart';
import 'routes/routes_artisan.dart';
import 'routes/routes_auth.dart';
import 'routes/routes_b2b_gifts.dart';
import 'routes/routes_public.dart';
import 'routes/routes_requests_exp.dart';
import 'routes/routes_whatsapp_coord.dart';

/// The in-app backend. `MockServer.router` answers every `/api/*` call; data
/// lives in [MockDb] (in memory, re-seeded on each app start).
abstract final class MockServer {
  static MockRouter? _router;

  static MockRouter get router => _router ??= _build();

  static MockRouter _build() {
    final db = MockDb.instance;
    db.areaSeeders
      ..clear()
      ..addAll([
        seedPublic,
        seedAuth,
        seedArtisan,
        seedRequestsExp,
        seedB2bGifts,
        seedWhatsappCoord,
        seedAdminMinistry,
      ]);
    db.ensureSeeded();

    final r = MockRouter();
    registerAuthRoutes(r);
    registerPublicRoutes(r);
    registerArtisanRoutes(r);
    registerRequestsExpRoutes(r);
    registerB2bGiftsRoutes(r);
    registerWhatsappCoordRoutes(r);
    registerAdminMinistryRoutes(r);
    return r;
  }
}
