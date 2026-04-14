import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/users_record.dart';
import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

List<DocumentReference> _dedupeReferences(
  Iterable<DocumentReference> references,
) {
  final seenPaths = <String>{};
  final deduped = <DocumentReference>[];

  for (final reference in references) {
    if (seenPaths.add(reference.path)) {
      deduped.add(reference);
    }
  }

  return List.unmodifiable(deduped);
}

bool _referenceListsMatchByPath(
  Iterable<DocumentReference> lhs,
  Iterable<DocumentReference> rhs,
) {
  final lhsPaths = lhs.map((reference) => reference.path).toSet();
  final rhsPaths = rhs.map((reference) => reference.path).toSet();
  if (lhsPaths.length != rhsPaths.length) {
    return false;
  }

  for (final path in lhsPaths) {
    if (!rhsPaths.contains(path)) {
      return false;
    }
  }

  return true;
}

List<DocumentReference> _storedFriends(UsersRecord user) =>
    getDataList(user.snapshotData['friends']) ?? const <DocumentReference>[];

extension UsersRecordFriendsX on UsersRecord {
  List<DocumentReference> get resolvedFriends =>
      _dedupeReferences([...friends, ...favoriteNativeSpeakers]);

  bool isFriend(DocumentReference? target) {
    if (target == null) {
      return false;
    }

    for (final reference in resolvedFriends) {
      if (reference.path == target.path) {
        return true;
      }
    }

    return false;
  }
}

List<DocumentReference> resolveFriendsForUser(UsersRecord? user) =>
    user?.resolvedFriends ?? const <DocumentReference>[];

bool userHasFriend(
  UsersRecord? user,
  DocumentReference? target,
) =>
    user?.isFriend(target) ?? false;

Map<String, dynamic> buildAddFriendUpdateData(DocumentReference friendRef) =>
    mapToFirestore(
      <String, dynamic>{
        'friends': FieldValue.arrayUnion([friendRef]),
        'favoriteNativeSpeakers': FieldValue.arrayUnion([friendRef]),
      },
    );

Map<String, dynamic> buildRemoveFriendUpdateData(DocumentReference friendRef) =>
    mapToFirestore(
      <String, dynamic>{
        'friends': FieldValue.arrayRemove([friendRef]),
        'favoriteNativeSpeakers': FieldValue.arrayRemove([friendRef]),
      },
    );

Map<String, dynamic> buildBlockAndRemoveFriendUpdateData(
  DocumentReference blockedRef,
) =>
    mapToFirestore(
      <String, dynamic>{
        'friends': FieldValue.arrayRemove([blockedRef]),
        'favoriteNativeSpeakers': FieldValue.arrayRemove([blockedRef]),
        'blockedUsers': FieldValue.arrayUnion([blockedRef]),
      },
    );

Future<void> backfillUserFriendsFromLegacy(UsersRecord user) async {
  if (user.favoriteNativeSpeakers.isEmpty) {
    return;
  }

  final resolvedFriends = user.resolvedFriends;
  final storedFriends = _storedFriends(user);
  if (_referenceListsMatchByPath(storedFriends, resolvedFriends)) {
    return;
  }

  final existingFriendPaths =
      storedFriends.map((reference) => reference.path).toSet();
  final missingLegacyFriends = resolvedFriends
      .where((reference) => !existingFriendPaths.contains(reference.path))
      .toList();
  if (missingLegacyFriends.isEmpty) {
    return;
  }

  await user.reference.update(
    mapToFirestore(
      <String, dynamic>{
        'friends': FieldValue.arrayUnion(missingLegacyFriends),
      },
    ),
  );
}
