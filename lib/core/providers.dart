import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'api/json.dart';
import 'models/shop_config.dart';

/// Overridden in `main()` with the loaded instance.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider not overridden'),
);

// ───────────────────────────── Auth ─────────────────────────────

class AuthState {
  const AuthState({this.token, this.user});

  final String? token;
  final Json? user;

  String? get role => str(user?['role']);
  String get name => str(user?['name']) ?? '';
  String? get company => str(user?['company']);
  String? get artisanId => str(user?['artisanId']) ?? (role == 'artisan' ? str(user?['id']) : null);

  bool get isLoggedIn => token != null && token!.isNotEmpty;
  bool get isArtisan => isLoggedIn && role == 'artisan';
  bool get isCoordinator => isLoggedIn && role == 'coordinator';
  bool get isB2b => isLoggedIn && role == 'b2b';
  bool get isMinistry => isLoggedIn && role == 'ministry';
  bool get isStaff => isLoggedIn && (role == 'admin' || role == 'expert');
  bool get isAdmin => isLoggedIn && role == 'admin';
  bool get isExpert => isLoggedIn && role == 'expert';
}

class AuthNotifier extends Notifier<AuthState> {
  static const _tokenKey = 'auth.token';
  static const _userKey = 'auth.user';

  SharedPreferences get _prefs => ref.read(sharedPrefsProvider);

  @override
  AuthState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final token = prefs.getString(_tokenKey);
    Json? user;
    final rawUser = prefs.getString(_userKey);
    if (rawUser != null) {
      try {
        user = asMap(jsonDecode(rawUser));
      } catch (_) {}
    }
    return AuthState(token: token, user: user);
  }

  Future<AuthState> login(String login, String password) async {
    final api = ref.read(apiProvider);
    final res = asMap(await api.post('/auth/login', {'login': login.trim(), 'password': password}));
    return _store(res);
  }

  /// Registers an artisan (multipart). Logs in afterwards if the server does
  /// not return a token directly.
  Future<AuthState> registerArtisan(
    FormData form, {
    required String phone,
    required String password,
  }) async {
    final api = ref.read(apiProvider);
    final res = asMap(await api.post('/auth/register-artisan', form));
    if (str(res['token']) != null) return _store(res);
    return login(phone, password);
  }

  Future<void> refreshMe() async {
    if (!state.isLoggedIn) return;
    try {
      final res = asMap(await ref.read(apiProvider).get('/auth/me'));
      final user = res['user'] is Map ? asMap(res['user']) : res;
      if (user.isNotEmpty) {
        await _prefs.setString(_userKey, jsonEncode(user));
        state = AuthState(token: state.token, user: user);
      }
    } catch (_) {}
  }

  Future<AuthState> _store(Json res) async {
    final token = str(res['token']);
    if (token == null) throw ApiException('Token missing in response');
    final user = asMap(res['user']);
    await _prefs.setString(_tokenKey, token);
    await _prefs.setString(_userKey, jsonEncode(user));
    state = AuthState(token: token, user: user);
    return state;
  }

  /// Business (B2B) self-registration; logs in with the returned token.
  Future<AuthState> registerB2b(Map<String, Object?> data) async {
    final res = asMap(await ref.read(apiProvider).post('/auth/register-b2b', data));
    if (str(res['token']) != null) return _store(res);
    return login('${data['email']}', '${data['password']}');
  }

  void logout() {
    if (!state.isLoggedIn) return;
    _prefs.remove(_tokenKey);
    _prefs.remove(_userKey);
    ref.read(actAsProvider.notifier).clear();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

final apiProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    token: () => ref.read(authProvider).token,
    onUnauthorized: () => ref.read(authProvider.notifier).logout(),
    actAs: () => ref.read(actAsProvider)?.id,
  );
});

/// The artisan a coordinator is currently working for (`x-act-as`).
class ActAs {
  const ActAs(this.id, this.name);

  final String id;
  final String name;
}

class ActAsNotifier extends Notifier<ActAs?> {
  static const _key = 'coordinator.actAs';

  @override
  ActAs? build() {
    final raw = ref.watch(sharedPrefsProvider).getString(_key);
    if (raw == null) return null;
    try {
      final j = asMap(jsonDecode(raw));
      final id = str(j['id']);
      return id == null ? null : ActAs(id, str(j['name']) ?? '');
    } catch (_) {
      return null;
    }
  }

  void set(String id, String name) {
    ref.read(sharedPrefsProvider).setString(_key, jsonEncode({'id': id, 'name': name}));
    state = ActAs(id, name);
  }

  void clear() {
    ref.read(sharedPrefsProvider).remove(_key);
    state = null;
  }
}

final actAsProvider = NotifierProvider<ActAsNotifier, ActAs?>(ActAsNotifier.new);

/// True when the artisan app may be used: an artisan, or a coordinator
/// acting for one of their artisans.
final canUseArtisanAppProvider = Provider<bool>((ref) {
  final auth = ref.watch(authProvider);
  return auth.isArtisan || (auth.isCoordinator && ref.watch(actAsProvider) != null);
});

// ─────────────────────── Config / language / currency ───────────────────────

final configProvider = FutureProvider<ShopConfig>((ref) async {
  final data = await ref.watch(apiProvider).get('/config');
  return ShopConfig.fromJson(asMap(data));
});

/// Config or a safe empty default while loading / offline.
final configOrEmptyProvider = Provider<ShopConfig>(
  (ref) => ref.watch(configProvider).value ?? ShopConfig.empty,
);

/// Storefront languages; `ar` is right-to-left.
const supportedLangs = ['az', 'en', 'ru', 'de', 'tr', 'fr', 'ar'];

bool isRtl(String lang) => lang == 'ar';

class LangNotifier extends Notifier<String> {
  static const _key = 'buyer.lang';

  @override
  String build() {
    final saved = ref.watch(sharedPrefsProvider).getString(_key);
    return supportedLangs.contains(saved) ? saved! : 'az';
  }

  void set(String lang) {
    if (!supportedLangs.contains(lang)) return;
    ref.read(sharedPrefsProvider).setString(_key, lang);
    state = lang;
  }
}

final langProvider = NotifierProvider<LangNotifier, String>(LangNotifier.new);

class CurrencyNotifier extends Notifier<String> {
  static const _key = 'buyer.currency';

  @override
  String build() => ref.watch(sharedPrefsProvider).getString(_key) ?? 'USD';

  void set(String code) {
    ref.read(sharedPrefsProvider).setString(_key, code);
    state = code;
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, String>(CurrencyNotifier.new);

/// Remembers the last email typed into "I want this" / checkout / tracking.
class EmailMemory extends Notifier<String> {
  static const _key = 'buyer.email';

  @override
  String build() => ref.watch(sharedPrefsProvider).getString(_key) ?? '';

  void remember(String email) {
    ref.read(sharedPrefsProvider).setString(_key, email.trim());
    state = email.trim();
  }
}

final emailMemoryProvider = NotifierProvider<EmailMemory, String>(EmailMemory.new);

// ───────────────────────────── Money ─────────────────────────────

/// Converts AZN amounts from the API into the buyer's currency.
class Money {
  Money(this.config, this.currencyCode, this.lang);

  final ShopConfig config;
  final String currencyCode;
  final String lang;

  String get _locale => switch (lang) {
    'de' => 'de',
    'tr' => 'tr',
    'fr' => 'fr',
    'ar' => 'ar',
    'ru' => 'ru',
    'az' => 'az',
    _ => 'en',
  };

  /// Formats [azn] in the selected buyer currency.
  String call(num? azn) => format(azn, currencyCode);

  String format(num? azn, String code) {
    final c = config.currency(code);
    final v = (azn ?? 0) * (c.code == 'AZN' ? 1 : c.rate);
    return formatIn(v, c.code, c.symbol);
  }

  String formatIn(num v, String code, String symbol) {
    // Whole amounts without cents; otherwise always two decimals so summary
    // lines and totals read consistently.
    final digits = (v * 100).round() % 100 == 0 ? 0 : 2;
    if (code == 'AZN') {
      final n = NumberFormat.decimalPatternDigits(locale: _locale, decimalDigits: digits);
      return '${n.format(v)} AZN';
    }
    return NumberFormat.currency(locale: _locale, symbol: symbol, decimalDigits: digits).format(v);
  }

  /// Always in AZN (used for "≈ N AZN" hints and the artisan app).
  String azn(num? v) => format(v, 'AZN');

  bool get isAzn => config.currency(currencyCode).code == 'AZN';
}

final moneyProvider = Provider<Money>(
  (ref) =>
      Money(ref.watch(configOrEmptyProvider), ref.watch(currencyProvider), ref.watch(langProvider)),
);

/// Plain AZN formatter for the artisan app (no buyer state involved).
String formatAzn(num? v) {
  final n = v ?? 0;
  final digits = n == n.roundToDouble() ? 0 : 2;
  return '${NumberFormat.decimalPatternDigits(locale: 'az', decimalDigits: digits).format(n)} AZN';
}
