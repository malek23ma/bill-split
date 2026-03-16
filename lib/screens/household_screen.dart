import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/household_provider.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  @override
  void initState() {
    super.initState();
    context.read<HouseholdProvider>().loadHouseholds();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HouseholdProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bill Split'),
        centerTitle: true,
      ),
      body: provider.households.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.home_outlined,
                      size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No households yet',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create one to start splitting bills',
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => _showCreateDialog(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Create Household'),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: provider.households.length,
              itemBuilder: (context, index) {
                final household = provider.households[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.home),
                    ),
                    title: Text(
                      household.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await provider.setCurrentHousehold(household);
                      if (context.mounted) {
                        Navigator.pushNamed(context, '/select-member');
                      }
                    },
                    onLongPress: () => _showDeleteDialog(context, household),
                  ),
                );
              },
            ),
      floatingActionButton: provider.households.isNotEmpty
          ? FloatingActionButton(
              onPressed: () => _showCreateDialog(context),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  void _showCreateDialog(BuildContext context) {
    final nameController = TextEditingController();
    final member1Controller = TextEditingController();
    final member2Controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create Household'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Household Name',
                  hintText: 'e.g., Our House',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: member1Controller,
                decoration: const InputDecoration(
                  labelText: 'Member 1',
                  hintText: 'e.g., Malek',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: member2Controller,
                decoration: const InputDecoration(
                  labelText: 'Member 2',
                  hintText: 'e.g., Zain',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final m1 = member1Controller.text.trim();
              final m2 = member2Controller.text.trim();

              if (name.isEmpty || m1.isEmpty || m2.isEmpty) return;

              try {
                await context
                    .read<HouseholdProvider>()
                    .createHousehold(name, [m1, m2]);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(
      BuildContext context, household) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Household?'),
        content: Text(
            'This will delete "${household.name}" and all its bills. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await context
                  .read<HouseholdProvider>()
                  .deleteHousehold(household.id!);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
