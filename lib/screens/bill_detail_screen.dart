import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/recurring_bill_provider.dart';
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
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
    final householdProvider = context.watch<HouseholdProvider>();
    final members = householdProvider.members;
    final currencySymbol = AppCurrency.getByCode(householdProvider.currency).symbol;
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
          if (!isSettlement)
            TextButton.icon(
              onPressed: () => _showMakeRecurringSheet(context, bill),
              icon: const Icon(Icons.repeat_rounded, size: 18),
              label: const Text('Recurring'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.secondary,
              ),
            ),
          TextButton(
            onPressed: () => _confirmDelete(context, bill),
            child: Text(
              'Delete',
              style: TextStyle(
                color: AppColors.negative,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Category chip and bill type badge row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isSettlement)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: category.color.withAlpha(20),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xxl),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(category.icon,
                                      size: 16, color: category.color),
                                  const SizedBox(width: 6),
                                  Text(
                                    category.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: category.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isSettlement)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.positive.withAlpha(20),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xxl),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.handshake,
                                      size: 16, color: AppColors.positive),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Settlement',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.positive,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!isSettlement) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: bill.billType == 'quick'
                                    ? AppColors.accent.withAlpha(20)
                                    : AppColors.primary.withAlpha(20),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xs),
                              ),
                              child: Text(
                                bill.billType == 'quick' ? 'Quick' : 'Full',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: bill.billType == 'quick'
                                      ? AppColors.accent
                                      : AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: 20),

                      // Amount display
                      Text(
                        '${bill.totalAmount.toStringAsFixed(2)} $currencySymbol',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurface,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isSettlement ? 'Amount' : 'Total',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Info rows with alternating backgrounds
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color:
                                isDark ? AppColors.darkBorder : AppColors.border,
                          ),
                        ),
                        child: Column(
                          children: [
                            _InfoRow(
                              label: 'Date',
                              value: dateStr,
                              isFirst: true,
                              showBackground: true,
                              isDark: isDark,
                            ),
                            _InfoRow(
                              label: 'Paid by',
                              value: paidBy?.name ?? 'Unknown',
                              showBackground: false,
                              isDark: isDark,
                            ),
                            if (!isSettlement)
                              _InfoRow(
                                label: 'Entered by',
                                value: enteredBy?.name ?? 'Unknown',
                                isLast: true,
                                showBackground: true,
                                isDark: isDark,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Items section
            if (bill.billType == 'full' && _items.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              ..._items.map((item) {
                final sharedNames = item.sharedByMemberIds
                    .map((id) =>
                        members.where((m) => m.id == id).firstOrNull?.name ??
                        '?')
                    .toList();
                final isAllMembers =
                    item.sharedByMemberIds.length == members.length;
                final splitLabel = isAllMembers
                    ? 'All members'
                    : sharedNames.join(', ');

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color:
                            isDark ? AppColors.darkBorder : AppColors.border,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          // Member initials circles
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (int i = 0;
                                    i < item.sharedByMemberIds.length && i < 3;
                                    i++)
                                  Positioned(
                                    left: i * 12.0,
                                    child: Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: _chipColor(i),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark
                                              ? AppColors.darkSurface
                                              : AppColors.surface,
                                          width: 2,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _initialFor(
                                              item.sharedByMemberIds[i],
                                              members),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  splitLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${item.price.toStringAsFixed(2)} $currencySymbol',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
            ],

            // Quick bill: show equal split text
            if (bill.billType == 'quick') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people_rounded,
                          size: 20, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Text(
                        'Split equally among all members',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Receipt photo
            if (bill.photoPath != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Receipt Photo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(isDark ? 40 : 15),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    child: Image.file(
                      File(bill.photoPath!),
                      fit: BoxFit.contain,
                    ),
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

  static const _chipColors = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFF8B5CF6),
    AppColors.positive,
    AppColors.accent,
    AppColors.negative,
  ];

  Color _chipColor(int index) => _chipColors[index % _chipColors.length];

  String _initialFor(int memberId, Iterable<dynamic> members) {
    for (final m in members) {
      if (m.id == memberId) {
        return m.name.isNotEmpty ? m.name[0].toUpperCase() : '?';
      }
    }
    return '?';
  }

  void _showMakeRecurringSheet(BuildContext context, Bill bill) {
    final category = BillCategories.getById(bill.category);
    final titleController = TextEditingController(text: category.label);
    String selectedFrequency = 'monthly';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                24, 8, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                const Text(
                  'Make Recurring',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'This bill will repeat automatically',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 20),
                // Title field
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle:
                        const TextStyle(color: AppColors.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Amount (read-only display)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        bill.totalAmount.toStringAsFixed(2),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Frequency picker
                const Text(
                  'Frequency',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: ['weekly', 'monthly', 'yearly'].map((freq) {
                    final isSelected = selectedFrequency == freq;
                    final label = freq[0].toUpperCase() + freq.substring(1);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: freq != 'yearly' ? 8 : 0),
                        child: ChoiceChip(
                          label: SizedBox(
                            width: double.infinity,
                            child: Text(label, textAlign: TextAlign.center),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setSheetState(
                                () => selectedFrequency = freq);
                          },
                          selectedColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.sm),
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                            ),
                          ),
                          showCheckmark: false,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                // Create button
                FilledButton(
                  onPressed: () async {
                    final title = titleController.text.trim();
                    if (title.isEmpty) return;
                    final householdProvider =
                        context.read<HouseholdProvider>();
                    final householdId =
                        householdProvider.currentHousehold?.id;
                    if (householdId == null) return;

                    await context
                        .read<RecurringBillProvider>()
                        .createRecurring(
                          householdId: householdId,
                          paidByMemberId: bill.paidByMemberId,
                          category: bill.category,
                          amount: bill.totalAmount,
                          title: title,
                          frequency: selectedFrequency,
                        );

                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Recurring bill created'),
                        ),
                      );
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: const Text(
                    'Create Recurring Bill',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.negative),
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

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showBackground;
  final bool isFirst;
  final bool isLast;
  final bool isDark;

  const _InfoRow({
    required this.label,
    required this.value,
    this.showBackground = false,
    this.isFirst = false,
    this.isLast = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: showBackground
            ? (isDark
                ? AppColors.darkSurfaceVariant.withAlpha(40)
                : AppColors.surfaceVariant.withAlpha(120))
            : Colors.transparent,
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(AppRadius.md) : Radius.zero,
          bottom: isLast ? const Radius.circular(AppRadius.md) : Radius.zero,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
