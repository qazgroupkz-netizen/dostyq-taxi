import 'package:firebase_auth/firebase_auth.dart';

Future<ConfirmationResult> signInWithPhone(String phone) {
  final verifier = RecaptchaVerifier(auth: FirebaseAuth.instance);
  return FirebaseAuth.instance.signInWithPhoneNumber(phone, verifier);
}
