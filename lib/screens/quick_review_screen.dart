import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../services/receipt_parser.dart';
import '../constants.dart';

class QuickReviewScreen extends StatefulWidget {
  const QuickReviewScreen({super.key});

  @override
  State<QuickReviewScreen> createState() => _QuickReviewScreenState();
}

class _QuickReviewScreenState extends State<QuickReviewScreen> {
  late TextEditingController _totalController;
  late DateTime _billDate;
  late int _paidByMemberId;
  late String _photoPath;
  String _category = 'other';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final args =
          ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
      final parsed = args['parsed'] as ParsedReceipt;
      _photoPath = args['photoPath'] as String;

      _totalController =
          TextEditingController(text: parsed.total.toStringAsFixed(2));
      _billDate = parsed.date ?? DateTime.now();
      _paidByMemberId =
          context.read<HouseholdProvider>().currentMember!.id!;
      _category = parsed.category;

      _initialized = true;
    }
  }

  @override
  void dispose() {
    _totalController.dispose();
    super.dispose();
  }

  double get _total {
    return double.tryParse(
            _totalController.text.trim().replaceAll(',', '.')) ??
        0.0;
  }

  Future<void> _saveBill() async {
    final total = _total;
    if (total <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid total')),
      );
      return;
    }

    final householdProvider = context.read<HouseholdProvider>();
    final billProvider = context.read<BillProvider>();

    final bill = Bill(
      householdId: householdProvider.currentHousehold!.id!,
      enteredByMemberId: householdProvider.currentMember!.id!,
      paidByMemberId: _paidByMemberId,
      billType: 'quick',
      totalAmount: total,
      billDate: _billDate,
      category: _category,
    );

    await billProvider.saveBill(
      bill: bill,
      items: <BillItem>[],
      tempPhotoPath: _photoPath,
    );

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final householdProvider = context.watch<HouseholdProvider>();
    final members = householdProvider.members;
    final otherMember =
        members.where((m) => m.id != _paidByMemberId).firstOrNull;
    final half = _total / 2;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Bill'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date picker
            OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _billDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                );
                if (picked != null) {
                  setState(() => _billDate = picked);
                }
              },
              icon: const Icon(Icons.calendar_today, size: 18),
              label: Text(DateFormat('dd/MM/yyyy').format(_billDate)),
            ),
            const SizedBox(height: 16),

            // Payer dropdown
            DropdownButtonFormField<int>(
              initialValue: _paidByMemberId,
              decoration: const InputDecoration(
                labelText: 'Paid by',
                border: OutlineInputBorder(),
              ),
              items: members
                  .map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.name),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _paidByMemberId = value);
                }
              },
            ),
            const SizedBox(height: 16),

            // Category selector
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: BillCategories.list.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final cat = BillCategories.list[index];
                  final isSelected = _category == cat.id;
                  return FilterChip(
                    label: Text(cat.label, style: const TextStyle(fontSize: 12)),
                    avatar: Icon(cat.icon, size: 16, color: isSelected ? null : cat.color),
                    selected: isSelected,
                    onSelected: (_) => setState(() => _category = cat.id),
                    showCheckmark: false,
                    visualDensity: VisualDensity.compact,
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // Total input
            TextField(
              controller: _totalController,
              decoration: const InputDecoration(
                labelText: 'Total Amount (TL)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              style:
                  const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),

            // Split preview
            Card(
              color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Split 50/50',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(members.isNotEmpty ? members[0].name : ''),
                        Text(
                          '${half.toStringAsFixed(2)} TL',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(members.length > 1 ? members[1].name : ''),
                        Text(
                          '${half.toStringAsFixed(2)} TL',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            if (otherMember != null)
              Text(
                '${otherMember.name} owes ${half.toStringAsFixed(2)} TL',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),

            const Spacer(),

            // Save button
            SizedBox(
              height: 48,
              child: FilledButton(
                onPressed: _saveBill,
                child:
                    const Text('Save Bill', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
