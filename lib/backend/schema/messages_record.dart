import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MessagesRecord extends FirestoreRecord {
  MessagesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "senderId" field.
  String? _senderId;
  String get senderId => _senderId ?? '';
  bool hasSenderId() => _senderId != null;

  // "senderRef" field.
  DocumentReference? _senderRef;
  DocumentReference? get senderRef => _senderRef;
  bool hasSenderRef() => _senderRef != null;

  // "type" field.
  String? _type;
  String get type => _type ?? '';
  bool hasType() => _type != null;

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  bool hasText() => _text != null;

  // "sessionRef" field.
  DocumentReference? _sessionRef;
  DocumentReference? get sessionRef => _sessionRef;
  bool hasSessionRef() => _sessionRef != null;

  // "callKind" field.
  String? _callKind;
  String get callKind => _callKind ?? '';
  bool hasCallKind() => _callKind != null;

  // "callOutcome" field.
  String? _callOutcome;
  String get callOutcome => _callOutcome ?? '';
  bool hasCallOutcome() => _callOutcome != null;

  // "callerId" field.
  String? _callerId;
  String get callerId => _callerId ?? '';
  bool hasCallerId() => _callerId != null;

  // "recipientId" field.
  String? _recipientId;
  String get recipientId => _recipientId ?? '';
  bool hasRecipientId() => _recipientId != null;

  // "callStartedAt" field.
  DateTime? _callStartedAt;
  DateTime? get callStartedAt => _callStartedAt;
  bool hasCallStartedAt() => _callStartedAt != null;

  // "callEndedAt" field.
  DateTime? _callEndedAt;
  DateTime? get callEndedAt => _callEndedAt;
  bool hasCallEndedAt() => _callEndedAt != null;

  // "callDurationSeconds" field.
  int? _callDurationSeconds;
  int get callDurationSeconds => _callDurationSeconds ?? 0;
  bool hasCallDurationSeconds() => _callDurationSeconds != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _senderId = snapshotData['senderId'] as String?;
    _senderRef = snapshotData['senderRef'] as DocumentReference?;
    _type = snapshotData['type'] as String?;
    _text = snapshotData['text'] as String?;
    _sessionRef = snapshotData['sessionRef'] as DocumentReference?;
    _callKind = snapshotData['callKind'] as String?;
    _callOutcome = snapshotData['callOutcome'] as String?;
    _callerId = snapshotData['callerId'] as String?;
    _recipientId = snapshotData['recipientId'] as String?;
    _callStartedAt = snapshotData['callStartedAt'] as DateTime?;
    _callEndedAt = snapshotData['callEndedAt'] as DateTime?;
    _callDurationSeconds = castToType<int>(snapshotData['callDurationSeconds']);
    _createdAt = snapshotData['createdAt'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('messages')
          : FirebaseFirestore.instance.collectionGroup('messages');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('messages').doc(id);

  static Stream<MessagesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MessagesRecord.fromSnapshot(s));

  static Future<MessagesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MessagesRecord.fromSnapshot(s));

  static MessagesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MessagesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MessagesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MessagesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MessagesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MessagesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMessagesRecordData({
  String? senderId,
  DocumentReference? senderRef,
  String? type,
  String? text,
  DocumentReference? sessionRef,
  String? callKind,
  String? callOutcome,
  String? callerId,
  String? recipientId,
  DateTime? callStartedAt,
  DateTime? callEndedAt,
  int? callDurationSeconds,
  DateTime? createdAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'senderId': senderId,
      'senderRef': senderRef,
      'type': type,
      'text': text,
      'sessionRef': sessionRef,
      'callKind': callKind,
      'callOutcome': callOutcome,
      'callerId': callerId,
      'recipientId': recipientId,
      'callStartedAt': callStartedAt,
      'callEndedAt': callEndedAt,
      'callDurationSeconds': callDurationSeconds,
      'createdAt': createdAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class MessagesRecordDocumentEquality implements Equality<MessagesRecord> {
  const MessagesRecordDocumentEquality();

  @override
  bool equals(MessagesRecord? e1, MessagesRecord? e2) {
    return e1?.senderId == e2?.senderId &&
        e1?.senderRef == e2?.senderRef &&
        e1?.type == e2?.type &&
        e1?.text == e2?.text &&
        e1?.sessionRef == e2?.sessionRef &&
        e1?.callKind == e2?.callKind &&
        e1?.callOutcome == e2?.callOutcome &&
        e1?.callerId == e2?.callerId &&
        e1?.recipientId == e2?.recipientId &&
        e1?.callStartedAt == e2?.callStartedAt &&
        e1?.callEndedAt == e2?.callEndedAt &&
        e1?.callDurationSeconds == e2?.callDurationSeconds &&
        e1?.createdAt == e2?.createdAt;
  }

  @override
  int hash(MessagesRecord? e) => const ListEquality().hash([
        e?.senderId,
        e?.senderRef,
        e?.type,
        e?.text,
        e?.sessionRef,
        e?.callKind,
        e?.callOutcome,
        e?.callerId,
        e?.recipientId,
        e?.callStartedAt,
        e?.callEndedAt,
        e?.callDurationSeconds,
        e?.createdAt,
      ]);

  @override
  bool isValidKey(Object? o) => o is MessagesRecord;
}
