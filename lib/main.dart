import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fonts are bundled in assets/google_fonts/ — never fetch at runtime (offline demo).
  GoogleFonts.config.allowRuntimeFetching = false;
  final prefs = await SharedPreferences.getInstance();
  await initializeDateFormatting();

  runApp(
    ProviderScope(
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      // Retry only transient network failures; API errors surface immediately.
      retry: (count, error) => error is ApiException && error.isNetwork && count < 2
          ? Duration(milliseconds: 800 * (count + 1))
          : null,
      child: const CultechApp(),
    ),
  );
}
