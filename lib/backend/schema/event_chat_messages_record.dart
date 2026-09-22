import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';

class EventChatMessagesRecord extends FirestoreRecord {
  EventChatMessagesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "senderId" field.
  String? _senderId;
  String get senderId => _senderId ?? '';
  bool hasSenderId() => _senderId != null;

  // "senderDisplayName" field.
  String? _senderDisplayName;
  String get senderDisplayName => _senderDisplayName ?? '';
  bool hasSenderDisplayName() => _senderDisplayName != null;

  // "senderPhotoUrl" field.
  String? _senderPhotoUrl;
  String get senderPhotoUrl => _senderPhotoUrl ?? '';
  bool hasSenderPhotoUrl() => _senderPhotoUrl != null;

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  bool hasText() => _text != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "deletedAt" field.
  DateTime? _deletedAt;
  DateTime? get deletedAt => _deletedAt;
  bool hasDeletedAt() => _deletedAt != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _senderId = snapshotData['senderId'] as String?;
    _senderDisplayName = snapshotData['senderDisplayName'] as String?;
    _senderPhotoUrl = snapshotData['senderPhotoUrl'] as String?;
    _text = snapshotData['text'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _deletedAt = snapshotData['deletedAt'] as DateTime?;
  }

  static CollectionReference collection(DocumentReference parent) =>
      parent.collection('messages');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('messages').doc(id);

  static Stream<EventChatMessagesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => EventChatMessagesRecord.fromSnapshot(s));

  static Future<EventChatMessagesRecord> getDocumentOnce(
    DocumentReference ref,
  ) =>
      ref.get().then((s) => EventChatMessagesRecord.fromSnapshot(s));

  static EventChatMessagesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      EventChatMessagesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EventChatMessagesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EventChatMessagesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'EventChatMessagesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is EventChatMessagesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

class EventChatMessagesRecordDocumentEquality
    implements Equality<EventChatMessagesRecord> {
  const EventChatMessagesRecordDocumentEquality();

  @override
  bool equals(EventChatMessagesRecord? e1, EventChatMessagesRecord? e2) {
    return e1?.senderId == e2?.senderId &&
        e1?.senderDisplayName == e2?.senderDisplayName &&
        e1?.senderPhotoUrl == e2?.senderPhotoUrl &&
        e1?.text == e2?.text &&
        e1?.createdAt == e2?.createdAt &&
        e1?.deletedAt == e2?.deletedAt;
  }

  @override
  int hash(EventChatMessagesRecord? e) => const ListEquality().hash([
        e?.senderId,
        e?.senderDisplayName,
        e?.senderPhotoUrl,
        e?.text,
        e?.createdAt,
        e?.deletedAt,
      ]);

  @override
  bool isValidKey(Object? o) => o is EventChatMessagesRecord;
}
