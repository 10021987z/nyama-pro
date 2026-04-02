import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Palette principale ────────────────────────────────────────────────────
  static const Color primary = Color(0xFF1B4332);       // Vert Nyama
  static const Color primaryDark = Color(0xFF0F2B1F);   // Vert foncé
  static const Color primaryLight = Color(0xFF2D6A4F);  // Vert clair
  static const Color secondary = Color(0xFFD4A017);     // Or gains
  static const Color error = Color(0xFFDC2626);         // Rouge alerte

  // ── Statuts commandes ─────────────────────────────────────────────────────
  static const Color success = Color(0xFF16A34A);       // Vert succès
  static const Color warning = Color(0xFFF59E0B);       // Orange attente
  static const Color newOrder = Color(0xFFDC2626);      // Rouge nouvelle commande

  // ── Textes ────────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textOnPrimary = Colors.white;

  // ── Surfaces ──────────────────────────────────────────────────────────────
  static const Color background = Color(0xFFF9FAFB);
  static const Color surface = Color(0xFFF3F4F6);
  static const Color cardBg = Colors.white;
  static const Color divider = Color(0xFFE5E7EB);

  // ── Ombres ────────────────────────────────────────────────────────────────
  static const Color cardShadow = Color(0x0D000000);
}
