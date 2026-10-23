import 'package:flutter/material.dart';

/// Design tokens. Every colour used in the app lives here — widgets never
/// hard-code hex values.
abstract final class AppColors {
  static const bg = Color(0xFFFFFFFF);
  static const soft = Color(0xFFFAF8F4);
  static const soft2 = Color(0xFFF3EFE7);
  static const line = Color(0xFFEBE6DC);
  static const line2 = Color(0xFFDCD5C7);

  static const ink = Color(0xFF1B1A17);
  static const ink2 = Color(0xFF47433B);
  static const muted = Color(0xFF7A7469);
  static const white = Color(0xFFFFFFFF);

  static const brand = Color(0xFF0E5A57);
  static const brandDark = Color(0xFF0A4442);
  static const brandLight = Color(0xFFE4F1EF);

  static const accent = Color(0xFFB5293E);
  static const accentLight = Color(0xFFFBEAED);

  static const gold = Color(0xFFD9A232);
  static const goldLight = Color(0xFFFDF3DA);

  /// Gold is too light for text; use this on gold-tinted surfaces.
  static const goldInk = Color(0xFF7D5A0E);

  static const ok = Color(0xFF1B7A4C);
  static const okLight = Color(0xFFE5F5EC);
  static const warn = Color(0xFFA8660C);
  static const warnLight = Color(0xFFFFF3DF);
  static const danger = Color(0xFFC0392B);
  static const dangerLight = Color(0xFFFBEAE8);

  /// AI concept visuals (never used for real photos).
  static const concept = Color(0xFF5B3FB0);
  static const conceptBg = Color(0xFFEDE9FE);
  static const conceptBorder = Color(0xFF8B6FDC);

  /// WhatsApp card / simulator only.
  static const waGreen = Color(0xFF25D366);
  static const waBubble = Color(0xFFD9FDD3);
  static const waWallpaper = Color(0xFFEFEAE2);
  static const waHeader = Color(0xFF075E54);

  /// Sample concept colours (hex strings, as the API sends them) used to
  /// illustrate "other versions" before any real variant exists.
  static const sampleTintHex = '#2F6FB3';
  static const samplePatternHex = '#B5293E';

  static const scrim = Color(0x661B1A17);
  static const shadow = Color(0xFF1B1A17);

  /// Palette used for artisan avatars when the API gives no colour.
  static const avatarFallbacks = [
    Color(0xFF0E5A57),
    Color(0xFFB5293E),
    Color(0xFF7D5A0E),
    Color(0xFF5B3FB0),
    Color(0xFF1B7A4C),
    Color(0xFF47433B),
  ];

  /// Parses `#rgb`, `#rrggbb` or `#aarrggbb` strings coming from the API
  /// (artisan colours, concept tints).
  static Color fromHex(String? hex, {Color fallback = brand}) {
    if (hex == null) return fallback;
    var h = hex.trim().replaceFirst('#', '');
    if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
    if (h.length == 6) h = 'FF$h';
    final v = int.tryParse(h, radix: 16);
    return v == null ? fallback : Color(v);
  }
}

abstract final class AppRadii {
  static const input = 12.0;
  static const inputArtisan = 16.0;
  static const image = 16.0;
  static const card = 24.0;
  static const panel = 24.0;
  static const artisanButton = 22.0;
  static const dialog = 28.0;
  static const pill = 999.0;
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const xxl = 40.0;

  static const maxContent = 1200.0;

  static double gutter(BuildContext context) => MediaQuery.sizeOf(context).width >= 700 ? 24 : 16;
}

abstract final class AppShadows {
  static final small = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: .06),
      offset: const Offset(0, 1),
      blurRadius: 3,
    ),
  ];
  static final raised = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: .18),
      offset: const Offset(0, 8),
      blurRadius: 28,
      spreadRadius: -10,
    ),
  ];
  static final modal = [
    BoxShadow(
      color: AppColors.shadow.withValues(alpha: .3),
      offset: const Offset(0, 24),
      blurRadius: 60,
      spreadRadius: -20,
    ),
  ];
  static final focusGlow = [const BoxShadow(color: AppColors.brandLight, spreadRadius: 4)];
}

abstract final class AppMotion {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 220);
  static const curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  static Duration of(BuildContext context, [Duration d = base]) =>
      reduced(context) ? Duration.zero : d;
}
