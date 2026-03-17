import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '/backend/backend.dart';
import 'package:stream_transform/stream_transform.dart';
import 'firebase_auth_manager.dart';

export 'firebase_auth_manager.dart';

final _authManager = FirebaseAuthManager();
FirebaseAuthManager get authManager => _authManager;

enum AuthenticatedUserIdSource {
  preferred,
  firebaseAuth,
  currentUser,
  unavailable,
}

class AuthenticatedUserIdResolution {
  const AuthenticatedUserIdResolution({
    required this.uid,
    required this.source,
  });

  final String? uid;
  final AuthenticatedUserIdSource source;
}

enum AuthenticatedUserProfileResolutionStatus {
  resolvedCanonical,
  resolvedLegacyMigration,
  missingProfile,
  duplicateLegacyProfiles,
  missingAuthUid,
}

class AuthenticatedUserProfileResolution {
  const AuthenticatedUserProfileResolution({
    required this.status,
    required this.uidResolution,
    required this.canonicalUserRef,
    this.userDocument,
    this.legacyMatchCount = 0,
    this.usedCachedDocument = false,
  });

  final AuthenticatedUserProfileResolutionStatus status;
  final AuthenticatedUserIdResolution uidResolution;
  final DocumentReference? canonicalUserRef;
  final UsersRecord? userDocument;
  final int legacyMatchCount;
  final bool usedCachedDocument;

  String? get uid => uidResolution.uid;
  bool get hasResolvedDocument => userDocument != null;
}

String get currentUserEmail =>
    currentUserDocument?.email ??
    currentUser?.email ??
    FirebaseAuth.instance.currentUser?.email ??
    '';

AuthenticatedUserIdResolution resolveAuthenticatedUserIdResolutionFromSources({
  String? preferredUid,
  String? firebaseAuthUid,
  String? currentUserUid,
}) {
  for (final candidate in <({
    String? uid,
    AuthenticatedUserIdSource source,
  })>[
    (
      uid: preferredUid,
      source: AuthenticatedUserIdSource.preferred,
    ),
    (
      uid: firebaseAuthUid,
      source: AuthenticatedUserIdSource.firebaseAuth,
    ),
    (
      uid: currentUserUid,
      source: AuthenticatedUserIdSource.currentUser,
    ),
  ]) {
    final trimmed = candidate.uid?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return AuthenticatedUserIdResolution(
        uid: trimmed,
        source: candidate.source,
      );
    }
  }
  return const AuthenticatedUserIdResolution(
    uid: null,
    source: AuthenticatedUserIdSource.unavailable,
  );
}

String? resolveAuthenticatedUserIdFromSources({
  String? preferredUid,
  String? firebaseAuthUid,
  String? currentUserUid,
}) =>
    resolveAuthenticatedUserIdResolutionFromSources(
      preferredUid: preferredUid,
      firebaseAuthUid: firebaseAuthUid,
      currentUserUid: currentUserUid,
    ).uid;

AuthenticatedUserIdResolution resolveAuthenticatedUserIdResolution({
  String? preferredUid,
}) =>
    resolveAuthenticatedUserIdResolutionFromSources(
      preferredUid: preferredUid,
      firebaseAuthUid: FirebaseAuth.instance.currentUser?.uid,
      currentUserUid: currentUser?.uid,
    );

String? resolveAuthenticatedUserId({String? preferredUid}) =>
    resolveAuthenticatedUserIdResolution(
      preferredUid: preferredUid,
    ).uid;

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

Map<String, dynamic> _buildCurrentUserSeedData({
  required String uid,
}) =>
    createUsersRecordData(
      email: FirebaseAuth.instance.currentUser?.email ?? currentUser?.email,
      displayName: FirebaseAuth.instance.currentUser?.displayName ??
          currentUser?.displayName,
      photoUrl:
          FirebaseAuth.instance.currentUser?.photoURL ?? currentUser?.photoUrl,
      uid: uid,
      phoneNumber: FirebaseAuth.instance.currentUser?.phoneNumber ??
          currentUser?.phoneNumber,
      createdTime: DateTime.now(),
    );

void _logUserDocumentSnapshot({
  required String uid,
  required UsersRecord userDocument,
  required void Function(String message)? onDebugLog,
  required String reason,
  int legacyMatchCount = 0,
  AuthenticatedUserIdSource? uidSource,
}) {
  onDebugLog?.call(
    'uid=$uid '
    'uidSource=${uidSource?.name ?? 'unknown'} '
    'reason=$reason '
    'legacyMatchCount=$legacyMatchCount '
    'rawRole=${userDocument.snapshotData['role']} '
    'role=${userDocument.role?.name ?? 'null'} '
    'acquaintance=${userDocument.hasAcquaintance() ? userDocument.acquaintance : 'null'} '
    'isProfileComplete=${userDocument.hasIsProfileComplete() ? userDocument.isProfileComplete : 'null'}',
  );
}

Future<UsersRecord?> ensureCanonicalCurrentUserDocument({
  String? preferredUid,
  DocumentReference? canonicalUserRef,
  void Function(String message)? onDebugLog,
}) async {
  final uidResolution = resolveAuthenticatedUserIdResolution(
    preferredUid: preferredUid,
  );
  final userRef = canonicalUserRef ??
      resolveCurrentUserReference(preferredUid: uidResolution.uid);
  if (userRef == null || uidResolution.uid == null) {
    onDebugLog?.call(
      'cannot ensure canonical doc; auth uid unavailable '
      '(uidSource=${uidResolution.source.name})',
    );
    return null;
  }

  try {
    final existingSnapshot = await userRef.get();
    if (existingSnapshot.exists && existingSnapshot.data() != null) {
      final userDocument = UsersRecord.fromSnapshot(existingSnapshot);
      currentUserDocument = userDocument;
      _logUserDocumentSnapshot(
        uid: userRef.id,
        userDocument: userDocument,
        onDebugLog: onDebugLog,
        reason: 'canonical_doc_already_exists',
        uidSource: uidResolution.source,
      );
      return userDocument;
    }

    await userRef.set(
      _buildCurrentUserSeedData(uid: userRef.id),
      SetOptions(merge: true),
    );

    final createdSnapshot = await userRef.get();
    if (!createdSnapshot.exists || createdSnapshot.data() == null) {
      onDebugLog?.call(
        'uid=${userRef.id} failed to create canonical doc '
        'uidSource=${uidResolution.source.name}',
      );
      return null;
    }

    final userDocument = UsersRecord.fromSnapshot(createdSnapshot);
    currentUserDocument = userDocument;
    _logUserDocumentSnapshot(
      uid: userRef.id,
      userDocument: userDocument,
      onDebugLog: onDebugLog,
      reason: 'created_canonical_doc',
      uidSource: uidResolution.source,
    );
    return userDocument;
  } catch (error) {
    onDebugLog?.call(
      'uid=${userRef.id} ensureCanonicalDocError=$error '
      'uidSource=${uidResolution.source.name}',
    );
    return null;
  }
}

Future<AuthenticatedUserProfileResolution> resolveAuthenticatedUserProfile({
  String? preferredUid,
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 250),
  bool refreshFromBackend = false,
  bool allowLegacyLookup = true,
  bool allowLegacyMigration = true,
  void Function(String message)? onDebugLog,
}) async {
  final uidResolution = resolveAuthenticatedUserIdResolution(
    preferredUid: preferredUid,
  );
  final userRef = resolveCurrentUserReference(preferredUid: uidResolution.uid);
  if (userRef == null || uidResolution.uid == null) {
    onDebugLog?.call(
      'auth uid unavailable (preferred=${preferredUid ?? 'null'}, '
      'firebase=${FirebaseAuth.instance.currentUser?.uid ?? 'null'}, '
      'current=${currentUser?.uid ?? 'null'}, '
      'uidSource=${uidResolution.source.name})',
    );
    return AuthenticatedUserProfileResolution(
      status: AuthenticatedUserProfileResolutionStatus.missingAuthUid,
      uidResolution: uidResolution,
      canonicalUserRef: userRef,
    );
  }

  final uid = userRef.id;
  UsersRecord? latestUser =
      hasCurrentUserDocumentForUid(uid) ? currentUserDocument : null;
  if (latestUser != null && !refreshFromBackend) {
    _logUserDocumentSnapshot(
      uid: uid,
      userDocument: latestUser,
      onDebugLog: onDebugLog,
      reason: 'cached_doc',
      uidSource: uidResolution.source,
    );
    return AuthenticatedUserProfileResolution(
      status: AuthenticatedUserProfileResolutionStatus.resolvedCanonical,
      uidResolution: uidResolution,
      canonicalUserRef: userRef,
      userDocument: latestUser,
      usedCachedDocument: true,
    );
  }

  if (latestUser != null) {
    onDebugLog?.call(
      'uid=$uid cachedDocPresent=true '
      'uidSource=${uidResolution.source.name} '
      'waitingForBackendRefresh=true',
    );
  }

  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    try {
      final snapshot = await userRef.get();
      if (snapshot.exists && snapshot.data() != null) {
        latestUser = UsersRecord.fromSnapshot(snapshot);
        currentUserDocument = latestUser;
        _logUserDocumentSnapshot(
          uid: uid,
          userDocument: latestUser,
          onDebugLog: onDebugLog,
          reason: 'canonical_doc_from_backend',
          uidSource: uidResolution.source,
        );
        return AuthenticatedUserProfileResolution(
          status: AuthenticatedUserProfileResolutionStatus.resolvedCanonical,
          uidResolution: uidResolution,
          canonicalUserRef: userRef,
          userDocument: latestUser,
        );
      }

      onDebugLog?.call(
        'uid=$uid canonicalHasDoc=false uidSource=${uidResolution.source.name}',
      );
    } catch (error) {
      onDebugLog?.call(
        'uid=$uid canonicalFetchError=$error '
        'uidSource=${uidResolution.source.name}',
      );
    }

    await Future<void>.delayed(pollInterval);
  }

  if (latestUser != null) {
    _logUserDocumentSnapshot(
      uid: uid,
      userDocument: latestUser,
      onDebugLog: onDebugLog,
      reason: 'timeout_fallback_cached_doc',
      uidSource: uidResolution.source,
    );
    return AuthenticatedUserProfileResolution(
      status: AuthenticatedUserProfileResolutionStatus.resolvedCanonical,
      uidResolution: uidResolution,
      canonicalUserRef: userRef,
      userDocument: latestUser,
      usedCachedDocument: true,
    );
  }

  onDebugLog?.call(
    'uid=$uid canonicalDocMissingAfterTimeout=true '
    'uidSource=${uidResolution.source.name}',
  );

  if (!allowLegacyLookup) {
    return AuthenticatedUserProfileResolution(
      status: AuthenticatedUserProfileResolutionStatus.missingProfile,
      uidResolution: uidResolution,
      canonicalUserRef: userRef,
    );
  }

  try {
    final legacyQuerySnapshot = await UsersRecord.collection
        .where('uid', isEqualTo: uid)
        .limit(2)
        .get();
    final legacyMatchCount = legacyQuerySnapshot.docs.length;
    onDebugLog?.call(
      'uid=$uid legacyMatchCount=$legacyMatchCount '
      'uidSource=${uidResolution.source.name}',
    );

    if (legacyMatchCount > 1) {
      return AuthenticatedUserProfileResolution(
        status:
            AuthenticatedUserProfileResolutionStatus.duplicateLegacyProfiles,
        uidResolution: uidResolution,
        canonicalUserRef: userRef,
        legacyMatchCount: legacyMatchCount,
      );
    }

    if (legacyMatchCount == 1 && allowLegacyMigration) {
      final legacySnapshot = legacyQuerySnapshot.docs.first;
      final legacyData =
          Map<String, dynamic>.from(legacySnapshot.data() as Map);
      await userRef.set(
        <String, dynamic>{
          ...legacyData,
          'uid': uid,
        },
        SetOptions(merge: true),
      );

      final migratedSnapshot = await userRef.get();
      if (migratedSnapshot.exists && migratedSnapshot.data() != null) {
        final migratedUser = UsersRecord.fromSnapshot(migratedSnapshot);
        currentUserDocument = migratedUser;
        _logUserDocumentSnapshot(
          uid: uid,
          userDocument: migratedUser,
          onDebugLog: onDebugLog,
          reason: 'resolved_via_legacy_migration',
          legacyMatchCount: legacyMatchCount,
          uidSource: uidResolution.source,
        );
        return AuthenticatedUserProfileResolution(
          status:
              AuthenticatedUserProfileResolutionStatus.resolvedLegacyMigration,
          uidResolution: uidResolution,
          canonicalUserRef: userRef,
          userDocument: migratedUser,
          legacyMatchCount: legacyMatchCount,
        );
      }
    }
  } catch (error) {
    onDebugLog?.call(
      'uid=$uid legacyLookupError=$error '
      'uidSource=${uidResolution.source.name}',
    );
  }

  return AuthenticatedUserProfileResolution(
    status: AuthenticatedUserProfileResolutionStatus.missingProfile,
    uidResolution: uidResolution,
    canonicalUserRef: userRef,
  );
}

Future<UsersRecord?> waitForResolvedCurrentUserDocument({
  String? preferredUid,
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 250),
  bool refreshFromBackend = false,
  bool allowLegacyLookup = true,
  bool allowLegacyMigration = true,
  void Function(String message)? onDebugLog,
}) async {
  final resolution = await resolveAuthenticatedUserProfile(
    preferredUid: preferredUid,
    timeout: timeout,
    pollInterval: pollInterval,
    refreshFromBackend: refreshFromBackend,
    allowLegacyLookup: allowLegacyLookup,
    allowLegacyMigration: allowLegacyMigration,
    onDebugLog: onDebugLog,
  );
  return resolution.userDocument;
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
