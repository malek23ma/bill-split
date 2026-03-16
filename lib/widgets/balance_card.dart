import 'package:flutter/material.dart';
import '../constants.dart';

class BalanceCard extends StatelessWidget {
  final int currentMemberId;
  final Map<int, double> memberBalances; // memberId -> balance (positive = owed to them)
  final Map<int, String> memberNames; // memberId -> name
  final void Function(int memberId, double amount)? onSettleUp;
  final String currencySymbol;

  const BalanceCard({
    super.key,
    required this.currentMemberId,
    required this.memberBalances,
    required this.memberNames,
    this.onSettleUp,
    this.currencySymbol = '₺',
  });

  @override
  Widget build(BuildContext context) {
    // Compute per-other-member balances relative to the current member.
    // currentMember's balance is memberBalances[currentMemberId].
    // If current member has positive balance, others owe them.
    // We show relative amounts per pair:
    //   For each other member: relative = -(otherBalance) normalized to the pair.
    //   Actually, we use the simple approach: current member's total balance
    //   spread proportionally, OR just show per-member how much they owe.
    //
    // The memberBalances map has absolute balances per member. Positive = they
    // are owed money, negative = they owe money. For a current member with
    // positive balance, the other members with negative balances owe them.
    //
    // Per-pair relative balance from current's perspective:
    //   otherOwesMe = -(memberBalances[otherId])  ... but only relevant if signs differ.
    //
    // Simpler: current member's balance tells how much total they are owed (or owe).
    // Each other member's negative balance represents what they owe the pool.
    // We attribute that to pairs: "otherOwesMe" = -(memberBalances[otherId]) when negative.

    final otherEntries = <int, double>{};
    for (final entry in memberBalances.entries) {
      if (entry.key != currentMemberId) {
        // Other member's balance: negative means they owe the group.
        // From current member's perspective, that's how much they owe current member.
        // But this is a simplification — in reality the debts are pairwise.
        // Using the absolute balance directly: if other has -X, they owe X total.
        // Current member is owed their share proportionally.
        // For simplicity, show: other's balance negated = what they owe current member.
        final otherBalance = entry.value;
        // Skip near-zero balances
        if (otherBalance.abs() > 0.01) {
          otherEntries[entry.key] = -otherBalance;
        }
      }
    }

    final allSettled = otherEntries.isEmpty;

    // Determine net position for gradient
    final currentBalance = memberBalances[currentMemberId] ?? 0.0;
    final isNetPositive = currentBalance > 0.01;
    final isNetNegative = currentBalance < -0.01;

    final gradient = isNetPositive
        ? const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF10B981), Color(0xFF059669)],
          )
        : isNetNegative
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
              );

    final shadowColor = isNetPositive
        ? AppColors.positive
        : isNetNegative
            ? AppColors.negative
            : AppColors.neutral;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withAlpha(40),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: allSettled
              ? Column(
                  children: [
                    Icon(
                      Icons.handshake,
                      color: Colors.white.withAlpha(200),
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'All settled up!',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white.withAlpha(220),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                )
              : Column(
                  children: [
                    for (final entry in otherEntries.entries)
                      _BalanceRow(
                        memberName: memberNames[entry.key] ?? 'Unknown',
                        amount: entry.value,
                        currencySymbol: currencySymbol,
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
}

class _BalanceRow extends StatelessWidget {
  final String memberName;
  final double amount; // positive = they owe you, negative = you owe them
  final String currencySymbol;
  final VoidCallback? onSettleUp;

  const _BalanceRow({
    required this.memberName,
    required this.amount,
    required this.currencySymbol,
    this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final theyOweYou = amount > 0;
    final message = theyOweYou
        ? '$memberName owes you'
        : 'You owe $memberName';
    final absAmount = amount.abs();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          Icon(
            theyOweYou ? Icons.arrow_downward : Icons.arrow_upward,
            color: Colors.white.withAlpha(200),
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withAlpha(220),
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
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onSettleUp,
            icon: const Icon(Icons.handshake, size: 16),
            label: const Text('Settle Up'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54, width: 1.5),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
