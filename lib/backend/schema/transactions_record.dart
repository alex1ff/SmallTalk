import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class TransactionsRecord extends FirestoreRecord {
  TransactionsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "userId" field.
  DocumentReference? _userId;
  DocumentReference? get userId => _userId;
  bool hasUserId() => _userId != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "type" field.
  TypeTransactions? _type;
  TypeTransactions? get type => _type;
  bool hasType() => _type != null;

  // "status" field.
  StatusTransactions? _status;
  StatusTransactions? get status => _status;
  bool hasStatus() => _status != null;

  // "amount_ST" field.
  double? _amountST;
  double get amountST => _amountST ?? 0.0;
  bool hasAmountST() => _amountST != null;

  // "packageDocRef" field.
  DocumentReference? _packageDocRef;
  DocumentReference? get packageDocRef => _packageDocRef;
  bool hasPackageDocRef() => _packageDocRef != null;

  // "card" field.
  DocumentReference? _card;
  DocumentReference? get card => _card;
  bool hasCard() => _card != null;

  // "promoCodeDocRef" field.
  DocumentReference? _promoCodeDocRef;
  DocumentReference? get promoCodeDocRef => _promoCodeDocRef;
  bool hasPromoCodeDocRef() => _promoCodeDocRef != null;

  // "sessionDocRef" field.
  DocumentReference? _sessionDocRef;
  DocumentReference? get sessionDocRef => _sessionDocRef;
  bool hasSessionDocRef() => _sessionDocRef != null;

  // "callDuration" field.
  String? _callDuration;
  String get callDuration => _callDuration ?? '';
  bool hasCallDuration() => _callDuration != null;

  // "freeMinuteApplied" field.
  bool? _freeMinuteApplied;
  bool get freeMinuteApplied => _freeMinuteApplied ?? false;
  bool hasFreeMinuteApplied() => _freeMinuteApplied != null;

  // "promoCode" field.
  String? _promoCode;
  String get promoCode => _promoCode ?? '';
  bool hasPromoCode() => _promoCode != null;

  // "paymentId" field.
  String? _paymentId;
  String get paymentId => _paymentId ?? '';
  bool hasPaymentId() => _paymentId != null;

  // "amount" field.
  double? _amount;
  double get amount => _amount ?? 0.0;
  bool hasAmount() => _amount != null;

  // "minutesPurchased" field.
  double? _minutesPurchased;
  double get minutesPurchased => _minutesPurchased ?? 0.0;
  bool hasMinutesPurchased() => _minutesPurchased != null;

  void _initializeFields() {
    _userId = snapshotData['userId'] as DocumentReference?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _type = snapshotData['type'] is TypeTransactions
        ? snapshotData['type']
        : deserializeEnum<TypeTransactions>(snapshotData['type']);
    _status = snapshotData['status'] is StatusTransactions
        ? snapshotData['status']
        : deserializeEnum<StatusTransactions>(snapshotData['status']);
    _amountST = castToType<double>(snapshotData['amount_ST']);
    _packageDocRef = snapshotData['packageDocRef'] as DocumentReference?;
    _card = snapshotData['card'] as DocumentReference?;
    _promoCodeDocRef = snapshotData['promoCodeDocRef'] as DocumentReference?;
    _sessionDocRef = snapshotData['sessionDocRef'] as DocumentReference?;
    _callDuration = snapshotData['callDuration']?.toString();
    _freeMinuteApplied = snapshotData['freeMinuteApplied'] as bool?;
    _promoCode = snapshotData['promoCode'] as String?;
    _paymentId = snapshotData['paymentId'] as String?;
    _amount = castToType<double>(snapshotData['amount']);
    _minutesPurchased = castToType<double>(snapshotData['minutesPurchased']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('transactions');

  static Stream<TransactionsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => TransactionsRecord.fromSnapshot(s));

  static Future<TransactionsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => TransactionsRecord.fromSnapshot(s));

  static TransactionsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      TransactionsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static TransactionsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      TransactionsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'TransactionsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is TransactionsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createTransactionsRecordData({
  DocumentReference? userId,
  DateTime? createdAt,
  TypeTransactions? type,
  StatusTransactions? status,
  double? amountST,
  DocumentReference? packageDocRef,
  DocumentReference? card,
  DocumentReference? promoCodeDocRef,
  DocumentReference? sessionDocRef,
  String? callDuration,
  bool? freeMinuteApplied,
  String? promoCode,
  String? paymentId,
  double? amount,
  double? minutesPurchased,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'userId': userId,
      'createdAt': createdAt,
      'type': type,
      'status': status,
      'amount_ST': amountST,
      'packageDocRef': packageDocRef,
      'card': card,
      'promoCodeDocRef': promoCodeDocRef,
      'sessionDocRef': sessionDocRef,
      'callDuration': callDuration,
      'freeMinuteApplied': freeMinuteApplied,
      'promoCode': promoCode,
      'paymentId': paymentId,
      'amount': amount,
      'minutesPurchased': minutesPurchased,
    }.withoutNulls,
  );

  return firestoreData;
}

class TransactionsRecordDocumentEquality
    implements Equality<TransactionsRecord> {
  const TransactionsRecordDocumentEquality();

  @override
  bool equals(TransactionsRecord? e1, TransactionsRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.createdAt == e2?.createdAt &&
        e1?.type == e2?.type &&
        e1?.status == e2?.status &&
        e1?.amountST == e2?.amountST &&
        e1?.packageDocRef == e2?.packageDocRef &&
        e1?.card == e2?.card &&
        e1?.promoCodeDocRef == e2?.promoCodeDocRef &&
        e1?.sessionDocRef == e2?.sessionDocRef &&
        e1?.callDuration == e2?.callDuration &&
        e1?.freeMinuteApplied == e2?.freeMinuteApplied &&
        e1?.promoCode == e2?.promoCode &&
        e1?.paymentId == e2?.paymentId &&
        e1?.amount == e2?.amount &&
        e1?.minutesPurchased == e2?.minutesPurchased;
  }

  @override
  int hash(TransactionsRecord? e) => const ListEquality().hash([
        e?.userId,
        e?.createdAt,
        e?.type,
        e?.status,
        e?.amountST,
        e?.packageDocRef,
        e?.card,
        e?.promoCodeDocRef,
        e?.sessionDocRef,
        e?.callDuration,
        e?.freeMinuteApplied,
        e?.promoCode,
        e?.paymentId,
        e?.amount,
        e?.minutesPurchased
      ]);

  @override
  bool isValidKey(Object? o) => o is TransactionsRecord;
}
