# Cultural Export Hub — Flutter client

A Flutter client for the Cultural Export Hub platform (AI-powered export platform for Azerbaijani
artisans). It talks to the **existing REST API** (`/api/*`) and re-creates the web app's design and
behaviour for phones, tablets and the web.

| Area | Users | Language | Route |
|---|---|---|---|
| **Buyer storefront** | foreign buyers, tourists, B2B clients | AZ (default), EN, RU, DE, TR, FR, AR (RTL) | `/` |
| **Artisan app** | artisans | Azerbaijani only | `/usta` |
| **Coordinator** | regional coordinators | Azerbaijani | `/koordinator` |
| **Admin / expert** | platform staff, heritage experts | English | `/admin` |
| **Ministry** | state analysts | English | `/ministry` |
| **Academy** | youth, mentors | Azerbaijani | `/academy` |

The artisan app is intentionally minimal: huge buttons, voice input, one action per screen.

## Run it

You need Flutter 3.44+ (Dart 3.12+).

```bash
flutter pub get
flutter run                      # picks a connected device / emulator / simulator
flutter run -d chrome            # web
```

### Offline demo mode (default)

**The app needs no server.** All `/api/*` calls are answered by an in-app mock backend
(`lib/core/mock/`): a router behind Dio's HTTP adapter, an in-memory database seeded with a small
set of artisans, products, variants, orders, certificates, tours, gift boxes and so on, plus a
simulated "AI" (voice text → English product page, price range, variant ideas) and a WhatsApp bot.
Everything behaves like the real thing — orders move through their steps, artisans get
Azerbaijani notifications, certificates are issued by routed experts, payouts happen after
delivery — but data lives in memory and resets when the app restarts. Pictures are drawn in code,
and fonts are bundled, so it works without internet.

The mock is documented in [`lib/core/mock/CONTRACT.md`](lib/core/mock/CONTRACT.md) (the same REST
contract the real backend implements).

### Using the real backend instead

```bash
flutter run --dart-define=USE_MOCK=false                                   # emulator/simulator defaults
flutter run --dart-define=USE_MOCK=false --dart-define=API_BASE=http://192.168.1.20:3000
```

The base URL lives in [`lib/core/config.dart`](lib/core/config.dart):

| Where you run | Base URL |
|---|---|
| Android emulator (default) | `http://10.0.2.2:3000` |
| iOS simulator / macOS / web (default) | `http://localhost:3000` |
| **Real phone** | `--dart-define=API_BASE=http://<your computer's LAN IP>:3000` (same Wi-Fi) |

Notes for a real phone: find your IP with `ipconfig getifaddr en0` (macOS) or `ipconfig` (Windows);
the backend must listen on `0.0.0.0` and your firewall must allow port 3000. Android allows plain
HTTP (`usesCleartextTraffic` is on) and iOS allows it through `NSAppTransportSecurity` — **tighten
both before a production release** and use HTTPS.

Certificate QR codes point at `<WEB_BASE>/#/cert/<number>`; `WEB_BASE` defaults to the API host and
can be set with `--dart-define=WEB_BASE=https://…`.

## Showing it on a real iPhone (jury demo)

The app is fully offline (see "Offline demo mode"): **no server and no internet** are needed once
it is loaded. Apple does not allow installing a native app on an iPhone without a cable or a paid
developer account, so the way to run it **cable-free** on any iPhone (yours or a juror's) is the
**web app (PWA)** — it launches full-screen from the home screen with its own icon, exactly like
an app, and needs no Apple account.

### 1. No cable — web app on your own iPhone (recommended)

**Quickest (same Wi-Fi as your Mac):**
```bash
scripts/serve_web_demo.sh
```
It prints two addresses, e.g. `http://192.168.1.20:8080` and `http://<your-mac>.local:8080`. On the
iPhone open one in **Safari**, then **Share → Add to Home Screen → Add**. Open **Export Hub** from
the home screen. The Mac must stay awake and on the same Wi-Fi while you test (stop with Ctrl+C).

**Permanent public link (best for the jury, works anywhere, works offline after first load):**
```bash
scripts/deploy_web_vercel.sh
```
It builds the web app and publishes it on your own (free) Vercel account — log in with your
personal account, not a company one. Open the printed `https://….vercel.app` link in Safari →
Share → **Add to Home Screen**. Do this once on each phone while it has internet; afterwards the
app also opens in airplane mode.

Tips
- Open the link in **Safari** (Add to Home Screen is not available in in-app browsers).
- After you redeploy, close the home-screen app fully and open it twice to pick up the new version.
- Camera/photo picking work; voice dictation depends on Safari's speech support (the text field is
  always available as the fallback).

### 2. Native iOS app (only if you have a cable or a paid developer account)

A native build needs your **personal** Apple ID in Xcode — never use a company team:
1. Xcode → Settings → Accounts → add your personal Apple ID.
2. Open `ios/Runner.xcworkspace` → Runner → *Signing & Capabilities* → choose your **Personal Team**
   (the project ships with no team set). Bundle id: `com.cingizzaidov.culturalexporthub`.
3. iPhone: Settings → Privacy & Security → **Developer Mode** → On, plug in, **Trust**.
4. `scripts/install_iphone.sh` (release mode; keeps working after unplugging). First launch: Settings
   → General → VPN & Device Management → **Trust**. A free Apple ID signs for **7 days**.

For over-the-air installs without a cable (TestFlight) you need a **paid personal** Apple Developer
Program membership: `flutter build ipa --release`, then upload with the *Transporter* app.

### Android phone

`flutter build apk --release` → `build/app/outputs/flutter-apk/app-release.apk` (copy/AirDrop it to
the phone, open it, allow "install unknown apps"), or the same web-app steps in Chrome ("Install app").

### Troubleshooting

| Message / symptom | Fix |
|---|---|
| iPhone can't open the Mac address | Same Wi-Fi? Try the `….local` address; turn off VPN; keep the Mac awake |
| "Add to Home Screen" missing | Use Safari (not Chrome/in-app browser); on iPad it is under Share → More |
| Old version after redeploy | Close the home-screen app fully and open it twice |
| *Signing requires a development team* (native) | Xcode → Runner → Signing & Capabilities → pick your personal team |
| *Failed to register bundle identifier* (native) | Change the bundle id (unique, never `com.example…`) |
| App closes right after opening (native) | You installed a debug build — reinstall with `--release` |

## Demo accounts

| Role | Login | Password |
|---|---|---|
| Artisan — Gülarə (ceramics) | `+994501110001` | `demo123` |
| Artisan — Əli (carpets) | `+994501110002` | `demo123` |
| Artisan — Rəşid (copper) | `+994501110004` | `demo123` |
| Artisan — Nüsrət (wood) | `+994501110005` | `demo123` |
| Coordinator | `+994501110009` | `demo123` |
| Admin | `admin@cultech.az` | `admin123` |
| Expert | `expert@cultech.az` (also `expert2@`, `expert3@`) | `expert123` |
| Ministry | `ministry@culture.gov.az` | `ministry123` |
| B2B (hotel) | `b2b@hotel-berlin.example` | `b2b123` |

The artisan, admin, ministry and business login screens show one-tap demo chips (always in offline
demo mode; in real-backend mode only in debug builds).

## Platform setup that matters

- **Android** — `INTERNET`, `RECORD_AUDIO`, `CAMERA` permissions and the speech-recognition `<queries>`
  entry are in `AndroidManifest.xml`.
- **iOS / macOS** — microphone, speech recognition, camera and photo-library usage strings are in
  `Info.plist`; macOS also has the network-client / audio-input / camera entitlements.
- **Voice input** uses `speech_to_text` with locale `az_AZ`. If recognition is unavailable or the
  permission is denied, the text field stays editable and a short hint is shown — voice is never
  required.

## Project layout

```
lib/
  core/            theme, api client, models, i18n (7 languages), shared widgets, voice
  features/
    buyer/         storefront: home, product, checkout, track, certificate, room preview,
                   custom requests, gifts, experiences, business (B2B), academy
    artisan/       artisan app: dashboard, new product, product flow, orders, requests,
                   earnings, tours, training, video story, WhatsApp simulator, profile
    coordinator/   coordinator dashboard (+ "work as artisan")
    admin/         admin / expert console
    ministry/      ministry statistics
  router.dart      all routes (go_router) and role guards
```

- **State**: Riverpod. **Routing**: go_router (deep links `/p/:id`, `/cert/:number`, `/box/:id`,
  `/track`, `/custom/:id`). **HTTP**: dio with a Bearer interceptor and an `x-act-as` header added to
  `/artisan/*` calls while a coordinator works for an artisan.
- **Design tokens** live in `lib/core/theme/tokens.dart`; no widget hard-codes a colour.
- **Money**: the API returns AZN integers; the app converts with `config.currencies[code].rate`
  (per 1 AZN) and formats with `intl`.
- **Strings**: `lib/core/i18n/dict_*.dart` — one dictionary per area, 7 languages, English fallback.
  The artisan, coordinator and academy screens are always Azerbaijani; admin and ministry are English.

## Business rules the UI enforces

1. The artisan always sets the final price — AI only recommends a range; warnings never block.
2. Variants are generated only after an explicit "Bəli", then approved one by one with their own
   price and lead days. "Edə bilmərəm" is remembered.
3. AI never confirms authenticity: products show "Expert review pending" until an expert verifies
   (certificate number, QR and a visible verification history).
4. AI visuals are always labelled — dashed violet frame, "AI concept" pill, "Concept · Made to order"
   badge, and the room preview carries a permanent "Preview — not a real photo" chip.
5. Made-to-order pieces: 30 % deposit starts the work, the balance is paid before shipping, and the
   buyer sees the artisan's real photo before it ships.
6. Order steps come from the API (`steps` / `stepIndex`), never hard-coded.
7. Coordinators act only for their own artisans (enforced by the server through `x-act-as`).

## Useful commands

```bash
flutter analyze                  # static analysis
dart format lib                  # formatting (page width 100)
flutter build web --release      # web build
flutter build apk                # Android release build
```
