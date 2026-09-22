import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EventParticipantsRecord extends FirestoreRecord {
  EventParticipantsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "userId" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "displayName" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "photoUrl" field.
  String? _photoUrl;
  String get photoUrl => _photoUrl ?? '';
  bool hasPhotoUrl() => _photoUrl != null;

  // "role" field.
  String? _role;
  String get role => _role ?? '';
  bool hasRole() => _role != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "joinedAt" field.
  DateTime? _joinedAt;
  DateTime? get joinedAt => _joinedAt;
  bool hasJoinedAt() => _joinedAt != null;

  // "leftAt" field.
  DateTime? _leftAt;
  DateTime? get leftAt => _leftAt;
  bool hasLeftAt() => _leftAt != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _userId = snapshotData['userId'] as String?;
    _displayName = snapshotData['displayName'] as String?;
    _photoUrl = snapshotData['photoUrl'] as String?;
    _role = snapshotData['role'] as String?;
    _status = snapshotData['status'] as String?;
    _joinedAt = snapshotData['joinedAt'] as DateTime?;
    _leftAt = snapshotData['leftAt'] as DateTime?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('participants')
          : FirebaseFirestore.instance.collectionGroup('participants');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('participants').doc(id);

  static Stream<EventParticipantsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => EventParticipantsRecord.fromSnapshot(s));

  static Future<EventParticipantsRecord> getDocumentOnce(
    DocumentReference ref,
  ) =>
      ref.get().then((s) => EventParticipantsRecord.fromSnapshot(s));

  static EventParticipantsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      EventParticipantsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EventParticipantsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EventParticipantsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'EventParticipantsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is EventParticipantsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createEventParticipantsRecordData({
  String? userId,
  String? displayName,
  String? photoUrl,
  String? role,
  String? status,
  DateTime? joinedAt,
  DateTime? leftAt,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'userId': userId,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'role': role,
      'status': status,
      'joinedAt': joinedAt,
      'leftAt': leftAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class EventParticipantsRecordDocumentEquality
    implements Equality<EventParticipantsRecord> {
  const EventParticipantsRecordDocumentEquality();

  @override
  bool equals(EventParticipantsRecord? e1, EventParticipantsRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.displayName == e2?.displayName &&
        e1?.photoUrl == e2?.photoUrl &&
        e1?.role == e2?.role &&
        e1?.status == e2?.status &&
        e1?.joinedAt == e2?.joinedAt &&
        e1?.leftAt == e2?.leftAt &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt;
  }

  @override
  int hash(EventParticipantsRecord? e) => const ListEquality().hash([
        e?.userId,
        e?.displayName,
        e?.photoUrl,
        e?.role,
        e?.status,
        e?.joinedAt,
        e?.leftAt,
        e?.createdAt,
        e?.updatedAt,
      ]);

  @override
  bool isValidKey(Object? o) => o is EventParticipantsRecord;
}
