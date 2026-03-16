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
    final otherMembers =
        members.where((m) => m.id != _paidByMemberId).toList();
    final perMemberShare = members.isNotEmpty ? _total / members.length : 0.0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Bill'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date & Payer card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  // Date picker row
                  InkWell(
                    onTap: () async {
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
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(20),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(Icons.calendar_today_rounded,
                                size: 18, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textTertiary,
                                  )),
                              const SizedBox(height: 2),
                              Text(
                                DateFormat('dd MMM yyyy').format(_billDate),
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.textTertiary, size: 20),
                        ],
                      ),
                    ),
                  ),

                  const Divider(color: AppColors.border, height: 20),

                  // Payer dropdown
                  DropdownButtonFormField<int>(
                    initialValue: _paidByMemberId,
                    decoration: InputDecoration(
                      labelText: 'Paid by',
                      labelStyle: const TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 13,
                      ),
                      prefixIcon: Container(
                        margin: const EdgeInsets.all(8),
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(20),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.person_rounded,
                            size: 18, color: AppColors.secondary),
                      ),
                      border: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 12),
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
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Category selector card
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
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
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? cat.color
                              : AppColors.textSecondary,
                        ),
                      ),
                      avatar: Icon(cat.icon, size: 16, color: cat.color),
                      selected: isSelected,
                      selectedColor: cat.color.withAlpha(30),
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: isSelected
                            ? cat.color.withAlpha(100)
                            : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                      ),
                      onSelected: (_) =>
                          setState(() => _category = cat.id),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Total amount input - large and prominent
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(15),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                          border: Border.all(
                              color: AppColors.primary.withAlpha(40)),
                        ),
                        child: const Text(
                          'TL',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _totalController,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                  color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                  color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                              borderSide: const BorderSide(
                                  color: AppColors.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            hintText: '0.00',
                            hintStyle: TextStyle(
                              color: AppColors.textTertiary.withAlpha(120),
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          keyboardType:
                              const TextInputType.numberWithOptions(
                                  decimal: true),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Split preview card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.secondary.withAlpha(20),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Icon(Icons.call_split_rounded,
                            size: 18, color: AppColors.secondary),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Split equally (${members.length} ways)',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Colored share bars
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    child: Row(
                      children: [
                        for (int i = 0; i < members.length; i++) ...[
                          if (i > 0) const SizedBox(width: 3),
                          Expanded(
                            child: Container(
                              height: 8,
                              color: _memberBarColor(i),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Per-member rows
                  for (int i = 0; i < members.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _memberBarColor(i),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            members[i].name,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Text(
                          '${perMemberShare.toStringAsFixed(2)} TL',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Owes summary text — show each non-payer member
            if (otherMembers.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(
                    vertical: 10, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Column(
                  children: otherMembers
                      .map((m) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text(
                              '${m.name} owes ${perMemberShare.toStringAsFixed(2)} TL',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ))
                      .toList(),
                ),
              ),

            const SizedBox(height: 28),

            // Save button - full width
            SizedBox(
              height: 54,
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

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  static const _barColors = [
    AppColors.primary,
    AppColors.secondary,
    Color(0xFF8B5CF6),
    AppColors.positive,
    AppColors.accent,
    AppColors.negative,
  ];

  Color _memberBarColor(int index) => _barColors[index % _barColors.length];
}
