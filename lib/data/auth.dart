import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../config.dart';
import '../services/phone_auth.dart' as phone_web;
import 'supabase/sb_auth.dart';

/// Вошедший пользователь. phone — в формате +7XXXXXXXXXX.
class AuthUser {
  final String uid;
  final String phone;
  const AuthUser(this.uid, this.phone);
}

/// Ошибка входа: code — 'invalid-phone-number', 'too-many-requests', 'invalid-code' или другое.
class AuthError implements Exception {
  final String code;
  const AuthError(this.code);
  @override
  String toString() => code;
}

/// Вход по номеру телефона и профиль пользователя (имя, роль).
abstract class AuthRepository {
  /// Сначала текущий пользователь (или null), потом каждый вход и выход.
  Stream<AuthUser?> changes();
  AuthUser? get current;

  /// Отправить код. На Android Firebase может войти сам, без кода.
  Future<void> sendCode(String phone);
  Future<void> verifyCode(String code);
  Future<void> signOut();

  /// role: client / driver / manager / admin. null — профиля ещё нет.
  Future<({String name, String role})?> profile(String uid);
  Future<void> createProfile(String uid, {required String name, required String phone});
}

/// Одна на всё приложение: Firebase или своя база — по сборке (config.dart).
final AuthRepository authRepo =
    kUseSupabase ? SupabaseAuthRepository() : FirebaseAuthRepository();

class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuth get _auth => FirebaseAuth.instance;
  String? _verificationId;
  ConfirmationResult? _webResult;

  static AuthUser? _user(User? u) => u == null ? null : AuthUser(u.uid, u.phoneNumber ?? '');

  @override
  Stream<AuthUser?> changes() => _auth.authStateChanges().map(_user);

  @override
  AuthUser? get current => _user(_auth.currentUser);

  @override
  Future<void> sendCode(String phone) async {
    try {
      if (kIsWeb) {
        _webResult = await phone_web.signInWithPhone(phone);
        return;
      }
      final done = Completer<void>();
      await _auth.verifyPhoneNumber(
        phoneNumber: phone,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          await _auth.signInWithCredential(cred);
          if (!done.isCompleted) done.complete();
        },
        verificationFailed: (e) {
          if (!done.isCompleted) done.completeError(AuthError(e.code));
        },
        codeSent: (vid, _) {
          _verificationId = vid;
          if (!done.isCompleted) done.complete();
        },
        codeAutoRetrievalTimeout: (_) {},
      );
      return done.future;
    } on FirebaseAuthException catch (e) {
      throw AuthError(e.code);
    }
  }

  @override
  Future<void> verifyCode(String code) async {
    try {
      if (kIsWeb) {
        await _webResult!.confirm(code);
      } else {
        await _auth.signInWithCredential(PhoneAuthProvider.credential(
          verificationId: _verificationId!,
          smsCode: code,
        ));
      }
    } catch (_) {
      throw const AuthError('invalid-code');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  @override
  Future<({String name, String role})?> profile(String uid) async {
    final m = (await FirebaseFirestore.instance.collection('users').doc(uid).get()).data();
    if (m == null) return null;
    return (name: m['name'] as String? ?? '', role: m['role'] as String? ?? 'client');
  }

  @override
  Future<void> createProfile(String uid, {required String name, required String phone}) =>
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'phone': phone,
        'role': 'client',
        'createdAt': FieldValue.serverTimestamp(),
      });
}
