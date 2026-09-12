import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';

class EventChatsRecord extends FirestoreRecord {
  EventChatsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "eventId" field.
  String? _eventId;
  String get eventId => _eventId ?? '';
  bool hasEventId() => _eventId != null;

  // "readAccessUserIds" field.
  List<String>? _readAccessUserIds;
  List<String> get readAccessUserIds => _readAccessUserIds ?? const [];
  bool hasReadAccessUserIds() => _readAccessUserIds != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  void _initializeFields() {
    _eventId = snapshotData['eventId'] as String?;
    _readAccessUserIds = getDataList(snapshotData['readAccessUserIds']);
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('eventChats');

  static Stream<EventChatsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => EventChatsRecord.fromSnapshot(s));

  static Future<EventChatsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => EventChatsRecord.fromSnapshot(s));

  static EventChatsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      EventChatsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EventChatsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EventChatsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'EventChatsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is EventChatsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

class EventChatsRecordDocumentEquality implements Equality<EventChatsRecord> {
  const EventChatsRecordDocumentEquality();

  @override
  bool equals(EventChatsRecord? e1, EventChatsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.eventId == e2?.eventId &&
        listEquality.equals(e1?.readAccessUserIds, e2?.readAccessUserIds) &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt;
  }

  @override
  int hash(EventChatsRecord? e) => const ListEquality().hash([
        e?.eventId,
        e?.readAccessUserIds,
        e?.createdAt,
        e?.updatedAt,
      ]);

  @override
  bool isValidKey(Object? o) => o is EventChatsRecord;
}
