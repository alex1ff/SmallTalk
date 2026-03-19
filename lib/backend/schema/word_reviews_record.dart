import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class WordReviewsRecord extends FirestoreRecord {
  WordReviewsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  DocumentReference? _wordRef;
  DocumentReference? get wordRef => _wordRef;
  bool hasWordRef() => _wordRef != null;

  int? _stage;
  int get stage => _stage ?? 1;
  bool hasStage() => _stage != null;

  DateTime? _dueAt;
  DateTime? get dueAt => _dueAt;
  bool hasDueAt() => _dueAt != null;

  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  DateTime? _lastReviewedAt;
  DateTime? get lastReviewedAt => _lastReviewedAt;
  bool hasLastReviewedAt() => _lastReviewedAt != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _wordRef = snapshotData['wordRef'] as DocumentReference?;
    _stage = castToType<int>(snapshotData['stage']);
    _dueAt = snapshotData['dueAt'] as DateTime?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
    _lastReviewedAt = snapshotData['lastReviewedAt'] as DateTime?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('wordReviews')
          : FirebaseFirestore.instance.collectionGroup('wordReviews');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('wordReviews').doc(id);

  static Stream<WordReviewsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WordReviewsRecord.fromSnapshot(s));

  static Future<WordReviewsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => WordReviewsRecord.fromSnapshot(s));

  static WordReviewsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WordReviewsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WordReviewsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WordReviewsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WordReviewsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WordReviewsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createWordReviewsRecordData({
  DocumentReference? wordRef,
  int? stage,
  DateTime? dueAt,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? lastReviewedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'wordRef': wordRef,
      'stage': stage,
      'dueAt': dueAt,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'lastReviewedAt': lastReviewedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class WordReviewsRecordDocumentEquality implements Equality<WordReviewsRecord> {
  const WordReviewsRecordDocumentEquality();

  @override
  bool equals(WordReviewsRecord? e1, WordReviewsRecord? e2) =>
      e1?.wordRef == e2?.wordRef &&
      e1?.stage == e2?.stage &&
      e1?.dueAt == e2?.dueAt &&
      e1?.createdAt == e2?.createdAt &&
      e1?.updatedAt == e2?.updatedAt &&
      e1?.lastReviewedAt == e2?.lastReviewedAt;

  @override
  int hash(WordReviewsRecord? e) => const ListEquality().hash([
        e?.wordRef,
        e?.stage,
        e?.dueAt,
        e?.createdAt,
        e?.updatedAt,
        e?.lastReviewedAt,
      ]);

  @override
  bool isValidKey(Object? o) => o is WordReviewsRecord;
}
