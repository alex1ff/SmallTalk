// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class URatingStruct extends FFFirebaseStruct {
  URatingStruct({
    double? average,
    int? totalReviews,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _average = average,
        _totalReviews = totalReviews,
        super(firestoreUtilData);

  // "average" field.
  double? _average;
  double get average => _average ?? 0.0;
  set average(double? val) => _average = val;

  void incrementAverage(double amount) => average = average + amount;

  bool hasAverage() => _average != null;

  // "totalReviews" field.
  int? _totalReviews;
  int get totalReviews => _totalReviews ?? 0;
  set totalReviews(int? val) => _totalReviews = val;

  void incrementTotalReviews(int amount) =>
      totalReviews = totalReviews + amount;

  bool hasTotalReviews() => _totalReviews != null;

  static URatingStruct fromMap(Map<String, dynamic> data) => URatingStruct(
        average: castToType<double>(data['average']),
        totalReviews: castToType<int>(data['totalReviews']),
      );

  static URatingStruct? maybeFromMap(dynamic data) =>
      data is Map ? URatingStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'average': _average,
        'totalReviews': _totalReviews,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'average': serializeParam(
          _average,
          ParamType.double,
        ),
        'totalReviews': serializeParam(
          _totalReviews,
          ParamType.int,
        ),
      }.withoutNulls;

  static URatingStruct fromSerializableMap(Map<String, dynamic> data) =>
      URatingStruct(
        average: deserializeParam(
          data['average'],
          ParamType.double,
          false,
        ),
        totalReviews: deserializeParam(
          data['totalReviews'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'URatingStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is URatingStruct &&
        average == other.average &&
        totalReviews == other.totalReviews;
  }

  @override
  int get hashCode => const ListEquality().hash([average, totalReviews]);
}

URatingStruct createURatingStruct({
  double? average,
  int? totalReviews,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    URatingStruct(
      average: average,
      totalReviews: totalReviews,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

URatingStruct? updateURatingStruct(
  URatingStruct? uRating, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    uRating
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addURatingStructData(
  Map<String, dynamic> firestoreData,
  URatingStruct? uRating,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (uRating == null) {
    return;
  }
  if (uRating.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && uRating.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final uRatingData = getURatingFirestoreData(uRating, forFieldValue);
  final nestedData = uRatingData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = uRating.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getURatingFirestoreData(
  URatingStruct? uRating, [
  bool forFieldValue = false,
]) {
  if (uRating == null) {
    return {};
  }
  final firestoreData = mapToFirestore(uRating.toMap());

  // Add any Firestore field values
  uRating.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getURatingListFirestoreData(
  List<URatingStruct>? uRatings,
) =>
    uRatings?.map((e) => getURatingFirestoreData(e, true)).toList() ?? [];
