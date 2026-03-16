import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../constants.dart';

class BillListTile extends StatelessWidget {
  final Bill bill;
  final String paidByName;
  final VoidCallback onTap;

  const BillListTile({
    super.key,
    required this.bill,
    required this.paidByName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd/MM/yyyy').format(bill.billDate);
    final isSettlement = bill.billType == 'settlement';

    final category = BillCategories.getById(bill.category);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isSettlement
              ? Colors.green.shade100
              : category.color.withAlpha(30),
          child: Icon(
            isSettlement ? Icons.handshake : category.icon,
            color: isSettlement ? Colors.green.shade700 : category.color,
          ),
        ),
        title: Text(
          isSettlement
              ? 'Settled up'
              : '${bill.totalAmount.toStringAsFixed(2)} TL',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSettlement ? Colors.green : null,
          ),
        ),
        subtitle: Text(isSettlement
            ? '$dateStr • ${bill.totalAmount.toStringAsFixed(2)} TL'
            : '$dateStr • Paid by $paidByName'),
        trailing: isSettlement
            ? null
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: bill.billType == 'quick'
                          ? Colors.orange.shade50
                          : Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      bill.billType == 'quick' ? 'Q' : 'F',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: bill.billType == 'quick'
                            ? Colors.orange.shade700
                            : Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right),
                ],
              ),
        onTap: onTap,
      ),
    );
  }
}
