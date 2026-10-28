import 'package:firebase_auth/firebase_auth.dart';

Future<ConfirmationResult> signInWithPhone(String phone) {
  return FirebaseAuth.instance.signInWithPhoneNumber(phone);
}
