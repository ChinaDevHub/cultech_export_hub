import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'features/admin/screens/admin_artisans_screen.dart';
import 'features/admin/screens/admin_b2b_screen.dart';
import 'features/admin/screens/admin_certs_screen.dart';
import 'features/admin/screens/admin_export_screen.dart';
import 'features/admin/screens/admin_login_screen.dart';
import 'features/admin/screens/admin_orders_screen.dart';
import 'features/admin/screens/admin_overview_screen.dart';
import 'features/admin/screens/admin_payouts_screen.dart';
import 'features/admin/screens/admin_products_screen.dart';
import 'features/admin/screens/admin_shell.dart';
import 'features/artisan/screens/artisan_shell.dart';
import 'features/artisan/screens/earnings_screen.dart';
import 'features/artisan/screens/home_screen.dart';
import 'features/artisan/screens/login_screen.dart';
import 'features/artisan/screens/more_screen.dart';
import 'features/artisan/screens/new_product_screen.dart';
import 'features/artisan/screens/notifications_screen.dart';
import 'features/artisan/screens/orders_screen.dart';
import 'features/artisan/screens/product_flow_screen.dart';
import 'features/artisan/screens/profile_screen.dart';
import 'features/artisan/screens/register_screen.dart';
import 'features/artisan/screens/requests_screen.dart';
import 'features/artisan/screens/tours_screen.dart';
import 'features/artisan/screens/training_screen.dart';
import 'features/artisan/screens/video_story_screen.dart';
import 'features/artisan/screens/whatsapp_screen.dart';
import 'features/buyer/screens/academy_screen.dart';
import 'features/buyer/screens/artisan_profile_screen.dart';
import 'features/buyer/screens/artisans_screen.dart';
import 'features/buyer/screens/business_screen.dart';
import 'features/buyer/screens/buyer_shell.dart';
import 'features/buyer/screens/certificate_screen.dart';
import 'features/buyer/screens/checkout_screen.dart';
import 'features/buyer/screens/custom_request_screen.dart';
import 'features/buyer/screens/experiences_screen.dart';
import 'features/buyer/screens/gift_story_screen.dart';
import 'features/buyer/screens/gifts_screen.dart';
import 'features/buyer/screens/home_screen.dart';
import 'features/buyer/screens/product_screen.dart';
import 'features/buyer/screens/track_screen.dart';
import 'features/buyer/screens/variant_screen.dart';
import 'features/coordinator/screens/coordinator_screen.dart';
import 'features/ministry/screens/ministry_login_screen.dart';
import 'features/ministry/screens/ministry_screen.dart';

/// Route paths in one place.
abstract final class Routes {
  // Buyer storefront.
  static const home = '/';
  static const artisans = '/artisans';
  static String artisan(String id) => '/artisans/$id';
  static String product(String id) => '/product/$id';
  static String variant(String id) => '/variant/$id';
  static String checkout(String type, String id) => '/checkout?type=$type&id=$id';
  static const track = '/track';
  static String trackOrder(String id, String email, {bool placed = false}) => Uri(
    path: track,
    queryParameters: {'id': id, 'email': email, if (placed) 'placed': '1'},
  ).toString();
  static String cert(String number) => '/cert/$number';
  static String customRequest(String id, String email) =>
      Uri(path: '/custom/$id', queryParameters: {'email': email}).toString();
  static const gifts = '/gifts';
  static String box(String groupId) => '/box/$groupId';
  static const experiences = '/experiences';
  static const business = '/business';
  static const academy = '/academy';

  // Artisan app (Azerbaijani).
  static const ustaLogin = '/usta/login';
  static const ustaRegister = '/usta/register';
  static const usta = '/usta';
  static const ustaNew = '/usta/new';
  static String ustaProduct(String id) => '/usta/product/$id';
  static String ustaVideo(String productId) => '/usta/product/$productId/video';
  static const ustaOrders = '/usta/orders';
  static const ustaRequests = '/usta/requests';
  static const ustaEarnings = '/usta/earnings';
  static const ustaMore = '/usta/more';
  static const ustaTours = '/usta/tours';
  static const ustaTraining = '/usta/training';
  static const ustaProfile = '/usta/profile';
  static const ustaWhatsApp = '/usta/whatsapp';
  static const ustaNotifications = '/usta/notifications';

  // Coordinator (Azerbaijani).
  static const coordinator = '/koordinator';

  // Admin / expert.
  static const adminLogin = '/admin/login';
  static const admin = '/admin';
  static const adminCerts = '/admin/certs';
  static const adminProducts = '/admin/products';
  static const adminOrders = '/admin/orders';
  static const adminB2b = '/admin/b2b';
  static const adminPayouts = '/admin/payouts';
  static const adminArtisans = '/admin/artisans';
  static const adminExport = '/admin/export';

  // Ministry.
  static const ministryLogin = '/ministry/login';
  static const ministry = '/ministry';
}

/// Which UI language an area uses, independent of the buyer's choice.
enum Area { buyer, artisan, admin }

Area areaOf(String path) {
  if (path.startsWith('/usta') || path.startsWith('/koordinator') || path.startsWith('/academy')) {
    return Area.artisan;
  }
  if (path.startsWith('/admin') || path.startsWith('/ministry')) return Area.admin;
  return Area.buyer;
}

final _rootKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final authChanges = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => authChanges.value++);
  ref.listen(actAsProvider, (_, _) => authChanges.value++);
  ref.onDispose(authChanges.dispose);

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: Routes.home,
    refreshListenable: authChanges,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final canUseArtisan = ref.read(canUseArtisanAppProvider);
      final path = state.uri.path;

      if (path.startsWith('/usta')) {
        final open = path == Routes.ustaLogin || path == Routes.ustaRegister;
        if (open) {
          if (auth.isArtisan) return Routes.usta;
          if (auth.isCoordinator) return canUseArtisan ? Routes.usta : Routes.coordinator;
          return null;
        }
        if (!canUseArtisan) return auth.isCoordinator ? Routes.coordinator : Routes.ustaLogin;
      }
      if (path.startsWith(Routes.coordinator) && !auth.isCoordinator) return Routes.ustaLogin;
      if (path.startsWith('/admin')) {
        final open = path == Routes.adminLogin;
        if (!auth.isStaff && !open) return Routes.adminLogin;
        if (auth.isStaff && open) return Routes.admin;
      }
      if (path.startsWith('/ministry')) {
        final open = path == Routes.ministryLogin;
        if (!auth.isMinistry && !open) return Routes.ministryLogin;
        if (auth.isMinistry && open) return Routes.ministry;
      }
      return null;
    },
    routes: [
      // ── Buyer storefront ──
      ShellRoute(
        builder: (context, state, child) => BuyerShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.home, builder: (_, _) => const BuyerHomeScreen()),
          GoRoute(
            path: Routes.artisans,
            builder: (_, _) => const ArtisansScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (_, s) => ArtisanProfileScreen(id: s.pathParameters['id']!),
              ),
            ],
          ),
          GoRoute(
            path: '/product/:id',
            builder: (_, s) => ProductScreen(id: s.pathParameters['id']!),
          ),
          // Short deep link used in shares / QR codes.
          GoRoute(
            path: '/p/:id',
            builder: (_, s) => ProductScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/variant/:id',
            builder: (_, s) => VariantScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(
            path: '/checkout',
            builder: (_, s) => CheckoutScreen(
              itemType: s.uri.queryParameters['type'] ?? 'product',
              itemId: s.uri.queryParameters['id'] ?? '',
            ),
          ),
          GoRoute(
            path: Routes.track,
            builder: (_, s) => TrackScreen(
              initialId: s.uri.queryParameters['id'],
              initialEmail: s.uri.queryParameters['email'],
              justPlaced: s.uri.queryParameters['placed'] == '1',
            ),
          ),
          GoRoute(
            path: '/cert/:number',
            builder: (_, s) => CertificateScreen(number: s.pathParameters['number']!),
          ),
          GoRoute(
            path: '/custom/:id',
            builder: (_, s) => CustomRequestScreen(
              id: s.pathParameters['id']!,
              email: s.uri.queryParameters['email'] ?? '',
            ),
          ),
          GoRoute(path: Routes.gifts, builder: (_, _) => const GiftsScreen()),
          GoRoute(
            path: '/box/:id',
            builder: (_, s) => GiftStoryScreen(id: s.pathParameters['id']!),
          ),
          GoRoute(path: Routes.experiences, builder: (_, _) => const ExperiencesScreen()),
          GoRoute(path: Routes.business, builder: (_, _) => const BusinessScreen()),
          GoRoute(path: Routes.academy, builder: (_, _) => const AcademyScreen()),
        ],
      ),

      // ── Artisan app ──
      GoRoute(path: Routes.ustaLogin, builder: (_, _) => const ArtisanLoginScreen()),
      GoRoute(path: Routes.ustaRegister, builder: (_, _) => const ArtisanRegisterScreen()),
      ShellRoute(
        builder: (context, state, child) => ArtisanShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.usta, builder: (_, _) => const ArtisanHomeScreen()),
          GoRoute(path: Routes.ustaOrders, builder: (_, _) => const ArtisanOrdersScreen()),
          GoRoute(path: Routes.ustaRequests, builder: (_, _) => const ArtisanRequestsScreen()),
          GoRoute(path: Routes.ustaEarnings, builder: (_, _) => const EarningsScreen()),
          GoRoute(path: Routes.ustaMore, builder: (_, _) => const ArtisanMoreScreen()),
          GoRoute(path: Routes.ustaTours, builder: (_, _) => const ToursScreen()),
          GoRoute(path: Routes.ustaTraining, builder: (_, _) => const TrainingScreen()),
          GoRoute(path: Routes.ustaProfile, builder: (_, _) => const ArtisanProfileEditScreen()),
        ],
      ),
      GoRoute(path: Routes.ustaNew, builder: (_, _) => const NewProductScreen()),
      GoRoute(
        path: '/usta/product/:id',
        builder: (_, s) => ProductFlowScreen(id: s.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'video',
            builder: (_, s) => VideoStoryScreen(productId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: Routes.ustaWhatsApp, builder: (_, _) => const WhatsAppScreen()),
      GoRoute(path: Routes.ustaNotifications, builder: (_, _) => const NotificationsScreen()),

      // ── Coordinator ──
      GoRoute(path: Routes.coordinator, builder: (_, _) => const CoordinatorScreen()),

      // ── Admin / expert ──
      GoRoute(path: Routes.adminLogin, builder: (_, _) => const AdminLoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AdminShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(path: Routes.admin, builder: (_, _) => const AdminOverviewScreen()),
          GoRoute(path: Routes.adminCerts, builder: (_, _) => const AdminCertsScreen()),
          GoRoute(path: Routes.adminProducts, builder: (_, _) => const AdminProductsScreen()),
          GoRoute(path: Routes.adminOrders, builder: (_, _) => const AdminOrdersScreen()),
          GoRoute(path: Routes.adminB2b, builder: (_, _) => const AdminB2bScreen()),
          GoRoute(path: Routes.adminPayouts, builder: (_, _) => const AdminPayoutsScreen()),
          GoRoute(path: Routes.adminArtisans, builder: (_, _) => const AdminArtisansScreen()),
          GoRoute(path: Routes.adminExport, builder: (_, _) => const AdminExportScreen()),
        ],
      ),

      // ── Ministry ──
      GoRoute(path: Routes.ministryLogin, builder: (_, _) => const MinistryLoginScreen()),
      GoRoute(path: Routes.ministry, builder: (_, _) => const MinistryScreen()),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
