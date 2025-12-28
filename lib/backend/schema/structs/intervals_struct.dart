// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class IntervalsStruct extends FFFirebaseStruct {
  IntervalsStruct({
    String? start,
    String? end,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _start = start,
        _end = end,
        super(firestoreUtilData);

  // "start" field.
  String? _start;
  String get start => _start ?? '';
  set start(String? val) => _start = val;

  bool hasStart() => _start != null;

  // "end" field.
  String? _end;
  String get end => _end ?? '';
  set end(String? val) => _end = val;

  bool hasEnd() => _end != null;

  static IntervalsStruct fromMap(Map<String, dynamic> data) => IntervalsStruct(
        start: data['start'] as String?,
        end: data['end'] as String?,
      );

  static IntervalsStruct? maybeFromMap(dynamic data) => data is Map
      ? IntervalsStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'start': _start,
        'end': _end,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'start': serializeParam(
          _start,
          ParamType.String,
        ),
        'end': serializeParam(
          _end,
          ParamType.String,
        ),
      }.withoutNulls;

  static IntervalsStruct fromSerializableMap(Map<String, dynamic> data) =>
      IntervalsStruct(
        start: deserializeParam(
          data['start'],
          ParamType.String,
          false,
        ),
        end: deserializeParam(
          data['end'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'IntervalsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is IntervalsStruct && start == other.start && end == other.end;
  }

  @override
  int get hashCode => const ListEquality().hash([start, end]);
}

IntervalsStruct createIntervalsStruct({
  String? start,
  String? end,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    IntervalsStruct(
      start: start,
      end: end,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

IntervalsStruct? updateIntervalsStruct(
  IntervalsStruct? intervals, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    intervals
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addIntervalsStructData(
  Map<String, dynamic> firestoreData,
  IntervalsStruct? intervals,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (intervals == null) {
    return;
  }
  if (intervals.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && intervals.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final intervalsData = getIntervalsFirestoreData(intervals, forFieldValue);
  final nestedData = intervalsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = intervals.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getIntervalsFirestoreData(
  IntervalsStruct? intervals, [
  bool forFieldValue = false,
]) {
  if (intervals == null) {
    return {};
  }
  final firestoreData = mapToFirestore(intervals.toMap());

  // Add any Firestore field values
  intervals.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getIntervalsListFirestoreData(
  List<IntervalsStruct>? intervalss,
) =>
    intervalss?.map((e) => getIntervalsFirestoreData(e, true)).toList() ?? [];
