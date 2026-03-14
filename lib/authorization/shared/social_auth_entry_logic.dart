import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_util.dart';

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

Future<UsersRecord?> refreshCurrentUserDocumentForAuthEntry() async {
  final userRef = currentUserReference;
  if (userRef == null) {
    return null;
  }

  final snapshot = await userRef.get();
  if (!snapshot.exists || snapshot.data() == null) {
    return null;
  }

  final userDocument = UsersRecord.fromSnapshot(snapshot);
  currentUserDocument = userDocument;
  return userDocument;
}

Future<SocialAuthEntryDecision?> resolveAndPersistSocialAuthEntry({
  required bool nativeSpeakerIntent,
}) async {
  final userRef = currentUserReference;
  if (userRef == null) {
    return null;
  }

  final currentUser = await refreshCurrentUserDocumentForAuthEntry();
  if (currentUser == null) {
    return null;
  }

  final decision = resolveSocialAuthEntryDecision(
    hasAssignedRole: currentUser.hasRole(),
    nativeSpeakerIntent: nativeSpeakerIntent,
    hasStudentBalance: currentUser.hasBalanceST(),
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

  await refreshCurrentUserDocumentForAuthEntry();
  return decision;
}
