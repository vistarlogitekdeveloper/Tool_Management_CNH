import 'package:flutter/material.dart';

/// Colour tokens lifted verbatim from the approved CNH TMS prototype
/// (`tms-prototype_2.html`), so the built app matches what the plant signed off.
abstract final class AppColors {
  // Surfaces
  static const bg = Color(0xFFF4F6F9);
  static const panel = Color(0xFFFFFFFF);
  static const line = Color(0xFFE3E8EF);
  static const line2 = Color(0xFFEEF2F7);
  static const zebra = Color(0xFFFAFBFC);
  static const hover = Color(0xFFF8FAFC);

  // Text
  static const ink = Color(0xFF1C2431);
  static const muted = Color(0xFF6B7688);
  static const label = Color(0xFF334155);

  // Brand
  static const brand = Color(0xFF0B4DA2);
  static const brandDark = Color(0xFF083A7C);
  static const brandSoft = Color(0xFFE8F0FB);

  // Semantic
  static const green = Color(0xFF1A9D5A);
  static const greenSoft = Color(0xFFE4F6EC);
  static const greenInk = Color(0xFF137A44);

  static const amber = Color(0xFFC9871A);
  static const amberSoft = Color(0xFFFDF3E0);
  static const amberInk = Color(0xFFA06A10);

  static const red = Color(0xFFCF3B3B);
  static const redSoft = Color(0xFFFBE8E8);
  static const redInk = Color(0xFFB02C2C);

  static const slate = Color(0xFF64748B);
  static const slateSoft = Color(0xFFEEF1F5);

  static const violet = Color(0xFF7C5CBF);
  static const violetSoft = Color(0xFFF1ECFA);

  // Navigation rail
  static const navBg = Color(0xFF0F1E33);
  static const navText = Color(0xFFC1CDDD);
  static const navSection = Color(0xFF5F728D);
  static const navFoot = Color(0xFF7D90AA);

  // Login gradient
  static const loginTop = Color(0xFF0B2545);
  static const loginMid = Color(0xFF0F1E33);
  static const loginEnd = Color(0xFF08315F);

  /// Fallback palette for tool categories whose master row has no colour set.
  static const categoryFallback = <Color>[
    brand, green, amber, violet, red, Color(0xFF0E7490),
  ];

  /// Parses a '#rrggbb' string from the API; falls back to slate.
  static Color fromHex(String? hex, {Color fallback = slate}) {
    if (hex == null || hex.isEmpty) return fallback;
    final cleaned = hex.replaceFirst('#', '').trim();
    if (cleaned.length != 6 && cleaned.length != 8) return fallback;
    final value = int.tryParse(cleaned.length == 6 ? 'FF$cleaned' : cleaned, radix: 16);
    return value == null ? fallback : Color(value);
  }
}

/// The three-part colour treatment behind every status chip: background,
/// foreground and the accent dot.
class StatusPalette {
  const StatusPalette(this.background, this.foreground);

  final Color background;
  final Color foreground;

  static const green = StatusPalette(AppColors.greenSoft, AppColors.greenInk);
  static const amber = StatusPalette(AppColors.amberSoft, AppColors.amberInk);
  static const red = StatusPalette(AppColors.redSoft, AppColors.redInk);
  static const blue = StatusPalette(AppColors.brandSoft, AppColors.brand);
  static const violet = StatusPalette(AppColors.violetSoft, AppColors.violet);
  static const slate = StatusPalette(AppColors.slateSoft, AppColors.slate);
}
