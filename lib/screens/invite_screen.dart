import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../constants.dart';
import '../services/invite_service.dart';
import '../providers/household_provider.dart';
import '../models/member.dart';

class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  // Code tab state
  String? _generatedCode;
  bool _generatingCode = false;

  // Email/Phone tab state
  bool _isEmail = true;
  final _contactController = TextEditingController();
  final _contactFormKey = GlobalKey<FormState>();
  bool _sendingInvite = false;
  String? _sendResult;
  bool _sendSuccess = false;

  // QR tab state
  String? _qrCode;
  bool _generatingQr = false;

  // Shared state
  String? _selectedMemberId;
  List<Map<String, dynamic>> _invites = [];
  bool _loadingInvites = false;

  @override
  void initState() {
    super.initState();
    _loadInvites();
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  String? get _householdId {
    final hh = context.read<HouseholdProvider>().currentHousehold;
    return hh?.remoteId;
  }

  List<Member> get _unclaimedMembers {
    return context.read<HouseholdProvider>().members;
  }

  Future<void> _loadInvites() async {
    final hhId = _householdId;
    if (hhId == null) return;
    setState(() => _loadingInvites = true);
    try {
      final service = context.read<InviteService>();
      final result = await service.getHouseholdInvites(hhId);
      if (mounted) setState(() => _invites = result);
    } catch (_) {
      // silently fail
    } finally {
      if (mounted) setState(() => _loadingInvites = false);
    }
  }

  Future<void> _generateCode() async {
    final hhId = _householdId;
    if (hhId == null) return;
    setState(() => _generatingCode = true);
    try {
      final service = context.read<InviteService>();
      final result = await service.createInvite(
        householdId: hhId,
        memberId: _selectedMemberId,
      );
      if (mounted) {
        setState(() => _generatedCode = result['invite_code'] as String?);
        _loadInvites();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate code: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingCode = false);
    }
  }

  Future<void> _sendContactInvite() async {
    if (!_contactFormKey.currentState!.validate()) return;
    final hhId = _householdId;
    if (hhId == null) return;
    setState(() {
      _sendingInvite = true;
      _sendResult = null;
    });
    try {
      final service = context.read<InviteService>();
      final result = await service.createInvite(
        householdId: hhId,
        memberId: _selectedMemberId,
        email: _isEmail ? _contactController.text.trim() : null,
        phone: !_isEmail ? _contactController.text.trim() : null,
      );
      final code = result['invite_code'] as String?;
      if (mounted) {
        setState(() {
          _sendResult = 'Invite sent! Code: $code';
          _sendSuccess = true;
        });
        _contactController.clear();
        _loadInvites();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendResult = 'Failed to send invite: $e';
          _sendSuccess = false;
        });
      }
    } finally {
      if (mounted) setState(() => _sendingInvite = false);
    }
  }

  Future<void> _generateQrCode() async {
    final hhId = _householdId;
    if (hhId == null) return;
    setState(() => _generatingQr = true);
    try {
      final service = context.read<InviteService>();
      final result = await service.createInvite(
        householdId: hhId,
        memberId: _selectedMemberId,
      );
      if (mounted) {
        setState(() => _qrCode = result['invite_code'] as String?);
        _loadInvites();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate QR: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingQr = false);
    }
  }

  Future<void> _revokeInvite(String inviteId) async {
    try {
      final service = context.read<InviteService>();
      await service.revokeInvite(inviteId);
      _loadInvites();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to revoke: $e')),
        );
      }
    }
  }

  String _inviteStatus(Map<String, dynamic> invite) {
    if (invite['claimed_by_user_id'] != null) return 'Claimed';
    final expiresAt = DateTime.parse(invite['expires_at'] as String);
    if (DateTime.now().toUtc().isAfter(expiresAt)) return 'Expired';
    return 'Active';
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Active':
        return AppColors.positive;
      case 'Expired':
        return AppColors.warning;
      case 'Claimed':
        return AppColors.neutral;
      default:
        return AppColors.neutral;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
        appBar: AppBar(
          title: Text(
            'Invite Members',
            style: TextStyle(fontSize: AppScale.fontSize(18)),
          ),
          backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Code'),
              Tab(text: 'Email/Phone'),
              Tab(text: 'QR'),
            ],
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: TabBarView(
                children: [
                  _buildCodeTab(isDark),
                  _buildContactTab(isDark),
                  _buildQrTab(isDark),
                ],
              ),
            ),
            _buildInvitesList(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberDropdown(bool isDark) {
    final members = _unclaimedMembers;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppScale.padding(16),
        vertical: AppScale.padding(8),
      ),
      child: DropdownButtonFormField<String?>(
        value: _selectedMemberId,
        decoration: InputDecoration(
          labelText: 'Assign to member (optional)',
          labelStyle: TextStyle(
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            fontSize: AppScale.fontSize(14),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          filled: true,
          fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
        ),
        dropdownColor: isDark ? AppColors.darkSurface : AppColors.surface,
        items: [
          DropdownMenuItem<String?>(
            value: null,
            child: Text(
              'No assignment',
              style: TextStyle(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                fontSize: AppScale.fontSize(14),
              ),
            ),
          ),
          ...members.map((m) => DropdownMenuItem<String?>(
                value: m.remoteId ?? m.id.toString(),
                child: Text(
                  m.name,
                  style: TextStyle(
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    fontSize: AppScale.fontSize(14),
                  ),
                ),
              )),
        ],
        onChanged: (v) => setState(() => _selectedMemberId = v),
      ),
    );
  }

  Widget _buildCodeTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppScale.padding(16)),
      child: Column(
        children: [
          _buildMemberDropdown(isDark),
          SizedBox(height: AppScale.padding(16)),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generatingCode ? null : _generateCode,
              icon: _generatingCode
                  ? SizedBox(
                      width: AppScale.size(18),
                      height: AppScale.size(18),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.vpn_key_rounded),
              label: Text(
                'Generate Invite Code',
                style: TextStyle(fontSize: AppScale.fontSize(15)),
              ),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          if (_generatedCode != null) ...[
            SizedBox(height: AppScale.padding(24)),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(AppScale.padding(20)),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'Invite Code',
                    style: TextStyle(
                      fontSize: AppScale.fontSize(13),
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppScale.padding(8)),
                  Text(
                    _generatedCode!,
                    style: TextStyle(
                      fontSize: AppScale.fontSize(32),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 4,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(height: AppScale.padding(16)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: _generatedCode!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code copied!')),
                          );
                        },
                        icon: const Icon(Icons.copy_rounded),
                        label: const Text('Copy'),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                      SizedBox(width: AppScale.padding(12)),
                      FilledButton.icon(
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(
                              text: 'Join my household! Use invite code: $_generatedCode',
                            ),
                          );
                        },
                        icon: const Icon(Icons.share_rounded),
                        label: const Text('Share'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppScale.padding(16)),
      child: Form(
        key: _contactFormKey,
        child: Column(
          children: [
            _buildMemberDropdown(isDark),
            SizedBox(height: AppScale.padding(12)),
            // Email / Phone toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isEmail = true;
                      _contactController.clear();
                      _sendResult = null;
                    }),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: AppScale.padding(10)),
                      decoration: BoxDecoration(
                        color: _isEmail ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: _isEmail
                              ? AppColors.primary
                              : (isDark ? AppColors.darkDivider : AppColors.divider),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Email',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(14),
                          fontWeight: FontWeight.w600,
                          color: _isEmail
                              ? Colors.white
                              : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppScale.padding(8)),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _isEmail = false;
                      _contactController.clear();
                      _sendResult = null;
                    }),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: AppScale.padding(10)),
                      decoration: BoxDecoration(
                        color: !_isEmail ? AppColors.primary : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(
                          color: !_isEmail
                              ? AppColors.primary
                              : (isDark ? AppColors.darkDivider : AppColors.divider),
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Phone',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(14),
                          fontWeight: FontWeight.w600,
                          color: !_isEmail
                              ? Colors.white
                              : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: AppScale.padding(16)),
            TextFormField(
              controller: _contactController,
              keyboardType: _isEmail ? TextInputType.emailAddress : TextInputType.phone,
              style: TextStyle(
                fontSize: AppScale.fontSize(15),
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
              decoration: InputDecoration(
                labelText: _isEmail ? 'Email address' : 'Phone number',
                labelStyle: TextStyle(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
                prefixIcon: Icon(
                  _isEmail ? Icons.email_rounded : Icons.phone_rounded,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                filled: true,
                fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return _isEmail ? 'Enter an email' : 'Enter a phone number';
                }
                if (_isEmail && !v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            SizedBox(height: AppScale.padding(16)),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sendingInvite ? null : _sendContactInvite,
                icon: _sendingInvite
                    ? SizedBox(
                        width: AppScale.size(18),
                        height: AppScale.size(18),
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded),
                label: Text(
                  'Send Invite',
                  style: TextStyle(fontSize: AppScale.fontSize(15)),
                ),
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
            ),
            if (_sendResult != null) ...[
              SizedBox(height: AppScale.padding(12)),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(AppScale.padding(12)),
                decoration: BoxDecoration(
                  color: _sendSuccess
                      ? AppColors.positiveSurface
                      : AppColors.negativeSurface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Text(
                  _sendResult!,
                  style: TextStyle(
                    fontSize: AppScale.fontSize(13),
                    color: _sendSuccess ? AppColors.positive : AppColors.negative,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQrTab(bool isDark) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(AppScale.padding(16)),
      child: Column(
        children: [
          _buildMemberDropdown(isDark),
          SizedBox(height: AppScale.padding(16)),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _generatingQr ? null : _generateQrCode,
              icon: _generatingQr
                  ? SizedBox(
                      width: AppScale.size(18),
                      height: AppScale.size(18),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.qr_code_rounded),
              label: Text(
                'Generate QR Code',
                style: TextStyle(fontSize: AppScale.fontSize(15)),
              ),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ),
          if (_qrCode != null) ...[
            SizedBox(height: AppScale.padding(24)),
            Container(
              padding: EdgeInsets.all(AppScale.padding(20)),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: isDark ? AppColors.darkDivider : AppColors.divider,
                ),
              ),
              child: Column(
                children: [
                  QrImageView(
                    data: _qrCode!,
                    version: QrVersions.auto,
                    size: AppScale.size(200),
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.roundedRect,
                      color: AppColors.primary,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.roundedRect,
                      color: AppColors.primary,
                    ),
                    backgroundColor: Colors.white,
                  ),
                  SizedBox(height: AppScale.padding(12)),
                  Text(
                    _qrCode!,
                    style: TextStyle(
                      fontSize: AppScale.fontSize(18),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvitesList(bool isDark) {
    return Container(
      constraints: BoxConstraints(maxHeight: AppScale.size(220)),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.darkDivider : AppColors.divider,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppScale.padding(16),
              AppScale.padding(12),
              AppScale.padding(16),
              AppScale.padding(4),
            ),
            child: Row(
              children: [
                Text(
                  'Invites',
                  style: TextStyle(
                    fontSize: AppScale.fontSize(14),
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (_loadingInvites)
                  SizedBox(
                    width: AppScale.size(16),
                    height: AppScale.size(16),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Flexible(
            child: _invites.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(AppScale.padding(16)),
                    child: Center(
                      child: Text(
                        'No invites yet',
                        style: TextStyle(
                          fontSize: AppScale.fontSize(13),
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppScale.padding(16),
                      vertical: AppScale.padding(4),
                    ),
                    shrinkWrap: true,
                    itemCount: _invites.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: isDark ? AppColors.darkDivider : AppColors.divider),
                    itemBuilder: (context, index) {
                      final invite = _invites[index];
                      final code = invite['invite_code'] as String? ?? '';
                      final status = _inviteStatus(invite);
                      final color = _statusColor(status);

                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: AppScale.padding(6)),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    code,
                                    style: TextStyle(
                                      fontSize: AppScale.fontSize(14),
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 1,
                                      color: isDark
                                          ? AppColors.darkTextPrimary
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  if (invite['invited_email'] != null)
                                    Text(
                                      invite['invited_email'] as String,
                                      style: TextStyle(
                                        fontSize: AppScale.fontSize(12),
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                  if (invite['invited_phone'] != null)
                                    Text(
                                      invite['invited_phone'] as String,
                                      style: TextStyle(
                                        fontSize: AppScale.fontSize(12),
                                        color: isDark
                                            ? AppColors.darkTextSecondary
                                            : AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppScale.padding(10),
                                vertical: AppScale.padding(4),
                              ),
                              decoration: BoxDecoration(
                                color: color.withAlpha(30),
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                status,
                                style: TextStyle(
                                  fontSize: AppScale.fontSize(12),
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                            if (status == 'Active') ...[
                              SizedBox(width: AppScale.padding(8)),
                              IconButton(
                                onPressed: () => _revokeInvite(invite['id'] as String),
                                icon: Icon(
                                  Icons.close_rounded,
                                  size: AppScale.size(18),
                                  color: AppColors.negative,
                                ),
                                tooltip: 'Revoke',
                                visualDensity: VisualDensity.compact,
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
