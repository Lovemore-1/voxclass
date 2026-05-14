import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Backgrounds ──────────────────────────────────────────────────────────
  static const darkBg        = Color(0xFF0D0D2B);
  static const card          = Color(0xFF1A1A3E);
  static const cardElevated  = Color(0xFF1E1E4A);
  static const cardGlass     = Color(0xFF252555);

  // ── Borders ───────────────────────────────────────────────────────────────
  static const border        = Color(0xFF2A2A5B);
  static const borderLight   = Color(0xFF3A3A6B);

  // ── Primary accent (indigo) — replaces lime everywhere ───────────────────
  static const lime          = Color(0xFF6366F1); // indigo
  static const limeLight     = Color(0xFF818CF8);
  static const limeDark      = Color(0xFF4F46E5);

  // ── Palette ───────────────────────────────────────────────────────────────
  static const indigo        = Color(0xFF6366F1);
  static const indigoLight   = Color(0xFF818CF8);
  static const purple        = Color(0xFF8B5CF6);
  static const purpleLight   = Color(0xFFA78BFA);
  static const purpleDark    = Color(0xFF7C3AED);
  static const blue          = Color(0xFF3B82F6);
  static const magenta       = Color(0xFFEC4899);
  static const teal          = Color(0xFF0D9488);

  // ── Status ────────────────────────────────────────────────────────────────
  static const white         = Color(0xFFFFFFFF);
  static const green         = Color(0xFF22C55E);
  static const greenBg       = Color(0xFF052E16);
  static const amber         = Color(0xFFF59E0B);
  static const amberBg       = Color(0xFF1C1400);
  static const red           = Color(0xFFEF4444);
  static const redBg         = Color(0xFF2A0A0A);

  static const success       = green;
  static const warning       = amber;
  static const error         = red;

  // ── Text ──────────────────────────────────────────────────────────────────
  static const textPrimary   = Color(0xFFFFFFFF);
  static const textSecondary = Color(0xFFCBD5E1);
  static const textMuted     = Color(0xFF64748B);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const bgGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0D0D2B), Color(0xFF16164A), Color(0xFF0D0D2B)],
    stops: [0.0, 0.5, 1.0],
  );

  static const indigoGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
  );

  static const purpleGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
  );

  static const blueGradient = LinearGradient(
    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
  );
}
