import 'package:flutter/material.dart';
import '../constants.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final subtitleColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppScale.padding(AppSpacing.xxl),
          ),
          child: Column(
            children: [
              const Spacer(flex: 3),

              // ── App Icon ──
              Container(
                width: AppScale.size(88),
                height: AppScale.size(88),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  size: AppScale.size(44),
                  color: Colors.white,
                ),
              ),
              SizedBox(height: AppScale.padding(AppSpacing.xxl)),

              // ── Title ──
              Text(
                'BillSplit',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      fontSize: AppScale.fontSize(32),
                    ),
              ),
              SizedBox(height: AppScale.padding(AppSpacing.sm)),

              // ── Subtitle ──
              Text(
                'Split bills, not friendships',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: subtitleColor,
                      fontSize: AppScale.fontSize(16),
                    ),
              ),

              const Spacer(flex: 4),

              // ── Get Started ──
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pushNamed(context, '/auth'),
                  child: const Text('Get Started'),
                ),
              ),
              SizedBox(height: AppScale.padding(AppSpacing.md)),

              // ── Continue without account ──
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(
                    context,
                    '/households',
                  ),
                  child: Text(
                    'Continue without account',
                    style: TextStyle(color: subtitleColor),
                  ),
                ),
              ),
              SizedBox(height: AppScale.padding(AppSpacing.xxxl)),
            ],
          ),
        ),
      ),
    );
  }
}
