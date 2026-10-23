import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'tokens.dart';

/// Typography: Manrope for UI/body, Fraunces for display & big prices.
abstract final class AppText {
  static TextStyle display(
    double size, {
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.ink,
    FontStyle? style,
    double height = 1.15,
  }) => GoogleFonts.fraunces(
    fontSize: size,
    fontWeight: weight,
    color: color,
    fontStyle: style,
    height: height,
    letterSpacing: -0.01 * size,
  );

  static TextStyle body(
    double size, {
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.ink,
    double height = 1.45,
    double? letterSpacing,
  }) => GoogleFonts.manrope(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  // Buyer scale.
  static TextStyle get h1 => display(44, weight: FontWeight.w700);
  static TextStyle get h2 => display(30, weight: FontWeight.w700);
  static TextStyle get h3 => display(21, weight: FontWeight.w600);
  static TextStyle get bodyM => body(16);
  static TextStyle get bodyS => body(14.5, color: AppColors.ink2);
  static TextStyle get caption => body(13, color: AppColors.muted);
  static TextStyle get label => body(13.5, weight: FontWeight.w700, color: AppColors.ink);
  static TextStyle price(double size, {Color color = AppColors.ink}) =>
      body(size, weight: FontWeight.w800, color: color, height: 1.1);
  static TextStyle mono(
    double size, {
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w700,
  }) =>
      GoogleFonts.jetBrainsMono(fontSize: size, color: color, fontWeight: weight, letterSpacing: 1);

  // Artisan scale (bigger everywhere).
  static TextStyle get aH1 => display(34, weight: FontWeight.w700);
  static TextStyle get aH2 => display(26, weight: FontWeight.w700);
  static TextStyle get aBody => body(18);
  static TextStyle get aBodyStrong => body(18, weight: FontWeight.w700);
  static TextStyle get aLabel => body(16, weight: FontWeight.w700, color: AppColors.ink);
  static TextStyle get aHint => body(15.5, color: AppColors.muted);
}
