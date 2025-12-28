import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class NotificationsRecord extends FirestoreRecord {
  NotificationsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "type" field.
  NotificationType? _type;
  NotificationType? get type => _type;
  bool hasType() => _type != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "recipientId" field.
  String? _recipientId;
  String get recipientId => _recipientId ?? '';
  bool hasRecipientId() => _recipientId != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "message" field.
  String? _message;
  String get message => _message ?? '';
  bool hasMessage() => _message != null;

  // "expiresAt" field.
  DateTime? _expiresAt;
  DateTime? get expiresAt => _expiresAt;
  bool hasExpiresAt() => _expiresAt != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "studentInfo" field.
  StudentInfoStruct? _studentInfo;
  StudentInfoStruct get studentInfo => _studentInfo ?? StudentInfoStruct();
  bool hasStudentInfo() => _studentInfo != null;

  // "acceptedAt" field.
  DateTime? _acceptedAt;
  DateTime? get acceptedAt => _acceptedAt;
  bool hasAcceptedAt() => _acceptedAt != null;

  // "sessionId" field.
  String? _sessionId;
  String get sessionId => _sessionId ?? '';
  bool hasSessionId() => _sessionId != null;

  void _initializeFields() {
    _type = snapshotData['type'] is NotificationType
        ? snapshotData['type']
        : deserializeEnum<NotificationType>(snapshotData['type']);
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _recipientId = snapshotData['recipientId'] as String?;
    _title = snapshotData['title'] as String?;
    _message = snapshotData['message'] as String?;
    _expiresAt = snapshotData['expiresAt'] as DateTime?;
    _status = snapshotData['status'] as String?;
    _studentInfo = snapshotData['studentInfo'] is StudentInfoStruct
        ? snapshotData['studentInfo']
        : StudentInfoStruct.maybeFromMap(snapshotData['studentInfo']);
    _acceptedAt = snapshotData['acceptedAt'] as DateTime?;
    _sessionId = snapshotData['sessionId'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('notifications');

  static Stream<NotificationsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => NotificationsRecord.fromSnapshot(s));

  static Future<NotificationsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => NotificationsRecord.fromSnapshot(s));

  static NotificationsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      NotificationsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static NotificationsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      NotificationsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'NotificationsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is NotificationsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createNotificationsRecordData({
  NotificationType? type,
  DateTime? createdAt,
  String? recipientId,
  String? title,
  String? message,
  DateTime? expiresAt,
  String? status,
  StudentInfoStruct? studentInfo,
  DateTime? acceptedAt,
  String? sessionId,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'type': type,
      'createdAt': createdAt,
      'recipientId': recipientId,
      'title': title,
      'message': message,
      'expiresAt': expiresAt,
      'status': status,
      'studentInfo': StudentInfoStruct().toMap(),
      'acceptedAt': acceptedAt,
      'sessionId': sessionId,
    }.withoutNulls,
  );

  // Handle nested data for "studentInfo" field.
  addStudentInfoStructData(firestoreData, studentInfo, 'studentInfo');

  return firestoreData;
}

class NotificationsRecordDocumentEquality
    implements Equality<NotificationsRecord> {
  const NotificationsRecordDocumentEquality();

  @override
  bool equals(NotificationsRecord? e1, NotificationsRecord? e2) {
    return e1?.type == e2?.type &&
        e1?.createdAt == e2?.createdAt &&
        e1?.recipientId == e2?.recipientId &&
        e1?.title == e2?.title &&
        e1?.message == e2?.message &&
        e1?.expiresAt == e2?.expiresAt &&
        e1?.status == e2?.status &&
        e1?.studentInfo == e2?.studentInfo &&
        e1?.acceptedAt == e2?.acceptedAt &&
        e1?.sessionId == e2?.sessionId;
  }

  @override
  int hash(NotificationsRecord? e) => const ListEquality().hash([
        e?.type,
        e?.createdAt,
        e?.recipientId,
        e?.title,
        e?.message,
        e?.expiresAt,
        e?.status,
        e?.studentInfo,
        e?.acceptedAt,
        e?.sessionId
      ]);

  @override
  bool isValidKey(Object? o) => o is NotificationsRecord;
}
