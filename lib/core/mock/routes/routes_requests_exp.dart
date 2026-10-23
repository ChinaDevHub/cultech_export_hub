import '../mock_core.dart';
import '../mock_db.dart';
import 'requests_exp/academy.dart';
import 'requests_exp/custom_requests.dart';
import 'requests_exp/experiences.dart';

/// Custom-order requests (4.6), experiences / tours (4.13) and the academy
/// (4.14). Owns the shared collections `requests`, `experiences`, `bookings`,
/// `courses` and `applications` (schemas in `mock_db.dart`).
void registerRequestsExpRoutes(MockRouter r) {
  registerCustomRequestRoutes(r);
  registerExperienceRoutes(r);
  registerAcademyRoutes(r);
}

void seedRequestsExp(MockDb db) {
  seedCustomRequests(db);
  seedExperiences(db);
  seedAcademy(db);
}
