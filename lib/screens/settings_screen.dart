import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/household_provider.dart';
import '../providers/auth_provider.dart';
import '../models/member.dart';
import '../services/push_notification_service.dart';
import '../services/notification_service.dart';
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: TextStyle(
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: AppScale.fontSize(20),
          ),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Builder(
          builder: (context) {
            final household = context.watch<HouseholdProvider>();
            final currentMember = household.currentMember;
            final members = household.members;
            final isAdmin = currentMember?.isAdmin ?? false;
            final selfIndex = members.indexWhere((m) => m.id == currentMember?.id);

            return ListView(
              padding: EdgeInsets.symmetric(horizontal: AppScale.padding(16), vertical: AppScale.padding(16)),
              children: [
                // ── 1. YOUR PROFILE ──
                _SectionHeader('Your Profile'),
                const SizedBox(height: 12),
                if (currentMember != null)
                  GestureDetector(
                    onTap: () => _showRenameDialog(context, currentMember, household),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(AppScale.padding(16)),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: AppScale.size(56),
                                  height: AppScale.size(56),
                                  decoration: BoxDecoration(
                                    color: AppColors.memberColor(selfIndex >= 0 ? selfIndex : 0).withAlpha(25),
                                    borderRadius: BorderRadius.circular(AppRadius.lg),
                                  ),
                                  child: Center(
                                    child: Text(
                                      currentMember.name.isNotEmpty
                                          ? currentMember.name[0].toUpperCase()
                                          : '?',
                                      style: TextStyle(
                                        fontSize: AppScale.fontSize(24),
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.memberColor(selfIndex >= 0 ? selfIndex : 0),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              currentMember.name,
                                              style: TextStyle(
                                                fontSize: AppScale.fontSize(18),
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (isAdmin) ...[
                                            SizedBox(width: 8),
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: AppScale.padding(8), vertical: AppScale.padding(3)),
                                              decoration: BoxDecoration(
                                                color: AppColors.accent.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(AppRadius.sm),
                                              ),
                                              child: Text(
                                                'Admin',
                                                style: TextStyle(
                                                  fontSize: AppScale.fontSize(11),
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.accent,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to change name',
                                        style: TextStyle(
                                          fontSize: AppScale.fontSize(13),
                                          color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: AppScale.size(24)),

                // ── 2. HOUSEHOLD ──
                _SectionHeader('Household'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppScale.padding(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Currency selector
                        Row(
                          children: [
                            Container(
                              width: AppScale.size(36),
                              height: AppScale.size(36),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(Icons.language_rounded,
                                  size: AppScale.size(18), color: AppColors.primary),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Currency',
                              style: TextStyle(
                                fontSize: AppScale.fontSize(15),
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 10),
                        Builder(
                          builder: (context) {
                            final currentCurrency = AppCurrency.getByCode(household.currency);
                            return DropdownButtonFormField<String>(
                              initialValue: currentCurrency.code,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: EdgeInsets.symmetric(horizontal: AppScale.padding(14), vertical: AppScale.padding(12)),
                              ),
                              dropdownColor: isDark ? AppColors.darkSurface : AppColors.surface,
                              style: TextStyle(
                                fontSize: AppScale.fontSize(14),
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                              items: AppCurrency.list.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c.code,
                                  child: Text('${c.symbol}  ${c.name} (${c.code})'),
                                );
                              }).toList(),
                              onChanged: (code) {
                                if (code != null) {
                                  context.read<HouseholdProvider>().updateCurrency(code);
                                }
                              },
                            );
                          },
                        ),
                        SizedBox(height: AppScale.size(16)),
                        Divider(
                          height: 1,
                          color: isDark ? AppColors.darkDivider : AppColors.divider,
                        ),
                        const SizedBox(height: 12),
                        // Members list
                        for (int i = 0; i < members.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: isDark ? AppColors.darkDivider : AppColors.divider,
                            ),
                          Padding(
                              padding: EdgeInsets.symmetric(vertical: AppScale.padding(10)),
                              child: Row(
                                children: [
                                  Container(
                                    width: AppScale.size(36),
                                    height: AppScale.size(36),
                                    decoration: BoxDecoration(
                                      color: AppColors.memberColor(i).withAlpha(25),
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    child: Center(
                                      child: Text(
                                        members[i].name.isNotEmpty
                                            ? members[i].name[0].toUpperCase()
                                            : '?',
                                        style: TextStyle(
                                          fontSize: AppScale.fontSize(16),
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.memberColor(i),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      members[i].name,
                                      style: TextStyle(
                                        fontSize: AppScale.fontSize(15),
                                        fontWeight: FontWeight.w600,
                                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (members[i].isAdmin)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: AppScale.padding(8), vertical: AppScale.padding(3)),
                                      margin: EdgeInsets.only(right: AppScale.padding(6)),
                                      decoration: BoxDecoration(
                                        color: AppColors.accent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: Text(
                                        'Admin',
                                        style: TextStyle(
                                          fontSize: AppScale.fontSize(11),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.accent,
                                        ),
                                      ),
                                    ),
                                  if (currentMember?.id == members[i].id)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: AppScale.padding(8), vertical: AppScale.padding(3)),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(AppRadius.sm),
                                      ),
                                      child: Text(
                                        'You',
                                        style: TextStyle(
                                          fontSize: AppScale.fontSize(11),
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                        if (isAdmin) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showAddMemberDialog(context, household),
                              icon: Icon(Icons.person_add_rounded, size: AppScale.size(18)),
                              label: const Text('Add Member'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: BorderSide(
                                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                padding: EdgeInsets.symmetric(vertical: AppScale.padding(12)),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: isDark ? AppColors.darkDivider : AppColors.divider,
                        ),
                        const SizedBox(height: 4),
                        // Manage Recurring Bills
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: AppScale.size(36),
                            height: AppScale.size(36),
                            decoration: BoxDecoration(
                              color: AppColors.accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Icon(Icons.repeat_rounded,
                                size: AppScale.size(18), color: AppColors.accent),
                          ),
                          title: Text(
                            'Manage Recurring Bills',
                            style: TextStyle(
                              fontSize: AppScale.fontSize(15),
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                            ),
                          ),
                          trailing: Icon(Icons.chevron_right_rounded,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                          onTap: () => Navigator.pushNamed(context, '/recurring-bills'),
                        ),
                        if (isAdmin && context.watch<AuthProvider>().isAuthenticated) ...[
                          const SizedBox(height: 4),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              width: AppScale.size(36),
                              height: AppScale.size(36),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(Icons.person_add_rounded,
                                  size: AppScale.size(18), color: AppColors.primary),
                            ),
                            title: Text(
                              'Invite Members',
                              style: TextStyle(
                                fontSize: AppScale.fontSize(15),
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                              ),
                            ),
                            trailing: Icon(Icons.chevron_right_rounded,
                                color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
                            onTap: () => Navigator.pushNamed(context, '/invite'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppScale.size(24)),

                // ── 3. APPEARANCE ──
                _SectionHeader('Appearance'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppScale.padding(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: AppScale.size(36),
                              height: AppScale.size(36),
                              decoration: BoxDecoration(
                                color: AppColors.accent.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(Icons.palette_outlined,
                                  size: AppScale.size(18), color: AppColors.accent),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dark Mode',
                                    style: TextStyle(
                                      fontSize: AppScale.fontSize(15),
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    switch (settings.themeMode) {
                                      ThemeMode.light => 'Off',
                                      ThemeMode.dark => 'On',
                                      ThemeMode.system => 'System default',
                                    },
                                    style: TextStyle(
                                      fontSize: AppScale.fontSize(13),
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<ThemeMode>(
                            segments: [
                              ButtonSegment(
                                value: ThemeMode.light,
                                icon: Icon(Icons.light_mode, size: AppScale.size(18)),
                              ),
                              ButtonSegment(
                                value: ThemeMode.system,
                                icon: Icon(Icons.phone_android, size: AppScale.size(18)),
                              ),
                              ButtonSegment(
                                value: ThemeMode.dark,
                                icon: Icon(Icons.dark_mode, size: AppScale.size(18)),
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
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                              side: WidgetStatePropertyAll(
                                BorderSide(
                                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppScale.size(24)),

                // ── 4. RECEIPT SCANNING ──
                _SectionHeader('Receipt Scanning'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppScale.padding(16)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: AppScale.size(36),
                              height: AppScale.size(36),
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: Icon(Icons.auto_awesome_outlined,
                                  size: AppScale.size(18), color: AppColors.primaryLight),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Groq API Key',
                                    style: TextStyle(
                                      fontSize: AppScale.fontSize(15),
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Free at console.groq.com',
                                    style: TextStyle(
                                      fontSize: AppScale.fontSize(13),
                                      color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Status indicator dot
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: settings.apiKey.isNotEmpty
                                    ? AppColors.positive
                                    : AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: AppScale.size(16)),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _apiKeyController,
                                decoration: InputDecoration(
                                  hintText: 'gsk_...',
                                  hintStyle: TextStyle(
                                    color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                                  ),
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
                                  isDense: true,
                                  contentPadding: EdgeInsets.symmetric(
                                      horizontal: AppScale.padding(14), vertical: AppScale.padding(12)),
                                ),
                                style: TextStyle(
                                  fontSize: AppScale.fontSize(13),
                                  fontFamily: 'monospace',
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
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
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: AppScale.padding(20), vertical: AppScale.padding(12)),
                              ),
                              child: const Text('Save'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: AppScale.padding(12), vertical: AppScale.padding(8)),
                          decoration: BoxDecoration(
                            color: settings.apiKey.isNotEmpty
                                ? AppColors.positiveSurface
                                : AppColors.warningSurface,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                settings.apiKey.isNotEmpty
                                    ? Icons.check_circle
                                    : Icons.info_outline,
                                size: AppScale.size(14),
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
                                  fontSize: AppScale.fontSize(12),
                                  fontWeight: FontWeight.w600,
                                  color: settings.apiKey.isNotEmpty
                                      ? AppColors.positive
                                      : AppColors.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: AppScale.size(24)),

                // ── 5. ABOUT ──
                _SectionHeader('About'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppScale.padding(16)),
                    child: Row(
                      children: [
                        Container(
                          width: AppScale.size(44),
                          height: AppScale.size(44),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Icon(
                            Icons.receipt_long_rounded,
                            size: AppScale.size(22),
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Bill Split',
                                style: TextStyle(
                                  fontSize: AppScale.fontSize(16),
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Version 1.0.0',
                                style: TextStyle(
                                  fontSize: AppScale.fontSize(13),
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── 6. DANGER ZONE (admin only) ──
                if (isAdmin) ...[
                  SizedBox(height: AppScale.size(24)),
                  _SectionHeader('Danger Zone'),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(
                        color: AppColors.negative.withValues(alpha: 0.3),
                      ),
                    ),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                      leading: Container(
                        width: AppScale.size(36),
                        height: AppScale.size(36),
                        decoration: BoxDecoration(
                          color: AppColors.negative.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Icon(Icons.delete_forever_rounded,
                            size: AppScale.size(18), color: AppColors.negative),
                      ),
                      title: Text(
                        'Delete Household',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(15),
                          fontWeight: FontWeight.w600,
                          color: AppColors.negative,
                        ),
                      ),
                      subtitle: Text(
                        'Permanently delete this household and all its data',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(12),
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
                        ),
                      ),
                      onTap: () => _confirmDeleteHousehold(context),
                    ),
                  ),
                ],
                // ── 7. SIGN OUT ──
                if (context.watch<AuthProvider>().isAuthenticated) ...[
                  SizedBox(height: AppScale.size(24)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppScale.padding(16)),
                    child: SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final pushSvc = context.read<PushNotificationService>();
                          final notifSvc = context.read<NotificationService>();
                          final authProv = context.read<AuthProvider>();
                          await pushSvc.removeToken();
                          notifSvc.unsubscribe();
                          await authProv.signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
                          }
                        },
                        icon: Icon(Icons.logout_rounded, color: AppColors.negative, size: AppScale.size(18)),
                        label: Text('Sign Out', style: TextStyle(color: AppColors.negative, fontWeight: FontWeight.w600)),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.negative.withValues(alpha: 0.3)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                          padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                        ),
                      ),
                    ),
                  ),
                ],
                SizedBox(height: AppScale.size(24)),
              ],
            );
          },
        ),
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
        actionsPadding: EdgeInsets.fromLTRB(AppScale.padding(24), 0, AppScale.padding(24), AppScale.padding(20)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            height: AppScale.size(48),
            child: FilledButton(
              onPressed: () async {
                if (controller.text.trim().isNotEmpty) {
                  await provider.addMember(controller.text);
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
              child: const Text('Add', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: AppScale.size(48),
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                side: BorderSide(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
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
          ),
        ],
      ),
    );
  }

  void _confirmDeleteHousehold(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.read<HouseholdProvider>();
    final householdName = provider.currentHousehold?.name ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        title: Text('Delete Household?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
            )),
        content: Text(
          'This will delete "$householdName" and all its bills. This cannot be undone.',
          style: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: AppColors.textTertiary)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.negative,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            onPressed: () async {
              final householdId = provider.currentHousehold?.id;
              if (householdId != null) {
                Navigator.pop(ctx); // close dialog
                await provider.deleteHousehold(householdId);
                if (context.mounted) {
                  Navigator.pushNamedAndRemoveUntil(context, '/households', (route) => false);
                }
              }
            },
            child: const Text('Delete'),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: AppScale.fontSize(12),
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary,
        letterSpacing: 1.2,
      ),
    );
  }
}
