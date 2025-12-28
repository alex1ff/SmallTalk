import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UserWordsRecord extends FirestoreRecord {
  UserWordsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "addedAt" field.
  DateTime? _addedAt;
  DateTime? get addedAt => _addedAt;
  bool hasAddedAt() => _addedAt != null;

  // "Sentence" field.
  List<SentenceStruct>? _sentence;
  List<SentenceStruct> get sentence => _sentence ?? const [];
  bool hasSentence() => _sentence != null;

  // "entry" field.
  List<EntryStruct>? _entry;
  List<EntryStruct> get entry => _entry ?? const [];
  bool hasEntry() => _entry != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _addedAt = snapshotData['addedAt'] as DateTime?;
    _sentence = getStructList(
      snapshotData['Sentence'],
      SentenceStruct.fromMap,
    );
    _entry = getStructList(
      snapshotData['entry'],
      EntryStruct.fromMap,
    );
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('userWords')
          : FirebaseFirestore.instance.collectionGroup('userWords');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('userWords').doc(id);

  static Stream<UserWordsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UserWordsRecord.fromSnapshot(s));

  static Future<UserWordsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UserWordsRecord.fromSnapshot(s));

  static UserWordsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      UserWordsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UserWordsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UserWordsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UserWordsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UserWordsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUserWordsRecordData({
  DateTime? addedAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'addedAt': addedAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class UserWordsRecordDocumentEquality implements Equality<UserWordsRecord> {
  const UserWordsRecordDocumentEquality();

  @override
  bool equals(UserWordsRecord? e1, UserWordsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.addedAt == e2?.addedAt &&
        listEquality.equals(e1?.sentence, e2?.sentence) &&
        listEquality.equals(e1?.entry, e2?.entry);
  }

  @override
  int hash(UserWordsRecord? e) =>
      const ListEquality().hash([e?.addedAt, e?.sentence, e?.entry]);

  @override
  bool isValidKey(Object? o) => o is UserWordsRecord;
}
