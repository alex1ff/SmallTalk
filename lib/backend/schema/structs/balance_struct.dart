// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class BalanceStruct extends FFFirebaseStruct {
  BalanceStruct({
    double? smallTalks,
    double? minutes,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _smallTalks = smallTalks,
        _minutes = minutes,
        super(firestoreUtilData);

  // "smallTalks" field.
  double? _smallTalks;
  double get smallTalks => _smallTalks ?? 0.0;
  set smallTalks(double? val) => _smallTalks = val;

  void incrementSmallTalks(double amount) => smallTalks = smallTalks + amount;

  bool hasSmallTalks() => _smallTalks != null;

  // "minutes" field.
  double? _minutes;
  double get minutes => _minutes ?? 0.0;
  set minutes(double? val) => _minutes = val;

  void incrementMinutes(double amount) => minutes = minutes + amount;

  bool hasMinutes() => _minutes != null;

  static BalanceStruct fromMap(Map<String, dynamic> data) => BalanceStruct(
        smallTalks: castToType<double>(data['smallTalks']),
        minutes: castToType<double>(data['minutes']),
      );

  static BalanceStruct? maybeFromMap(dynamic data) =>
      data is Map ? BalanceStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'smallTalks': _smallTalks,
        'minutes': _minutes,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'smallTalks': serializeParam(
          _smallTalks,
          ParamType.double,
        ),
        'minutes': serializeParam(
          _minutes,
          ParamType.double,
        ),
      }.withoutNulls;

  static BalanceStruct fromSerializableMap(Map<String, dynamic> data) =>
      BalanceStruct(
        smallTalks: deserializeParam(
          data['smallTalks'],
          ParamType.double,
          false,
        ),
        minutes: deserializeParam(
          data['minutes'],
          ParamType.double,
          false,
        ),
      );

  @override
  String toString() => 'BalanceStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is BalanceStruct &&
        smallTalks == other.smallTalks &&
        minutes == other.minutes;
  }

  @override
  int get hashCode => const ListEquality().hash([smallTalks, minutes]);
}

BalanceStruct createBalanceStruct({
  double? smallTalks,
  double? minutes,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    BalanceStruct(
      smallTalks: smallTalks,
      minutes: minutes,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

BalanceStruct? updateBalanceStruct(
  BalanceStruct? balance, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    balance
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addBalanceStructData(
  Map<String, dynamic> firestoreData,
  BalanceStruct? balance,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (balance == null) {
    return;
  }
  if (balance.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && balance.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final balanceData = getBalanceFirestoreData(balance, forFieldValue);
  final nestedData = balanceData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = balance.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getBalanceFirestoreData(
  BalanceStruct? balance, [
  bool forFieldValue = false,
]) {
  if (balance == null) {
    return {};
  }
  final firestoreData = mapToFirestore(balance.toMap());

  // Add any Firestore field values
  balance.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getBalanceListFirestoreData(
  List<BalanceStruct>? balances,
) =>
    balances?.map((e) => getBalanceFirestoreData(e, true)).toList() ?? [];
