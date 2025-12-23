import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendPasswordResetEmail(String email) async {
    // If you want to enforce redirect, you can also pass ActionCodeSettings from Flutter,
    // but since you set it in the Console template, this is enough:
    await _auth.sendPasswordResetEmail(email: email);
  }
}
