import 'package:flutter/material.dart';
import '../constants.dart';
import '../providers/bill_provider.dart';

class SettleAllSheet extends StatefulWidget {
  final List<OptimalSettlement> optimized;
  final List<OptimalSettlement> rawDebts;
  final Map<int, String> memberNames;
  final String currencySymbol;
  final Function(int fromId, int toId, double amount) onSettle;

  const SettleAllSheet({
    super.key,
    required this.optimized,
    required this.rawDebts,
    required this.memberNames,
    required this.currencySymbol,
    required this.onSettle,
  });

  @override
  State<SettleAllSheet> createState() => _SettleAllSheetState();
}

class _SettleAllSheetState extends State<SettleAllSheet> {
  bool _showOptimized = true;
  late List<OptimalSettlement> _optimizedList;
  late List<OptimalSettlement> _rawList;

  @override
  void initState() {
    super.initState();
    _optimizedList = List.of(widget.optimized);
    _rawList = List.of(widget.rawDebts);
  }

  List<OptimalSettlement> get _activeList =>
      _showOptimized ? _optimizedList : _rawList;

  void _handleSettle(int index) {
    final settlement = _activeList[index];
    widget.onSettle(
      settlement.fromMemberId,
      settlement.toMemberId,
      settlement.amount,
    );
    setState(() {
      _activeList.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: AppSpacing.sm),
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurfaceVariant
                    : AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Header
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: Text(
              'Settlement Plan',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.darkTextPrimary
                    : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Segmented toggle
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('Optimized (${_optimizedList.length})'),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('All debts (${_rawList.length})'),
                ),
              ],
              selected: {_showOptimized},
              onSelectionChanged: (selected) {
                setState(() {
                  _showOptimized = selected.first;
                });
              },
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return AppColors.primary;
                  }
                  return isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.surfaceVariant;
                }),
                foregroundColor:
                    WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary;
                }),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // Settlement list or empty state
          if (_activeList.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.xxxl,
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.handshake_rounded,
                    size: 48,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'All settled up!',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                itemCount: _activeList.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpacing.sm),
                itemBuilder: (context, index) {
                  final s = _activeList[index];
                  final fromName =
                      widget.memberNames[s.fromMemberId] ?? '?';
                  final toName =
                      widget.memberNames[s.toMemberId] ?? '?';
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkSurfaceVariant
                          : AppColors.surfaceVariant,
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_forward_rounded,
                          size: 20,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            '$fromName → $toName',
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '${widget.currencySymbol}${s.amount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        FilledButton(
                          onPressed: () => _handleSettle(index),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Pay',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}
