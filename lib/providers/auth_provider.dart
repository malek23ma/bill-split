import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../database/database_helper.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  User? _user;
  bool _loading = false;
  String? _error;
  StreamSubscription<AuthState>? _authSub;

  AuthProvider(this._authService) {
    _user = _authService.currentUser;
    _authSub = _authService.authStateChanges.listen((state) {
      _user = state.session?.user;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get loading => _loading;
  String? get error => _error;

  Future<bool> signUpWithEmail(String email, String password, String displayName) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signUpWithEmail(email, password, displayName);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithEmail(String email, String password) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithEmail(email, password);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> sendPhoneOtp(String phone) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithPhone(phone);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyPhoneOtp(String phone, String code) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.verifyOtp(phone, code);
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithGoogle() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithGoogle();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithApple() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _authService.signInWithApple();
      _loading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString();
      _loading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    // Wipe local data so next user doesn't see this user's households
    await DatabaseHelper.instance.clearAllLocalData();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('last_household_id');
    await _authService.signOut();
    _user = null;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
