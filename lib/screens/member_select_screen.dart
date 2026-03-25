import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/member.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../providers/auth_provider.dart';
import '../constants.dart';
import '../widgets/scale_tap.dart';

class MemberSelectScreen extends StatelessWidget {
  const MemberSelectScreen({super.key});

  void _login(BuildContext context, Member member) {
    final provider = context.read<HouseholdProvider>();
    provider.setCurrentMember(member);
    context.read<BillProvider>().loadBills(provider.currentHousehold!.id!);

    // Link auth user to this member in the cloud
    _linkAuthToMember(context, member);

    Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
  }

  /// Link the current auth user's ID to this member in Supabase
  Future<void> _linkAuthToMember(BuildContext context, Member member) async {
    try {
      final authProvider = context.read<AuthProvider>();
      if (!authProvider.isAuthenticated) return;
      final userId = authProvider.user!.id;
      final remoteId = member.remoteId;
      if (remoteId == null) return;

      // Update the cloud member record with this user's auth ID
      await Supabase.instance.client
          .from('members')
          .update({'user_id': userId})
          .eq('id', remoteId);
    } catch (e) {
      debugPrint('Failed to link auth to member: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HouseholdProvider>();
    final members = provider.members;
    final householdName = provider.currentHousehold?.name ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(householdName),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                "Who's this?",
                style: TextStyle(
                  fontSize: AppScale.fontSize(28),
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkTextPrimary
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Select your profile',
                style: TextStyle(
                  fontSize: AppScale.fontSize(16),
                  fontWeight: FontWeight.w400,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xxxl + 4),
              Expanded(
                child: ListView.separated(
                  itemCount: members.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.lg),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final initial = member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : '?';
                    final avatarColor = AppColors.memberColor(index);

                    return ScaleTap(
                      onTap: () => _login(context, member),
                      // Member management is admin-only, handled in settings
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkSurface
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                        ),
                        child: Row(
                          children: [
                            // Avatar — rounded rect (md radius), not circle
                            Container(
                              width: AppScale.size(56),
                              height: AppScale.size(56),
                              decoration: BoxDecoration(
                                color: avatarColor.withAlpha(25),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontSize: AppScale.fontSize(24),
                                    fontWeight: FontWeight.w700,
                                    color: avatarColor,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.lg),
                            // Name + subtitle
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    member.name,
                                    style: TextStyle(
                                      fontSize: AppScale.fontSize(16),
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    'Tap to enter',
                                    style: TextStyle(
                                      fontSize: AppScale.fontSize(13),
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
