import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_provider.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  final supabase = ref.watch(supabaseProvider);
  return supabase.auth.onAuthStateChange;
});

final pendingEmailConfirmationProvider =
    StateProvider<PendingEmailConfirmation?>((ref) => null);

class PendingEmailConfirmation {
  const PendingEmailConfirmation({required this.email, required this.password});

  final String email;
  final String password;
}

class AuthController {
  AuthController(this.ref);
  final Ref ref;

  static const oauthRedirectTo = 'modelapp://login-callback';

  static String get authRedirectTo {
    if (!kIsWeb) return oauthRedirectTo;
    final base = Uri.base;
    if (!base.hasScheme || base.host.isEmpty) return oauthRedirectTo;
    final origin = base.hasPort
        ? '${base.scheme}://${base.host}:${base.port}'
        : '${base.scheme}://${base.host}';
    if (base.host == 'aresartemius.github.io') {
      return '$origin/PKModelApp/';
    }

    final firstSegment = base.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .firstOrNull;
    if (firstSegment != null) {
      return '$origin/$firstSegment/';
    }
    return origin;
  }

  SupabaseClient get _sb => ref.read(supabaseProvider);

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) {
    return _sb.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: authRedirectTo,
      data: data,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _sb.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signInWithPhonePassword({
    required String phone,
    required String password,
  }) {
    return _sb.auth.signInWithPassword(phone: phone, password: password);
  }

  Future<String?> resolveEmailByPhone(String phone) async {
    final value = await _sb.rpc<String?>(
      'resolve_auth_email_by_phone',
      params: {'p_phone': phone},
    );
    final email = value?.trim();
    return email == null || email.isEmpty ? null : email;
  }

  Future<AuthResponse> signInWithResponse({
    required String email,
    required String password,
  }) {
    return _sb.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> sendPhoneOtp({required String phone}) async {
    await _sb.auth.signInWithOtp(phone: phone);
  }

  Future<AuthResponse> verifyPhoneOtp({
    required String phone,
    required String token,
  }) {
    return _sb.auth.verifyOTP(phone: phone, token: token, type: OtpType.sms);
  }

  Future<UserResponse> setCurrentUserPassword({required String password}) {
    return _sb.auth.updateUser(UserAttributes(password: password));
  }

  Future<UserResponse> linkPhoneForLogin({required String phone}) {
    return _sb.auth.updateUser(UserAttributes(phone: phone));
  }

  Future<AuthResponse> verifyPhoneForLogin({
    required String phone,
    required String token,
  }) {
    return _sb.auth.verifyOTP(
      phone: phone,
      token: token,
      type: OtpType.phoneChange,
    );
  }

  Future<bool> signInWithGoogle() {
    return _sb.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: authRedirectTo,
    );
  }

  Future<bool> signInWithApple() {
    return _sb.auth.signInWithOAuth(
      OAuthProvider.apple,
      redirectTo: authRedirectTo,
    );
  }

  Future<void> resendSignUpEmail(String email) {
    return _sb.auth.resend(
      email: email,
      type: OtpType.signup,
      emailRedirectTo: authRedirectTo,
    );
  }

  bool isEmailConfirmed(User? user) {
    if (user == null) return false;
    final email = user.email?.trim() ?? '';
    if (email.isEmpty) return true;
    return user.emailConfirmedAt?.trim().isNotEmpty ?? false;
  }

  Future<void> signOut() async {
    await _sb.auth.signOut();
  }

  User? get currentUser => _sb.auth.currentUser;
}

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(ref);
});
