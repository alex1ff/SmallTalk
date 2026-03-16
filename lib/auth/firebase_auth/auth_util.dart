import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '/backend/backend.dart';
import 'package:stream_transform/stream_transform.dart';
import 'firebase_auth_manager.dart';

export 'firebase_auth_manager.dart';

final _authManager = FirebaseAuthManager();
FirebaseAuthManager get authManager => _authManager;

String get currentUserEmail =>
    currentUserDocument?.email ??
    currentUser?.email ??
    FirebaseAuth.instance.currentUser?.email ??
    '';

String? resolveAuthenticatedUserIdFromSources({
  String? preferredUid,
  String? firebaseAuthUid,
  String? currentUserUid,
}) {
  for (final candidate in <String?>[
    preferredUid,
    firebaseAuthUid,
    currentUserUid,
  ]) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return null;
}

String? resolveAuthenticatedUserId({String? preferredUid}) =>
    resolveAuthenticatedUserIdFromSources(
      preferredUid: preferredUid,
      firebaseAuthUid: FirebaseAuth.instance.currentUser?.uid,
      currentUserUid: currentUser?.uid,
    );

String get currentUserUid => resolveAuthenticatedUserId() ?? '';

String get currentUserDisplayName =>
    currentUserDocument?.displayName ??
    currentUser?.displayName ??
    FirebaseAuth.instance.currentUser?.displayName ??
    '';

String get currentUserPhoto =>
    currentUserDocument?.photoUrl ??
    currentUser?.photoUrl ??
    FirebaseAuth.instance.currentUser?.photoURL ??
    '';

String get currentPhoneNumber =>
    currentUserDocument?.phoneNumber ??
    currentUser?.phoneNumber ??
    FirebaseAuth.instance.currentUser?.phoneNumber ??
    '';

String get currentJwtToken => _currentJwtToken ?? '';

bool get currentUserEmailVerified => currentUser?.emailVerified ?? false;

/// Create a Stream that listens to the current user's JWT Token, since Firebase
/// generates a new token every hour.
String? _currentJwtToken;
final jwtTokenStream = FirebaseAuth.instance
    .idTokenChanges()
    .map((user) async => _currentJwtToken = await user?.getIdToken())
    .asBroadcastStream();

DocumentReference? get currentUserReference => resolveCurrentUserReference();

DocumentReference? resolveCurrentUserReference({String? preferredUid}) {
  final uid = resolveAuthenticatedUserId(preferredUid: preferredUid);
  if (uid == null) {
    return null;
  }
  return UsersRecord.collection.doc(uid);
}

bool hasCurrentUserDocumentForUid(String? uid) {
  final resolvedUid = uid?.trim();
  if (resolvedUid == null ||
      resolvedUid.isEmpty ||
      currentUserDocument == null) {
    return false;
  }
  return currentUserDocument!.reference.id == resolvedUid;
}

Future<UsersRecord?> waitForResolvedCurrentUserDocument({
  String? preferredUid,
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 250),
  bool refreshFromBackend = false,
  void Function(String message)? onDebugLog,
}) async {
  final userRef = resolveCurrentUserReference(preferredUid: preferredUid);
  if (userRef == null) {
    onDebugLog?.call(
      'auth uid unavailable (preferred=${preferredUid ?? 'null'}, '
      'firebase=${FirebaseAuth.instance.currentUser?.uid ?? 'null'}, '
      'current=${currentUser?.uid ?? 'null'})',
    );
    return null;
  }

  final uid = userRef.id;
  UsersRecord? latestUser =
      hasCurrentUserDocumentForUid(uid) ? currentUserDocument : null;
  if (latestUser != null && !refreshFromBackend) {
    onDebugLog?.call(
      'uid=$uid using cached doc '
      'rawRole=${latestUser.snapshotData['role']} '
      'role=${latestUser.role?.name ?? 'null'} '
      'acquaintance=${latestUser.hasAcquaintance() ? latestUser.acquaintance : 'null'} '
      'isProfileComplete=${latestUser.hasIsProfileComplete() ? latestUser.isProfileComplete : 'null'}',
    );
    return latestUser;
  }

  if (latestUser != null) {
    onDebugLog?.call(
      'uid=$uid cached doc present, waiting for backend refresh '
      'rawRole=${latestUser.snapshotData['role']} '
      'role=${latestUser.role?.name ?? 'null'}',
    );
  }

  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final snapshot = await userRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        final rawData = snapshot.data() as Map<String, dynamic>?;
        latestUser = UsersRecord.fromSnapshot(snapshot);
        currentUserDocument = latestUser;
        onDebugLog?.call(
          'uid=$uid hasDoc=true '
          'rawRole=${rawData?['role']} '
          'role=${latestUser.role?.name ?? 'null'} '
          'acquaintance=${latestUser.hasAcquaintance() ? latestUser.acquaintance : 'null'} '
          'isProfileComplete=${latestUser.hasIsProfileComplete() ? latestUser.isProfileComplete : 'null'}',
        );
        return latestUser;
      }

      onDebugLog?.call('uid=$uid hasDoc=false');
    } catch (error) {
      onDebugLog?.call('uid=$uid fetchError=$error');
    }

    await Future<void>.delayed(pollInterval);
  }

  if (latestUser != null) {
    onDebugLog?.call(
      'uid=$uid timeout, falling back to cached doc '
      'rawRole=${latestUser.snapshotData['role']} '
      'role=${latestUser.role?.name ?? 'null'} '
      'acquaintance=${latestUser.hasAcquaintance() ? latestUser.acquaintance : 'null'} '
      'isProfileComplete=${latestUser.hasIsProfileComplete() ? latestUser.isProfileComplete : 'null'}',
    );
  } else {
    onDebugLog?.call('uid=$uid timeout, no user doc');
  }

  return latestUser;
}

UsersRecord? currentUserDocument;
final authenticatedUserStream = FirebaseAuth.instance
    .authStateChanges()
    .map<String>((user) => user?.uid ?? '')
    .switchMap(
      (uid) => uid.isEmpty
          ? Stream.value(null)
          : UsersRecord.getDocument(UsersRecord.collection.doc(uid))
              .handleError((_) {}),
    )
    .map((user) {
  currentUserDocument = user;

  return currentUserDocument;
}).asBroadcastStream();

class AuthUserStreamWidget extends StatelessWidget {
  const AuthUserStreamWidget({Key? key, required this.builder})
      : super(key: key);

  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) => StreamBuilder(
        stream: authenticatedUserStream,
        builder: (context, _) => builder(context),
      );
}
