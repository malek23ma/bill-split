import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/bill_provider.dart';
import '../providers/household_provider.dart';
import '../constants.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _year = now.year;
    _month = now.month;
  }

  void _goToPreviousMonth() {
    setState(() {
      if (_month == 1) {
        _month = 12;
        _year--;
      } else {
        _month--;
      }
    });
  }

  void _goToNextMonth() {
    final now = DateTime.now();
    // Don't go past the current month
    if (_year == now.year && _month >= now.month) return;
    setState(() {
      if (_month == 12) {
        _month = 1;
        _year++;
      } else {
        _month++;
      }
    });
  }

  bool _canGoBack(DateTime? oldestDate) {
    if (oldestDate == null) return false;
    // Can go back if current selection is after the oldest bill's month
    if (_year > oldestDate.year) return true;
    if (_year == oldestDate.year && _month > oldestDate.month) return true;
    return false;
  }

  bool _canGoForward() {
    final now = DateTime.now();
    return _year < now.year || (_year == now.year && _month < now.month);
  }

  @override
  Widget build(BuildContext context) {
    final billProvider = context.watch<BillProvider>();
    final householdProvider = context.watch<HouseholdProvider>();
    final members = householdProvider.members;
    final memberNames = {for (final m in members) m.id!: m.name};
    final insights = billProvider.getInsightsForMonth(_year, _month);
    final oldestDate = billProvider.oldestBillDate;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Insights',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined,
                color: AppColors.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Export coming soon')),
              );
            },
            tooltip: 'Export',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: AppColors.border, height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month selector
            _buildMonthSelector(oldestDate),
            const SizedBox(height: 16),

            // Total spent card
            _buildTotalSpentCard(insights, householdProvider),
            const SizedBox(height: 24),

            // By Category section
            if (insights.categorySpend.isNotEmpty) ...[
              _buildSectionTitle('By Category'),
              const SizedBox(height: 12),
              _buildCategoryBreakdown(insights, householdProvider),
              const SizedBox(height: 24),
            ],

            // By Member section
            if (insights.memberSpend.isNotEmpty) ...[
              _buildSectionTitle('By Member'),
              const SizedBox(height: 12),
              _buildMemberBreakdown(insights, memberNames, householdProvider),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(DateTime? oldestDate) {
    final canBack = _canGoBack(oldestDate);
    final canForward = _canGoForward();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              Icons.chevron_left_rounded,
              color: canBack ? AppColors.textPrimary : AppColors.border,
            ),
            onPressed: canBack ? _goToPreviousMonth : null,
          ),
          Text(
            '${months[_month - 1]} $_year',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canForward ? AppColors.textPrimary : AppColors.border,
            ),
            onPressed: canForward ? _goToNextMonth : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSpentCard(
      MonthlyInsights insights, HouseholdProvider householdProvider) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text(
            'Total Spent',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            householdProvider.formatAmount(insights.totalSpent),
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${insights.billCount} bill${insights.billCount == 1 ? '' : 's'}',
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCategoryBreakdown(
      MonthlyInsights insights, HouseholdProvider householdProvider) {
    final sorted = insights.categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxAmount =
        sorted.isNotEmpty ? sorted.first.value : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            if (i > 0)
              const Divider(color: AppColors.border, height: 1, indent: 16, endIndent: 16),
            _buildCategoryRow(sorted[i], maxAmount, insights.totalSpent, householdProvider),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(MapEntry<String, double> entry, double maxAmount,
      double totalSpent, HouseholdProvider householdProvider) {
    final category = BillCategories.getById(entry.key);
    final percentage =
        totalSpent > 0 ? (entry.value / totalSpent * 100) : 0.0;
    final barFraction = maxAmount > 0 ? entry.value / maxAmount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(category.icon, size: 16, color: category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                householdProvider.formatAmount(entry.value),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(category.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBreakdown(MonthlyInsights insights,
      Map<int, String> memberNames, HouseholdProvider householdProvider) {
    final sorted = insights.memberSpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxAmount =
        sorted.isNotEmpty ? sorted.first.value : 1.0;

    const memberColors = [
      AppColors.primary,
      AppColors.secondary,
      Color(0xFF8B5CF6), // purple
      AppColors.positive,
      AppColors.accent,
      AppColors.negative,
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            if (i > 0)
              const Divider(color: AppColors.border, height: 1, indent: 16, endIndent: 16),
            _buildMemberRow(
              sorted[i],
              memberNames[sorted[i].key] ?? 'Unknown',
              memberColors[i % memberColors.length],
              maxAmount,
              householdProvider,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberRow(MapEntry<int, double> entry, String name, Color color,
      double maxAmount, HouseholdProvider householdProvider) {
    final barFraction = maxAmount > 0 ? entry.value / maxAmount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                householdProvider.formatAmount(entry.value),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.xs),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 6,
              backgroundColor: AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
