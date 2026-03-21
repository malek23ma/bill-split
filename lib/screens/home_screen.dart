import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/recurring_bill_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/bill_list_tile.dart';
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
                  isDark ? AppColors.darkSurface : AppColors.surface,
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
    final summary = billProvider.monthlySummary;
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

        // Monthly summary
        if (summary != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: summary.billCount > 0
                  ? Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        tilePadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        childrenPadding: EdgeInsets.zero,
                        shape: const Border(),
                        collapsedShape: const Border(),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color:
                                AppColors.primary.withValues(alpha: 0.10),
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.calendar_month_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                        ),
                        title: Text(
                          summary.monthLabel,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          '${summary.billCount} bills \u2022 ${summary.memberSpend.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)} $currencySymbol total',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textTertiary,
                          ),
                        ),
                        initiallyExpanded: false,
                        children: [
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              children: [
                                Divider(
                                  color: isDark
                                      ? AppColors.darkDivider
                                      : AppColors.divider,
                                  height: 1,
                                ),
                                const SizedBox(height: 12),
                                ...members.asMap().entries.map((entry) {
                                  final idx = entry.key;
                                  final m = entry.value;
                                  final spent =
                                      summary.memberSpend[m.id] ?? 0.0;
                                  final totalSpend = summary
                                      .memberSpend.values
                                      .fold(0.0, (a, b) => a + b);
                                  final proportion = totalSpend > 0
                                      ? (spent / totalSpend)
                                      : 0.0;
                                  final barColor =
                                      AppColors.memberColor(idx);

                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(bottom: 10),
                                    child: Column(
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment
                                                  .spaceBetween,
                                          children: [
                                            Text(
                                              m.name,
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: isDark
                                                    ? AppColors
                                                        .darkTextSecondary
                                                    : AppColors
                                                        .textSecondary,
                                              ),
                                            ),
                                            Text(
                                              '${spent.toStringAsFixed(2)} $currencySymbol',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: isDark
                                                    ? AppColors
                                                        .darkTextPrimary
                                                    : AppColors.textPrimary,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(
                                                  AppRadius.xs),
                                          child: LinearProgressIndicator(
                                            value: proportion,
                                            minHeight: 6,
                                            backgroundColor: isDark
                                                ? AppColors
                                                    .darkSurfaceVariant
                                                : AppColors.surfaceVariant,
                                            valueColor:
                                                AlwaysStoppedAnimation<
                                                    Color>(barColor),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary
                                  .withValues(alpha: 0.10),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                summary.monthLabel,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.darkTextPrimary
                                      : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'No bills this month yet',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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
                final deletedBill = bill;
                final deletedItems = bill.billType == 'full'
                    ? await billProvider.getBillItems(bill.id!)
                    : <dynamic>[];

                await billProvider.deleteBill(
                    bill.id!, bill.householdId);

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
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
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    '/bill-detail',
                    arguments: bill.id,
                  );
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
