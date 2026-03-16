import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../services/receipt_parser.dart';
import '../widgets/item_row.dart';
import '../constants.dart';

class ItemReviewScreen extends StatefulWidget {
  const ItemReviewScreen({super.key});

  @override
  State<ItemReviewScreen> createState() => _ItemReviewScreenState();
}

class _ItemReviewScreenState extends State<ItemReviewScreen> {
  late List<_EditableItem> _items;
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

      _items = parsed.items
          .map((item) => _EditableItem(
                name: item.name,
                price: item.price,
                isIncluded: true,
                splitPercent: 50,
              ))
          .toList();

      _billDate = parsed.date ?? DateTime.now();
      _paidByMemberId =
          context.read<HouseholdProvider>().currentMember!.id!;
      _category = parsed.category;

      _initialized = true;
    }
  }

  double get _totalAmount {
    return _items.fold(0.0, (sum, item) => sum + item.price);
  }

  double get _splitAmount {
    double amount = 0;
    for (final item in _items) {
      if (item.isIncluded) {
        amount += item.price * (100 - item.splitPercent) / 100;
      }
    }
    return amount;
  }

  Future<void> _saveBill() async {
    final householdProvider = context.read<HouseholdProvider>();
    final billProvider = context.read<BillProvider>();

    final bill = Bill(
      householdId: householdProvider.currentHousehold!.id!,
      enteredByMemberId: householdProvider.currentMember!.id!,
      paidByMemberId: _paidByMemberId,
      billType: 'full',
      totalAmount: _totalAmount,
      billDate: _billDate,
      category: _category,
    );

    final billItems = _items
        .map((item) => BillItem(
              billId: 0,
              name: item.name,
              price: item.price,
              isIncluded: item.isIncluded,
              splitPercent: item.splitPercent,
            ))
        .toList();

    await billProvider.saveBill(
      bill: bill,
      items: billItems,
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Items'),
      ),
      body: Column(
        children: [
          // Date and payer row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _billDate,
                        firstDate: DateTime(2020),
                        lastDate:
                            DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setState(() => _billDate = picked);
                      }
                    },
                    icon: const Icon(Icons.calendar_today, size: 18),
                    label: Text(DateFormat('dd/MM/yyyy').format(_billDate)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _paidByMemberId,
                    decoration: const InputDecoration(
                      labelText: 'Paid by',
                      border: OutlineInputBorder(),
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                ),
              ],
            ),
          ),

          // Category selector
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
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
          const SizedBox(height: 4),

          // Items list
          Expanded(
            child: _items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.warning_amber,
                            size: 48, color: Colors.orange.shade400),
                        const SizedBox(height: 12),
                        const Text('No items detected from the receipt'),
                        const SizedBox(height: 8),
                        FilledButton.icon(
                          onPressed: _addManualItem,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Item Manually'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: OutlinedButton.icon(
                            onPressed: _addManualItem,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Item'),
                          ),
                        );
                      }
                      final item = _items[index];
                      return Dismissible(
                        key: ValueKey(index),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          setState(() => _items.removeAt(index));
                        },
                        child: ItemRow(
                          name: item.name,
                          price: item.price,
                          isIncluded: item.isIncluded,
                          splitPercent: item.splitPercent,
                          onIncludedChanged: (value) {
                            setState(
                                () => item.isIncluded = value ?? true);
                          },
                          onSplitChanged: (value) {
                            setState(() => item.splitPercent = value);
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Bottom summary
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(20),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      Text('${_totalAmount.toStringAsFixed(2)} TL',
                          style:
                              const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${otherMember?.name ?? "Other"} owes'),
                      Text('${_splitAmount.toStringAsFixed(2)} TL',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _saveBill,
                      child: const Text('Save Bill',
                          style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _addManualItem() {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Add Item'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Price (TL)',
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(
                  priceController.text.trim().replaceAll(',', '.'));
              if (name.isNotEmpty && price != null && price > 0) {
                setState(() {
                  _items.add(_EditableItem(
                    name: name,
                    price: price,
                    isIncluded: true,
                    splitPercent: 50,
                  ));
                });
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class _EditableItem {
  String name;
  double price;
  bool isIncluded;
  int splitPercent;

  _EditableItem({
    required this.name,
    required this.price,
    required this.isIncluded,
    required this.splitPercent,
  });
}
