import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';

class MemberSelectScreen extends StatelessWidget {
  const MemberSelectScreen({super.key});

  void _login(BuildContext context, Member member) {
    final provider = context.read<HouseholdProvider>();
    provider.setCurrentMember(member);
    context.read<BillProvider>().loadBills(provider.currentHousehold!.id!);
    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  void _onMemberTap(BuildContext context, Member member) {
    if (member.pin != null && member.pin!.isNotEmpty) {
      _showPinDialog(context, member);
    } else {
      _login(context, member);
    }
  }

  void _showPinDialog(BuildContext context, Member member) {
    final controller = TextEditingController();
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Enter PIN for ${member.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 12),
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  counterText: '',
                  errorText: error,
                ),
                onSubmitted: (_) {
                  if (controller.text == member.pin) {
                    Navigator.pop(ctx);
                    _login(context, member);
                  } else {
                    setDialogState(() => error = 'Wrong PIN');
                    controller.clear();
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (controller.text == member.pin) {
                  Navigator.pop(ctx);
                  _login(context, member);
                } else {
                  setDialogState(() => error = 'Wrong PIN');
                  controller.clear();
                }
              },
              child: const Text('Enter'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HouseholdProvider>();
    final members = provider.members;
    final householdName = provider.currentHousehold?.name ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(householdName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Who are you?',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            ...members.map((member) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: FilledButton.icon(
                      onPressed: () => _onMemberTap(context, member),
                      icon: Icon(
                        member.pin != null && member.pin!.isNotEmpty
                            ? Icons.lock
                            : Icons.person,
                        size: 28,
                      ),
                      label: Text(
                        member.name,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
