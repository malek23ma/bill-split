import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/household_provider.dart';
import '../database/database_helper.dart';

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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          // Appearance section
          const _SectionHeader('Appearance'),
          ListTile(
            leading: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            subtitle: Text(switch (settings.themeMode) {
              ThemeMode.light => 'Off',
              ThemeMode.dark => 'On',
              ThemeMode.system => 'System default',
            }),
            trailing: SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode, size: 18)),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android, size: 18)),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode, size: 18)),
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
          const Divider(),

          // AI Scanning section
          const _SectionHeader('AI Scanning'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Groq API key for accurate receipt scanning',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Free at console.groq.com',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _apiKeyController,
                        decoration: const InputDecoration(
                          hintText: 'gsk_...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      settings.apiKey.isNotEmpty
                          ? Icons.check_circle
                          : Icons.info_outline,
                      size: 16,
                      color: settings.apiKey.isNotEmpty
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      settings.apiKey.isNotEmpty
                          ? 'AI scanning active'
                          : 'Using basic on-device OCR',
                      style: TextStyle(
                        fontSize: 12,
                        color: settings.apiKey.isNotEmpty
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),

          // Security section
          const _SectionHeader('Security'),
          Builder(
            builder: (context) {
              final household = context.watch<HouseholdProvider>();
              final currentMember = household.currentMember;
              if (currentMember == null) return const SizedBox.shrink();

              final hasPin = currentMember.pin != null && currentMember.pin!.isNotEmpty;
              return ListTile(
                leading: Icon(hasPin ? Icons.lock : Icons.lock_open),
                title: const Text('Login PIN'),
                subtitle: Text(hasPin ? 'PIN is set' : 'No PIN — anyone can log in as you'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasPin)
                      TextButton(
                        onPressed: () => _removePin(context, currentMember.id!),
                        child: const Text('Remove'),
                      ),
                    FilledButton.tonal(
                      onPressed: () => _setPinDialog(context, currentMember.id!, hasPin),
                      child: Text(hasPin ? 'Change' : 'Set PIN'),
                    ),
                  ],
                ),
              );
            },
          ),
          const Divider(),

          // About section
          const _SectionHeader('About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Bill Split'),
            subtitle: Text('Version 1.0.0'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
