import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'text_styles.dart';
import 'tokens.dart';

abstract final class AppTheme {
  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: AppColors.white,
      primaryContainer: AppColors.brandLight,
      onPrimaryContainer: AppColors.brandDark,
      secondary: AppColors.accent,
      onSecondary: AppColors.white,
      secondaryContainer: AppColors.accentLight,
      onSecondaryContainer: AppColors.accent,
      tertiary: AppColors.gold,
      onTertiary: AppColors.ink,
      error: AppColors.danger,
      onError: AppColors.white,
      surface: AppColors.bg,
      onSurface: AppColors.ink,
      onSurfaceVariant: AppColors.ink2,
      surfaceContainerLowest: AppColors.white,
      surfaceContainerLow: AppColors.soft,
      surfaceContainer: AppColors.soft,
      surfaceContainerHigh: AppColors.soft2,
      surfaceContainerHighest: AppColors.soft2,
      outline: AppColors.line2,
      outlineVariant: AppColors.line,
      shadow: AppColors.shadow,
      scrim: AppColors.scrim,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final textTheme = GoogleFonts.manropeTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    const pill = StadiumBorder();
    final buttonText = AppText.body(15, weight: FontWeight.w700);

    OutlineInputBorder border(Color c, [double w = 1.5]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadii.input),
      borderSide: BorderSide(color: c, width: w),
    );

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      highlightColor: Colors.transparent,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeSlideTransitionsBuilder(),
          TargetPlatform.iOS: FadeSlideTransitionsBuilder(),
          TargetPlatform.macOS: FadeSlideTransitionsBuilder(),
          TargetPlatform.windows: FadeSlideTransitionsBuilder(),
          TargetPlatform.linux: FadeSlideTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeSlideTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.ink,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.body(17, weight: FontWeight.w800),
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: AppColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.white,
          minimumSize: const Size(48, 48),
          shape: pill,
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 22),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          backgroundColor: AppColors.white,
          minimumSize: const Size(48, 48),
          shape: pill,
          side: const BorderSide(color: AppColors.line2, width: 1.5),
          textStyle: buttonText,
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          minimumSize: const Size(48, 44),
          shape: pill,
          textStyle: buttonText,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 48),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.white,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        hintStyle: AppText.body(15, color: AppColors.muted),
        labelStyle: AppText.label,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        border: border(AppColors.line2),
        enabledBorder: border(AppColors.line2),
        focusedBorder: border(AppColors.brand),
        errorBorder: border(AppColors.danger),
        focusedErrorBorder: border(AppColors.danger),
        disabledBorder: border(AppColors.line),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.soft2,
        selectedColor: AppColors.brandLight,
        side: BorderSide.none,
        shape: pill,
        labelStyle: AppText.body(13.5, weight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppText.body(15, weight: FontWeight.w700, color: AppColors.white),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.dialog)),
        titleTextStyle: AppText.display(24, weight: FontWeight.w700),
        contentTextStyle: AppText.body(16, color: AppColors.ink2),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.line2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.dialog)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shadowColor: AppColors.shadow.withValues(alpha: .25),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.line),
        ),
        textStyle: AppText.body(15, weight: FontWeight.w600),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.brandLight,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => AppText.body(
            12.5,
            weight: FontWeight.w700,
            color: s.contains(WidgetState.selected) ? AppColors.brand : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? AppColors.brand : AppColors.muted,
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
        linearTrackColor: AppColors.soft2,
        circularTrackColor: Colors.transparent,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.brand,
        selectionColor: AppColors.brandLight,
        selectionHandleColor: AppColors.brand,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(10)),
        textStyle: AppText.body(13, color: AppColors.white),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(AppColors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.brand : AppColors.line2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: AppText.body(16, weight: FontWeight.w700),
        subtitleTextStyle: AppText.body(14, color: AppColors.muted),
        iconColor: AppColors.ink2,
      ),
    );
  }
}

/// Fade + 12 px slide-up page transition (none when reduced motion is on).
class FadeSlideTransitionsBuilder extends PageTransitionsBuilder {
  const FadeSlideTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final curved = CurvedAnimation(parent: animation, curve: AppMotion.curve);
    return AnimatedBuilder(
      animation: curved,
      builder: (context, child) => Opacity(
        opacity: curved.value,
        child: Transform.translate(offset: Offset(0, 12 * (1 - curved.value)), child: child),
      ),
      child: child,
    );
  }

  @override
  Duration get transitionDuration => AppMotion.slow;
}
