import 'package:flutter/material.dart';
import '../constants.dart';

class BalanceCard extends StatelessWidget {
  final int currentMemberId;
  final Map<int, double> memberBalances; // memberId -> net balance
  final Map<int, Map<int, double>> pairwiseBalances; // pairwise debts
  final Map<int, String> memberNames; // memberId -> name
  final void Function(int memberId, double amount)? onSettleUp;
  final String currencySymbol;

  const BalanceCard({
    super.key,
    required this.currentMemberId,
    required this.memberBalances,
    required this.pairwiseBalances,
    required this.memberNames,
    this.onSettleUp,
    this.currencySymbol = '\u20BA',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Use PAIRWISE balances for display — shows actual debts between
    // the current user and each other member, not global net positions
    final myPairwise = pairwiseBalances[currentMemberId] ?? {};
    final otherEntries = <int, double>{};
    for (final entry in myPairwise.entries) {
      if (entry.value.abs() > 0.01) {
        otherEntries[entry.key] = entry.value;
      }
    }

    final allSettled = otherEntries.isEmpty;

    final currentBalance = memberBalances[currentMemberId] ?? 0.0;
    final isNetPositive = currentBalance > 0.01;
    // Flat color-blocked backgrounds based on net position
    final Color containerColor;
    final Color iconColor;
    final Color statusTextColor;
    final Color amountColor;

    if (allSettled) {
      containerColor =
          isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
      iconColor = isDark ? AppColors.darkTextSecondary : AppColors.textTertiary;
      statusTextColor =
          isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
      amountColor =
          isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    } else if (isNetPositive) {
      containerColor =
          isDark ? AppColors.positive.withAlpha(20) : AppColors.positiveSurface;
      iconColor = AppColors.positive;
      statusTextColor = AppColors.positive;
      amountColor = AppColors.positive;
    } else {
      containerColor =
          isDark ? AppColors.negative.withAlpha(20) : AppColors.negativeSurface;
      iconColor = AppColors.negative;
      statusTextColor = AppColors.negative;
      amountColor = AppColors.negative;
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: containerColor,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: allSettled
              ? _buildSettledState(iconColor, statusTextColor)
              : Column(
                  children: [
                    for (final entry in otherEntries.entries)
                      _BalanceRow(
                        memberName: memberNames[entry.key] ?? 'Unknown',
                        amount: entry.value,
                        currencySymbol: currencySymbol,
                        iconColor: iconColor,
                        statusTextColor: statusTextColor,
                        amountColor: amountColor,
                        statusIcon: entry.value > 0
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded,
                        isDark: isDark,
                        onSettleUp: onSettleUp != null
                            ? () => onSettleUp!(entry.key, entry.value.abs())
                            : null,
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildSettledState(Color iconColor, Color textColor) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          child: Icon(
            Icons.handshake_rounded,
            color: iconColor,
            size: 24,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'All settled up!',
          style: TextStyle(
            fontSize: 16,
            color: textColor,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String memberName;
  final double amount; // positive = they owe you, negative = you owe them
  final String currencySymbol;
  final Color iconColor;
  final Color statusTextColor;
  final Color amountColor;
  final IconData statusIcon;
  final bool isDark;
  final VoidCallback? onSettleUp;

  const _BalanceRow({
    required this.memberName,
    required this.amount,
    required this.currencySymbol,
    required this.iconColor,
    required this.statusTextColor,
    required this.amountColor,
    required this.statusIcon,
    required this.isDark,
    this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final theyOweYou = amount > 0;
    final message =
        theyOweYou ? '$memberName owes you' : 'You owe $memberName';
    final absAmount = amount.abs();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              statusIcon,
              color: iconColor,
              size: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: statusTextColor,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: absAmount),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOut,
            builder: (context, value, child) {
              return Text(
                '${value.toStringAsFixed(2)} $currencySymbol',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: amountColor,
                  letterSpacing: -0.5,
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onSettleUp,
            style: FilledButton.styleFrom(
              backgroundColor: iconColor.withValues(alpha: 0.12),
              foregroundColor: iconColor,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.handshake_rounded, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Text(
                  'Settle Up',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: iconColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
