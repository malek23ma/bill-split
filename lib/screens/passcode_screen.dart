import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants.dart';
import '../services/passcode_service.dart';

class PasscodeScreen extends StatefulWidget {
  final String userId;
  final VoidCallback onSuccess;

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
      duration: const Duration(milliseconds: 500),
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
      final correct =
          await _passcodeService.verifyPasscode(widget.userId, _entered);
      if (correct) {
        widget.onSuccess();
      } else {
        _shakeController.forward(from: 0);
        setState(() {
          _error = true;
          _entered = '';
        });
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
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Icon(Icons.lock_rounded,
                size: AppScale.size(48), color: AppColors.primary),
            SizedBox(height: AppScale.size(16)),
            Text(
              'Enter Passcode',
              style: TextStyle(
                fontSize: AppScale.fontSize(20),
                fontWeight: FontWeight.w700,
                color:
                    isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
              ),
            ),
            SizedBox(height: AppScale.size(32)),
            // Dots with shake animation
            AnimatedBuilder(
              animation: _shakeController,
              builder: (context, child) {
                final sineValue =
                    sin(_shakeController.value * pi * 4);
                final offset = _shakeController.isAnimating
                    ? sineValue * 8.0 * (1 - _shakeController.value)
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
                  return Container(
                    margin: EdgeInsets.symmetric(
                        horizontal: AppScale.padding(8)),
                    width: AppScale.size(16),
                    height: AppScale.size(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled
                          ? (_error ? AppColors.negative : AppColors.primary)
                          : Colors.transparent,
                      border: Border.all(
                        color: _error
                            ? AppColors.negative
                            : (isDark
                                ? AppColors.darkTextSecondary
                                : AppColors.textTertiary),
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
                      fontSize: AppScale.fontSize(13)),
                ),
              ),
            const Spacer(),
            // Number pad
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: AppScale.padding(40)),
              child: Column(
                children: [
                  for (int row = 0; row < 4; row++)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (row < 3)
                          for (int col = 0; col < 3; col++)
                            _buildKey(row * 3 + col + 1, isDark),
                        if (row == 3) ...[
                          const SizedBox(width: 64, height: 64),
                          _buildKey(0, isDark),
                          _buildBackspaceKey(isDark),
                        ],
                      ],
                    ),
                ],
              ),
            ),
            SizedBox(height: AppScale.size(16)),
            TextButton(
              onPressed: () {
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
              },
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
            SizedBox(height: AppScale.size(24)),
          ],
        ),
      ),
    );
  }

  Widget _buildKey(int digit, bool isDark) {
    return GestureDetector(
      onTap: () => _onDigit(digit),
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.darkSurface : AppColors.surface,
        ),
        alignment: Alignment.center,
        child: Text(
          '$digit',
          style: TextStyle(
            fontSize: AppScale.fontSize(24),
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildBackspaceKey(bool isDark) {
    return GestureDetector(
      onTap: _onBackspace,
      child: Container(
        width: 64,
        height: 64,
        margin: const EdgeInsets.all(8),
        alignment: Alignment.center,
        child: Icon(Icons.backspace_outlined,
            color:
                isDark ? AppColors.darkTextSecondary : AppColors.textTertiary),
      ),
    );
  }
}
