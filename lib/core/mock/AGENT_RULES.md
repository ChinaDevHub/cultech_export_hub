# Rules for building a mock-backend area

The Flutter app (`/Users/cingizzaidov/Developer/Projects/Mobile/Lab/cultech_export_hub`) must work
**offline for a jury demo**. A local mock backend replaces the REST API; the client code is already
written and must NOT change. You implement route handlers + a small seed for your area.

## What you may touch
- Only the route file(s) named in your task (`lib/core/mock/routes/routes_<area>.dart`) and new
  files you create next to it (e.g. `lib/core/mock/routes/<area>/…`).
- **Do not edit** core files: `mock_core.dart, mock_db.dart, mock_orders.dart, mock_pricing.dart,
  mock_views.dart, mock_ai.dart, mock_media.dart, mock_seed.dart, mock_server.dart`, nor anything
  under `lib/features/**`, `lib/core/models`, router, pubspec. If you find a bug or need a core
  helper, put a private helper in your own file; if it's a real core bug, say so in your report.
- No commits, no branches, no `pub add`. **Do not write test files and do not run the Flutter app / browser.**
- Keep your function names exactly: `register<Area>Routes(MockRouter r)` and `seed<Area>(MockDb db)`
  (they're already called from `mock_server.dart`).

## Read first
1. `lib/core/mock/CONTRACT.md` (endpoints + business rules) and `mock_db.dart` (record schemas and
   shared collections), `mock_core.dart` (router API: `r.get/post/put/delete(path, handler, ms:)`,
   `MockRequest` helpers: `req.params / query / body / files / user / requireUser / requireArtisan /
   str() number() integer() flag() list() file() filesOf()`, `MockError.*`, `MockBytes`).
2. `mock_orders.dart` (order flows, `create / placed / setStatus / view / certView / total / paid /
   balance`), `mock_pricing.dart`, `mock_views.dart` (`MockRef`, `MockViews`), `mock_ai.dart`,
   `mock_media.dart` (`MockMedia.store(file)` for uploads; seed art paths `/seed/*.svg`), `mock_seed.dart`.
3. The **client code that consumes your endpoints** — return JSON those parsers read completely.
   Models: `lib/core/models/*.dart`; per feature: `lib/features/<area>/data/*.dart` and
   `lib/features/<area>/**/*models*.dart`, then the screens. Search for the endpoint path
   (`grep -rn "'/path" lib/features lib/core`) to find the caller.

## Quality bar
- Every endpoint of your area in CONTRACT.md works with realistic behaviour: validation → `MockError`,
  state changes persist in `MockDb`, related records stay consistent (orders ↔ notifications ↔
  products ↔ earnings), ids come from `db.nextId/nextCode`.
- Azerbaijani text (notifications, artisan-facing summaries) must be correct Azerbaijani.
- Seeds are SMALL (2–4 records per collection): just enough to show each screen with data. Do not
  mass-produce data.
- Latency: default is fine; AI-like steps may use `ms: 1800–2800`.
- Handlers must never throw non-`MockError` exceptions on bad input; guard casts and nulls.
- Payload keys follow the client parsers (they accept some aliases, but prefer the canonical names
  from CONTRACT.md / the models).

## Verify (briefly)
- `flutter analyze <your files>` → zero issues; `dart format <your files>` (page width 100).
- Optional quick smoke (not a test suite, don't leave files in the repo): write a throwaway script in
  the scratchpad that imports `package:cultech_export_hub/core/mock/mock_server.dart` +
  `mock_core.dart` (they are pure Dart), builds a `Dio` with `MockAdapter(MockServer.router)`, calls
  a few of your endpoints and prints/validates the JSON. Run it from the repo root with
  `dart run --packages=.dart_tool/package_config.json <script>`. Keep it short.

## Report
Files created/changed, anything that deviates from the contract, core issues you noticed, and the
final analyzer output.
