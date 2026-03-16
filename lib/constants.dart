import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF2E7D32);
  static const secondary = Color(0xFF66BB6A);
  static const background = Color(0xFFF5F5F5);
  static const cardBackground = Colors.white;
  static const positive = Color(0xFF4CAF50);
  static const negative = Color(0xFFE53935);
  static const neutral = Color(0xFF757575);
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
    BillCategory('groceries', 'Groceries', Icons.shopping_cart, Color(0xFF4CAF50)),
    BillCategory('restaurant', 'Restaurant', Icons.restaurant, Color(0xFFFF9800)),
    BillCategory('utilities', 'Utilities', Icons.bolt, Color(0xFF2196F3)),
    BillCategory('rent', 'Rent', Icons.home, Color(0xFF9C27B0)),
    BillCategory('transport', 'Transport', Icons.directions_car, Color(0xFF607D8B)),
    BillCategory('health', 'Health', Icons.local_hospital, Color(0xFFF44336)),
    BillCategory('entertainment', 'Entertainment', Icons.movie, Color(0xFFE91E63)),
    BillCategory('shopping', 'Shopping', Icons.shopping_bag, Color(0xFF00BCD4)),
    BillCategory('other', 'Other', Icons.receipt, Color(0xFF757575)),
  ];

  static BillCategory getById(String id) =>
      list.firstWhere((c) => c.id == id, orElse: () => list.last);
}
