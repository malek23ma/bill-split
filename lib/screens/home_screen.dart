import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../widgets/balance_card.dart';
import '../widgets/bill_list_tile.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final householdProvider = context.watch<HouseholdProvider>();
    final billProvider = context.watch<BillProvider>();

    final currentMember = householdProvider.currentMember;
    final members = householdProvider.members;
    final otherMember = members
        .where((m) => m.id != currentMember?.id)
        .firstOrNull;

    final currentBalance =
        billProvider.memberBalances[currentMember?.id] ?? 0.0;

    final summary = billProvider.monthlySummary;

    return Scaffold(
      appBar: AppBar(
        title: Text(householdProvider.currentHousehold?.name ?? 'Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/', (route) => false);
            },
            child: Text(
              currentMember?.name ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Balance card with settle up
          BalanceCard(
            currentMemberName: currentMember?.name ?? '',
            otherMemberName: otherMember?.name ?? '',
            balanceAmount: currentBalance,
            onSettleUp: currentBalance.abs() > 0.01
                ? () => _confirmSettleUp(
                      context,
                      householdProvider,
                      billProvider,
                      currentBalance,
                      currentMember?.id,
                      otherMember?.id,
                      otherMember?.name ?? '',
                    )
                : null,
          ),

          // Monthly summary
          if (summary != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                child: summary.billCount > 0
                    ? ExpansionTile(
                        leading: const Icon(Icons.calendar_month, size: 20),
                        title: Text(
                          summary.monthLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${summary.billCount} bills — ${summary.memberSpend.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)} TL total',
                          style: const TextStyle(fontSize: 12),
                        ),
                        initiallyExpanded: true,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            child: Column(
                              children: members.map((m) {
                                final spent =
                                    summary.memberSpend[m.id] ?? 0.0;
                                return Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(m.name),
                                      Text(
                                        '${spent.toStringAsFixed(2)} TL',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      )
                    : ListTile(
                        leading: const Icon(Icons.calendar_month, size: 20),
                        title: Text(
                          summary.monthLabel,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'No bills this month yet',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
              ),
            ),

          // Bills header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  'Bills',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const Spacer(),
                Text(
                  '${billProvider.bills.length} total',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Bills list with swipe to delete
          Expanded(
            child: billProvider.bills.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long,
                            size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'No bills yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap + to add your first bill',
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
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
                          color: Colors.red,
                          child: const Icon(Icons.delete,
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
        icon: const Icon(Icons.add),
        label: const Text('Add Bill'),
      ),
    );
  }

  void _confirmSettleUp(
    BuildContext context,
    HouseholdProvider householdProvider,
    BillProvider billProvider,
    double currentBalance,
    int? currentMemberId,
    int? otherMemberId,
    String otherName,
  ) {
    final amount = currentBalance.abs();
    final whoOwes = currentBalance < 0 ? 'You' : otherName;
    final payerId = currentBalance < 0 ? currentMemberId! : otherMemberId!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.handshake, size: 32),
        title: const Text('Settle Up?'),
        content: Text(
          '$whoOwes owes ${amount.toStringAsFixed(2)} TL',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _showPartialSettleDialog(
                context,
                householdProvider,
                billProvider,
                amount,
                payerId,
              );
            },
            child: const Text('Partial Amount'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await billProvider.settleUp(
                householdId: householdProvider.currentHousehold!.id!,
                payerMemberId: payerId,
                amount: amount,
              );
            },
            child: const Text('Settle All'),
          ),
        ],
      ),
    );
  }

  void _showPartialSettleDialog(
    BuildContext context,
    HouseholdProvider householdProvider,
    BillProvider billProvider,
    double totalOwed,
    int payerId,
  ) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Partial Settlement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total owed: ${totalOwed.toStringAsFixed(2)} TL',
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount paid',
                border: OutlineInputBorder(),
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
                amount: partial,
              );
            },
            child: const Text('Settle'),
          ),
        ],
      ),
    );
  }
}
