import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PackagesRecord extends FirestoreRecord {
  PackagesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "smallTalks" field.
  int? _smallTalks;
  int get smallTalks => _smallTalks ?? 0;
  bool hasSmallTalks() => _smallTalks != null;

  // "minutes" field.
  int? _minutes;
  int get minutes => _minutes ?? 0;
  bool hasMinutes() => _minutes != null;

  // "price" field.
  int? _price;
  int get price => _price ?? 0;
  bool hasPrice() => _price != null;

  // "currency" field.
  String? _currency;
  String get currency => _currency ?? '';
  bool hasCurrency() => _currency != null;

  // "old_price" field.
  int? _oldPrice;
  int get oldPrice => _oldPrice ?? 0;
  bool hasOldPrice() => _oldPrice != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _smallTalks = castToType<int>(snapshotData['smallTalks']);
    _minutes = castToType<int>(snapshotData['minutes']);
    _price = castToType<int>(snapshotData['price']);
    _currency = snapshotData['currency'] as String?;
    _oldPrice = castToType<int>(snapshotData['old_price']);
    _description = snapshotData['description'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('packages');

  static Stream<PackagesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => PackagesRecord.fromSnapshot(s));

  static Future<PackagesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => PackagesRecord.fromSnapshot(s));

  static PackagesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      PackagesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static PackagesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      PackagesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'PackagesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is PackagesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createPackagesRecordData({
  String? name,
  int? smallTalks,
  int? minutes,
  int? price,
  String? currency,
  int? oldPrice,
  String? description,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'smallTalks': smallTalks,
      'minutes': minutes,
      'price': price,
      'currency': currency,
      'old_price': oldPrice,
      'description': description,
    }.withoutNulls,
  );

  return firestoreData;
}

class PackagesRecordDocumentEquality implements Equality<PackagesRecord> {
  const PackagesRecordDocumentEquality();

  @override
  bool equals(PackagesRecord? e1, PackagesRecord? e2) {
    return e1?.name == e2?.name &&
        e1?.smallTalks == e2?.smallTalks &&
        e1?.minutes == e2?.minutes &&
        e1?.price == e2?.price &&
        e1?.currency == e2?.currency &&
        e1?.oldPrice == e2?.oldPrice &&
        e1?.description == e2?.description;
  }

  @override
  int hash(PackagesRecord? e) => const ListEquality().hash([
        e?.name,
        e?.smallTalks,
        e?.minutes,
        e?.price,
        e?.currency,
        e?.oldPrice,
        e?.description
      ]);

  @override
  bool isValidKey(Object? o) => o is PackagesRecord;
}
