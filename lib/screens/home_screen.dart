import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../models/member.dart';
import '../providers/recurring_bill_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/bill_list_tile.dart';
import '../widgets/filter_bottom_sheet.dart';
import '../widgets/filtered_results_sheet.dart';
import '../widgets/scale_tap.dart';
import '../constants.dart';
import 'insights_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentTab = 0;
  bool _recurringLoaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_recurringLoaded) {
      _recurringLoaded = true;
      final householdId =
          context.read<HouseholdProvider>().currentHousehold?.id;
      if (householdId != null) {
        context.read<RecurringBillProvider>().loadDueBills(householdId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdProvider = context.watch<HouseholdProvider>();
    final billProvider = context.watch<BillProvider>();
    final currentMember = householdProvider.currentMember;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: _currentTab == 0
          ? AppBar(
              backgroundColor:
                  isDark ? AppColors.darkBackground : AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: Text(
                householdProvider.currentHousehold?.name ?? 'Home',
                style: TextStyle(
                  color:
                      isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              actions: [
                IconButton(
                  icon: Icon(Icons.filter_list_rounded,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                  onPressed: () => _showFilterSheet(context),
                  tooltip: 'Filter',
                ),
                IconButton(
                  icon: Icon(Icons.settings_outlined,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                  onPressed: () => Navigator.pushNamed(context, '/settings'),
                  tooltip: 'Settings',
                ),
                IconButton(
                  icon: Icon(Icons.person_outline_rounded,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                        context, '/', (route) => false);
                  },
                  tooltip: currentMember?.name ?? 'Logout',
                ),
                const SizedBox(width: 4),
              ],
            )
          : null,
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildBillsTab(householdProvider, billProvider),
          const InsightsScreen(),
        ],
      ),
      floatingActionButton: _currentTab == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.pushNamed(context, '/bill-type');
              },
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: const Icon(Icons.add_rounded, size: 28),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (i) => setState(() => _currentTab = i),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        indicatorColor: isDark ? AppColors.primary.withAlpha(40) : AppColors.primarySurface,
        elevation: 0,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.receipt_long_rounded), label: 'Bills'),
          NavigationDestination(
              icon: Icon(Icons.bar_chart_rounded), label: 'Insights'),
        ],
      ),
    );
  }

  Widget _buildBillsTab(
      HouseholdProvider householdProvider, BillProvider billProvider) {
    final currentMember = householdProvider.currentMember;
    final members = householdProvider.members;
    final memberNames = {
      for (final m in members) m.id!: m.name,
    };
    final currencySymbol =
        AppCurrency.getByCode(householdProvider.currency).symbol;

    final recurringProvider = context.watch<RecurringBillProvider>();
    final dueBills = recurringProvider.dueBills;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 88),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Recurring bills due banner
        if (dueBills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              children: dueBills.map((recurring) {
                final cat = BillCategories.getById(recurring.category);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ScaleTap(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.accentSurface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color:
                                    AppColors.accent.withValues(alpha: 0.10),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(
                                Icons.repeat_rounded,
                                size: 20,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    recurring.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${recurring.amount.toStringAsFixed(2)} $currencySymbol \u2022 ${cat.label}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            FilledButton(
                              onPressed: () async {
                                final householdId =
                                    householdProvider.currentHousehold?.id;
                                final memberId = currentMember?.id;
                                if (householdId == null || memberId == null) {
                                  return;
                                }
                                await recurringProvider.confirmBill(
                                  recurring,
                                  billProvider,
                                  householdId,
                                  memberId,
                                );
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            TextButton(
                              onPressed: () async {
                                final householdId =
                                    householdProvider.currentHousehold?.id;
                                if (householdId == null) return;
                                await recurringProvider.dismissBill(
                                  recurring,
                                  householdId,
                                );
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textTertiary,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 8),
                                minimumSize: Size.zero,
                              ),
                              child: const Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

        // Balance card with settle up
        BalanceCard(
          currentMemberId: currentMember?.id ?? 0,
          memberBalances: billProvider.memberBalances,
          pairwiseBalances: billProvider.pairwiseBalances,
          memberNames: memberNames,
          currencySymbol: currencySymbol,
          onSettleUp: (otherMemberId, amount) => _confirmSettleUp(
            context,
            householdProvider,
            billProvider,
            otherMemberId,
            amount,
            memberNames[otherMemberId] ?? 'Unknown',
          ),
        ),

        // Quick stats row
        if (billProvider.bills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(
              builder: (context) {
                final now = DateTime.now();
                final thisMonthBills = billProvider.bills.where((b) =>
                    b.billDate.year == now.year &&
                    b.billDate.month == now.month &&
                    b.billType != 'settlement').toList();
                final thisMonthTotal = thisMonthBills.fold(0.0, (sum, b) => sum + b.totalAmount);
                final lastBill = billProvider.bills.first;
                final daysSince = DateTime.now().difference(lastBill.billDate).inDays;
                final lastBillText = daysSince == 0
                    ? 'Today'
                    : daysSince == 1
                        ? 'Yesterday'
                        : '$daysSince days ago';

                return IntrinsicHeight(
                  child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // This month total
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'This month',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${thisMonthTotal.toStringAsFixed(2)} $currencySymbol',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Bill count
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bills',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${thisMonthBills.length}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Last bill
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Last bill',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lastBillText,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                );
              },
            ),
          ),

        // Spending pulse
        if (billProvider.bills.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Builder(
              builder: (context) {
                final now = DateTime.now();
                final thisMonthBills = billProvider.bills.where((b) =>
                    b.billDate.year == now.year &&
                    b.billDate.month == now.month &&
                    b.billType != 'settlement').toList();
                final thisMonthTotal = thisMonthBills.fold(0.0, (sum, b) => sum + b.totalAmount);

                final lastMonth = now.month == 1
                    ? DateTime(now.year - 1, 12)
                    : DateTime(now.year, now.month - 1);
                final lastMonthBills = billProvider.bills.where((b) =>
                    b.billDate.year == lastMonth.year &&
                    b.billDate.month == lastMonth.month &&
                    b.billType != 'settlement').toList();
                final lastMonthTotal = lastMonthBills.fold(0.0, (sum, b) => sum + b.totalAmount);

                if (lastMonthTotal < 0.01) return const SizedBox.shrink();

                final diff = thisMonthTotal - lastMonthTotal;
                final pct = (diff / lastMonthTotal * 100).abs();
                final isUp = diff > 0;
                final months = [
                  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
                ];
                final lastMonthName = months[lastMonth.month - 1];

                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? (isUp ? AppColors.negative.withAlpha(15) : AppColors.positive.withAlpha(15))
                        : (isUp ? AppColors.negativeSurface : AppColors.positiveSurface),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                        size: 18,
                        color: isUp ? AppColors.negative : AppColors.positive,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${isUp ? '↑' : '↓'} ${pct.toStringAsFixed(0)}% vs $lastMonthName',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isUp ? AppColors.negative : AppColors.positive,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Recent Bills — collapsible
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                childrenPadding: EdgeInsets.zero,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Row(
                  children: [
                    Text(
                      'Recent Bills',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                    ),
                    const SizedBox(width: 8),
                    if (billProvider.bills.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withAlpha(30)
                              : AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${billProvider.bills.length}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                  ],
                ),
                children: [
                  if (billProvider.bills.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceVariant
                                    : AppColors.surfaceVariant,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                size: 32,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No bills yet',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...billProvider.bills.map((bill) {
            final paidBy = members
                .where((m) => m.id == bill.paidByMemberId)
                .firstOrNull;

            return Dismissible(
              key: ValueKey(bill.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                margin: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.negative,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: Colors.white),
              ),
              confirmDismiss: (_) async => true,
              onDismissed: (_) async {
                final messenger = ScaffoldMessenger.of(context);
                final deletedBill = bill;
                final deletedItems = bill.billType == 'full'
                    ? await billProvider.getBillItems(bill.id!)
                    : <dynamic>[];

                await billProvider.deleteBill(
                    bill.id!, bill.householdId);

                messenger.clearSnackBars();
                messenger.showSnackBar(
                  SnackBar(
                    content: const Text('Bill deleted'),
                    duration: const Duration(seconds: 4),
                    action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () {
                        billProvider.reinsertBill(
                          deletedBill,
                          deletedItems.cast(),
                        );
                      },
                    ),
                  ),
                );
              },
              child: BillListTile(
                bill: bill,
                paidByName: paidBy?.name ?? 'Unknown',
                currencySymbol: currencySymbol,
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final result = await Navigator.pushNamed(
                    context,
                    '/bill-detail',
                    arguments: bill.id,
                  );
                  if (result is Map && result['deleted'] == true) {
                    final deletedBill = result['bill'] as Bill;
                    final deletedItems = result['items'] as List<BillItem>;
                    messenger.clearSnackBars();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Bill deleted'),
                        duration: const Duration(seconds: 4),
                        action: SnackBarAction(
                          label: 'UNDO',
                          onPressed: () {
                            billProvider.reinsertBill(deletedBill, deletedItems);
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
            );
          }),
                ],
              ),
            ),
          ),
        ),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    final billProvider = context.read<BillProvider>();
    final householdProvider = context.read<HouseholdProvider>();
    final members = householdProvider.members;
    final currencySymbol = AppCurrency.getByCode(householdProvider.currency).symbol;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FilterBottomSheet(
        currentFilter: billProvider.activeFilter,
        members: members,
        onApply: (filter) async {
          if (filter == null || !filter.hasActiveFilters) {
            billProvider.clearFilter();
            return;
          }
          await billProvider.setFilter(filter);
          if (!context.mounted) return;
          // Show filtered results sheet
          _showFilteredResults(context, billProvider, members, currencySymbol);
        },
      ),
    );
  }

  void _showFilteredResults(BuildContext context, BillProvider billProvider,
      List<Member> members, String currencySymbol) {
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
          filteredBills: billProvider.filteredBills,
          filter: billProvider.activeFilter!,
          members: members,
          currencySymbol: currencySymbol,
          onBillTap: (bill) async {
            final result = await Navigator.pushNamed(context, '/bill-detail', arguments: bill);
            if (result is Map && result['deleted'] == true && context.mounted) {
              final deletedBill = result['bill'] as Bill;
              final deletedItems = result['items'] as List<BillItem>;
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Bill deleted'),
                  duration: const Duration(seconds: 4),
                  action: SnackBarAction(
                    label: 'UNDO',
                    onPressed: () {
                      billProvider.reinsertBill(deletedBill, deletedItems);
                    },
                  ),
                ),
              );
            }
          },
          onClearFilters: () => billProvider.clearFilter(),
        ),
      ),
    ).then((_) {
      // Clear filters when sheet is dismissed
      billProvider.clearFilter();
    });
  }

  void _confirmSettleUp(
    BuildContext context,
    HouseholdProvider householdProvider,
    BillProvider billProvider,
    int otherMemberId,
    double amount,
    String otherName,
  ) {
    final currentMemberId = householdProvider.currentMember!.id!;
    final currSymbol =
        AppCurrency.getByCode(householdProvider.currency).symbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Other member's balance negated tells us who owes whom.
    // Positive amount from BalanceCard means other owes current member.
    final otherBalance = billProvider.memberBalances[otherMemberId] ?? 0.0;
    final otherOwes =
        otherBalance < -0.01; // other has negative balance = they owe
    final whoOwes = otherOwes ? otherName : 'You';
    final payerId = otherOwes ? otherMemberId : currentMemberId;
    final receiverId = otherOwes ? currentMemberId : otherMemberId;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.handshake_outlined,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Settle Up?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$whoOwes owes ${amount.toStringAsFixed(2)} $currSymbol',
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _showPartialSettleDialog(
                          context,
                          householdProvider,
                          billProvider,
                          amount,
                          payerId,
                          receiverId,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: BorderSide(
                            color: isDark
                                ? AppColors.darkDivider
                                : AppColors.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Partial Amount',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await billProvider.settleUp(
                          householdId:
                              householdProvider.currentHousehold!.id!,
                          payerMemberId: payerId,
                          receiverMemberId: receiverId,
                          amount: amount,
                        );
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Settle All',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textTertiary,
                  ),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPartialSettleDialog(
    BuildContext context,
    HouseholdProvider householdProvider,
    BillProvider billProvider,
    double totalOwed,
    int payerId,
    int receiverId,
  ) {
    final controller = TextEditingController();
    final currSymbol =
        AppCurrency.getByCode(householdProvider.currency).symbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Partial Settlement',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color:
                isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total owed: ${totalOwed.toStringAsFixed(2)} $currSymbol',
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Amount paid',
                labelStyle: TextStyle(
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.divider),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.divider),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
                suffixText: currSymbol,
              ),
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.textTertiary,
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final partial = double.tryParse(
                  controller.text.trim().replaceAll(',', '.'));
              if (partial == null ||
                  partial <= 0 ||
                  partial > totalOwed) {
                return;
              }
              Navigator.pop(ctx);
              await billProvider.settleUp(
                householdId: householdProvider.currentHousehold!.id!,
                payerMemberId: payerId,
                receiverMemberId: receiverId,
                amount: partial,
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              elevation: 0,
            ),
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }
}
