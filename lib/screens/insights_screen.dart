import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Insights',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.file_download_outlined,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            onPressed: () async {
              final billProvider = context.read<BillProvider>();
              final allMembers = await DatabaseHelper.instance.getAllMembersByHousehold(
                context.read<HouseholdProvider>().currentHousehold!.id!,
              );
              final path = await billProvider.exportFilteredBillsCsv(allMembers);
              if (!context.mounted) return;
              await SharePlus.instance.share(ShareParams(files: [XFile(path)], subject: 'Bill Split Export'));
            },
            tooltip: 'Export',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month selector
            _buildMonthSelector(oldestDate, isDark),
            const SizedBox(height: 20),

            // Total spent card
            _buildTotalSpentCard(insights, householdProvider, isDark),
            const SizedBox(height: 24),

            // By Category section
            if (insights.categorySpend.isNotEmpty) ...[
              _buildSectionTitle('By Category', isDark),
              const SizedBox(height: 12),
              _buildCategoryBreakdown(insights, householdProvider, isDark),
              const SizedBox(height: 24),
            ],

            // By Member section
            if (insights.memberSpend.isNotEmpty) ...[
              _buildSectionTitle('By Member', isDark),
              const SizedBox(height: 12),
              _buildMemberBreakdown(insights, memberNames, householdProvider, isDark),
            ],

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMonthSelector(DateTime? oldestDate, bool isDark) {
    final canBack = _canGoBack(oldestDate);
    final canForward = _canGoForward();
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: canBack
                  ? (isDark ? AppColors.darkSurface : AppColors.primarySurface)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chevron_left_rounded,
                color: canBack
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                    : (isDark ? AppColors.darkDivider : AppColors.divider),
              ),
              onPressed: canBack ? _goToPreviousMonth : null,
            ),
          ),
          Text(
            '${months[_month - 1]} $_year',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: canForward
                  ? (isDark ? AppColors.darkSurface : AppColors.primarySurface)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: IconButton(
              icon: Icon(
                Icons.chevron_right_rounded,
                color: canForward
                    ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                    : (isDark ? AppColors.darkDivider : AppColors.divider),
              ),
              onPressed: canForward ? _goToNextMonth : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSpentCard(
      MonthlyInsights insights, HouseholdProvider householdProvider, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              size: 20,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Total Spent',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            householdProvider.formatAmount(insights.totalSpent),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${insights.billCount} bill${insights.billCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCategoryBreakdown(
      MonthlyInsights insights, HouseholdProvider householdProvider, bool isDark) {
    final sorted = insights.categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxAmount =
        sorted.isNotEmpty ? sorted.first.value : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            if (i > 0)
              Divider(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
            _buildCategoryRow(sorted[i], maxAmount, insights.totalSpent, householdProvider, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildCategoryRow(MapEntry<String, double> entry, double maxAmount,
      double totalSpent, HouseholdProvider householdProvider, bool isDark) {
    final category = BillCategories.getById(entry.key);
    final percentage =
        totalSpent > 0 ? (entry.value / totalSpent * 100) : 0.0;
    final barFraction = maxAmount > 0 ? entry.value / maxAmount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(category.icon, size: 18, color: category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                householdProvider.formatAmount(entry.value),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 8,
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(category.color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberBreakdown(MonthlyInsights insights,
      Map<int, String> memberNames, HouseholdProvider householdProvider, bool isDark) {
    final sorted = insights.memberSpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final maxAmount =
        sorted.isNotEmpty ? sorted.first.value : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          for (int i = 0; i < sorted.length; i++) ...[
            if (i > 0)
              Divider(
                color: isDark ? AppColors.darkDivider : AppColors.divider,
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
            _buildMemberRow(
              sorted[i],
              memberNames[sorted[i].key] ?? 'Unknown',
              AppColors.memberColor(i),
              maxAmount,
              householdProvider,
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberRow(MapEntry<int, double> entry, String name, Color color,
      double maxAmount, HouseholdProvider householdProvider, bool isDark) {
    final barFraction = maxAmount > 0 ? entry.value / maxAmount : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                householdProvider.formatAmount(entry.value),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: barFraction,
              minHeight: 8,
              backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}
