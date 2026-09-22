import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PromoCodesRecord extends FirestoreRecord {
  PromoCodesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "code" field.
  String? _code;
  String get code => _code ?? '';
  bool hasCode() => _code != null;

  // "usageLimit" field.
  int? _usageLimit;
  int get usageLimit => _usageLimit ?? 0;
  bool hasUsageLimit() => _usageLimit != null;

  // "usageCount" field.
  int? _usageCount;
  int get usageCount => _usageCount ?? 0;
  bool hasUsageCount() => _usageCount != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "isActive" field.
  bool? _isActive;
  bool get isActive => _isActive ?? false;
  bool hasIsActive() => _isActive != null;

  // "expiredDate" field.
  DateTime? _expiredDate;
  DateTime? get expiredDate => _expiredDate;
  bool hasExpiredDate() => _expiredDate != null;

  // "usedBy" field.
  List<PromoUsedByStruct>? _usedBy;
  List<PromoUsedByStruct> get usedBy => _usedBy ?? const [];
  bool hasUsedBy() => _usedBy != null;

  // "minutesGifted" field.
  int? _minutesGifted;
  int get minutesGifted => _minutesGifted ?? 0;
  bool hasMinutesGifted() => _minutesGifted != null;

  // "validForDays" field.
  int? _validForDays;
  int get validForDays => _validForDays ?? 0;
  bool hasValidForDays() => _validForDays != null;

  void _initializeFields() {
    _code = snapshotData['code'] as String?;
    _usageLimit = castToType<int>(snapshotData['usageLimit']);
    _usageCount = castToType<int>(snapshotData['usageCount']);
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _isActive = snapshotData['isActive'] as bool?;
    _expiredDate = snapshotData['expiredDate'] as DateTime?;
    _usedBy = getStructList(
      snapshotData['usedBy'],
      PromoUsedByStruct.fromMap,
    );
    _minutesGifted = castToType<int>(snapshotData['minutesGifted']);
    _validForDays = castToType<int>(snapshotData['validForDays']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('promoCodes');

  static Stream<PromoCodesRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => PromoCodesRecord.fromSnapshot(s));

  static Future<PromoCodesRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => PromoCodesRecord.fromSnapshot(s));

  static PromoCodesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      PromoCodesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static PromoCodesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      PromoCodesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'PromoCodesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is PromoCodesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createPromoCodesRecordData({
  String? code,
  int? usageLimit,
  int? usageCount,
  DateTime? createdAt,
  bool? isActive,
  DateTime? expiredDate,
  int? minutesGifted,
  int? validForDays,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'code': code,
      'usageLimit': usageLimit,
      'usageCount': usageCount,
      'createdAt': createdAt,
      'isActive': isActive,
      'expiredDate': expiredDate,
      'minutesGifted': minutesGifted,
      'validForDays': validForDays,
    }.withoutNulls,
  );

  return firestoreData;
}

class PromoCodesRecordDocumentEquality implements Equality<PromoCodesRecord> {
  const PromoCodesRecordDocumentEquality();

  @override
  bool equals(PromoCodesRecord? e1, PromoCodesRecord? e2) {
    const listEquality = ListEquality();
    return e1?.code == e2?.code &&
        e1?.usageLimit == e2?.usageLimit &&
        e1?.usageCount == e2?.usageCount &&
        e1?.createdAt == e2?.createdAt &&
        e1?.isActive == e2?.isActive &&
        e1?.expiredDate == e2?.expiredDate &&
        listEquality.equals(e1?.usedBy, e2?.usedBy) &&
        e1?.minutesGifted == e2?.minutesGifted &&
        e1?.validForDays == e2?.validForDays;
  }

  @override
  int hash(PromoCodesRecord? e) => const ListEquality().hash([
        e?.code,
        e?.usageLimit,
        e?.usageCount,
        e?.createdAt,
        e?.isActive,
        e?.expiredDate,
        e?.usedBy,
        e?.minutesGifted,
        e?.validForDays
      ]);

  @override
  bool isValidKey(Object? o) => o is PromoCodesRecord;
}
