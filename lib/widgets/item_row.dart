import 'package:flutter/material.dart';
import '../constants.dart';

enum SplitMode { mine, yours, split }

class ItemRow extends StatelessWidget {
  final String name;
  final double price;
  final bool isIncluded;
  final int splitPercent;
  final ValueChanged<bool?> onIncludedChanged;
  final ValueChanged<int> onSplitChanged;
  final ValueChanged<String>? onNameChanged;
  final ValueChanged<double>? onPriceChanged;

  const ItemRow({
    super.key,
    required this.name,
    required this.price,
    required this.isIncluded,
    required this.splitPercent,
    required this.onIncludedChanged,
    required this.onSplitChanged,
    this.onNameChanged,
    this.onPriceChanged,
  });

  SplitMode get _mode {
    if (splitPercent == 100) return SplitMode.mine;
    if (splitPercent == 0) return SplitMode.yours;
    return SplitMode.split;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Item name and price
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
                Text(
                  '${price.toStringAsFixed(2)} TL',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Mine / Yours / Split buttons
            Row(
              children: [
                _ModeButton(
                  label: 'Mine',
                  icon: Icons.person,
                  isSelected: _mode == SplitMode.mine,
                  color: colorScheme.tertiary,
                  onTap: () {
                    onIncludedChanged(true);
                    onSplitChanged(100);
                  },
                ),
                const SizedBox(width: 8),
                _ModeButton(
                  label: 'Yours',
                  icon: Icons.person_outline,
                  isSelected: _mode == SplitMode.yours,
                  color: colorScheme.secondary,
                  onTap: () {
                    onIncludedChanged(true);
                    onSplitChanged(0);
                  },
                ),
                const SizedBox(width: 8),
                _ModeButton(
                  label: 'Split',
                  icon: Icons.handshake_outlined,
                  isSelected: _mode == SplitMode.split,
                  color: colorScheme.primary,
                  onTap: () {
                    onIncludedChanged(true);
                    if (_mode != SplitMode.split) {
                      onSplitChanged(50);
                    }
                  },
                ),
              ],
            ),

            // Split percentage chips (only when Split is selected)
            if (_mode == SplitMode.split) ...[
              const SizedBox(height: 8),
              Row(
                children: SplitPresets.values.map((preset) {
                  final isActive = splitPercent == preset;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        SplitPresets.displayLabel(preset),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isActive ? FontWeight.w600 : null,
                        ),
                      ),
                      selected: isActive,
                      onSelected: (_) => onSplitChanged(preset),
                      showCheckmark: false,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: isSelected ? color.withAlpha(30) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border.all(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: isSelected ? color : Colors.grey),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : null,
                    color: isSelected ? color : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
