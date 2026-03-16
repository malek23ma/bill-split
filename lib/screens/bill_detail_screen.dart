import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../database/database_helper.dart';
import '../constants.dart';

class BillDetailScreen extends StatefulWidget {
  const BillDetailScreen({super.key});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  Bill? _bill;
  List<BillItem> _items = [];
  bool _loading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loading) {
      _loadBill();
    }
  }

  Future<void> _loadBill() async {
    final billId = ModalRoute.of(context)!.settings.arguments as int;
    final db = DatabaseHelper.instance;
    final bill = await db.getBill(billId);
    final items = await db.getBillItems(billId);

    if (mounted) {
      setState(() {
        _bill = bill;
        _items = items;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bill Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_bill == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Bill Details')),
        body: const Center(child: Text('Bill not found')),
      );
    }

    final bill = _bill!;
    final members = context.watch<HouseholdProvider>().members;
    final paidBy =
        members.where((m) => m.id == bill.paidByMemberId).firstOrNull;
    final enteredBy =
        members.where((m) => m.id == bill.enteredByMemberId).firstOrNull;
    final dateStr = DateFormat('dd/MM/yyyy').format(bill.billDate);
    final isSettlement = bill.billType == 'settlement';
    final category = BillCategories.getById(bill.category);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _confirmDelete(context, bill),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Bill info header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Category chip
                      if (!isSettlement)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Chip(
                            avatar: Icon(category.icon,
                                size: 18, color: category.color),
                            label: Text(category.label),
                            backgroundColor: category.color.withAlpha(20),
                            side: BorderSide.none,
                          ),
                        ),

                      if (isSettlement)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Chip(
                            avatar: const Icon(Icons.handshake,
                                size: 18, color: Colors.green),
                            label: const Text('Settlement'),
                            backgroundColor: Colors.green.shade50,
                            side: BorderSide.none,
                          ),
                        ),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Date'),
                          Text(dateStr,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (!isSettlement) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Type'),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: bill.billType == 'quick'
                                    ? Colors.orange.shade50
                                    : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                bill.billType == 'quick' ? 'Quick' : 'Full',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: bill.billType == 'quick'
                                      ? Colors.orange.shade700
                                      : Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Paid by'),
                          Text(paidBy?.name ?? 'Unknown',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (!isSettlement) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Entered by'),
                            Text(enteredBy?.name ?? 'Unknown'),
                          ],
                        ),
                      ],
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isSettlement ? 'Amount' : 'Total',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(
                            '${bill.totalAmount.toStringAsFixed(2)} TL',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Items (only for full bills)
            if (bill.billType == 'full' && _items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              ..._items.map((item) {
                final splitLabel = item.splitPercent == 100
                    ? 'Mine'
                    : item.splitPercent == 0
                        ? 'Yours'
                        : 'Split ${item.splitPercent}/${100 - item.splitPercent}';
                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      item.splitPercent == 100
                          ? Icons.person
                          : item.splitPercent == 0
                              ? Icons.person_outline
                              : Icons.handshake_outlined,
                      color: item.splitPercent == 100
                          ? Theme.of(context).colorScheme.tertiary
                          : item.splitPercent == 0
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).colorScheme.primary,
                    ),
                    title: Text(item.name),
                    subtitle: Text(splitLabel),
                    trailing: Text(
                      '${item.price.toStringAsFixed(2)} TL',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Receipt photo
            if (bill.photoPath != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Receipt Photo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(bill.photoPath!),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, Bill bill) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Bill?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context
                  .read<BillProvider>()
                  .deleteBill(bill.id!, bill.householdId);
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
