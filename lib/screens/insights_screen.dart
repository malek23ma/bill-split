import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../models/bill_filter.dart';
import '../models/member.dart';
import '../providers/bill_provider.dart';
import '../providers/household_provider.dart';
import '../widgets/filtered_results_sheet.dart';
import '../constants.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  late int _year;
  late int _month;
  int _trendMonths = 6;

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
            fontSize: AppScale.fontSize(20),
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
        padding: EdgeInsets.all(AppScale.padding(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month selector
            _buildMonthSelector(oldestDate, isDark),
            SizedBox(height: AppScale.size(20)),

            // Total spent card
            _buildTotalSpentCard(insights, householdProvider, isDark),
            SizedBox(height: AppScale.size(24)),

            // By Category section
            if (insights.categorySpend.isNotEmpty) ...[
              _buildSectionTitle('By Category', isDark),
              const SizedBox(height: 12),
              _buildCategoryBreakdown(insights, householdProvider, isDark),
              SizedBox(height: AppScale.size(24)),
            ],

            // Spending Trends section
            _buildSectionTitle('Spending Trends', isDark),
            const SizedBox(height: 12),
            _buildSpendingTrends(billProvider, householdProvider, isDark),
            SizedBox(height: AppScale.size(24)),

            // By Member section
            if (insights.memberSpend.isNotEmpty) ...[
              _buildSectionTitle('By Member', isDark),
              const SizedBox(height: 12),
              _buildMemberBreakdown(insights, memberNames, householdProvider, isDark),
            ],

            SizedBox(height: AppScale.size(32)),
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
      padding: EdgeInsets.symmetric(horizontal: AppScale.padding(8), vertical: AppScale.padding(8)),
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
              fontSize: AppScale.fontSize(18),
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
      padding: EdgeInsets.all(AppScale.padding(24)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          Container(
            width: AppScale.size(40),
            height: AppScale.size(40),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              size: AppScale.size(20),
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Total Spent',
            style: TextStyle(
              fontSize: AppScale.fontSize(14),
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            householdProvider.formatAmount(insights.totalSpent),
            style: TextStyle(
              fontSize: AppScale.fontSize(32),
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${insights.billCount} bill${insights.billCount == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: AppScale.fontSize(14),
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
        fontSize: AppScale.fontSize(16),
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
      ),
    );
  }

  void _showCategoryDrillDown(String categoryId) {
    final billProvider = context.read<BillProvider>();
    final householdProvider = context.read<HouseholdProvider>();
    final members = householdProvider.members;
    final currencySymbol = AppCurrency.getByCode(householdProvider.currency).symbol;

    final filteredBills = billProvider.bills.where((b) =>
        b.category == categoryId &&
        b.billDate.year == _year &&
        b.billDate.month == _month &&
        b.billType != 'settlement').toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => FilteredResultsSheet(
          scrollController: scrollCtrl,
          filteredBills: filteredBills,
          filter: BillFilter(category: categoryId),
          members: members,
          currencySymbol: currencySymbol,
          onBillTap: (bill) {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/bill-detail', arguments: bill);
          },
          onClearFilters: () {},
        ),
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
            GestureDetector(
              onTap: () => _showCategoryDrillDown(sorted[i].key),
              child: _buildCategoryRow(sorted[i], maxAmount, insights.totalSpent, householdProvider, isDark),
            ),
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
      padding: EdgeInsets.symmetric(horizontal: AppScale.padding(16), vertical: AppScale.padding(14)),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: AppScale.size(36),
                height: AppScale.size(36),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(category.icon, size: AppScale.size(18), color: category.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  category.label,
                  style: TextStyle(
                    fontSize: AppScale.fontSize(15),
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                '${percentage.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: AppScale.fontSize(13),
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                householdProvider.formatAmount(entry.value),
                style: TextStyle(
                  fontSize: AppScale.fontSize(15),
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
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

    final totalSpent = insights.totalSpent > 0 ? insights.totalSpent : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: EdgeInsets.all(AppScale.padding(16)),
      child: Column(
        children: [
          // Stacked bar showing proportional spend
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (int i = 0; i < sorted.length; i++)
                    Expanded(
                      flex: (sorted[i].value / totalSpent * 1000).round().clamp(1, 1000),
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.memberColor(i),
                          // Add small gap between segments
                          border: i < sorted.length - 1
                              ? Border(right: BorderSide(
                                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                                  width: 2,
                                ))
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: AppScale.size(16)),
          // Member legend with amounts and percentages
          for (int i = 0; i < sorted.length; i++) ...[
            if (i > 0) SizedBox(height: 10),
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: AppColors.memberColor(i),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    memberNames[sorted[i].key] ?? 'Unknown',
                    style: TextStyle(
                      fontSize: AppScale.fontSize(15),
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ),
                Text(
                  '${(sorted[i].value / totalSpent * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: AppScale.fontSize(13),
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  householdProvider.formatAmount(sorted[i].value),
                  style: TextStyle(
                    fontSize: AppScale.fontSize(15),
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpendingTrends(
      BillProvider billProvider, HouseholdProvider householdProvider, bool isDark) {
    const monthAbbr = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    // Collect totals for each month going backward
    final totals = <double>[];
    final labels = <String>[];
    int y = _year;
    int m = _month;
    for (int i = 0; i < _trendMonths; i++) {
      final insights = billProvider.getInsightsForMonth(y, m);
      totals.insert(0, insights.totalSpent);
      labels.insert(0, monthAbbr[m - 1]);
      m--;
      if (m < 1) {
        m = 12;
        y--;
      }
    }

    final maxTotal = totals.fold<double>(0, (a, b) => a > b ? a : b);
    const barAreaHeight = 200.0;

    return Container(
      padding: EdgeInsets.all(AppScale.padding(16)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          // Segmented button
          SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 3, label: Text('3M')),
                ButtonSegment(value: 6, label: Text('6M')),
                ButtonSegment(value: 9, label: Text('9M')),
                ButtonSegment(value: 12, label: Text('12M')),
              ],
              selected: {_trendMonths},
              onSelectionChanged: (val) {
                setState(() => _trendMonths = val.first);
              },
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          SizedBox(height: AppScale.size(16)),
          // Bar chart
          SizedBox(
            height: barAreaHeight + 40, // extra for labels
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (int i = 0; i < totals.length; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          totals[i] > 0
                              ? householdProvider.formatAmount(totals[i])
                              : '',
                          style: TextStyle(
                            fontSize: AppScale.fontSize(10),
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textTertiary,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Container(
                          height: maxTotal > 0
                              ? (totals[i] / maxTotal * barAreaHeight)
                                  .clamp(4.0, barAreaHeight)
                              : 4.0,
                          decoration: BoxDecoration(
                            color: i == totals.length - 1
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkSurfaceVariant
                                    : AppColors.surfaceMuted),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: AppScale.fontSize(11),
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
