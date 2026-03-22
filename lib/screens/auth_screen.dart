import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../constants.dart';

class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Welcome'),
          bottom: TabBar(
            tabs: const [
              Tab(text: 'Sign Up'),
              Tab(text: 'Sign In'),
            ],
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelStyle: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: AppScale.fontSize(14),
            ),
          ),
        ),
        body: const TabBarView(
          children: [
            _AuthTab(isSignUp: true),
            _AuthTab(isSignUp: false),
          ],
        ),
      ),
    );
  }
}

// ─── Auth Mode ────────────────────────────────────────────

enum _AuthMode { email, phone }

// ─── Auth Tab ─────────────────────────────────────────────

class _AuthTab extends StatefulWidget {
  final bool isSignUp;
  const _AuthTab({required this.isSignUp});

  @override
  State<_AuthTab> createState() => _AuthTabState();
}

class _AuthTabState extends State<_AuthTab>
    with AutomaticKeepAliveClientMixin {
  _AuthMode _mode = _AuthMode.email;
  bool _codeSent = false;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _obscurePassword = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // ── Actions ──

  Future<void> _submitEmail() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    bool success;
    if (widget.isSignUp) {
      success = await auth.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
        _nameController.text.trim(),
      );
    } else {
      success = await auth.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/households');
    }
  }

  Future<void> _sendCode() async {
    if (_phoneController.text.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    final sent = await auth.sendPhoneOtp(_phoneController.text.trim());
    if (sent && mounted) {
      setState(() => _codeSent = true);
    }
  }

  Future<void> _verifyCode() async {
    if (_otpController.text.trim().isEmpty) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.verifyPhoneOtp(
      _phoneController.text.trim(),
      _otpController.text.trim(),
    );
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/households');
    }
  }

  Future<void> _socialSignIn(Future<bool> Function() method) async {
    final success = await method();
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, '/households');
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final subtitleColor =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    final dividerColor = isDark ? AppColors.darkDivider : AppColors.divider;
    final auth = context.watch<AuthProvider>();

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
        padding: EdgeInsets.symmetric(
          horizontal: AppScale.padding(AppSpacing.xxl),
          vertical: AppScale.padding(AppSpacing.xl),
        ),
        children: [
          // ── Mode Toggle ──
          _ModeToggle(
            mode: _mode,
            onChanged: (m) => setState(() {
              _mode = m;
              _codeSent = false;
              context.read<AuthProvider>().clearError();
            }),
          ),
          SizedBox(height: AppScale.padding(AppSpacing.xxl)),

          // ── Form ──
          Form(
            key: _formKey,
            child: _mode == _AuthMode.email
                ? _buildEmailForm()
                : _buildPhoneForm(),
          ),
          SizedBox(height: AppScale.padding(AppSpacing.xxl)),

          // ── Error ──
          if (auth.error != null) ...[
            Container(
              padding: EdgeInsets.all(AppScale.padding(AppSpacing.md)),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.negative.withValues(alpha: 0.15)
                    : AppColors.negativeSurface,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded,
                      color: AppColors.negative,
                      size: AppScale.size(20)),
                  SizedBox(width: AppScale.padding(AppSpacing.sm)),
                  Expanded(
                    child: Text(
                      auth.error!,
                      style: TextStyle(
                        color: AppColors.negative,
                        fontSize: AppScale.fontSize(13),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: AppScale.padding(AppSpacing.xxl)),
          ],

          // ── Submit Button ──
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: auth.loading ? null : _onSubmit,
              child: auth.loading
                  ? SizedBox(
                      height: AppScale.size(20),
                      width: AppScale.size(20),
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(_submitLabel),
            ),
          ),
          SizedBox(height: AppScale.padding(AppSpacing.xxl)),

          // ── Divider ──
          Row(
            children: [
              Expanded(child: Divider(color: dividerColor)),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: AppScale.padding(AppSpacing.lg)),
                child: Text(
                  'or continue with',
                  style: TextStyle(
                    color: subtitleColor,
                    fontSize: AppScale.fontSize(13),
                  ),
                ),
              ),
              Expanded(child: Divider(color: dividerColor)),
            ],
          ),
          SizedBox(height: AppScale.padding(AppSpacing.xxl)),

          // ── Social Sign-In ──
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: auth.loading
                      ? null
                      : () => _socialSignIn(
                            context.read<AuthProvider>().signInWithGoogle,
                          ),
                  icon: Icon(Icons.g_mobiledata_rounded,
                      size: AppScale.size(24)),
                  label: const Text('Google'),
                ),
              ),
              SizedBox(width: AppScale.padding(AppSpacing.md)),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: auth.loading
                      ? null
                      : () => _socialSignIn(
                            context.read<AuthProvider>().signInWithApple,
                          ),
                  icon: Icon(Icons.apple_rounded, size: AppScale.size(22)),
                  label: const Text('Apple'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Helpers ──

  String get _submitLabel {
    if (_mode == _AuthMode.phone) {
      return _codeSent ? 'Verify' : 'Send Code';
    }
    return widget.isSignUp ? 'Sign Up' : 'Sign In';
  }

  VoidCallback get _onSubmit {
    if (_mode == _AuthMode.phone) {
      return _codeSent ? _verifyCode : _sendCode;
    }
    return _submitEmail;
  }

  Widget _buildEmailForm() {
    return Column(
      children: [
        if (widget.isSignUp) ...[
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Name is required' : null,
          ),
          SizedBox(height: AppScale.padding(AppSpacing.lg)),
        ],
        TextFormField(
          controller: _emailController,
          textInputAction: TextInputAction.next,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Email is required';
            if (!v.contains('@')) return 'Enter a valid email';
            return null;
          },
        ),
        SizedBox(height: AppScale.padding(AppSpacing.lg)),
        TextFormField(
          controller: _passwordController,
          textInputAction: TextInputAction.done,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
          ),
          validator: (v) {
            if (v == null || v.isEmpty) return 'Password is required';
            if (v.length < 6) return 'At least 6 characters';
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPhoneForm() {
    return Column(
      children: [
        TextFormField(
          controller: _phoneController,
          textInputAction:
              _codeSent ? TextInputAction.next : TextInputAction.done,
          keyboardType: TextInputType.phone,
          enabled: !_codeSent,
          decoration: InputDecoration(
            labelText: 'Phone Number',
            hintText: '+1 234 567 8900',
            prefixIcon: const Icon(Icons.phone_outlined),
            suffixIcon: _codeSent
                ? TextButton(
                    onPressed: () => setState(() => _codeSent = false),
                    child: const Text('Edit'),
                  )
                : null,
          ),
        ),
        if (_codeSent) ...[
          SizedBox(height: AppScale.padding(AppSpacing.lg)),
          TextFormField(
            controller: _otpController,
            textInputAction: TextInputAction.done,
            keyboardType: TextInputType.number,
            autofocus: true,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'Verification Code',
              prefixIcon: Icon(Icons.pin_outlined),
              counterText: '',
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Mode Toggle ──────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkSurfaceVariant : AppColors.surfaceVariant;
    final activeColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final activeFg = isDark ? AppColors.darkTextPrimary : AppColors.textPrimary;
    final inactiveFg =
        isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;

    return Container(
      height: AppScale.size(44),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          _toggleItem('Email', _AuthMode.email, activeColor, activeFg,
              inactiveFg),
          _toggleItem('Phone', _AuthMode.phone, activeColor, activeFg,
              inactiveFg),
        ],
      ),
    );
  }

  Widget _toggleItem(String label, _AuthMode value, Color activeColor,
      Color activeFg, Color inactiveFg) {
    final selected = mode == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: selected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? activeFg : inactiveFg,
              fontSize: AppScale.fontSize(14),
            ),
          ),
        ),
      ),
    );
  }
}
