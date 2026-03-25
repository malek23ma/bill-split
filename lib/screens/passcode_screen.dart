import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';
import '../services/passcode_service.dart';

class PasscodeScreen extends StatefulWidget {
  final String userId;
  final void Function() onSuccess;

  const PasscodeScreen({
    super.key,
    required this.userId,
    required this.onSuccess,
  });

  @override
  State<PasscodeScreen> createState() => _PasscodeScreenState();
}

class _PasscodeScreenState extends State<PasscodeScreen>
    with SingleTickerProviderStateMixin {
  String _entered = '';
  bool _error = false;
  late AnimationController _shakeController;
  final _passcodeService = PasscodeService();

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDigit(int digit) async {
    if (_entered.length >= 4) return;
    setState(() {
      _entered += digit.toString();
      _error = false;
    });
    if (_entered.length == 4) {
      debugPrint('PASSCODE: verifying "$_entered" for userId=${widget.userId}');
      final correct =
          await _passcodeService.verifyPasscode(widget.userId, _entered);
      debugPrint('PASSCODE: result=$correct');
      if (correct) {
        widget.onSuccess();
      } else {
        _shakeController.forward(from: 0);
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted) {
          setState(() {
            _error = true;
            _entered = '';
          });
        }
      }
    }
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() {
      _entered = _entered.substring(0, _entered.length - 1);
      _error = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final keySize = AppScale.size(64);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // Lock icon
            Icon(Icons.lock_rounded,
                size: AppScale.size(48), color: AppColors.primary),
            SizedBox(height: AppScale.size(16)),
            Text(
              'Enter Passcode',
              style: TextStyle(
                fontSize: AppScale.fontSize(20),
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppScale.size(32)),
            // Dots with shake animation
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final offset = _shakeController.isAnimating
                    ? sin(_shakeController.value * pi * 4) *
                        8.0 *
                        (1 - _shakeController.value)
                    : 0.0;
                return Transform.translate(
                  offset: Offset(offset, 0),
                  child: child,
                );
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _entered.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.symmetric(horizontal: AppScale.padding(10)),
                    width: AppScale.size(18),
                    height: AppScale.size(18),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (_error ? AppColors.negative : AppColors.primary)
                          : Colors.transparent,
                      border: Border.all(
                        color: _error
                            ? AppColors.negative
                            : (filled
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textTertiary)),
                        width: 2,
                      ),
                    ),
                  );
                }),
              ),
            ),
            if (_error)
              Padding(
                padding: EdgeInsets.only(top: AppScale.padding(12)),
                child: Text(
                  'Wrong passcode',
                  style: TextStyle(
                    color: AppColors.negative,
                    fontSize: AppScale.fontSize(13),
                  ),
                ),
              ),
            const Spacer(flex: 1),
            // Number pad
            Padding(
              padding: EdgeInsets.symmetric(horizontal: AppScale.padding(32)),
              child: Column(
                children: [
                  // Row 1: 1, 2, 3
                  _buildKeyRow([1, 2, 3], isDark, keySize),
                  // Row 2: 4, 5, 6
                  _buildKeyRow([4, 5, 6], isDark, keySize),
                  // Row 3: 7, 8, 9
                  _buildKeyRow([7, 8, 9], isDark, keySize),
                  // Row 4: empty, 0, backspace
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(width: keySize, height: keySize),
                      _buildKey(0, isDark, keySize),
                      _buildBackspaceKey(isDark, keySize),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: AppScale.size(16)),
            // Forgot passcode
            TextButton(
              onPressed: _showForgotDialog,
              child: Text(
                'Forgot passcode? Sign out',
                style: TextStyle(
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textTertiary,
                  fontSize: AppScale.fontSize(13),
                ),
              ),
            ),
            SizedBox(height: AppScale.size(16)),
          ],
        ),
      ),
    );
  }

  Widget _buildKeyRow(List<int> digits, bool isDark, double keySize) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: digits.map((d) => _buildKey(d, isDark, keySize)).toList(),
    );
  }

  Widget _buildKey(int digit, bool isDark, double keySize) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Material(
        color: isDark ? AppColors.darkSurface : AppColors.surface,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: () => _onDigit(digit),
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: keySize,
            height: keySize,
            child: Center(
              child: Text(
                '$digit',
                style: TextStyle(
                  fontSize: AppScale.fontSize(24),
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(bool isDark, double keySize) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: InkWell(
        onTap: _onBackspace,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: keySize,
          height: keySize,
          child: Center(
            child: Icon(Icons.backspace_outlined,
                size: AppScale.size(24),
                color: isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
          ),
        ),
      ),
    );
  }

  void _showForgotDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Forgot Passcode?'),
        content: const Text(
            'You need to sign out and sign back in to reset your passcode.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Supabase.instance.client.auth.signOut();
              Navigator.pushNamedAndRemoveUntil(
                  context, '/auth', (route) => false);
            },
            child: Text('Sign Out',
                style: TextStyle(color: AppColors.negative)),
          ),
        ],
      ),
    );
  }
}
