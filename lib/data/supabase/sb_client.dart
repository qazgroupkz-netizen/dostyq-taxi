import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import '../../config.dart';

late final SupabaseClient sb;
bool _ready = false;

const _sessionKey = 'sb_session';

/// Подключение к своей базе. Вход хранится на устройстве, чтобы не спрашивать код каждый раз.
/// Повторный вызов ничего не делает (страница переноса в Firebase-админке зовёт его сама).
Future<void> initSupabase() async {
  if (_ready) return;
  _ready = true;
  sb = SupabaseClient(
    kSupabaseUrl,
    kSupabaseAnonKey,
    authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
  );
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_sessionKey);
  if (saved != null) {
    try {
      await sb.auth.recoverSession(saved);
    } catch (_) {
      await prefs.remove(_sessionKey);
    }
  }
  sb.auth.onAuthStateChange.listen((s) {
    final session = s.session;
    if (session == null) {
      if (s.event == AuthChangeEvent.signedOut) prefs.remove(_sessionKey);
    } else {
      prefs.setString(_sessionKey, jsonEncode(session.toJson()));
    }
  });
}
