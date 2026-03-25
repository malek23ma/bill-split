import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
// TODO: re-enable when passcode flow is fixed
// import '../services/passcode_service.dart';
// import 'passcode_screen.dart';

class LaunchScreen extends StatefulWidget {
  const LaunchScreen({super.key});

  @override
  State<LaunchScreen> createState() => _LaunchScreenState();
}

class _LaunchScreenState extends State<LaunchScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _route());
  }

  Future<void> _route() async {
    final authUser = Supabase.instance.client.auth.currentUser;

    if (authUser == null) {
      if (mounted) Navigator.pushReplacementNamed(context, '/auth');
      return;
    }

    // TODO: Passcode check disabled — needs context fix before re-enabling
    // final passcodeService = PasscodeService();
    // final hasPasscode = await passcodeService.hasPasscode(authUser.id);

    // No passcode — proceed directly
    await _navigateAfterAuth(authUser);
  }

  Future<void> _navigateAfterAuth(User authUser) async {
    final prefs = await SharedPreferences.getInstance();
    final lastId = prefs.getInt('last_household_id');

    if (lastId != null && mounted) {
      final provider = context.read<HouseholdProvider>();
      await provider.loadHouseholds();
      final household =
          provider.households.where((h) => h.id == lastId).firstOrNull;

      if (household != null) {
        await provider.setCurrentHousehold(household);
        final member = await provider.resolveCurrentMember(authUser.id);

        if (member != null && mounted) {
          context.read<BillProvider>().loadBills(lastId);
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      }
    }

    if (mounted) Navigator.pushReplacementNamed(context, '/households');
  }

  @override
  Widget build(BuildContext context) {
    // Show a loading spinner while routing
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
