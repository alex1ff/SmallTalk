import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class RewiewsOfTheAppRecord extends FirestoreRecord {
  RewiewsOfTheAppRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "chips" field.
  String? _chips;
  String get chips => _chips ?? '';
  bool hasChips() => _chips != null;

  // "comment" field.
  String? _comment;
  String get comment => _comment ?? '';
  bool hasComment() => _comment != null;

  // "user" field.
  DocumentReference? _user;
  DocumentReference? get user => _user;
  bool hasUser() => _user != null;

  // "date" field.
  DateTime? _date;
  DateTime? get date => _date;
  bool hasDate() => _date != null;

  void _initializeFields() {
    _chips = snapshotData['chips'] as String?;
    _comment = snapshotData['comment'] as String?;
    _user = snapshotData['user'] as DocumentReference?;
    _date = snapshotData['date'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('rewiews_of_the_app');

  static Stream<RewiewsOfTheAppRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => RewiewsOfTheAppRecord.fromSnapshot(s));

  static Future<RewiewsOfTheAppRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => RewiewsOfTheAppRecord.fromSnapshot(s));

  static RewiewsOfTheAppRecord fromSnapshot(DocumentSnapshot snapshot) =>
      RewiewsOfTheAppRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static RewiewsOfTheAppRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      RewiewsOfTheAppRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'RewiewsOfTheAppRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is RewiewsOfTheAppRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createRewiewsOfTheAppRecordData({
  String? chips,
  String? comment,
  DocumentReference? user,
  DateTime? date,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'chips': chips,
      'comment': comment,
      'user': user,
      'date': date,
    }.withoutNulls,
  );

  return firestoreData;
}

class RewiewsOfTheAppRecordDocumentEquality
    implements Equality<RewiewsOfTheAppRecord> {
  const RewiewsOfTheAppRecordDocumentEquality();

  @override
  bool equals(RewiewsOfTheAppRecord? e1, RewiewsOfTheAppRecord? e2) {
    return e1?.chips == e2?.chips &&
        e1?.comment == e2?.comment &&
        e1?.user == e2?.user &&
        e1?.date == e2?.date;
  }

  @override
  int hash(RewiewsOfTheAppRecord? e) =>
      const ListEquality().hash([e?.chips, e?.comment, e?.user, e?.date]);

  @override
  bool isValidKey(Object? o) => o is RewiewsOfTheAppRecord;
}
