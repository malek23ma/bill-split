import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../models/bill.dart';
import '../models/bill_item.dart';
import '../providers/auth_provider.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/recurring_bill_provider.dart';
import '../services/notification_service.dart';
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
    final billProvider = context.read<BillProvider>();
    final bill = await billProvider.getBill(billId);
    final items = await billProvider.getBillItems(billId);

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
    final currentMember = householdProvider.currentMember;
    final canDelete = currentMember != null &&
        (bill.paidByMemberId == currentMember.id || currentMember.isAdmin);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Details'),
        actions: [
          if (!isSettlement)
            IconButton(
              onPressed: () => _showMakeRecurringSheet(context, bill),
              icon: Icon(Icons.repeat_rounded, size: AppScale.size(20)),
              tooltip: 'Make Recurring',
              color: AppColors.primary,
            ),
          if (canDelete)
            IconButton(
              onPressed: () => _confirmDelete(context, bill),
              icon: Icon(Icons.delete_outline_rounded, size: AppScale.size(20)),
              tooltip: 'Delete',
              color: AppColors.negative,
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header card
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      // Category chip and bill type badge row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (!isSettlement)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppScale.padding(12), vertical: AppScale.padding(6)),
                              decoration: BoxDecoration(
                                color: category.color.withAlpha(20),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(category.icon,
                                      size: AppScale.size(16), color: category.color),
                                  const SizedBox(width: 6),
                                  Text(
                                    category.label,
                                    style: TextStyle(
                                      fontSize: AppScale.fontSize(13),
                                      fontWeight: FontWeight.w600,
                                      color: category.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (isSettlement)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppScale.padding(12), vertical: AppScale.padding(6)),
                              decoration: BoxDecoration(
                                color: AppColors.positiveSurface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.handshake,
                                      size: AppScale.size(16), color: AppColors.positive),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Settlement',
                                    style: TextStyle(
                                      fontSize: AppScale.fontSize(13),
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.positive,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (!isSettlement) ...[
                            const SizedBox(width: AppSpacing.sm),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: AppScale.padding(8), vertical: AppScale.padding(4)),
                              decoration: BoxDecoration(
                                color: bill.billType == 'quick'
                                    ? AppColors.accentSurface
                                    : AppColors.primarySurface,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                bill.billType == 'quick' ? 'Quick' : 'Full',
                                style: TextStyle(
                                  fontSize: AppScale.fontSize(11),
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

                      const SizedBox(height: AppSpacing.xl),

                      // Amount display
                      Text(
                        '${bill.totalAmount.toStringAsFixed(2)} $currencySymbol',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(32),
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        isSettlement ? 'Amount' : 'Total',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(13),
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      // Info rows with alternating backgrounds
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
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
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Text(
                  'Items',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                ),
              ),
              ..._items.asMap().entries.map((entry) {
                final item = entry.value;
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
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppScale.padding(3)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                      child: Row(
                        children: [
                          // Member initials circles
                          SizedBox(
                            width: AppScale.size(36),
                            height: AppScale.size(36),
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                for (int i = 0;
                                    i < item.sharedByMemberIds.length && i < 3;
                                    i++)
                                  Positioned(
                                    left: i * 12.0,
                                    child: Container(
                                      width: AppScale.size(24),
                                      height: AppScale.size(24),
                                      decoration: BoxDecoration(
                                        color: AppColors.memberColor(i),
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
                                          style: TextStyle(
                                            fontSize: AppScale.fontSize(10),
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
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
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
                                  splitLabel,
                                  style: TextStyle(
                                    fontSize: AppScale.fontSize(12),
                                    color: isDark
                                        ? AppColors.darkTextSecondary
                                        : AppColors.textSecondary,
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
                              fontSize: AppScale.fontSize(14),
                              color: isDark
                                  ? AppColors.darkTextPrimary
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: AppSpacing.lg),
            ],

            // Quick bill: show equal split text
            if (bill.billType == 'quick') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: AppScale.size(32),
                        height: AppScale.size(32),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(26),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(Icons.people_rounded,
                            size: AppScale.size(18), color: AppColors.primary),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Text(
                        'Split equally among all members',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(14),
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
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
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
                child: Text(
                  'Receipt Photo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Image.file(
                    File(bill.photoPath!),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ],
        ),
      ),
    );
  }

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl,
                MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.xxl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: AppScale.size(40),
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkDivider
                          : AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Title
                Text(
                  'Make Recurring',
                  style: TextStyle(
                    fontSize: AppScale.fontSize(20),
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'This bill will repeat automatically',
                  style: TextStyle(
                    fontSize: AppScale.fontSize(14),
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                // Title field
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: 'Title',
                    labelStyle:
                        const TextStyle(color: AppColors.textTertiary),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Amount (read-only display)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppScale.padding(14)),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Amount',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(14),
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        bill.totalAmount.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: AppScale.fontSize(16),
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkTextPrimary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Frequency picker
                Text(
                  'Frequency',
                  style: TextStyle(
                    fontSize: AppScale.fontSize(14),
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: ['weekly', 'monthly', 'yearly'].map((freq) {
                    final isSelected = selectedFrequency == freq;
                    final label = freq[0].toUpperCase() + freq.substring(1);
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: freq != 'yearly' ? AppSpacing.sm : 0),
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
                          backgroundColor: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.surfaceVariant,
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: AppScale.fontSize(13),
                            color: isSelected
                                ? AppColors.primary
                                : isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.full),
                            side: BorderSide.none,
                          ),
                          showCheckmark: false,
                          padding: EdgeInsets.symmetric(vertical: AppScale.padding(8)),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.xxl),
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
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text('Delete Bill?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.darkTextPrimary
                  : AppColors.textPrimary,
            )),
        content: Text('This cannot be undone.',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textTertiary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext); // close dialog

              final billProvider = context.read<BillProvider>();
              final authProvider = context.read<AuthProvider>();
              final curMember =
                  context.read<HouseholdProvider>().currentMember;
              // Capture bill and items before deletion
              final deletedBill = bill;
              final deletedItems = bill.billType == 'full'
                  ? await billProvider.getBillItems(bill.id!)
                  : <BillItem>[];

              await billProvider.deleteBill(bill.id!, bill.householdId);

              // Send notification if admin deleted another member's bill
              if (authProvider.isAuthenticated &&
                  curMember != null &&
                  curMember.isAdmin &&
                  bill.paidByMemberId != curMember.id) {
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
                  // Only use if it's a valid UUID (not a local integer string)
                  final householdRemoteId =
                      (rawRemoteId != null && rawRemoteId.length > 8) ? rawRemoteId : null;

                  // Look up payer's user_id via their remote_id
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
                } catch (e, stack) {
                  debugPrint(
                      'Failed to send admin delete notification: $e\n$stack');
                }
              }

              if (context.mounted) {
                Navigator.pop(context, {
                  'deleted': true,
                  'bill': deletedBill,
                  'items': deletedItems,
                });
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
      padding: EdgeInsets.symmetric(horizontal: AppScale.padding(14), vertical: AppScale.padding(11)),
      decoration: BoxDecoration(
        color: showBackground
            ? (isDark
                ? AppColors.darkSurfaceVariant.withAlpha(80)
                : AppColors.surfaceVariant)
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
              fontSize: AppScale.fontSize(13),
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: AppScale.fontSize(13),
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
