import 'package:flutter/material.dart';
import '../constants.dart';
import '../models/bill_filter.dart';
import '../models/member.dart';

class FilterBottomSheet extends StatefulWidget {
  final BillFilter? currentFilter;
  final List<Member> members;
  final ValueChanged<BillFilter?> onApply;

  const FilterBottomSheet({
    super.key,
    this.currentFilter,
    required this.members,
    required this.onApply,
  });

  @override
  State<FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<FilterBottomSheet> {
  String? _category;
  int? _memberId;
  bool _filterByPaidBy = true;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _datePresetLabel;

  @override
  void initState() {
    super.initState();
    final f = widget.currentFilter;
    if (f != null) {
      _category = f.category;
      _memberId = f.memberId;
      _filterByPaidBy = f.filterByPaidBy;
      _dateFrom = f.dateFrom;
      _dateTo = f.dateTo;
      _datePresetLabel = f.datePresetLabel;
    }
  }

  void _applyDatePreset(String label) {
    final now = DateTime.now();
    DateTime from;
    switch (label) {
      case 'This month':
        from = DateTime(now.year, now.month);
        break;
      case 'Last 30 days':
        from = now.subtract(const Duration(days: 30));
        break;
      case 'Last 3 months':
        from = DateTime(now.year, now.month - 3, now.day);
        break;
      default:
        return;
    }
    setState(() {
      _dateFrom = from;
      _dateTo = now;
      _datePresetLabel = label;
    });
  }

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : null,
    );
    if (picked != null) {
      setState(() {
        _dateFrom = picked.start;
        _dateTo = picked.end;
        _datePresetLabel = null;
      });
    }
  }

  void _clearAll() {
    widget.onApply(null);
    Navigator.pop(context);
  }

  void _apply() {
    final hasAny = _category != null ||
        _memberId != null ||
        _dateFrom != null ||
        _dateTo != null;

    if (!hasAny) {
      widget.onApply(null);
    } else {
      widget.onApply(BillFilter(
        category: _category,
        memberId: _memberId,
        filterByPaidBy: _filterByPaidBy,
        dateFrom: _dateFrom,
        dateTo: _dateTo,
        datePresetLabel: _datePresetLabel,
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.surface;
    final textColor = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final secondaryText =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xl),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl, AppSpacing.sm, AppSpacing.xl, AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
              ),
            ),

            // Title
            Text(
              'Filters',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Category section ──
            _SectionLabel(label: 'Category', color: textColor),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: BillCategories.list.map((cat) {
                final selected = _category == cat.id;
                return FilterChip(
                  selected: selected,
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(cat.icon, size: 16,
                          color: selected ? Colors.white : cat.color),
                      const SizedBox(width: 6),
                      Text(cat.label),
                    ],
                  ),
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : textColor,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                  backgroundColor:
                      isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.full),
                    side: BorderSide(
                      color: selected
                          ? AppColors.primary
                          : (isDark ? AppColors.darkDivider : AppColors.divider),
                    ),
                  ),
                  showCheckmark: false,
                  onSelected: (_) {
                    setState(() {
                      _category = selected ? null : cat.id;
                    });
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Member section ──
            _SectionLabel(label: 'Member', color: textColor),
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<int?>(
              value: _memberId,
              isExpanded: true,
              decoration: InputDecoration(
                filled: true,
                fillColor:
                    isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg, vertical: AppSpacing.md,
                ),
              ),
              dropdownColor: isDark ? AppColors.darkSurface : AppColors.surface,
              style: TextStyle(color: textColor, fontSize: 14),
              items: [
                DropdownMenuItem<int?>(
                  value: null,
                  child: Text('All members',
                      style: TextStyle(color: secondaryText)),
                ),
                ...widget.members.map((m) => DropdownMenuItem<int?>(
                      value: m.id,
                      child: Text(m.name),
                    )),
              ],
              onChanged: (val) => setState(() => _memberId = val),
            ),
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Paid by')),
                  ButtonSegment(value: false, label: Text('Shared with')),
                ],
                selected: {_filterByPaidBy},
                onSelectionChanged: (val) {
                  setState(() => _filterByPaidBy = val.first);
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return AppColors.primary;
                    }
                    return isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surfaceVariant;
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return secondaryText;
                  }),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ── Date range section ──
            _SectionLabel(label: 'Date Range', color: textColor),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final preset in ['This month', 'Last 30 days', 'Last 3 months'])
                  ChoiceChip(
                    label: Text(preset),
                    selected: _datePresetLabel == preset,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _datePresetLabel == preset
                          ? Colors.white
                          : textColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    backgroundColor: isDark
                        ? AppColors.darkSurfaceVariant
                        : AppColors.surfaceVariant,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      side: BorderSide(
                        color: _datePresetLabel == preset
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.darkDivider
                                : AppColors.divider),
                      ),
                    ),
                    showCheckmark: false,
                    onSelected: (selected) {
                      if (selected) {
                        _applyDatePreset(preset);
                      } else {
                        setState(() {
                          _dateFrom = null;
                          _dateTo = null;
                          _datePresetLabel = null;
                        });
                      }
                    },
                  ),
                OutlinedButton.icon(
                  onPressed: _pickCustomRange,
                  icon: const Icon(Icons.date_range_rounded, size: 18),
                  label: Text(
                    _datePresetLabel == null && _dateFrom != null
                        ? '${_fmtDate(_dateFrom!)} - ${_fmtDate(_dateTo!)}'
                        : 'Custom',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        _datePresetLabel == null && _dateFrom != null
                            ? AppColors.primary
                            : secondaryText,
                    side: BorderSide(
                      color: _datePresetLabel == null && _dateFrom != null
                          ? AppColors.primary
                          : (isDark
                              ? AppColors.darkDivider
                              : AppColors.divider),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg, vertical: AppSpacing.sm,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.xxxl),

            // ── Action row ──
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: _clearAll,
                    style: TextButton.styleFrom(
                      foregroundColor: secondaryText,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text('Clear all',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _apply,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                    ),
                    child: const Text('Apply',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color color;

  const _SectionLabel({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}
