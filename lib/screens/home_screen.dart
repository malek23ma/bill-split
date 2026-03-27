import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/auth_provider.dart';
import '../services/settlement_service.dart';
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
import '../services/notification_service.dart';
import '../services/sync_service.dart';
import '../widgets/settle_all_sheet.dart';
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
        // Load local data immediately, then sync in background
        context.read<BillProvider>().loadBills(householdId);
        context.read<RecurringBillProvider>().loadDueBills(householdId);
        // Sync from cloud, then refresh with any new data
        context.read<SyncService>().sync(householdId).then((_) {
          if (mounted) {
            context.read<BillProvider>().loadBills(householdId);
          }
        });
      }
      // Reload notifications and resubscribe for current user
      final householdRemoteId = context.read<HouseholdProvider>().currentHousehold?.remoteId;
      final notifService = context.read<NotificationService>();
      notifService.loadNotifications(householdId: householdRemoteId);

      // Register handler: when a settlement confirmation arrives in realtime,
      // auto-create the local bill so the balance updates immediately.
      notifService.onSettlementNotification = (notification) {
        _handleSettlementConfirmed(notification);
      };
      notifService.subscribeToRealtime();
    }
  }

  /// Process a realtime "settlement_confirmed" notification:
  /// fetch settlement details, create local bill, refresh balances.
  Future<void> _handleSettlementConfirmed(Map<String, dynamic> notification) async {
    try {
      final data = notification['data'] as Map<String, dynamic>? ?? {};
      final settlementId = data['settlement_id'] as String?;
      if (settlementId == null) return;

      final supabase = Supabase.instance.client;
      final settlement = await supabase
          .from('settlements')
          .select()
          .eq('id', settlementId)
          .single();

      final amount = (settlement['amount'] as num).toDouble();
      final fromRemoteId = settlement['from_member_id'] as String;
      final toRemoteId = settlement['to_member_id'] as String;

      final db = await DatabaseHelper.instance.database;
      final fromRows = await db.query('members',
          where: 'remote_id = ?', whereArgs: [fromRemoteId]);
      final toRows = await db.query('members',
          where: 'remote_id = ?', whereArgs: [toRemoteId]);

      if (fromRows.isNotEmpty && toRows.isNotEmpty && mounted) {
        await context.read<BillProvider>().settleUp(
          householdId: fromRows.first['household_id'] as int,
          payerMemberId: fromRows.first['id'] as int,
          receiverMemberId: toRows.first['id'] as int,
          amount: amount,
        );
      }

      // Mark notification as read
      if (mounted) {
        context.read<NotificationService>().markAsRead(notification['id'] as String);
      }
    } catch (e) {
      debugPrint('Failed to apply confirmed settlement: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdProvider = context.watch<HouseholdProvider>();
    final billProvider = context.watch<BillProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: _currentTab == 0
          ? AppBar(
              backgroundColor:
                  isDark ? AppColors.darkBackground : AppColors.background,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              title: GestureDetector(
                onTap: () => _showHouseholdSwitcher(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      householdProvider.currentHousehold?.name ?? 'Home',
                      style: TextStyle(
                        fontSize: AppScale.fontSize(20),
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
              actions: [
                Builder(
                  builder: (context) {
                    final notificationService = context.watch<NotificationService>();
                    final unread = notificationService.unreadCount;
                    return IconButton(
                      icon: Badge(
                        isLabelVisible: unread > 0,
                        label: Text('$unread', style: const TextStyle(fontSize: 10)),
                        backgroundColor: AppColors.negative,
                        child: Icon(Icons.notifications_outlined,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                      ),
                      onPressed: () => Navigator.pushNamed(context, '/notifications'),
                    );
                  },
                ),
                Builder(
                  builder: (context) {
                    final syncService = context.watch<SyncService>();
                    return AnimatedOpacity(
                      opacity: syncService.syncing ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: AppScale.padding(8)),
                        child: SizedBox(
                          width: AppScale.size(18),
                          height: AppScale.size(18),
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                        ),
                      ),
                    );
                  },
                ),
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
              child: Icon(Icons.add_rounded, size: AppScale.size(28)),
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
      padding: EdgeInsets.only(bottom: AppScale.padding(88)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
        // Recurring bills due banner
        if (dueBills.isNotEmpty)
          Padding(
            padding: EdgeInsets.fromLTRB(AppScale.padding(16), AppScale.padding(8), AppScale.padding(16), AppScale.padding(8)),
            child: Column(
              children: dueBills.map((recurring) {
                final cat = BillCategories.getById(recurring.category);
                return Padding(
                  padding: EdgeInsets.only(bottom: AppScale.padding(8)),
                  child: ScaleTap(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.accentSurface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AppScale.padding(14)),
                        child: Row(
                          children: [
                            Container(
                              width: AppScale.size(40),
                              height: AppScale.size(40),
                              decoration: BoxDecoration(
                                color:
                                    AppColors.accent.withValues(alpha: 0.10),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(
                                Icons.repeat_rounded,
                                size: AppScale.size(20),
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
                                      fontSize: AppScale.fontSize(14),
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
                                      fontSize: AppScale.fontSize(12),
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: AppScale.padding(14), vertical: AppScale.padding(8)),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.full),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Confirm',
                                style: TextStyle(
                                  fontSize: AppScale.fontSize(13),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
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
                                padding: EdgeInsets.symmetric(
                                    horizontal: AppScale.padding(8), vertical: AppScale.padding(8)),
                                minimumSize: Size.zero,
                              ),
                              child: Text(
                                'Skip',
                                style: TextStyle(
                                  fontSize: AppScale.fontSize(13),
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
          key: const ValueKey('balance-card'),
          currentMemberId: currentMember?.id ?? 0,
          memberBalances: billProvider.memberBalances,
          pairwiseBalances: billProvider.pairwiseBalances,
          memberNames: memberNames,
          currencySymbol: currencySymbol,
          isAuthenticated: context.read<AuthProvider>().isAuthenticated,
          onSettleUp: (otherMemberId, amount) => _confirmSettleUp(
            context,
            householdProvider,
            billProvider,
            otherMemberId,
            amount,
            memberNames[otherMemberId] ?? 'Unknown',
          ),
        ),

        // Settle All button
        if (billProvider.pairwiseBalances.values.any(
            (inner) => inner.values.any((v) => v.abs() > 0.01)))
          Padding(
            padding: EdgeInsets.only(
              left: AppScale.padding(16),
              right: AppScale.padding(16),
              top: AppScale.padding(2),
              bottom: AppScale.padding(12),
            ),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showSettleAllSheet(context),
                icon: Icon(Icons.account_balance_wallet_rounded, size: AppScale.size(18),
                    color: AppColors.primary),
                label: Text('Settle All',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    )),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                      color: isDark ? AppColors.darkDivider : AppColors.divider),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg)),
                  padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                ),
              ),
            ),
          ),

        // Quick stats row
        if (billProvider.bills.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppScale.padding(16)),
            child: Builder(
              builder: (context) {
                final thisMonthTotal = billProvider.thisMonthTotal;
                final thisMonthBills = billProvider.thisMonthCount;
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
                        padding: EdgeInsets.all(AppScale.padding(14)),
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
                                fontSize: AppScale.fontSize(11),
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${thisMonthTotal.toStringAsFixed(2)} $currencySymbol',
                              style: TextStyle(
                                fontSize: AppScale.fontSize(16),
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
                        padding: EdgeInsets.all(AppScale.padding(14)),
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
                                fontSize: AppScale.fontSize(11),
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '$thisMonthBills',
                              style: TextStyle(
                                fontSize: AppScale.fontSize(16),
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
                        padding: EdgeInsets.all(AppScale.padding(14)),
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
                                fontSize: AppScale.fontSize(11),
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              lastBillText,
                              style: TextStyle(
                                fontSize: AppScale.fontSize(16),
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
            padding: EdgeInsets.fromLTRB(AppScale.padding(16), AppScale.padding(10), AppScale.padding(16), 0),
            child: Builder(
              builder: (context) {
                final now = DateTime.now();
                final thisMonthTotal = billProvider.thisMonthTotal;
                final lastMonthTotal = billProvider.lastMonthTotal;

                if (lastMonthTotal < 0.01) return const SizedBox.shrink();

                final lastMonth = now.month == 1
                    ? DateTime(now.year - 1, 12)
                    : DateTime(now.year, now.month - 1);

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
                  padding: EdgeInsets.symmetric(horizontal: AppScale.padding(14), vertical: AppScale.padding(10)),
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
                        size: AppScale.size(18),
                        color: isUp ? AppColors.negative : AppColors.positive,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '${isUp ? '↑' : '↓'} ${pct.toStringAsFixed(0)}% vs $lastMonthName',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(13),
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
          padding: EdgeInsets.symmetric(horizontal: AppScale.padding(16)),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                initiallyExpanded: false,
                tilePadding: EdgeInsets.symmetric(horizontal: AppScale.padding(16)),
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
                    SizedBox(width: 8),
                    if (billProvider.bills.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: AppScale.padding(8), vertical: AppScale.padding(2)),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primary.withAlpha(30)
                              : AppColors.primarySurface,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${billProvider.bills.length}',
                          style: TextStyle(
                            fontSize: AppScale.fontSize(12),
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
                      padding: EdgeInsets.all(AppScale.padding(32)),
                      child: Center(
                        child: Column(
                          children: [
                            Container(
                              width: AppScale.size(64),
                              height: AppScale.size(64),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkSurfaceVariant
                                    : AppColors.surfaceVariant,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.lg),
                              ),
                              child: Icon(
                                Icons.receipt_long_rounded,
                                size: AppScale.size(32),
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textTertiary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No bills yet',
                              style: TextStyle(
                                fontSize: AppScale.fontSize(15),
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
                    ...billProvider.bills.take(50).map((bill) {
            final paidBy = members
                .where((m) => m.id == bill.paidByMemberId)
                .firstOrNull;
            final canDelete = currentMember != null &&
                (bill.paidByMemberId == currentMember.id || currentMember.isAdmin);

            return Dismissible(
              key: ValueKey(bill.id),
              direction: canDelete
                  ? DismissDirection.endToStart
                  : DismissDirection.none,
              background: Container(
                alignment: Alignment.centerRight,
                padding: EdgeInsets.only(right: AppScale.padding(24)),
                margin: EdgeInsets.symmetric(
                    horizontal: AppScale.padding(16), vertical: AppScale.padding(4)),
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
                final authProvider = context.read<AuthProvider>();
                final deletedBill = bill;
                final deletedItems = bill.billType == 'full'
                    ? await billProvider.getBillItems(bill.id!)
                    : <dynamic>[];

                await billProvider.deleteBill(
                    bill.id!, bill.householdId);

                // Send notification if admin deleted another member's bill
                if (authProvider.isAuthenticated &&
                    currentMember != null &&
                    currentMember.isAdmin &&
                    bill.paidByMemberId != currentMember.id) {
                  try {
                    final supabase = Supabase.instance.client;
                    final notificationService = NotificationService(supabase);
                    final db = await DatabaseHelper.instance.database;

                    // Look up household remote_id
                    final householdRows = await db.query('households',
                        where: 'id = ?',
                        whereArgs: [bill.householdId]);
                    final rawRemoteId =
                        householdRows.firstOrNull?['remote_id'] as String?;
                    final householdRemoteId =
                        (rawRemoteId != null && rawRemoteId.length > 8) ? rawRemoteId : null;

                    final payerRows = await db.query('members',
                        where: 'id = ?',
                        whereArgs: [bill.paidByMemberId]);
                    final rawPayerRemoteId =
                        payerRows.firstOrNull?['remote_id'] as String?;
                    final payerRemoteId =
                        (rawPayerRemoteId != null && rawPayerRemoteId.length > 8) ? rawPayerRemoteId : null;
                    if (payerRemoteId != null) {
                      final memberData = await supabase
                          .from('members')
                          .select('user_id')
                          .eq('id', payerRemoteId)
                          .maybeSingle();
                      if (memberData != null &&
                          memberData['user_id'] != null) {
                        final cat =
                            BillCategories.getById(bill.category);
                        await notificationService.sendNotification(
                          householdId: householdRemoteId,
                          recipientUserId:
                              memberData['user_id'] as String,
                          type: 'admin_bill_delete',
                          title: 'Bill Deleted',
                          body:
                              'Admin deleted your bill: ${cat.label} (${bill.totalAmount.toStringAsFixed(2)})',
                          data: {
                            'bill_category': bill.category,
                            'bill_amount': bill.totalAmount,
                          },
                        );
                      }
                    }
                  } catch (e) {
                    debugPrint(
                        'Failed to send admin delete notification: $e');
                  }
                }

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

  void _showHouseholdSwitcher(BuildContext context) async {
    final householdProvider = context.read<HouseholdProvider>();
    final billProvider = context.read<BillProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser == null) return;

    await householdProvider.loadHouseholds();
    final userHouseholds = householdProvider.households;
    if (!mounted) return;

    showModalBottomSheet(
      // ignore: use_build_context_synchronously
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.all(AppScale.padding(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: AppScale.size(16)),
              Text('Switch Household',
                style: TextStyle(
                  fontSize: AppScale.fontSize(18),
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
              SizedBox(height: AppScale.size(12)),
              ...userHouseholds.map((h) => ListTile(
                leading: Icon(
                  h.id == householdProvider.currentHousehold?.id
                      ? Icons.home_rounded
                      : Icons.home_outlined,
                  color: h.id == householdProvider.currentHousehold?.id
                      ? AppColors.primary
                      : (isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
                ),
                title: Text(h.name,
                  style: TextStyle(
                    fontWeight: h.id == householdProvider.currentHousehold?.id
                        ? FontWeight.w700 : FontWeight.w500,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                trailing: h.id == householdProvider.currentHousehold?.id
                    ? Icon(Icons.check_rounded, color: AppColors.primary)
                    : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (h.id == householdProvider.currentHousehold?.id) return;
                  await householdProvider.setCurrentHousehold(h);
                  final member = await householdProvider.resolveCurrentMember(authUser.id);
                  if (member != null) {
                    billProvider.loadBills(h.id!);
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setInt('last_household_id', h.id!);
                  }
                },
              )),
              SizedBox(height: AppScale.size(8)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettleAllSheet(BuildContext context) {
    final billProvider = context.read<BillProvider>();
    final householdProvider = context.read<HouseholdProvider>();
    final memberNames = {
      for (final m in householdProvider.members) m.id!: m.name,
    };
    final currencySymbol = AppCurrency.getByCode(householdProvider.currency).symbol;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (_, scrollController) => SettleAllSheet(
          optimized: billProvider.computeOptimalSettlements(),
          rawDebts: billProvider.getRawPairwiseDebts(),
          memberNames: memberNames,
          currencySymbol: currencySymbol,
          onSettle: (fromId, toId, amount) async {
            Navigator.pop(context);
            final isAuthenticated =
                context.read<AuthProvider>().isAuthenticated;
            if (isAuthenticated) {
              final members = householdProvider.members;
              final payerMember =
                  members.where((m) => m.id == fromId).firstOrNull;
              final receiverMember =
                  members.where((m) => m.id == toId).firstOrNull;
              await _createPendingSettlement(
                context,
                householdProvider,
                payerMember,
                receiverMember,
                amount,
              );
            } else {
              await billProvider.settleUp(
                householdId: householdProvider.currentHousehold!.id!,
                payerMemberId: fromId,
                receiverMemberId: toId,
                amount: amount,
              );
            }
          },
        ),
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
    final isAuthenticated = context.read<AuthProvider>().isAuthenticated;
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

    // Resolve member objects for remote IDs (needed for authenticated flow)
    final members = householdProvider.members;
    final payerMember = members.where((m) => m.id == payerId).firstOrNull;
    final receiverMember =
        members.where((m) => m.id == receiverId).firstOrNull;
    final payerName =
        payerMember?.name ?? (otherOwes ? otherName : 'You');
    final receiverName =
        receiverMember?.name ?? (otherOwes ? 'You' : otherName);

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppScale.padding(24), AppScale.padding(8), AppScale.padding(24), AppScale.padding(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: AppScale.size(40),
                height: 4,
                margin: EdgeInsets.only(bottom: AppScale.padding(20)),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icon
              Container(
                width: AppScale.size(56),
                height: AppScale.size(56),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.handshake_outlined,
                  size: AppScale.size(28),
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isAuthenticated
                    ? (payerId == currentMemberId ? 'Send Settlement Request?' : 'Request Payment?')
                    : 'Settle Up?',
                style: TextStyle(
                  fontSize: AppScale.fontSize(20),
                  fontWeight: FontWeight.w800,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isAuthenticated
                    ? (payerId == currentMemberId
                        ? 'Send settlement of ${amount.toStringAsFixed(2)} $currSymbol to $receiverName?'
                        : 'Request ${amount.toStringAsFixed(2)} $currSymbol from $payerName?')
                    : '$whoOwes owes ${amount.toStringAsFixed(2)} $currSymbol',
                style: TextStyle(
                  fontSize: AppScale.fontSize(15),
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppScale.size(24)),
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
                        padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
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
                        if (isAuthenticated) {
                          await _createPendingSettlement(
                            context,
                            householdProvider,
                            payerMember,
                            receiverMember,
                            amount,
                          );
                        } else {
                          await billProvider.settleUp(
                            householdId:
                                householdProvider.currentHousehold!.id!,
                            payerMemberId: payerId,
                            receiverMemberId: receiverId,
                            amount: amount,
                          );
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        isAuthenticated ? 'Send Request' : 'Settle All',
                        style: const TextStyle(fontWeight: FontWeight.w600),
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

  Future<void> _createPendingSettlement(
    BuildContext context,
    HouseholdProvider householdProvider,
    Member? payerMember,
    Member? receiverMember,
    double amount,
  ) async {
    final supabaseClient = Supabase.instance.client;
    final settlementService = SettlementService(supabaseClient);
    final notificationService = NotificationService(supabaseClient);

    var householdRemoteId = householdProvider.currentHousehold?.remoteId;
    var payerRemoteId = payerMember?.remoteId;
    var receiverRemoteId = receiverMember?.remoteId;

    // Auto-sync household and members to cloud if not yet synced
    if (householdRemoteId == null || payerRemoteId == null || receiverRemoteId == null) {
      try {
        final db = await DatabaseHelper.instance.database;
        final uuid = const Uuid();

        // Sync household
        if (householdRemoteId == null && householdProvider.currentHousehold != null) {
          final hId = uuid.v4();
          await supabaseClient.from('households').upsert({
            'id': hId,
            'name': householdProvider.currentHousehold!.name,
            'currency': householdProvider.currency,
          });
          await db.update('households', {'remote_id': hId},
              where: 'id = ?', whereArgs: [householdProvider.currentHousehold!.id]);
          householdRemoteId = hId;
        }

        // Sync all members in this household
        for (final m in householdProvider.members) {
          if (m.remoteId == null && householdRemoteId != null) {
            final mId = uuid.v4();
            await supabaseClient.from('members').upsert({
              'id': mId,
              'household_id': householdRemoteId,
              'name': m.name,
              'is_active': m.isActive,
              'is_admin': m.isAdmin,
            });
            await db.update('members', {'remote_id': mId},
                where: 'id = ?', whereArgs: [m.id]);
            if (m.id == payerMember?.id) payerRemoteId = mId;
            if (m.id == receiverMember?.id) receiverRemoteId = mId;
          }
        }

        // Reload members to pick up remote_ids
        await householdProvider.setCurrentHousehold(householdProvider.currentHousehold!);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to sync data to cloud: $e')),
          );
        }
        return;
      }
    }

    if (householdRemoteId == null || payerRemoteId == null || receiverRemoteId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to sync members to cloud')),
        );
      }
      return;
    }

    try {
      final settlement = await settlementService.createSettlement(
        householdId: householdRemoteId,
        fromMemberId: payerRemoteId,
        toMemberId: receiverRemoteId,
        amount: amount,
      );

      // Determine who to notify — the OTHER person (not the current user)
      final currentMemberId = householdProvider.currentMember?.id;
      final isCurrentUserPayer = currentMemberId == payerMember?.id;

      // Notify the other party
      final otherMemberRemoteId = isCurrentUserPayer ? receiverRemoteId : payerRemoteId;
      final otherData = await supabaseClient
          .from('members')
          .select('user_id')
          .eq('id', otherMemberRemoteId)
          .maybeSingle();
      final otherUserId = otherData?['user_id'] as String?;

      if (otherUserId != null) {
        final String notifTitle;
        final String notifBody;
        if (isCurrentUserPayer) {
          notifTitle = 'Settlement Request';
          notifBody = '${payerMember?.name ?? 'Someone'} wants to settle ${amount.toStringAsFixed(2)} with you';
        } else {
          notifTitle = 'Payment Request';
          notifBody = '${receiverMember?.name ?? 'Someone'} is requesting ${amount.toStringAsFixed(2)} from you';
        }
        await notificationService.sendNotification(
          householdId: householdRemoteId,
          recipientUserId: otherUserId,
          type: 'settlement_request',
          title: notifTitle,
          body: notifBody,
          data: {
            'settlement_id': settlement['id'],
            'amount': amount,
          },
        );
      }

      // Don't create local settlement bill yet — balance only changes
      // when the other party confirms the settlement request.

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Settlement request sent — awaiting confirmation')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send settlement request: $e')),
        );
      }
    }
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
                fontSize: AppScale.fontSize(13),
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
              style: TextStyle(
                  fontSize: AppScale.fontSize(20), fontWeight: FontWeight.bold),
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
              final isAuthenticated =
                  context.read<AuthProvider>().isAuthenticated;
              if (isAuthenticated) {
                final members = householdProvider.members;
                final payerMember =
                    members.where((m) => m.id == payerId).firstOrNull;
                final receiverMember =
                    members.where((m) => m.id == receiverId).firstOrNull;
                await _createPendingSettlement(
                  context,
                  householdProvider,
                  payerMember,
                  receiverMember,
                  partial,
                );
              } else {
                await billProvider.settleUp(
                  householdId: householdProvider.currentHousehold!.id!,
                  payerMemberId: payerId,
                  receiverMemberId: receiverId,
                  amount: partial,
                );
              }
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
