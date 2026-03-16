import 'package:flutter/material.dart';

class BillTypeScreen extends StatelessWidget {
  const BillTypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Bill'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Choose bill type',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            _BillTypeCard(
              icon: Icons.receipt_long,
              title: 'Full Bill',
              description: 'Review each item and choose what to split',
              color: Colors.blue,
              onTap: () {
                Navigator.pushNamed(context, '/camera', arguments: 'full');
              },
            ),
            const SizedBox(height: 16),
            _BillTypeCard(
              icon: Icons.flash_on,
              title: 'Quick Bill',
              description: 'Auto-split the total 50/50',
              color: Colors.orange,
              onTap: () {
                Navigator.pushNamed(context, '/camera', arguments: 'quick');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BillTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final MaterialColor color;
  final VoidCallback onTap;

  const _BillTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: color.shade100,
                child: Icon(icon, color: color.shade700, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
