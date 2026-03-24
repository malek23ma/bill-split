import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../constants.dart';
import '../services/invite_service.dart';

class JoinHouseholdScreen extends StatefulWidget {
  const JoinHouseholdScreen({super.key});

  @override
  State<JoinHouseholdScreen> createState() => _JoinHouseholdScreenState();
}

class _JoinHouseholdScreenState extends State<JoinHouseholdScreen> {
  final _codeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _validating = false;
  bool _joining = false;
  Map<String, dynamic>? _invite;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _validateCode(String code) async {
    if (code.length != 8) return;
    setState(() {
      _validating = true;
      _invite = null;
      _error = null;
    });
    try {
      final service = context.read<InviteService>();
      final result = await service.getInviteByCode(code);
      if (!mounted) return;
      if (result == null) {
        setState(() => _error = 'Invalid or already claimed invite code.');
      } else {
        final expiresAt = DateTime.parse(result['expires_at'] as String);
        if (DateTime.now().toUtc().isAfter(expiresAt)) {
          setState(() => _error = 'This invite code has expired.');
        } else {
          setState(() => _invite = result);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error validating code: $e');
    } finally {
      if (mounted) setState(() => _validating = false);
    }
  }

  Future<void> _joinHousehold() async {
    if (_invite == null) return;
    setState(() => _joining = true);
    try {
      final service = context.read<InviteService>();
      final success = await service.claimInvite(_invite!['id'] as String);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined household!')),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() => _error = 'Failed to join. The invite may have expired or been claimed.');
        setState(() => _invite = null);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Error joining household: $e');
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  void _openScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.black,
      builder: (ctx) => SizedBox(
        height: MediaQuery.of(ctx).size.height * 0.6,
        child: Stack(
          children: [
            MobileScanner(
              onDetect: (capture) {
                final barcodes = capture.barcodes;
                if (barcodes.isNotEmpty) {
                  final code = barcodes.first.rawValue;
                  if (code != null && code.length == 8) {
                    Navigator.of(ctx).pop();
                    _codeController.text = code.toUpperCase();
                    _validateCode(code.toUpperCase());
                  }
                }
              },
            ),
            Positioned(
              top: AppScale.padding(12),
              right: AppScale.padding(12),
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              ),
            ),
            Positioned(
              bottom: AppScale.padding(24),
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Scan the invite QR code',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: AppScale.fontSize(15),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final householdName = _invite != null
        ? ((_invite!['households'] as Map<String, dynamic>?)?['name'] as String?)
        : null;
    final memberIdAssigned = _invite?['member_id'] as String?;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      appBar: AppBar(
        title: Text(
          'Join Household',
          style: TextStyle(fontSize: AppScale.fontSize(18)),
        ),
        backgroundColor: isDark ? AppColors.darkSurface : AppColors.surface,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(AppScale.padding(20)),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the 8-character invite code or scan a QR code to join a household.',
                style: TextStyle(
                  fontSize: AppScale.fontSize(14),
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                ),
              ),
              SizedBox(height: AppScale.padding(24)),
              TextFormField(
                controller: _codeController,
                maxLength: 8,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: AppScale.fontSize(24),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 6,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'ABCD1234',
                  hintStyle: TextStyle(
                    fontSize: AppScale.fontSize(24),
                    letterSpacing: 6,
                    color: isDark ? AppColors.darkTextSecondary.withAlpha(100) : AppColors.textTertiary,
                  ),
                  counterText: '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: AppScale.padding(16),
                    horizontal: AppScale.padding(16),
                  ),
                ),
                inputFormatters: [
                  _UpperCaseTextFormatter(),
                ],
                onChanged: (v) {
                  setState(() {
                    _invite = null;
                    _error = null;
                  });
                  if (v.length == 8) _validateCode(v);
                },
                validator: (v) {
                  if (v == null || v.length != 8) return 'Code must be 8 characters';
                  return null;
                },
              ),
              SizedBox(height: AppScale.padding(12)),
              OutlinedButton.icon(
                onPressed: _openScanner,
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: Text(
                  'Scan QR Code',
                  style: TextStyle(fontSize: AppScale.fontSize(15)),
                ),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
              ),
              SizedBox(height: AppScale.padding(20)),

              // Validation status
              if (_validating)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppScale.padding(16)),
                    child: const CircularProgressIndicator(),
                  ),
                ),

              if (_error != null)
                Container(
                  padding: EdgeInsets.all(AppScale.padding(12)),
                  decoration: BoxDecoration(
                    color: AppColors.negativeSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          color: AppColors.negative, size: AppScale.size(20)),
                      SizedBox(width: AppScale.padding(8)),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            fontSize: AppScale.fontSize(13),
                            color: AppColors.negative,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              if (_invite != null) ...[
                Container(
                  padding: EdgeInsets.all(AppScale.padding(16)),
                  decoration: BoxDecoration(
                    color: AppColors.positiveSurface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.positive.withAlpha(60)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded,
                              color: AppColors.positive, size: AppScale.size(20)),
                          SizedBox(width: AppScale.padding(8)),
                          Text(
                            'Valid Invite',
                            style: TextStyle(
                              fontSize: AppScale.fontSize(15),
                              fontWeight: FontWeight.w600,
                              color: AppColors.positive,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppScale.padding(12)),
                      if (householdName != null)
                        Row(
                          children: [
                            Icon(Icons.home_rounded,
                                size: AppScale.size(18),
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary),
                            SizedBox(width: AppScale.padding(8)),
                            Text(
                              'Household: $householdName',
                              style: TextStyle(
                                fontSize: AppScale.fontSize(14),
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      if (memberIdAssigned != null) ...[
                        SizedBox(height: AppScale.padding(6)),
                        Row(
                          children: [
                            Icon(Icons.person_rounded,
                                size: AppScale.size(18),
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary),
                            SizedBox(width: AppScale.padding(8)),
                            Text(
                              'Assigned to an existing member',
                              style: TextStyle(
                                fontSize: AppScale.fontSize(13),
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(height: AppScale.padding(20)),
                FilledButton.icon(
                  onPressed: _joining ? null : _joinHousehold,
                  icon: _joining
                      ? SizedBox(
                          width: AppScale.size(18),
                          height: AppScale.size(18),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(
                    'Join Household',
                    style: TextStyle(fontSize: AppScale.fontSize(16)),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.positive,
                    padding: EdgeInsets.symmetric(vertical: AppScale.padding(14)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
