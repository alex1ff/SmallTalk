import 'package:firebase_auth/firebase_auth.dart';
import 'package:rxdart/rxdart.dart';

import '../base_auth_user_provider.dart';
// ─── SUBSCRIPTION REWORK ───────────────────────────────────────────────
// RevenueCat needs the Firebase uid as its App User ID. We hook the
// auth stream so login/logout in RC happens transparently whenever
// Firebase Auth state flips.
import '/services/subscription_service.dart';
// ──────────────────────────────────────────────────────────────────────

export '../base_auth_user_provider.dart';

class SmallTalkFirebaseUser extends BaseAuthUser {
  SmallTalkFirebaseUser(this.user);
  User? user;
  bool get loggedIn => user != null;

  @override
  AuthUserInfo get authUserInfo => AuthUserInfo(
        uid: user?.uid,
        email: user?.email,
        displayName: user?.displayName,
        photoUrl: user?.photoURL,
        phoneNumber: user?.phoneNumber,
      );

  @override
  Future? delete() => user?.delete();

  @override
  Future? updateEmail(String email) async {
    await user?.verifyBeforeUpdateEmail(email);
  }

  @override
  Future? updatePassword(String newPassword) async {
    await user?.updatePassword(newPassword);
  }

  @override
  Future? sendEmailVerification() => user?.sendEmailVerification();

  @override
  bool get emailVerified {
    // Reloads the user when checking in order to get the most up to date
    // email verified status.
    if (loggedIn && !user!.emailVerified) {
      refreshUser();
    }
    return user?.emailVerified ?? false;
  }

  @override
  Future refreshUser() async {
    await FirebaseAuth.instance.currentUser
        ?.reload()
        .then((_) => user = FirebaseAuth.instance.currentUser);
  }

  static BaseAuthUser fromUserCredential(UserCredential userCredential) =>
      fromFirebaseUser(userCredential.user);
  static BaseAuthUser fromFirebaseUser(User? user) =>
      SmallTalkFirebaseUser(user);
}

Stream<BaseAuthUser> smallTalkFirebaseUserStream() => FirebaseAuth.instance
        .authStateChanges()
        .startWith(FirebaseAuth.instance.currentUser)
        .map<BaseAuthUser>(
      (user) {
        currentUser = SmallTalkFirebaseUser(user);
        // ─── SUBSCRIPTION REWORK ───────────────────────────────────────
        // Mirror auth state into RevenueCat. Fire-and-forget so this map
        // stays synchronous and the stream emits without delay. The
        // service guards re-entry and logs its own errors.
        if (user != null && user.uid.isNotEmpty) {
          SubscriptionService.instance.logInUser(user.uid);
        } else {
          SubscriptionService.instance.logOutUser();
        }
        // ──────────────────────────────────────────────────────────────
        return currentUser!;
      },
    ).distinct(
      (previous, next) =>
          previous.uid == next.uid && previous.loggedIn == next.loggedIn,
    );
