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

      final allMemberIds = context
          .read<HouseholdProvider>()
          .members
          .map((m) => m.id!)
          .toList();

      _items = parsed.items
          .map((item) => _EditableItem(
                name: item.name,
                price: item.price,
                isIncluded: true,
                sharedByMemberIds: List<int>.from(allMemberIds),
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

  /// Calculates how much each member owes (excluding payer's own share).
  Map<int, double> get _memberOwes {
    final owes = <int, double>{};
    for (final item in _items) {
      if (item.isIncluded && item.sharedByMemberIds.isNotEmpty) {
        final perMember = item.price / item.sharedByMemberIds.length;
        for (final memberId in item.sharedByMemberIds) {
          if (memberId != _paidByMemberId) {
            owes[memberId] = (owes[memberId] ?? 0) + perMember;
          }
        }
      }
    }
    return owes;
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
              sharedByMemberIds: item.sharedByMemberIds,
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
    final memberOwes = _memberOwes;
    final currencySymbol = AppCurrency.getByCode(householdProvider.currency).symbol;

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
                    icon: Icon(Icons.calendar_today_rounded,
                        size: 18, color: AppColors.primary),
                    label: Text(
                      DateFormat('dd/MM/yyyy').format(_billDate),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _paidByMemberId,
                    decoration: InputDecoration(
                      labelText: 'Paid by',
                      labelStyle: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                    ),
                    items: members
                        .map((m) => DropdownMenuItem(
                              value: m.id,
                              child: Text(m.name,
                                  style: const TextStyle(fontSize: 14)),
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
                  label: Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected ? cat.color : AppColors.textSecondary,
                    ),
                  ),
                  avatar: Icon(cat.icon, size: 16, color: cat.color),
                  selected: isSelected,
                  selectedColor: cat.color.withAlpha(30),
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                    color: isSelected ? cat.color.withAlpha(100) : AppColors.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
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
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withAlpha(20),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.warning_amber_rounded,
                              size: 32, color: AppColors.accent),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No items detected from the receipt',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: _addManualItem,
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Add Item Manually'),
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _items.length + 1,
                    itemBuilder: (context, index) {
                      if (index == _items.length) {
                        // Add item button with dashed outline style
                        return Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: InkWell(
                            onTap: _addManualItem,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                            child: CustomPaint(
                              painter: _DashedRectPainter(
                                color: AppColors.primary.withAlpha(100),
                                radius: AppRadius.md,
                              ),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_rounded,
                                        size: 20, color: AppColors.primary),
                                    SizedBox(width: 8),
                                    Text(
                                      'Add Item',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }
                      final item = _items[index];
                      return Dismissible(
                        key: ValueKey(index),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.negative,
                            borderRadius:
                                BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete_outline_rounded,
                              color: Colors.white, size: 22),
                        ),
                        onDismissed: (_) {
                          setState(() => _items.removeAt(index));
                        },
                        child: ItemRow(
                          name: item.name,
                          price: item.price,
                          isIncluded: item.isIncluded,
                          allMembers: members,
                          selectedMemberIds: item.sharedByMemberIds,
                          currencySymbol: currencySymbol,
                          onMembersChanged: (ids) {
                            setState(() => item.sharedByMemberIds = ids);
                          },
                        ),
                      );
                    },
                  ),
          ),

          // Bottom summary bar
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 1),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          )),
                      Text('${_totalAmount.toStringAsFixed(2)} $currencySymbol',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          )),
                    ],
                  ),
                  // Per-member owes
                  ...memberOwes.entries.map((entry) {
                    final member = members
                        .where((m) => m.id == entry.key)
                        .firstOrNull;
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${member?.name ?? "Member"} owes',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          Text('${entry.value.toStringAsFixed(2)} $currencySymbol',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              )),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: _saveBill,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                      ),
                      child: const Text('Save Bill',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
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
    final currencySymbol = AppCurrency.getByCode(
      context.read<HouseholdProvider>().currency,
    ).symbol;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: const Text('Add Item',
            style: TextStyle(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Item Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: InputDecoration(
                labelText: 'Price ($currencySymbol)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textTertiary)),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              final price = double.tryParse(
                  priceController.text.trim().replaceAll(',', '.'));
              if (name.isNotEmpty && price != null && price > 0) {
                final allMemberIds = context
                    .read<HouseholdProvider>()
                    .members
                    .map((m) => m.id!)
                    .toList();
                setState(() {
                  _items.add(_EditableItem(
                    name: name,
                    price: price,
                    isIncluded: true,
                    sharedByMemberIds: allMemberIds,
                  ));
                });
                Navigator.pop(dialogContext);
              }
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
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
  List<int> sharedByMemberIds;

  _EditableItem({
    required this.name,
    required this.price,
    required this.isIncluded,
    required this.sharedByMemberIds,
  });
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double radius;

  _DashedRectPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    const dashWidth = 6.0;
    const dashSpace = 4.0;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final end = (distance + dashWidth).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) =>
      color != oldDelegate.color;
}
