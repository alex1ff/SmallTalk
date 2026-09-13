import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ConversationsRecord extends FirestoreRecord {
  ConversationsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "pairId" field.
  String? _pairId;
  String get pairId => _pairId ?? '';
  bool hasPairId() => _pairId != null;

  // "participantIds" field.
  List<String>? _participantIds;
  List<String> get participantIds => _participantIds ?? const [];
  bool hasParticipantIds() => _participantIds != null;

  // "participantRefs" field.
  List<DocumentReference>? _participantRefs;
  List<DocumentReference> get participantRefs => _participantRefs ?? const [];
  bool hasParticipantRefs() => _participantRefs != null;

  // "isUnlocked" field.
  bool? _isUnlocked;
  bool get isUnlocked => _isUnlocked ?? false;
  bool hasIsUnlocked() => _isUnlocked != null;

  // "unlockedAt" field.
  DateTime? _unlockedAt;
  DateTime? get unlockedAt => _unlockedAt;
  bool hasUnlockedAt() => _unlockedAt != null;

  // "unlockedBySessionRef" field.
  DocumentReference? _unlockedBySessionRef;
  DocumentReference? get unlockedBySessionRef => _unlockedBySessionRef;
  bool hasUnlockedBySessionRef() => _unlockedBySessionRef != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  // "lastMessageAt" field.
  DateTime? _lastMessageAt;
  DateTime? get lastMessageAt => _lastMessageAt;
  bool hasLastMessageAt() => _lastMessageAt != null;

  // "lastMessageText" field.
  String? _lastMessageText;
  String? get lastMessageText => _lastMessageText;
  bool hasLastMessageText() => _lastMessageText != null;

  // "lastMessageType" field.
  String? _lastMessageType;
  String? get lastMessageType => _lastMessageType;
  bool hasLastMessageType() => _lastMessageType != null;

  // "lastMessageSenderId" field.
  String? _lastMessageSenderId;
  String? get lastMessageSenderId => _lastMessageSenderId;
  bool hasLastMessageSenderId() => _lastMessageSenderId != null;

  // "lastMessageId" field.
  String? _lastMessageId;
  String? get lastMessageId => _lastMessageId;
  bool hasLastMessageId() => _lastMessageId != null;

  // "lastCallOutcome" field.
  String? _lastCallOutcome;
  String? get lastCallOutcome => _lastCallOutcome;
  bool hasLastCallOutcome() => _lastCallOutcome != null;

  // "lastCallCallerId" field.
  String? _lastCallCallerId;
  String? get lastCallCallerId => _lastCallCallerId;
  bool hasLastCallCallerId() => _lastCallCallerId != null;

  // "lastCallRecipientId" field.
  String? _lastCallRecipientId;
  String? get lastCallRecipientId => _lastCallRecipientId;
  bool hasLastCallRecipientId() => _lastCallRecipientId != null;

  // "lastUnreadMessageAt" field.
  DateTime? _lastUnreadMessageAt;
  DateTime? get lastUnreadMessageAt => _lastUnreadMessageAt;
  bool hasLastUnreadMessageAt() => _lastUnreadMessageAt != null;

  // "lastUnreadMessageSenderId" field.
  String? _lastUnreadMessageSenderId;
  String? get lastUnreadMessageSenderId => _lastUnreadMessageSenderId;
  bool hasLastUnreadMessageSenderId() => _lastUnreadMessageSenderId != null;

  // "lastReadAtByUserId" field.
  Map<String, DateTime?>? _lastReadAtByUserId;
  Map<String, DateTime?> get lastReadAtByUserId =>
      _lastReadAtByUserId ?? const {};
  bool hasLastReadAtByUserId() => _lastReadAtByUserId != null;

  void _initializeFields() {
    _pairId = snapshotData['pairId'] as String?;
    _participantIds = getDataList(snapshotData['participantIds']);
    _participantRefs = getDataList(snapshotData['participantRefs']);
    _isUnlocked = snapshotData['isUnlocked'] as bool?;
    _unlockedAt = snapshotData['unlockedAt'] as DateTime?;
    _unlockedBySessionRef =
        snapshotData['unlockedBySessionRef'] as DocumentReference?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
    _lastMessageAt = snapshotData['lastMessageAt'] as DateTime?;
    _lastMessageText = snapshotData['lastMessageText'] as String?;
    _lastMessageType = snapshotData['lastMessageType'] as String?;
    _lastMessageSenderId = snapshotData['lastMessageSenderId'] as String?;
    _lastMessageId = snapshotData['lastMessageId'] as String?;
    _lastCallOutcome = snapshotData['lastCallOutcome'] as String?;
    _lastCallCallerId = snapshotData['lastCallCallerId'] as String?;
    _lastCallRecipientId = snapshotData['lastCallRecipientId'] as String?;
    _lastUnreadMessageAt = snapshotData['lastUnreadMessageAt'] as DateTime?;
    _lastUnreadMessageSenderId =
        snapshotData['lastUnreadMessageSenderId'] as String?;
    _lastReadAtByUserId =
        (snapshotData['lastReadAtByUserId'] as Map<String, dynamic>?)?.map(
      (key, value) => MapEntry(key, value as DateTime?),
    );
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('conversations');

  static Stream<ConversationsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ConversationsRecord.fromSnapshot(s));

  static Future<ConversationsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ConversationsRecord.fromSnapshot(s));

  static ConversationsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ConversationsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ConversationsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ConversationsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ConversationsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ConversationsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createConversationsRecordData({
  String? pairId,
  List<String>? participantIds,
  List<DocumentReference>? participantRefs,
  bool? isUnlocked,
  DateTime? unlockedAt,
  DocumentReference? unlockedBySessionRef,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? lastMessageAt,
  String? lastMessageText,
  String? lastMessageType,
  String? lastMessageSenderId,
  String? lastMessageId,
  String? lastCallOutcome,
  String? lastCallCallerId,
  String? lastCallRecipientId,
  DateTime? lastUnreadMessageAt,
  String? lastUnreadMessageSenderId,
  Map<String, DateTime?>? lastReadAtByUserId,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'pairId': pairId,
      'participantIds': participantIds,
      'participantRefs': participantRefs,
      'isUnlocked': isUnlocked,
      'unlockedAt': unlockedAt,
      'unlockedBySessionRef': unlockedBySessionRef,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastMessageAt': lastMessageAt,
      'lastMessageText': lastMessageText,
      'lastMessageType': lastMessageType,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageId': lastMessageId,
      'lastCallOutcome': lastCallOutcome,
      'lastCallCallerId': lastCallCallerId,
      'lastCallRecipientId': lastCallRecipientId,
      'lastUnreadMessageAt': lastUnreadMessageAt,
      'lastUnreadMessageSenderId': lastUnreadMessageSenderId,
      'lastReadAtByUserId': lastReadAtByUserId ?? const <String, DateTime?>{},
    }.withoutNulls,
  );

  return firestoreData;
}

class ConversationsRecordDocumentEquality
    implements Equality<ConversationsRecord> {
  const ConversationsRecordDocumentEquality();

  @override
  bool equals(ConversationsRecord? e1, ConversationsRecord? e2) {
    const listEquality = ListEquality();
    const mapEquality = MapEquality();
    return e1?.pairId == e2?.pairId &&
        listEquality.equals(e1?.participantIds, e2?.participantIds) &&
        listEquality.equals(e1?.participantRefs, e2?.participantRefs) &&
        e1?.isUnlocked == e2?.isUnlocked &&
        e1?.unlockedAt == e2?.unlockedAt &&
        e1?.unlockedBySessionRef == e2?.unlockedBySessionRef &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt &&
        e1?.lastMessageAt == e2?.lastMessageAt &&
        e1?.lastMessageText == e2?.lastMessageText &&
        e1?.lastMessageType == e2?.lastMessageType &&
        e1?.lastMessageSenderId == e2?.lastMessageSenderId &&
        e1?.lastMessageId == e2?.lastMessageId &&
        e1?.lastCallOutcome == e2?.lastCallOutcome &&
        e1?.lastCallCallerId == e2?.lastCallCallerId &&
        e1?.lastCallRecipientId == e2?.lastCallRecipientId &&
        e1?.lastUnreadMessageAt == e2?.lastUnreadMessageAt &&
        e1?.lastUnreadMessageSenderId == e2?.lastUnreadMessageSenderId &&
        mapEquality.equals(e1?.lastReadAtByUserId, e2?.lastReadAtByUserId);
  }

  @override
  int hash(ConversationsRecord? e) => const ListEquality().hash([
        e?.pairId,
        e?.participantIds,
        e?.participantRefs,
        e?.isUnlocked,
        e?.unlockedAt,
        e?.unlockedBySessionRef,
        e?.createdAt,
        e?.updatedAt,
        e?.lastMessageAt,
        e?.lastMessageText,
        e?.lastMessageType,
        e?.lastMessageSenderId,
        e?.lastMessageId,
        e?.lastCallOutcome,
        e?.lastCallCallerId,
        e?.lastCallRecipientId,
        e?.lastUnreadMessageAt,
        e?.lastUnreadMessageSenderId,
        e?.lastReadAtByUserId
      ]);

  @override
  bool isValidKey(Object? o) => o is ConversationsRecord;
}
