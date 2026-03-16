import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/household_provider.dart';
import '../database/database_helper.dart';
import '../constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _apiKeyController;

  @override
  void initState() {
    super.initState();
    _apiKeyController = TextEditingController(
      text: context.read<SettingsProvider>().apiKey,
    );
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  Future<void> _setPinDialog(BuildContext context, int memberId, bool hasExisting) async {
    final controller = TextEditingController();
    final confirmController = TextEditingController();
    String? error;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(hasExisting ? 'Change PIN' : 'Set PIN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 12),
                decoration: const InputDecoration(
                  labelText: 'Enter 4-digit PIN',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 12),
                decoration: InputDecoration(
                  labelText: 'Confirm PIN',
                  border: const OutlineInputBorder(),
                  counterText: '',
                  errorText: error,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final pin = controller.text.trim();
                final confirm = confirmController.text.trim();
                if (pin.length != 4) {
                  setDialogState(() => error = 'PIN must be 4 digits');
                  return;
                }
                if (pin != confirm) {
                  setDialogState(() => error = 'PINs do not match');
                  confirmController.clear();
                  return;
                }
                await DatabaseHelper.instance.updateMemberPin(memberId, pin);
                // Reload members to reflect the change
                final household = context.read<HouseholdProvider>();
                await household.setCurrentHousehold(household.currentHousehold!);
                household.setCurrentMember(
                  household.members.firstWhere((m) => m.id == memberId),
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('PIN set'), duration: Duration(seconds: 1)),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removePin(BuildContext context, int memberId) async {
    await DatabaseHelper.instance.updateMemberPin(memberId, null);
    final household = context.read<HouseholdProvider>();
    await household.setCurrentHousehold(household.currentHousehold!);
    household.setCurrentMember(
      household.members.firstWhere((m) => m.id == memberId),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN removed'), duration: Duration(seconds: 1)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // General section
          const _SectionHeader('General'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Builder(
                builder: (context) {
                  final household = context.watch<HouseholdProvider>();
                  final currentCurrency = AppCurrency.getByCode(household.currency);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Currency selector
                      Row(
                        children: [
                          Icon(Icons.language_rounded,
                              size: 20, color: colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Currency',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          DropdownButton<String>(
                            value: currentCurrency.code,
                            underline: const SizedBox.shrink(),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            items: AppCurrency.list.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.code,
                                child: Text(
                                  '${c.symbol}  ${c.name} (${c.code})',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              );
                            }).toList(),
                            onChanged: (code) {
                              if (code != null) {
                                context.read<HouseholdProvider>().updateCurrency(code);
                              }
                            },
                          ),
                        ],
                      ),
                      Divider(
                        color: isDark ? AppColors.darkBorder : AppColors.border,
                        height: 24,
                      ),
                      // Dark mode toggle
                      Row(
                    children: [
                      Icon(Icons.palette_outlined,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      switch (settings.themeMode) {
                        ThemeMode.light => 'Off',
                        ThemeMode.dark => 'On',
                        ThemeMode.system => 'System default',
                      },
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.phone_android, size: 18),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode, size: 18),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (selected) {
                        settings.setThemeMode(selected.first);
                      },
                      showSelectedIcon: false,
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ),
                  ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Receipt Scanning section
          const _SectionHeader('Receipt Scanning'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.auto_awesome_outlined,
                          size: 20, color: colorScheme.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Groq API Key',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      // Status indicator dot
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: settings.apiKey.isNotEmpty
                              ? AppColors.positive
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      'Accurate receipt scanning',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 30),
                    child: Text(
                      'Free at console.groq.com',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _apiKeyController,
                          decoration: InputDecoration(
                            hintText: 'gsk_...',
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          style: const TextStyle(
                              fontSize: 13, fontFamily: 'monospace'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          settings.setApiKey(_apiKeyController.text);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('API key saved'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                        child: const Text('Save'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        settings.apiKey.isNotEmpty
                            ? Icons.check_circle
                            : Icons.info_outline,
                        size: 14,
                        color: settings.apiKey.isNotEmpty
                            ? AppColors.positive
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        settings.apiKey.isNotEmpty
                            ? 'AI scanning active'
                            : 'Using basic on-device OCR',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: settings.apiKey.isNotEmpty
                              ? AppColors.positive
                              : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Security section
          const _SectionHeader('Security'),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final household = context.watch<HouseholdProvider>();
              final currentMember = household.currentMember;
              if (currentMember == null) return const SizedBox.shrink();

              final hasPin = currentMember.pin != null && currentMember.pin!.isNotEmpty;
              return Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.border,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasPin ? Icons.lock : Icons.lock_open,
                            size: 20,
                            color: hasPin
                                ? AppColors.positive
                                : AppColors.warning,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Login PIN',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  hasPin
                                      ? 'PIN is set'
                                      : 'No PIN — anyone can log in as you',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textTertiary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Status dot
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: hasPin
                                  ? AppColors.positive
                                  : AppColors.warning,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (hasPin)
                            TextButton(
                              onPressed: () =>
                                  _removePin(context, currentMember.id!),
                              child: Text(
                                'Remove',
                                style: TextStyle(color: AppColors.negative),
                              ),
                            ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: () => _setPinDialog(
                                context, currentMember.id!, hasPin),
                            child: Text(hasPin ? 'Change' : 'Set PIN'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 20),

          // About section
          const _SectionHeader('About'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: isDark ? AppColors.darkBorder : AppColors.border,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha(20),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      size: 22,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bill Split',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.textTertiary,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 1,
            color: isDark ? AppColors.darkBorder : AppColors.border,
          ),
        ),
      ],
    );
  }
}
