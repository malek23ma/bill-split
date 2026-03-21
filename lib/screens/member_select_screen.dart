import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/member.dart';
import '../providers/household_provider.dart';
import '../providers/bill_provider.dart';
import '../services/pin_helper.dart';
import '../constants.dart';
import '../widgets/scale_tap.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          title: null,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.primary.withAlpha(30) : AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Enter PIN for ${member.name}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Please enter your 4-digit PIN to continue.',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              TextField(
                controller: controller,
                autofocus: true,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 28, letterSpacing: 12),
                decoration: InputDecoration(
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
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.negative),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide:
                        const BorderSide(color: AppColors.negative, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? AppColors.darkSurfaceVariant
                      : AppColors.surfaceVariant,
                  counterText: '',
                  errorText: error,
                  contentPadding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.md, horizontal: AppSpacing.lg),
                ),
                onSubmitted: (_) {
                  if (PinHelper.verifyPin(controller.text, member.pin!)) {
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
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
          actions: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton(
                onPressed: () {
                  if (PinHelper.verifyPin(controller.text, member.pin!)) {
                    Navigator.pop(ctx);
                    _login(context, member);
                  } else {
                    setDialogState(() => error = 'Wrong PIN');
                    controller.clear();
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Enter',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
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
          ],
        ),
      ),
    );
  }

  void _showMemberOptions(BuildContext context, Member member, HouseholdProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppSpacing.md),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Icon(
                  Icons.edit_rounded,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                title: Text(
                  'Rename',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRenameDialog(context, member, provider);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.person_remove_rounded,
                  color: AppColors.negative,
                ),
                title: const Text(
                  'Remove from household',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.negative,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _showRemoveConfirmation(context, member, provider);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, Member member, HouseholdProvider provider) {
    final controller = TextEditingController(text: member.name);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Rename Member',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: TextFormField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: InputDecoration(
            labelText: 'Name',
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
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
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onFieldSubmitted: (_) async {
            await provider.renameMember(member.id!, controller.text);
            if (ctx.mounted) Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              await provider.renameMember(member.id!, controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Save',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context, Member member, HouseholdProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Remove ${member.name}?',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: Text(
          'They will be hidden from new bills. Existing bills and balances are preserved.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          FilledButton(
            onPressed: () async {
              final success = await provider.softDeleteMember(member.id!);
              if (ctx.mounted) Navigator.pop(ctx);
              if (!success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Cannot remove the last member')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text(
              'Remove',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMemberDialog(BuildContext context, HouseholdProvider provider) {
    final controller = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        title: Text(
          'Add Member',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
        content: TextFormField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          decoration: InputDecoration(
            labelText: 'Name',
            filled: true,
            fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
          onFieldSubmitted: (_) async {
            if (controller.text.trim().isNotEmpty) {
              await provider.addMember(controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                )),
          ),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await provider.addMember(controller.text);
                if (ctx.mounted) Navigator.pop(ctx);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
                  fontSize: 28,
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
                  fontSize: 16,
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
                  itemCount: members.length + 1, // +1 for add button
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: AppSpacing.lg),
                  itemBuilder: (context, index) {
                    // Last item is the add member button
                    if (index == members.length) {
                      return OutlinedButton.icon(
                        onPressed: () => _showAddMemberDialog(context, provider),
                        icon: const Icon(Icons.person_add_rounded, size: 20),
                        label: const Text('Add Member',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: BorderSide(
                            color: isDark ? AppColors.darkDivider : AppColors.divider,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                      );
                    }
                    final member = members[index];
                    final hasPin =
                        member.pin != null && member.pin!.isNotEmpty;
                    final initial = member.name.isNotEmpty
                        ? member.name[0].toUpperCase()
                        : '?';
                    final avatarColor = AppColors.memberColor(index);

                    return ScaleTap(
                      onTap: () => _onMemberTap(context, member),
                      onLongPress: () => _showMemberOptions(context, member, provider),
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
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                color: avatarColor.withAlpha(25),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.md),
                              ),
                              child: Center(
                                child: Text(
                                  initial,
                                  style: TextStyle(
                                    fontSize: 24,
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
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.xs),
                                  Text(
                                    hasPin ? 'PIN protected' : 'Tap to enter',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                      color: isDark
                                          ? AppColors.darkTextSecondary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Lock / chevron
                            if (hasPin)
                              Icon(
                                Icons.lock_rounded,
                                size: 20,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textTertiary,
                              )
                            else
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
