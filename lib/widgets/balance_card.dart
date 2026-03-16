import 'package:flutter/material.dart';
import '../constants.dart';

class BalanceCard extends StatelessWidget {
  final String currentMemberName;
  final String otherMemberName;
  final double balanceAmount;
  final VoidCallback? onSettleUp;

  const BalanceCard({
    super.key,
    required this.currentMemberName,
    required this.otherMemberName,
    required this.balanceAmount,
    this.onSettleUp,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = balanceAmount > 0.01;
    final isNegative = balanceAmount < -0.01;
    final isSettled = !isPositive && !isNegative;

    final color = isPositive
        ? AppColors.positive
        : isNegative
            ? AppColors.negative
            : AppColors.neutral;

    final message = isSettled
        ? 'All settled up!'
        : isPositive
            ? '$otherMemberName owes you'
            : 'You owe $otherMemberName';

    final amount = balanceAmount.abs();

    return Card(
      color: color.withAlpha(25),
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              isSettled
                  ? Icons.handshake
                  : isPositive
                      ? Icons.arrow_downward
                      : Icons.arrow_upward,
              color: color,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(
                fontSize: 16,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!isSettled) ...[
              const SizedBox(height: 4),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: amount),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOut,
                builder: (context, value, child) {
                  return Text(
                    '${value.toStringAsFixed(2)} TL',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              FilledButton.tonalIcon(
                onPressed: onSettleUp,
                icon: const Icon(Icons.handshake, size: 18),
                label: const Text('Settle Up'),
                style: FilledButton.styleFrom(
                  backgroundColor: color.withAlpha(30),
                  foregroundColor: color,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
