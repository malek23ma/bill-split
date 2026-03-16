import 'package:flutter/material.dart';

class AppColors {
  // Primary palette — Indigo for trust
  static const primary = Color(0xFF4F46E5);
  static const primaryLight = Color(0xFF818CF8);
  static const primaryDark = Color(0xFF3730A3);

  // Secondary — Teal for freshness
  static const secondary = Color(0xFF14B8A6);
  static const secondaryLight = Color(0xFF5EEAD4);

  // Accent — Amber for premium CTAs
  static const accent = Color(0xFFF59E0B);

  // Semantic colors
  static const positive = Color(0xFF10B981);
  static const negative = Color(0xFFEF4444);
  static const neutral = Color(0xFF6B7280);
  static const warning = Color(0xFFF59E0B);

  // Surface colors (light mode)
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF1F5F9);
  static const textPrimary = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF475569);
  static const textTertiary = Color(0xFF94A3B8);
  static const border = Color(0xFFE2E8F0);

  // Dark mode surfaces
  static const darkBackground = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkSurfaceVariant = Color(0xFF334155);
  static const darkBorder = Color(0xFF334155);
}

class AppRadius {
  static const xs = 6.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 28.0;
}

class SplitPresets {
  static const List<int> values = [50, 60, 70, 80];

  static String displayLabel(int percent) {
    return '$percent/${100 - percent}';
  }
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
    BillCategory('groceries', 'Groceries', Icons.shopping_cart_rounded, Color(0xFF10B981)),
    BillCategory('restaurant', 'Restaurant', Icons.restaurant_rounded, Color(0xFFF59E0B)),
    BillCategory('utilities', 'Utilities', Icons.bolt_rounded, Color(0xFF3B82F6)),
    BillCategory('rent', 'Rent', Icons.home_rounded, Color(0xFF8B5CF6)),
    BillCategory('transport', 'Transport', Icons.directions_car_rounded, Color(0xFF6366F1)),
    BillCategory('health', 'Health', Icons.favorite_rounded, Color(0xFFEF4444)),
    BillCategory('entertainment', 'Entertainment', Icons.movie_rounded, Color(0xFFEC4899)),
    BillCategory('shopping', 'Shopping', Icons.shopping_bag_rounded, Color(0xFF14B8A6)),
    BillCategory('other', 'Other', Icons.receipt_long_rounded, Color(0xFF6B7280)),
  ];

  static BillCategory getById(String id) =>
      list.firstWhere((c) => c.id == id, orElse: () => list.last);
}
