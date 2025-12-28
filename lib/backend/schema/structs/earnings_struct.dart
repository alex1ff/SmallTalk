// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class EarningsStruct extends FFFirebaseStruct {
  EarningsStruct({
    int? total,
    int? available,
    int? withdrawn,
    String? currency,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _total = total,
        _available = available,
        _withdrawn = withdrawn,
        _currency = currency,
        super(firestoreUtilData);

  // "total" field.
  int? _total;
  int get total => _total ?? 0;
  set total(int? val) => _total = val;

  void incrementTotal(int amount) => total = total + amount;

  bool hasTotal() => _total != null;

  // "available" field.
  int? _available;
  int get available => _available ?? 0;
  set available(int? val) => _available = val;

  void incrementAvailable(int amount) => available = available + amount;

  bool hasAvailable() => _available != null;

  // "withdrawn" field.
  int? _withdrawn;
  int get withdrawn => _withdrawn ?? 0;
  set withdrawn(int? val) => _withdrawn = val;

  void incrementWithdrawn(int amount) => withdrawn = withdrawn + amount;

  bool hasWithdrawn() => _withdrawn != null;

  // "currency" field.
  String? _currency;
  String get currency => _currency ?? '';
  set currency(String? val) => _currency = val;

  bool hasCurrency() => _currency != null;

  static EarningsStruct fromMap(Map<String, dynamic> data) => EarningsStruct(
        total: castToType<int>(data['total']),
        available: castToType<int>(data['available']),
        withdrawn: castToType<int>(data['withdrawn']),
        currency: data['currency'] as String?,
      );

  static EarningsStruct? maybeFromMap(dynamic data) =>
      data is Map ? EarningsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'total': _total,
        'available': _available,
        'withdrawn': _withdrawn,
        'currency': _currency,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'total': serializeParam(
          _total,
          ParamType.int,
        ),
        'available': serializeParam(
          _available,
          ParamType.int,
        ),
        'withdrawn': serializeParam(
          _withdrawn,
          ParamType.int,
        ),
        'currency': serializeParam(
          _currency,
          ParamType.String,
        ),
      }.withoutNulls;

  static EarningsStruct fromSerializableMap(Map<String, dynamic> data) =>
      EarningsStruct(
        total: deserializeParam(
          data['total'],
          ParamType.int,
          false,
        ),
        available: deserializeParam(
          data['available'],
          ParamType.int,
          false,
        ),
        withdrawn: deserializeParam(
          data['withdrawn'],
          ParamType.int,
          false,
        ),
        currency: deserializeParam(
          data['currency'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'EarningsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is EarningsStruct &&
        total == other.total &&
        available == other.available &&
        withdrawn == other.withdrawn &&
        currency == other.currency;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([total, available, withdrawn, currency]);
}

EarningsStruct createEarningsStruct({
  int? total,
  int? available,
  int? withdrawn,
  String? currency,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EarningsStruct(
      total: total,
      available: available,
      withdrawn: withdrawn,
      currency: currency,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EarningsStruct? updateEarningsStruct(
  EarningsStruct? earnings, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    earnings
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEarningsStructData(
  Map<String, dynamic> firestoreData,
  EarningsStruct? earnings,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (earnings == null) {
    return;
  }
  if (earnings.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && earnings.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final earningsData = getEarningsFirestoreData(earnings, forFieldValue);
  final nestedData = earningsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = earnings.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEarningsFirestoreData(
  EarningsStruct? earnings, [
  bool forFieldValue = false,
]) {
  if (earnings == null) {
    return {};
  }
  final firestoreData = mapToFirestore(earnings.toMap());

  // Add any Firestore field values
  earnings.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEarningsListFirestoreData(
  List<EarningsStruct>? earningss,
) =>
    earningss?.map((e) => getEarningsFirestoreData(e, true)).toList() ?? [];
