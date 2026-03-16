import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/foundation.dart';

enum SocialAuthEntryDestination {
  loading,
  acquaintanceNativeSpeaker,
  acquaintanceStudent,
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

SocialAuthEntryDecision resolveSocialAuthEntryDecision({
  required bool hasAssignedRole,
  required bool nativeSpeakerIntent,
  required bool hasStudentBalance,
}) {
  if (hasAssignedRole) {
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

Future<UsersRecord?> refreshCurrentUserDocumentForAuthEntry({
  String? authUserUid,
}) async {
  return waitForResolvedCurrentUserDocument(
    preferredUid: authUserUid,
    refreshFromBackend: true,
    onDebugLog: _debugSocialAuthLog,
  );
}

Future<SocialAuthEntryDecision?> resolveAndPersistSocialAuthEntry({
  required bool nativeSpeakerIntent,
  String? authUserUid,
}) async {
  final userRef = resolveCurrentUserReference(preferredUid: authUserUid);
  if (userRef == null) {
    _debugSocialAuthLog('cannot resolve userRef after social auth');
    return null;
  }

  final currentUser =
      await refreshCurrentUserDocumentForAuthEntry(authUserUid: authUserUid);
  if (currentUser == null) {
    _debugSocialAuthLog('user doc unavailable after social auth');
    return null;
  }

  final decision = resolveSocialAuthEntryDecision(
    hasAssignedRole: currentUser.hasRole(),
    nativeSpeakerIntent: nativeSpeakerIntent,
    hasStudentBalance: currentUser.hasBalanceST(),
  );
  _debugSocialAuthLog(
    'uid=${userRef.id} decision=${decision.destination.name} '
    'rawRole=${currentUser.snapshotData['role']} '
    'role=${currentUser.role?.name ?? 'null'} '
    'assignRole=${decision.roleToAssign?.name ?? 'null'} '
    'grantBonus=${decision.grantStudentBonus}',
  );

  if (!decision.shouldAssignRole) {
    return decision;
  }

  final updateData = <String, dynamic>{
    ...createUsersRecordData(
      role: decision.roleToAssign,
    ),
  };

  if (decision.grantStudentBonus) {
    updateData.addAll(
      createUsersRecordData(
        balanceST: updateBalanceStruct(
          BalanceStruct(
            smallTalks: 1,
            minutes: 10,
          ),
          clearUnsetFields: false,
          create: true,
        ),
      ),
    );
  }

  await userRef.update(updateData);

  if (decision.grantStudentBonus) {
    await TransactionsRecord.collection.doc().set(
          createTransactionsRecordData(
            userId: userRef,
            createdAt: getCurrentTimestamp,
            type: TypeTransactions.bonus,
            status: StatusTransactions.completed,
            amountST: 1.0,
          ),
        );
  }

  await refreshCurrentUserDocumentForAuthEntry(authUserUid: authUserUid);
  return decision;
}
