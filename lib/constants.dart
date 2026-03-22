import 'package:flutter/material.dart';

// ─── Color System ──────────────────────────────────────────
// Flat Design Mobile: bold, clear, no shadows, color-blocking

class AppColors {
  // Primary — Blue for trust and clarity
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF60A5FA);
  static const primaryDark = Color(0xFF1D4ED8);
  static const primarySurface = Color(0xFFEFF6FF);

  // Accent — Orange for CTAs and attention
  static const accent = Color(0xFFF97316);
  static const accentLight = Color(0xFFFB923C);
  static const accentSurface = Color(0xFFFFF7ED);

  // Semantic colors
  static const positive = Color(0xFF22C55E);
  static const positiveSurface = Color(0xFFF0FDF4);
  static const negative = Color(0xFFEF4444);
  static const negativeSurface = Color(0xFFFEF2F2);
  static const warning = Color(0xFFF59E0B);
  static const warningSurface = Color(0xFFFFFBEB);
  static const neutral = Color(0xFF64748B);

  // Light mode surfaces
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF1F5F9);
  static const surfaceMuted = Color(0xFFE2E8F0);
  static const textPrimary = Color(0xFF1E293B);
  static const textSecondary = Color(0xFF64748B);
  static const textTertiary = Color(0xFF94A3B8);
  static const divider = Color(0xFFE2E8F0);

  // Dark mode surfaces
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkSurfaceVariant = Color(0xFF334155);
  static const darkDivider = Color(0xFF334155);
  static const darkTextPrimary = Color(0xFFF1F5F9);
  static const darkTextSecondary = Color(0xFF94A3B8);

  // Member avatar palette — vibrant, distinct, accessible
  static const memberColors = [
    Color(0xFF2563EB), // blue
    Color(0xFF7C3AED), // violet
    Color(0xFFDB2777), // pink
    Color(0xFF059669), // emerald
    Color(0xFFD97706), // amber
    Color(0xFFDC2626), // red
  ];

  static Color memberColor(int index) =>
      memberColors[index % memberColors.length];
}

// ─── Radius System ─────────────────────────────────────────

class AppRadius {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
  static const full = 999.0;
}

// ─── Spacing System (8dp grid) ─────────────────────────────

class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
}

// ─── Domain Constants ──────────────────────────────────────

class SplitPresets {
  static const List<int> values = [50, 60, 70, 80];
  static String displayLabel(int percent) => '$percent/${100 - percent}';
}

class AppCurrency {
  final String code;
  final String symbol;
  final String name;
  const AppCurrency(this.code, this.symbol, this.name);

  static const list = [
    AppCurrency('TRY', '₺', 'Turkish Lira'),
    AppCurrency('USD', '\$', 'US Dollar'),
    AppCurrency('EUR', '€', 'Euro'),
    AppCurrency('GBP', '£', 'British Pound'),
    AppCurrency('SAR', '﷼', 'Saudi Riyal'),
    AppCurrency('AED', 'د.إ', 'UAE Dirham'),
    AppCurrency('JPY', '¥', 'Japanese Yen'),
    AppCurrency('KRW', '₩', 'South Korean Won'),
  ];

  static AppCurrency getByCode(String code) =>
      list.firstWhere((c) => c.code == code, orElse: () => list.first);
}

class BillCategory {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  const BillCategory(this.id, this.label, this.icon, this.color);
}

class BillCategories {
  static const list = [
    BillCategory('groceries', 'Groceries', Icons.shopping_cart_rounded, Color(0xFF22C55E)),
    BillCategory('restaurant', 'Restaurant', Icons.restaurant_rounded, Color(0xFFF97316)),
    BillCategory('utilities', 'Utilities', Icons.bolt_rounded, Color(0xFF2563EB)),
    BillCategory('rent', 'Rent', Icons.home_rounded, Color(0xFF7C3AED)),
    BillCategory('transport', 'Transport', Icons.directions_car_rounded, Color(0xFF0891B2)),
    BillCategory('health', 'Health', Icons.favorite_rounded, Color(0xFFEF4444)),
    BillCategory('entertainment', 'Entertainment', Icons.movie_rounded, Color(0xFFDB2777)),
    BillCategory('shopping', 'Shopping', Icons.shopping_bag_rounded, Color(0xFF059669)),
    BillCategory('other', 'Other', Icons.receipt_long_rounded, Color(0xFF64748B)),
  ];

  static BillCategory getById(String id) =>
      list.firstWhere((c) => c.id == id, orElse: () => list.last);
}

// ─── Responsive Scaling ───────────────────────────────────

class AppScale {
  static double _scale = 1.0;
  static bool _initialized = false;

  /// Initialize with screen width. Call once from app root.
  static void init(double screenWidth) {
    _scale = (screenWidth / 375).clamp(0.85, 1.3);
    _initialized = true;
  }

  /// Scale a font size value
  static double fontSize(double base) => _initialized ? (base * _scale) : base;

  /// Scale a dimension (width, height, icon size)
  static double size(double base) => _initialized ? (base * _scale) : base;

  /// Scale a padding/margin value
  static double padding(double base) => _initialized ? (base * _scale) : base;
}
