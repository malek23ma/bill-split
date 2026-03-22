import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final SupabaseClient _client;

  AuthService(this._client);

  User? get currentUser => _client.auth.currentUser;
  bool get isAuthenticated => currentUser != null;
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  /// Email/password sign up
  Future<AuthResponse> signUpWithEmail(
      String email, String password, String displayName) async {
    return await _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  /// Email/password sign in
  Future<AuthResponse> signInWithEmail(String email, String password) async {
    return await _client.auth.signInWithPassword(
        email: email, password: password);
  }

  /// Phone/OTP — send code
  Future<void> signInWithPhone(String phone) async {
    await _client.auth.signInWithOtp(phone: phone);
  }

  /// Phone/OTP — verify code
  Future<AuthResponse> verifyOtp(String phone, String token) async {
    return await _client.auth
        .verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  /// Google sign in
  Future<AuthResponse> signInWithGoogle() async {
    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw Exception('Google sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    final accessToken = googleAuth.accessToken;

    if (idToken == null) throw Exception('No ID token from Google');

    return await _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
      accessToken: accessToken,
    );
  }

  /// Apple sign in
  Future<bool> signInWithApple() async {
    return await _client.auth.signInWithOAuth(OAuthProvider.apple);
  }

  /// Sign out
  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  /// Update display name in profiles table
  Future<void> updateDisplayName(String name) async {
    await _client
        .from('profiles')
        .update({'display_name': name}).eq('id', currentUser!.id);
  }

  /// Get profile
  Future<Map<String, dynamic>?> getProfile() async {
    if (currentUser == null) return null;
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', currentUser!.id)
        .maybeSingle();
    return response;
  }
}
