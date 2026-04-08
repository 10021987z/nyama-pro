import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Palette officielle NYAMA ──────────────────────────────────────────────
  static const Color primary = Color(0xFFF57C20);       // Nyama Orange
  static const Color primaryDark = Color(0xFFD4691A);
  static const Color primaryLight = Color(0xFFFF9A4D);
  static const Color secondary = Color(0xFF3D3D3D);     // Charcoal
  static const Color ctaGreen = Color(0xFF1B4332);      // Forest Green — CTA
  static const Color forestGreen = Color(0xFF1B4332);   // Alias Forest Green (CTA)
  static const Color charcoal = Color(0xFF3D3D3D);      // Alias Charcoal
  static const Color creme = Color(0xFFF5F5F0);         // Alias fond crème
  static const Color surfaceWhite = Colors.white;
  static const Color textTertiary = Color(0xFF9E9E9E);
  static const Color outlineVariant = Color(0xFFE0E0DB);
  static const Color gold = Color(0xFFD4A017);           // Gold — revenus/étoiles
  static const Color accent = Color(0xFFE8413C);         // Rouge accent
  static const Color error = Color(0xFFE8413C);          // = accent

  // ── Statuts commandes ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);        // Vert succès
  static const Color warning = Color(0xFFF59E0B);        // Orange attente
  static const Color newOrder = Color(0xFFE8413C);       // Rouge nouvelle commande

  // ── Textes ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF3D3D3D);    // Charcoal
  static const Color textSecondary = Color(0xFF6B6B6B);
  static const Color textOnPrimary = Colors.white;

  // ── Surfaces — fond crème NYAMA ───────────────────────────────────────────
  static const Color background = Color(0xFFF5F5F0);     // Crème
  static const Color surface = Color(0xFFEDEDE8);
  static const Color cardBg = Colors.white;
  static const Color divider = Color(0xFFE0E0DB);

  // ── Ombres ────────────────────────────────────────────────────────────────
  static const Color cardShadow = Color(0x0D000000);
}
