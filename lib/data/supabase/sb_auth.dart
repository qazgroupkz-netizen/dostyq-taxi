import 'package:supabase/supabase.dart' hide AuthUser;
import '../auth.dart';
import 'sb_client.dart';

class SupabaseAuthRepository implements AuthRepository {
  static AuthUser? _user(User? u) {
    if (u == null) return null;
    final p = u.phone ?? '';
    return AuthUser(u.id, p.isEmpty || p.startsWith('+') ? p : '+$p');
  }

  @override
  Stream<AuthUser?> changes() async* {
    var last = current;
    yield last;
    await for (final s in sb.auth.onAuthStateChange) {
      final u = _user(s.session?.user);
      if (u?.uid == last?.uid) continue;
      last = u;
      yield u;
    }
  }

  @override
  AuthUser? get current => _user(sb.auth.currentUser);

  @override
  Future<void> sendCode(String phone) async {
    _pendingPhone = phone;
    try {
      await sb.auth.signInWithOtp(phone: phone);
    } on AuthException catch (e) {
      throw AuthError(e.statusCode == '429' ? 'too-many-requests' : e.message);
    }
  }

  @override
  Future<void> verifyCode(String code) async {
    final phone = _pendingPhone;
    try {
      await sb.auth.verifyOTP(phone: phone, token: code, type: OtpType.sms);
    } on AuthException {
      throw const AuthError('invalid-code');
    }
  }

  // Номер, на который отправили код (verifyOTP просит его ещё раз).
  String _pendingPhone = '';

  @override
  Future<void> signOut() => sb.auth.signOut();

  @override
  Future<({String name, String role})?> profile(String uid) async {
    final m = await sb.from('profiles').select('name, role').eq('id', uid).maybeSingle();
    if (m == null) return null;
    return (name: m['name'] as String? ?? '', role: m['role'] as String? ?? 'client');
  }

  @override
  Future<void> createProfile(String uid, {required String name, required String phone}) =>
      sb.from('profiles').upsert({'id': uid, 'name': name, 'phone': phone});
}
