import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../providers/household_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/bill_provider.dart';
import '../models/household.dart';
import '../database/database_helper.dart';
import '../constants.dart';
import '../widgets/scale_tap.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  List<Household>? _userHouseholds;

  @override
  void initState() {
    super.initState();
    context.read<HouseholdProvider>().loadHouseholds();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadUserHouseholds();
  }

  Future<void> _loadUserHouseholds() async {
    final authUser = Supabase.instance.client.auth.currentUser;
    if (authUser != null) {
      final provider = context.read<HouseholdProvider>();
      final filtered = await provider.getHouseholdsForUser(authUser.id);
      if (mounted) setState(() => _userHouseholds = filtered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HouseholdProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final households = _userHouseholds ?? provider.households;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with account info and sign out
            Padding(
              padding: EdgeInsets.fromLTRB(AppScale.padding(16), AppScale.padding(8), AppScale.padding(8), 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      Supabase.instance.client.auth.currentUser?.email ?? '',
                      style: TextStyle(
                        fontSize: AppScale.fontSize(13),
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      await context.read<AuthProvider>().signOut();
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/auth', (route) => false);
                      }
                    },
                    icon: Icon(Icons.logout_rounded, size: AppScale.size(16), color: AppColors.negative),
                    label: Text('Sign Out', style: TextStyle(color: AppColors.negative, fontSize: AppScale.fontSize(12))),
                  ),
                ],
              ),
            ),
            // Join household button (always visible when authenticated)
            if (context.watch<AuthProvider>().isAuthenticated)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: AppScale.padding(16), vertical: AppScale.padding(4)),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/join-household'),
                    icon: Icon(Icons.group_add_rounded, size: AppScale.size(16), color: AppColors.primary),
                    label: Text('Join Household', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600, fontSize: AppScale.fontSize(13))),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      padding: EdgeInsets.symmetric(vertical: AppScale.padding(10)),
                    ),
                  ),
                ),
              ),
            Expanded(
              child: households.isEmpty
                  ? _buildEmptyState(context, isDark)
                  : _buildHouseholdList(context, provider, isDark, households),
            ),
          ],
        ),
      ),
      floatingActionButton: households.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateSheet(context),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              highlightElevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'New',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            )
          : null,
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Solid color icon container — no gradient
            Container(
              width: AppScale.size(120),
              height: AppScale.size(120),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.xxl),
              ),
              child: Icon(
                Icons.home_rounded,
                size: AppScale.size(56),
                color: Colors.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            Text(
              'Welcome to Bill Split',
              style: TextStyle(
                fontSize: AppScale.fontSize(28),
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Create a household to start tracking\nand splitting bills with others.',
              style: TextStyle(
                fontSize: AppScale.fontSize(16),
                fontWeight: FontWeight.w400,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: AppScale.size(40)),
            SizedBox(
              width: double.infinity,
              height: AppScale.size(56),
              child: FilledButton.icon(
                onPressed: () => _showCreateSheet(context),
                icon: const Icon(Icons.add_rounded),
                label: Text(
                  'Create Household',
                  style: TextStyle(fontSize: AppScale.fontSize(16), fontWeight: FontWeight.w600),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            if (context.watch<AuthProvider>().isAuthenticated)
              Padding(
                padding: EdgeInsets.only(top: AppScale.padding(12)),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pushNamed(context, '/join-household'),
                    icon: Icon(Icons.group_add_rounded, color: AppColors.primary),
                    label: Text('Join Household', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? AppColors.darkDivider : AppColors.divider),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                      padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHouseholdList(
      BuildContext context, HouseholdProvider provider, bool isDark, List<Household> households) {
    return CustomScrollView(
      slivers: [
        // Header
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.xxl, AppSpacing.xxl, AppSpacing.xxl, AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your Households',
                  style: TextStyle(
                    fontSize: AppScale.fontSize(28),
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${households.length} household${households.length != 1 ? 's' : ''}',
                  style: TextStyle(
                    fontSize: AppScale.fontSize(14),
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        // List
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxl, AppSpacing.sm, AppSpacing.xxl, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final household = households[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.md),
                  child: ScaleTap(
                    onTap: () async {
                      await provider.setCurrentHousehold(household);
                      final authUser = Supabase.instance.client.auth.currentUser;
                      if (authUser != null && context.mounted) {
                        final member = await provider.resolveCurrentMember(authUser.id);
                        if (member != null && context.mounted) {
                          context.read<BillProvider>().loadBills(provider.currentHousehold!.id!);
                          // Save last used household
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setInt('last_household_id', household.id!);
                          if (context.mounted) {
                            Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
                          }
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('You are not a member of this household')),
                          );
                        }
                      }
                    },
                    // Delete moved to settings — admin only
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Row(
                        children: [
                          // Icon container — rounded rect, 10% opacity bg
                          Container(
                            width: AppScale.size(48),
                            height: AppScale.size(48),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(25),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(
                              Icons.home_rounded,
                              color: AppColors.primary,
                              size: AppScale.size(24),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  household.name,
                                  style: TextStyle(
                                    fontSize: AppScale.fontSize(16),
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? AppColors.darkTextPrimary
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
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
                  ),
                );
              },
              childCount: households.length,
            ),
          ),
        ),
      ],
    );
  }

  void _showCreateSheet(BuildContext context) {
    final nameController = TextEditingController();
    final memberControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : AppColors.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xxl, AppSpacing.md, AppSpacing.xxl, AppSpacing.xxxl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Center(
                      child: Container(
                        width: AppScale.size(40),
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppSpacing.xxl),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkDivider
                              : AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text(
                      'Create Household',
                      style: TextStyle(
                        fontSize: AppScale.fontSize(22),
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Set up a new household and add members.',
                      style: TextStyle(
                        fontSize: AppScale.fontSize(14),
                        fontWeight: FontWeight.w400,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    TextField(
                      controller: nameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Household Name',
                        hintText: 'e.g., Our House',
                        prefixIcon: const Icon(Icons.home_rounded),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 2),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkSurfaceVariant
                            : AppColors.surfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    // Dynamic member fields
                    for (int i = 0; i < memberControllers.length; i++) ...[
                      TextField(
                        controller: memberControllers[i],
                        decoration: InputDecoration(
                          labelText: 'Member ${i + 1}',
                          hintText: i == 0
                              ? 'e.g., Malek'
                              : i == 1
                                  ? 'e.g., Zain'
                                  : 'Name',
                          prefixIcon: const Icon(Icons.person_rounded),
                          suffixIcon: i >= 2
                              ? IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      size: AppScale.size(20)),
                                  onPressed: () {
                                    setSheetState(() {
                                      memberControllers[i].dispose();
                                      memberControllers.removeAt(i);
                                    });
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                                color: AppColors.primary, width: 2),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.darkSurfaceVariant
                              : AppColors.surfaceVariant,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    // Add member button
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setSheetState(() {
                            memberControllers.add(TextEditingController());
                          });
                        },
                        icon: Icon(Icons.person_add_rounded, size: AppScale.size(18)),
                        label: const Text('Add Member'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: isDark
                                ? AppColors.darkDivider
                                : AppColors.divider,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl + 4),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: AppScale.size(52),
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(sheetContext),
                              style: OutlinedButton.styleFrom(
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                                side: BorderSide(
                                  color: isDark
                                      ? AppColors.darkDivider
                                      : AppColors.divider,
                                ),
                              ),
                              child: Text(
                                'Cancel',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.darkTextSecondary
                                      : AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 2,
                          child: SizedBox(
                            height: AppScale.size(52),
                            child: FilledButton(
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final memberNames = memberControllers
                                    .map((c) => c.text.trim())
                                    .where((n) => n.isNotEmpty)
                                    .toList();

                                if (name.isEmpty || memberNames.length < 2) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Enter a household name and at least 2 members'),
                                    ),
                                  );
                                  return;
                                }

                                try {
                                  final provider = context.read<HouseholdProvider>();
                                  await provider.createHousehold(name, memberNames);

                                  // Cloud-sync the new household and admin member
                                  final authUser = Supabase.instance.client.auth.currentUser;
                                  if (authUser != null) {
                                    final db = await DatabaseHelper.instance.database;
                                    final uuid = const Uuid();

                                    // Get the household that was just created
                                    final household = provider.currentHousehold ?? provider.households.last;

                                    // Sync household to cloud
                                    final hRemoteId = uuid.v4();
                                    await Supabase.instance.client.from('households').upsert({
                                      'id': hRemoteId,
                                      'name': household.name,
                                      'currency': household.currency,
                                    });
                                    await db.update('households', {'remote_id': hRemoteId},
                                        where: 'id = ?', whereArgs: [household.id]);

                                    // Sync the admin member to cloud with user_id linked
                                    final members = await db.query('members',
                                        where: 'household_id = ?', whereArgs: [household.id]);
                                    if (members.isNotEmpty) {
                                      final member = members.first;
                                      final mRemoteId = uuid.v4();
                                      await Supabase.instance.client.from('members').insert({
                                        'id': mRemoteId,
                                        'household_id': hRemoteId,
                                        'name': member['name'],
                                        'user_id': authUser.id,
                                        'is_admin': true,
                                        'is_active': true,
                                      });
                                      await db.update('members', {'remote_id': mRemoteId},
                                          where: 'id = ?', whereArgs: [member['id']]);
                                    }

                                    // Save last household
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setInt('last_household_id', household.id!);
                                  }

                                  if (sheetContext.mounted) {
                                    Navigator.pop(sheetContext);
                                  }
                                } catch (e) {
                                  if (sheetContext.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content: Text('Error: $e'),
                                          backgroundColor: AppColors.negative),
                                    );
                                  }
                                }
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(AppRadius.md),
                                ),
                                elevation: 0,
                              ),
                              child: Text(
                                'Create',
                                style: TextStyle(
                                    fontSize: AppScale.fontSize(16), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}
