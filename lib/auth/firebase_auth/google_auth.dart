import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

Future<UserCredential?> googleSignInFunc() async {
  if (kIsWeb) {
    // Once signed in, return the UserCredential
    return await FirebaseAuth.instance.signInWithPopup(GoogleAuthProvider());
  }

  // Use Firebase OAuth provider flow on mobile to avoid native plugin crashes
  // caused by incomplete platform GoogleSignIn configuration.
  return FirebaseAuth.instance.signInWithProvider(GoogleAuthProvider());
}

Future signOutWithGoogle() async {}
