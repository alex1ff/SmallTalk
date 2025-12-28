import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class AvatarsRecord extends FirestoreRecord {
  AvatarsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "gender" field.
  Gender? _gender;
  Gender? get gender => _gender;
  bool hasGender() => _gender != null;

  // "images" field.
  List<String>? _images;
  List<String> get images => _images ?? const [];
  bool hasImages() => _images != null;

  void _initializeFields() {
    _gender = snapshotData['gender'] is Gender
        ? snapshotData['gender']
        : deserializeEnum<Gender>(snapshotData['gender']);
    _images = getDataList(snapshotData['images']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('avatars');

  static Stream<AvatarsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => AvatarsRecord.fromSnapshot(s));

  static Future<AvatarsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => AvatarsRecord.fromSnapshot(s));

  static AvatarsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      AvatarsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static AvatarsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      AvatarsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'AvatarsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is AvatarsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createAvatarsRecordData({
  Gender? gender,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'gender': gender,
    }.withoutNulls,
  );

  return firestoreData;
}

class AvatarsRecordDocumentEquality implements Equality<AvatarsRecord> {
  const AvatarsRecordDocumentEquality();

  @override
  bool equals(AvatarsRecord? e1, AvatarsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.gender == e2?.gender &&
        listEquality.equals(e1?.images, e2?.images);
  }

  @override
  int hash(AvatarsRecord? e) =>
      const ListEquality().hash([e?.gender, e?.images]);

  @override
  bool isValidKey(Object? o) => o is AvatarsRecord;
}
