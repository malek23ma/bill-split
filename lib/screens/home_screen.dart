import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/bill_list_tile.dart';
import '../constants.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final householdProvider = context.watch<HouseholdProvider>();
    final billProvider = context.watch<BillProvider>();

    final currentMember = householdProvider.currentMember;
    final members = householdProvider.members;

    final memberNames = {
      for (final m in members) m.id!: m.name,
    };

    final summary = billProvider.monthlySummary;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          householdProvider.currentHousehold?.name ?? 'Home',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Settings',
          ),
          IconButton(
            icon: const Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/', (route) => false);
            },
            tooltip: currentMember?.name ?? 'Logout',
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: AppColors.border,
            height: 1,
          ),
        ),
      ),
      body: Column(
        children: [
          // Balance card with settle up
          BalanceCard(
            currentMemberId: currentMember?.id ?? 0,
            memberBalances: billProvider.memberBalances,
            memberNames: memberNames,
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
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.border),
                ),
                child: summary.billCount > 0
                    ? Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                          childrenPadding: EdgeInsets.zero,
                          shape: const Border(),
                          collapsedShape: const Border(),
                          leading: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(
                              Icons.calendar_month_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                          ),
                          title: Text(
                            summary.monthLabel,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          subtitle: Text(
                            '${summary.billCount} bills \u2022 ${summary.memberSpend.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)} TL total',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          initiallyExpanded: true,
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: Column(
                                children: [
                                  const Divider(color: AppColors.border, height: 1),
                                  const SizedBox(height: 12),
                                  ...members.map((m) {
                                    final spent =
                                        summary.memberSpend[m.id] ?? 0.0;
                                    final totalSpend = summary.memberSpend.values
                                        .fold(0.0, (a, b) => a + b);
                                    final proportion = totalSpend > 0
                                        ? (spent / totalSpend)
                                        : 0.0;
                                    final memberColors = [
                                      AppColors.primary,
                                      AppColors.secondary,
                                      AppColors.accent,
                                    ];
                                    final colorIndex =
                                        members.toList().indexOf(m) %
                                            memberColors.length;
                                    final barColor =
                                        memberColors[colorIndex];

                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: Column(
                                        children: [
                                          Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                m.name,
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.textSecondary,
                                                ),
                                              ),
                                              Text(
                                                '${spent.toStringAsFixed(2)} TL',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(AppRadius.xs),
                                            child: LinearProgressIndicator(
                                              value: proportion,
                                              minHeight: 6,
                                              backgroundColor:
                                                  AppColors.surfaceVariant,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      barColor),
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
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.sm),
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
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'No bills this month yet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
              ),
            ),

          // Bills header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Text(
                  'Recent Bills',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(width: 8),
                if (billProvider.bills.isNotEmpty)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                    ),
                    child: Text(
                      '${billProvider.bills.length}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Bills list with swipe to delete
          Expanded(
            child: billProvider.bills.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xl),
                            ),
                            child: const Icon(
                              Icons.receipt_long_rounded,
                              size: 40,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No bills yet',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap the button below to add your first bill',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: billProvider.bills.length,
                    itemBuilder: (context, index) {
                      final bill = billProvider.bills[index];
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
                            borderRadius:
                                BorderRadius.circular(AppRadius.lg),
                          ),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white),
                        ),
                        confirmDismiss: (_) async => true,
                        onDismissed: (_) async {
                          // Save for undo
                          final deletedBill = bill;
                          final deletedItems = bill.billType == 'full'
                              ? await billProvider.getBillItems(bill.id!)
                              : <dynamic>[];

                          await billProvider.deleteBill(
                              bill.id!, bill.householdId);

                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context)
                              .clearSnackBars();
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
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              '/bill-detail',
                              arguments: bill.id,
                            );
                          },
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.pushNamed(context, '/bill-type');
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Bill',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppColors.primary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
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
    // Other member's balance negated tells us who owes whom.
    // Positive amount from BalanceCard means other owes current member.
    final otherBalance = billProvider.memberBalances[otherMemberId] ?? 0.0;
    final otherOwes = otherBalance < -0.01; // other has negative balance = they owe
    final whoOwes = otherOwes ? otherName : 'You';
    final payerId = otherOwes ? otherMemberId : currentMemberId;
    final receiverId = otherOwes ? currentMemberId : otherMemberId;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
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
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Icon
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: const Icon(
                  Icons.handshake_outlined,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Settle Up?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$whoOwes owes ${amount.toStringAsFixed(2)} TL',
                style: const TextStyle(
                  fontSize: 15,
                  color: AppColors.textSecondary,
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
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.md),
                        ),
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
                              BorderRadius.circular(AppRadius.md),
                        ),
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

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: const Text(
          'Partial Settlement',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total owed: ${totalOwed.toStringAsFixed(2)} TL',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textTertiary,
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
                labelStyle: const TextStyle(color: AppColors.textTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(
                      color: AppColors.primary, width: 1.5),
                ),
                suffixText: 'TL',
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
              if (partial == null || partial <= 0 || partial > totalOwed) {
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
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }
}
