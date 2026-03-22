import 'package:flutter/material.dart';
import '../constants.dart';
import '../widgets/scale_tap.dart';

class BillTypeScreen extends StatelessWidget {
  const BillTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Add Bill',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: AppScale.fontSize(20),
          ),
        ),
        iconTheme: IconThemeData(
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: AppScale.padding(24)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'How would you like\nto split?',
              style: TextStyle(
                fontSize: AppScale.fontSize(28),
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how to handle the bill items and splitting.',
              style: TextStyle(
                fontSize: AppScale.fontSize(15),
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
            ),
            SizedBox(height: AppScale.size(32)),
            ScaleTap(
              onTap: () {
                Navigator.pushNamed(context, '/camera', arguments: 'full');
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppScale.padding(20)),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: AppScale.size(56),
                      height: AppScale.size(56),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.primary.withAlpha(26)
                            : AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.receipt_long_rounded,
                        color: AppColors.primary,
                        size: AppScale.size(28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Full Bill',
                            style: TextStyle(
                              fontSize: AppScale.fontSize(17),
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Review each item and choose what to split',
                            style: TextStyle(
                              fontSize: AppScale.fontSize(14),
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: AppScale.size(16),
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: AppScale.size(16)),
            ScaleTap(
              onTap: () {
                Navigator.pushNamed(context, '/camera', arguments: 'quick');
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppScale.padding(20)),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: AppScale.size(56),
                      height: AppScale.size(56),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.accent.withAlpha(26)
                            : AppColors.accentSurface,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Icon(
                        Icons.flash_on_rounded,
                        color: AppColors.accent,
                        size: AppScale.size(28),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quick Bill',
                            style: TextStyle(
                              fontSize: AppScale.fontSize(17),
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Auto-split the total equally',
                            style: TextStyle(
                              fontSize: AppScale.fontSize(14),
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: AppScale.size(16),
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
