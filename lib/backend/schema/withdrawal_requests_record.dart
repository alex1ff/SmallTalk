import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class WithdrawalRequestsRecord extends FirestoreRecord {
  WithdrawalRequestsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "userId" field.
  DocumentReference? _userId;
  DocumentReference? get userId => _userId;
  bool hasUserId() => _userId != null;

  // "currency" field.
  String? _currency;
  String get currency => _currency ?? '';
  bool hasCurrency() => _currency != null;

  // "reason" field.
  String? _reason;
  String get reason => _reason ?? '';
  bool hasReason() => _reason != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "processedAt" field.
  DateTime? _processedAt;
  DateTime? get processedAt => _processedAt;
  bool hasProcessedAt() => _processedAt != null;

  // "completedAt" field.
  DateTime? _completedAt;
  DateTime? get completedAt => _completedAt;
  bool hasCompletedAt() => _completedAt != null;

  // "amount" field.
  double? _amount;
  double get amount => _amount ?? 0.0;
  bool hasAmount() => _amount != null;

  // "status" field.
  StatusTransactions? _status;
  StatusTransactions? get status => _status;
  bool hasStatus() => _status != null;

  void _initializeFields() {
    _userId = snapshotData['userId'] as DocumentReference?;
    _currency = snapshotData['currency'] as String?;
    _reason = snapshotData['reason'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _processedAt = snapshotData['processedAt'] as DateTime?;
    _completedAt = snapshotData['completedAt'] as DateTime?;
    _amount = castToType<double>(snapshotData['amount']);
    _status = snapshotData['status'] is StatusTransactions
        ? snapshotData['status']
        : deserializeEnum<StatusTransactions>(snapshotData['status']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('withdrawalRequests');

  static Stream<WithdrawalRequestsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => WithdrawalRequestsRecord.fromSnapshot(s));

  static Future<WithdrawalRequestsRecord> getDocumentOnce(
          DocumentReference ref) =>
      ref.get().then((s) => WithdrawalRequestsRecord.fromSnapshot(s));

  static WithdrawalRequestsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      WithdrawalRequestsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static WithdrawalRequestsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      WithdrawalRequestsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'WithdrawalRequestsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is WithdrawalRequestsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createWithdrawalRequestsRecordData({
  DocumentReference? userId,
  String? currency,
  String? reason,
  DateTime? createdAt,
  DateTime? processedAt,
  DateTime? completedAt,
  double? amount,
  StatusTransactions? status,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'userId': userId,
      'currency': currency,
      'reason': reason,
      'createdAt': createdAt,
      'processedAt': processedAt,
      'completedAt': completedAt,
      'amount': amount,
      'status': status,
    }.withoutNulls,
  );

  return firestoreData;
}

class WithdrawalRequestsRecordDocumentEquality
    implements Equality<WithdrawalRequestsRecord> {
  const WithdrawalRequestsRecordDocumentEquality();

  @override
  bool equals(WithdrawalRequestsRecord? e1, WithdrawalRequestsRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.currency == e2?.currency &&
        e1?.reason == e2?.reason &&
        e1?.createdAt == e2?.createdAt &&
        e1?.processedAt == e2?.processedAt &&
        e1?.completedAt == e2?.completedAt &&
        e1?.amount == e2?.amount &&
        e1?.status == e2?.status;
  }

  @override
  int hash(WithdrawalRequestsRecord? e) => const ListEquality().hash([
        e?.userId,
        e?.currency,
        e?.reason,
        e?.createdAt,
        e?.processedAt,
        e?.completedAt,
        e?.amount,
        e?.status
      ]);

  @override
  bool isValidKey(Object? o) => o is WithdrawalRequestsRecord;
}
