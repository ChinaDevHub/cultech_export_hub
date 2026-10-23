import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/feedback.dart';
import 'router.dart';

class CultechApp extends ConsumerStatefulWidget {
  const CultechApp({super.key});

  @override
  ConsumerState<CultechApp> createState() => _CultechAppState();
}

class _CultechAppState extends ConsumerState<CultechApp> {
  late final GoRouter _router = ref.read(routerProvider);
  Area _area = Area.buyer;

  @override
  void initState() {
    super.initState();
    _area = areaOf(_router.routeInformationProvider.value.uri.path);
    _router.routeInformationProvider.addListener(_onRoute);
  }

  @override
  void dispose() {
    _router.routeInformationProvider.removeListener(_onRoute);
    super.dispose();
  }

  void _onRoute() {
    final area = areaOf(_router.routeInformationProvider.value.uri.path);
    if (area != _area && mounted) setState(() => _area = area);
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(langProvider);
    final locale = switch (_area) {
      Area.artisan => const Locale('az'),
      Area.admin => const Locale('en'),
      Area.buyer => Locale(lang),
    };
    return MaterialApp.router(
      title: 'Cultural Export Hub',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      routerConfig: _router,
      scaffoldMessengerKey: rootMessengerKey,
      locale: locale,
      supportedLocales: [for (final l in supportedLangs) Locale(l)],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
