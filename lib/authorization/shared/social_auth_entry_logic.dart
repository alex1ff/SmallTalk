import '/auth/firebase_auth/auth_util.dart';
import '/authorization/shared/pending_social_auth_context.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/new_account_inbox_bootstrap.dart';
import 'package:flutter/foundation.dart';

enum SocialAuthEntryDestination {
  loading,
  acquaintanceNativeSpeaker,
  acquaintanceStudent,
}

enum UserRoleRecoverySource {
  canonical,
  pendingIntent,
  profileShape,
}

enum LoadingRecoveryAction {
  assignRole,
  fatalError,
}

enum LoadingRecoveryFailure {
  duplicateProfiles,
  ambiguousProfile,
  profileUnavailable,
}

class SocialAuthEntryDecision {
  const SocialAuthEntryDecision({
    required this.destination,
    required this.roleToAssign,
    required this.grantStudentBonus,
  });

  final SocialAuthEntryDestination destination;
  final UserRole? roleToAssign;
  final bool grantStudentBonus;

  bool get shouldAssignRole => roleToAssign != null;
}

class LoadingRecoveryDecision {
  const LoadingRecoveryDecision({
    required this.action,
    this.roleToAssign,
    this.grantStudentBonus = false,
    this.recoverySource,
    this.failure,
  });

  final LoadingRecoveryAction action;
  final UserRole? roleToAssign;
  final bool grantStudentBonus;
  final UserRoleRecoverySource? recoverySource;
  final LoadingRecoveryFailure? failure;
}

SocialAuthEntryDecision resolveSocialAuthEntryDecision({
  required bool hasAssignedRole,
  required bool nativeSpeakerIntent,
  required bool hasStudentBalance,
  UserRole? inferredRole,
  bool allowNewAccountRoleIntent = true,
}) {
  if (hasAssignedRole) {
    return const SocialAuthEntryDecision(
      destination: SocialAuthEntryDestination.loading,
      roleToAssign: null,
      grantStudentBonus: false,
    );
  }

  if (inferredRole != null) {
    return SocialAuthEntryDecision(
      destination: SocialAuthEntryDestination.loading,
      roleToAssign: inferredRole,
      grantStudentBonus: inferredRole == UserRole.student && !hasStudentBalance,
    );
  }

  if (!allowNewAccountRoleIntent) {
    return const SocialAuthEntryDecision(
      destination: SocialAuthEntryDestination.loading,
      roleToAssign: null,
      grantStudentBonus: false,
    );
  }

  if (nativeSpeakerIntent) {
    return const SocialAuthEntryDecision(
      destination: SocialAuthEntryDestination.acquaintanceNativeSpeaker,
      roleToAssign: UserRole.native_speaker,
      grantStudentBonus: false,
    );
  }

  return SocialAuthEntryDecision(
    destination: SocialAuthEntryDestination.acquaintanceStudent,
    roleToAssign: UserRole.student,
    grantStudentBonus: !hasStudentBalance,
  );
}

void _debugSocialAuthLog(String message) {
  if (!kDebugMode) {
    return;
  }
  debugPrint('🔐 SocialAuthEntry: $message');
}

UserRole roleIntentFromNativeSpeakerIntent(bool nativeSpeakerIntent) =>
    nativeSpeakerIntent ? UserRole.native_speaker : UserRole.student;

void beginPendingSocialAuthContext({
  required String providerId,
  required String sourceScreen,
  required bool nativeSpeakerIntent,
}) {
  FFAppState().setPendingSocialAuthContext(
    providerId: providerId,
    sourceScreen: sourceScreen,
    roleIntent: roleIntentFromNativeSpeakerIntent(nativeSpeakerIntent),
  );
}

void attachPendingSocialAuthUid(String authUserUid) {
  FFAppState().attachPendingSocialAuthUid(authUserUid);
}

void clearPendingSocialAuthContext() {
  FFAppState().clearPendingSocialAuthContext();
}

PendingSocialAuthContext? getValidPendingSocialAuthContext({
  String? currentAuthUid,
}) =>
    FFAppState().getValidPendingSocialAuthContext(
      currentAuthUid: currentAuthUid,
    );

Future<bool> waitForAuthenticatedAppStateSync({
  String? authUserUid,
  Duration timeout = const Duration(seconds: 5),
  Duration pollInterval = const Duration(milliseconds: 100),
  void Function(String message)? onDebugLog,
}) async {
  final expectedUid = resolveAuthenticatedUserId(preferredUid: authUserUid);
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    final appUser = AppStateNotifier.instance.user;
    if (AppStateNotifier.instance.loggedIn &&
        (expectedUid == null || appUser?.uid == expectedUid)) {
      onDebugLog?.call(
        'appStateSynced=true expectedUid=${expectedUid ?? 'null'} '
        'appUid=${appUser?.uid ?? 'null'}',
      );
      return true;
    }

    onDebugLog?.call(
      'waitingForAppStateSync expectedUid=${expectedUid ?? 'null'} '
      'loggedIn=${AppStateNotifier.instance.loggedIn} '
      'appUid=${appUser?.uid ?? 'null'}',
    );
    await Future<void>.delayed(pollInterval);
  }

  onDebugLog?.call(
    'appStateSyncTimedOut expectedUid=${expectedUid ?? 'null'} '
    'loggedIn=${AppStateNotifier.instance.loggedIn} '
    'appUid=${AppStateNotifier.instance.user?.uid ?? 'null'}',
  );
  return AppStateNotifier.instance.loggedIn;
}

Future<AuthenticatedUserProfileResolution> refreshCurrentUserProfileResolution({
  String? authUserUid,
  void Function(String message)? onDebugLog,
}) async {
  return resolveAuthenticatedUserProfile(
    preferredUid: authUserUid,
    refreshFromBackend: true,
    onDebugLog: onDebugLog,
  );
}

Future<UsersRecord?> refreshCurrentUserDocumentForAuthEntry({
  String? authUserUid,
}) async {
  final resolution = await refreshCurrentUserProfileResolution(
    authUserUid: authUserUid,
    onDebugLog: _debugSocialAuthLog,
  );
  return resolution.userDocument;
}

Future<UsersRecord?> ensureSocialAuthUserDocument({
  required AuthenticatedUserProfileResolution resolution,
  String? authUserUid,
  void Function(String message)? onDebugLog,
}) async {
  if (resolution.userDocument != null) {
    return resolution.userDocument;
  }

  if (resolution.canonicalUserRef == null) {
    onDebugLog
        ?.call('cannot ensure social auth doc; canonical user ref missing');
    return null;
  }

  return ensureCanonicalCurrentUserDocument(
    preferredUid: authUserUid,
    canonicalUserRef: resolution.canonicalUserRef,
    onDebugLog: onDebugLog,
  );
}

bool _hasTeacherRoleSignals(UsersRecord? user) {
  if (user == null) {
    return false;
  }

  return user.hasLanguageInstructionNS() ||
      user.hasNativeLanguageNS() ||
      user.hasCountryNS() ||
      user.hasVerifNS() ||
      user.hasEarnings() ||
      user.hasBalanceNS();
}

bool _hasStudentRoleSignals(UsersRecord? user) {
  if (user == null) {
    return false;
  }

  return user.hasLearningLanguage() ||
      user.hasPurpose() ||
      user.hasPreferences() ||
      user.hasBalanceST() ||
      user.hasFriends() ||
      user.hasFavoriteNativeSpeakers();
}

UserRole? inferRoleFromProfileShape({
  required bool hasTeacherSignals,
  required bool hasStudentSignals,
}) {
  if (hasTeacherSignals == hasStudentSignals) {
    return null;
  }
  return hasTeacherSignals ? UserRole.native_speaker : UserRole.student;
}

UserRole? inferRoleFromUserDocument(UsersRecord? user) =>
    inferRoleFromProfileShape(
      hasTeacherSignals: _hasTeacherRoleSignals(user),
      hasStudentSignals: _hasStudentRoleSignals(user),
    );

Map<String, dynamic> buildCanonicalUserRoleUpdateData({
  required UserRole role,
}) {
  final updateData = createUsersRecordData(role: role);
  if (role == UserRole.student) {
    updateData['availabilityToday'] = FieldValue.delete();
  }
  return updateData;
}

Future<UsersRecord?> persistCanonicalUserRole({
  required DocumentReference userRef,
  required UserRole role,
  required UserRoleRecoverySource recoverySource,
  String? authUserUid,
  UsersRecord? existingUser,
  bool grantStudentBonus = false,
  void Function(String message)? onDebugLog,
}) async {
  // Trial access is now granted by RevenueCat after the user subscribes.
  // Do not create legacy gift-minute balances during registration or role
  // recovery; they bypass the one-call trial policy.
  const shouldGrantStudentBonus = false;

  final updateData = buildCanonicalUserRoleUpdateData(role: role);

  await userRef.set(updateData, SetOptions(merge: true));

  final updatedUser = await ensureCanonicalCurrentUserDocument(
    preferredUid: authUserUid ?? userRef.id,
    canonicalUserRef: userRef,
    onDebugLog: onDebugLog,
  );
  clearPendingSocialAuthContext();
  onDebugLog?.call(
    'uid=${userRef.id} persistedRole=${role.name} '
    'grantStudentBonus=$shouldGrantStudentBonus '
    'recoverySource=${recoverySource.name}',
  );
  return updatedUser;
}

LoadingRecoveryDecision resolveLoadingRecoveryDecision({
  required AuthenticatedUserProfileResolution resolution,
  required UsersRecord? userDocument,
  required PendingSocialAuthContext? pendingContext,
}) =>
    resolveLoadingRecoveryDecisionFromState(
      resolutionStatus: resolution.status,
      hasUserDocument: userDocument != null,
      hasStudentBalance: userDocument?.hasBalanceST() ?? false,
      pendingContextRole: pendingContext?.roleIntent,
      inferredRole: inferRoleFromUserDocument(userDocument),
    );

LoadingRecoveryDecision resolveLoadingRecoveryDecisionFromState({
  required AuthenticatedUserProfileResolutionStatus resolutionStatus,
  required bool hasUserDocument,
  required bool hasStudentBalance,
  required UserRole? pendingContextRole,
  required UserRole? inferredRole,
}) {
  if (resolutionStatus ==
      AuthenticatedUserProfileResolutionStatus.duplicateLegacyProfiles) {
    return const LoadingRecoveryDecision(
      action: LoadingRecoveryAction.fatalError,
      failure: LoadingRecoveryFailure.duplicateProfiles,
    );
  }

  if (hasUserDocument && inferredRole != null) {
    return LoadingRecoveryDecision(
      action: LoadingRecoveryAction.assignRole,
      roleToAssign: inferredRole,
      grantStudentBonus: inferredRole == UserRole.student && !hasStudentBalance,
      recoverySource: UserRoleRecoverySource.profileShape,
    );
  }

  if (!hasUserDocument && pendingContextRole != null) {
    return LoadingRecoveryDecision(
      action: LoadingRecoveryAction.assignRole,
      roleToAssign: pendingContextRole,
      grantStudentBonus:
          pendingContextRole == UserRole.student && !hasStudentBalance,
      recoverySource: UserRoleRecoverySource.pendingIntent,
    );
  }

  if (hasUserDocument) {
    return const LoadingRecoveryDecision(
      action: LoadingRecoveryAction.fatalError,
      failure: LoadingRecoveryFailure.ambiguousProfile,
    );
  }

  if (resolutionStatus ==
      AuthenticatedUserProfileResolutionStatus.missingProfile) {
    return const LoadingRecoveryDecision(
      action: LoadingRecoveryAction.fatalError,
      failure: LoadingRecoveryFailure.profileUnavailable,
    );
  }

  return const LoadingRecoveryDecision(
    action: LoadingRecoveryAction.fatalError,
    failure: LoadingRecoveryFailure.profileUnavailable,
  );
}

Future<SocialAuthEntryDecision?> resolveAndPersistSocialAuthEntry({
  required bool nativeSpeakerIntent,
  String? authUserUid,
}) async {
  if (authUserUid != null && authUserUid.trim().isNotEmpty) {
    attachPendingSocialAuthUid(authUserUid);
  }

  await waitForAuthenticatedAppStateSync(
    authUserUid: authUserUid,
    onDebugLog: _debugSocialAuthLog,
  );

  final resolution = await refreshCurrentUserProfileResolution(
    authUserUid: authUserUid,
    onDebugLog: _debugSocialAuthLog,
  );
  final userRef = resolution.canonicalUserRef;
  if (userRef == null) {
    _debugSocialAuthLog('cannot resolve userRef after social auth');
    return null;
  }

  final currentUser = await ensureSocialAuthUserDocument(
    resolution: resolution,
    authUserUid: authUserUid,
    onDebugLog: _debugSocialAuthLog,
  );
  if (currentUser == null) {
    _debugSocialAuthLog('user doc unavailable after social auth');
    return null;
  }

  final pendingContext = getValidPendingSocialAuthContext(
    currentAuthUid: userRef.id,
  );
  final inferredRole = inferRoleFromUserDocument(currentUser);
  final effectiveRoleIntent = pendingContext?.roleIntent ??
      roleIntentFromNativeSpeakerIntent(nativeSpeakerIntent);
  final decision = resolveSocialAuthEntryDecision(
    hasAssignedRole: currentUser.hasRole(),
    nativeSpeakerIntent: effectiveRoleIntent == UserRole.native_speaker,
    hasStudentBalance: currentUser.hasBalanceST(),
    inferredRole: inferredRole,
    allowNewAccountRoleIntent:
        NewAccountInboxBootstrap.wasAccountCreatedInCurrentSession(userRef.id),
  );
  _debugSocialAuthLog(
    'uid=${userRef.id} decision=${decision.destination.name} '
    'uidSource=${resolution.uidResolution.source.name} '
    'resolutionStatus=${resolution.status.name} '
    'legacyMatchCount=${resolution.legacyMatchCount} '
    'pendingContext=${pendingContext != null} '
    'rawRole=${currentUser.snapshotData['role']} '
    'role=${currentUser.role?.name ?? 'null'} '
    'assignRole=${decision.roleToAssign?.name ?? 'null'} '
    'grantBonus=${decision.grantStudentBonus}',
  );

  if (!decision.shouldAssignRole) {
    clearPendingSocialAuthContext();
    return decision;
  }

  final updatedUser = await persistCanonicalUserRole(
    userRef: userRef,
    role: decision.roleToAssign!,
    recoverySource: inferredRole != null
        ? UserRoleRecoverySource.profileShape
        : UserRoleRecoverySource.pendingIntent,
    authUserUid: authUserUid ?? userRef.id,
    existingUser: currentUser,
    grantStudentBonus: decision.grantStudentBonus,
    onDebugLog: _debugSocialAuthLog,
  );
  if (updatedUser == null) {
    return null;
  }

  return decision;
}
