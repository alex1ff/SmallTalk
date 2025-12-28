import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CardsRecord extends FirestoreRecord {
  CardsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "num" field.
  String? _num;
  String get num => _num ?? '';
  bool hasNum() => _num != null;

  // "pan" field.
  String? _pan;
  String get pan => _pan ?? '';
  bool hasPan() => _pan != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _num = snapshotData['num'] as String?;
    _pan = snapshotData['pan'] as String?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('cards')
          : FirebaseFirestore.instance.collectionGroup('cards');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('cards').doc(id);

  static Stream<CardsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CardsRecord.fromSnapshot(s));

  static Future<CardsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CardsRecord.fromSnapshot(s));

  static CardsRecord fromSnapshot(DocumentSnapshot snapshot) => CardsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CardsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CardsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CardsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CardsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCardsRecordData({
  String? num,
  String? pan,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'num': num,
      'pan': pan,
    }.withoutNulls,
  );

  return firestoreData;
}

class CardsRecordDocumentEquality implements Equality<CardsRecord> {
  const CardsRecordDocumentEquality();

  @override
  bool equals(CardsRecord? e1, CardsRecord? e2) {
    return e1?.num == e2?.num && e1?.pan == e2?.pan;
  }

  @override
  int hash(CardsRecord? e) => const ListEquality().hash([e?.num, e?.pan]);

  @override
  bool isValidKey(Object? o) => o is CardsRecord;
}
