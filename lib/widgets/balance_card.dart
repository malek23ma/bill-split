import 'package:flutter/material.dart';
import '../constants.dart';

class BalanceCard extends StatelessWidget {
  final int currentMemberId;
  final Map<int, double> memberBalances;
  final Map<int, Map<int, double>> pairwiseBalances;
  final Map<int, String> memberNames;
  final void Function(int memberId, double amount)? onSettleUp;
  final String currencySymbol;
  final bool isAuthenticated;

  const BalanceCard({
    super.key,
    required this.currentMemberId,
    required this.memberBalances,
    required this.pairwiseBalances,
    required this.memberNames,
    this.onSettleUp,
    this.currencySymbol = '\u20BA',
    this.isAuthenticated = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final myPairwise = pairwiseBalances[currentMemberId] ?? {};
    final otherEntries = <int, double>{};
    for (final entry in myPairwise.entries) {
      if (entry.value.abs() > 0.01) {
        otherEntries[entry.key] = entry.value;
      }
    }

    final allSettled = otherEntries.isEmpty;

    if (allSettled) {
      return Padding(
        padding: EdgeInsets.all(AppScale.padding(16)),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          padding: EdgeInsets.symmetric(horizontal: AppScale.padding(24), vertical: AppScale.padding(24)),
          child: Column(
            children: [
              Container(
                width: AppScale.size(48),
                height: AppScale.size(48),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkTextSecondary : AppColors.textTertiary)
                      .withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.handshake_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                  size: AppScale.size(24),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'All settled up!',
                style: TextStyle(
                  fontSize: AppScale.fontSize(16),
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final entries = otherEntries.entries.toList();
    final useGrid = entries.length >= 2;

    if (!useGrid) {
      // Single full-width row
      return Padding(
        padding: EdgeInsets.all(AppScale.padding(16)),
        child: _BalanceRow(
          memberName: memberNames[entries.first.key] ?? 'Unknown',
          amount: entries.first.value,
          currencySymbol: currencySymbol,
          isDark: isDark,
          compact: false,
          isAuthenticated: isAuthenticated,
          onSettleUp: onSettleUp != null
              ? () => onSettleUp!(entries.first.key, entries.first.value.abs())
              : null,
        ),
      );
    }

    // 2-column grid for 2+ balance rows
    // Last item gets full width if odd count
    final halfWidth = (MediaQuery.of(context).size.width - 42) / 2;
    final isOdd = entries.length.isOdd;

    return Padding(
      padding: EdgeInsets.all(AppScale.padding(16)),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (int i = 0; i < entries.length; i++)
            SizedBox(
              width: (isOdd && i == entries.length - 1)
                  ? double.infinity
                  : halfWidth,
              child: _BalanceRow(
                memberName: memberNames[entries[i].key] ?? 'Unknown',
                amount: entries[i].value,
                currencySymbol: currencySymbol,
                isDark: isDark,
                compact: true,
                isAuthenticated: isAuthenticated,
                onSettleUp: onSettleUp != null
                    ? () => onSettleUp!(entries[i].key, entries[i].value.abs())
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

class _BalanceRow extends StatelessWidget {
  final String memberName;
  final double amount; // positive = they owe you, negative = you owe them
  final String currencySymbol;
  final bool isDark;
  final bool compact;
  final bool isAuthenticated;
  final VoidCallback? onSettleUp;

  const _BalanceRow({
    required this.memberName,
    required this.amount,
    required this.currencySymbol,
    required this.isDark,
    this.compact = false,
    this.isAuthenticated = false,
    this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final theyOweYou = amount > 0;
    final absAmount = amount.abs();

    // Per-row colors: green when owed, red when owing
    final Color rowColor = theyOweYou ? AppColors.positive : AppColors.negative;
    final Color bgColor = theyOweYou
        ? (isDark ? AppColors.positive.withAlpha(20) : AppColors.positiveSurface)
        : (isDark ? AppColors.negative.withAlpha(20) : AppColors.negativeSurface);

    // Arrows: down = money coming to you (owed), up = money leaving (you owe)
    final IconData arrowIcon = theyOweYou
        ? Icons.arrow_downward_rounded
        : Icons.arrow_upward_rounded;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 24,
        vertical: compact ? 14 : 20,
      ),
      child: Column(
        children: [
          Container(
            width: compact ? 32 : 40,
            height: compact ? 32 : 40,
            decoration: BoxDecoration(
              color: rowColor.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(arrowIcon, color: rowColor, size: compact ? 16 : 20),
          ),
          SizedBox(height: 6),
          Text(
            memberName,
            style: TextStyle(
              fontSize: compact ? 13 : 15,
              color: rowColor,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          Text(
            theyOweYou ? 'owes you' : 'you owe',
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              color: rowColor.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
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
                  fontSize: compact ? 20 : 32,
                  fontWeight: FontWeight.w800,
                  color: rowColor,
                  letterSpacing: -0.5,
                ),
              );
            },
          ),
          SizedBox(height: 10),
          FilledButton.tonal(
            onPressed: onSettleUp,
            style: FilledButton.styleFrom(
              backgroundColor: rowColor.withValues(alpha: 0.12),
              foregroundColor: rowColor,
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 20,
                vertical: compact ? 8 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAuthenticated && theyOweYou
                      ? Icons.request_page_rounded
                      : Icons.handshake_rounded,
                  size: compact ? 14 : 16,
                  color: rowColor,
                ),
                const SizedBox(width: 4),
                Text(
                  isAuthenticated && theyOweYou ? 'Request Payment' : 'Settle Up',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: rowColor,
                    fontSize: compact ? 12 : 14,
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
