// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class AvailabilityTodayStruct extends FFFirebaseStruct {
  AvailabilityTodayStruct({
    bool? enabled,
    List<IntervalsStruct>? intervals,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _enabled = enabled,
        _intervals = intervals,
        super(firestoreUtilData);

  // "enabled" field.
  bool? _enabled;
  bool get enabled => _enabled ?? false;
  set enabled(bool? val) => _enabled = val;

  bool hasEnabled() => _enabled != null;

  // "intervals" field.
  List<IntervalsStruct>? _intervals;
  List<IntervalsStruct> get intervals => _intervals ?? const [];
  set intervals(List<IntervalsStruct>? val) => _intervals = val;

  void updateIntervals(Function(List<IntervalsStruct>) updateFn) {
    updateFn(_intervals ??= []);
  }

  bool hasIntervals() => _intervals != null;

  static AvailabilityTodayStruct fromMap(Map<String, dynamic> data) =>
      AvailabilityTodayStruct(
        enabled: data['enabled'] as bool?,
        intervals: getStructList(
          data['intervals'],
          IntervalsStruct.fromMap,
        ),
      );

  static AvailabilityTodayStruct? maybeFromMap(dynamic data) => data is Map
      ? AvailabilityTodayStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'enabled': _enabled,
        'intervals': _intervals?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'enabled': serializeParam(
          _enabled,
          ParamType.bool,
        ),
        'intervals': serializeParam(
          _intervals,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static AvailabilityTodayStruct fromSerializableMap(
          Map<String, dynamic> data) =>
      AvailabilityTodayStruct(
        enabled: deserializeParam(
          data['enabled'],
          ParamType.bool,
          false,
        ),
        intervals: deserializeStructParam<IntervalsStruct>(
          data['intervals'],
          ParamType.DataStruct,
          true,
          structBuilder: IntervalsStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'AvailabilityTodayStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is AvailabilityTodayStruct &&
        enabled == other.enabled &&
        listEquality.equals(intervals, other.intervals);
  }

  @override
  int get hashCode => const ListEquality().hash([enabled, intervals]);
}

AvailabilityTodayStruct createAvailabilityTodayStruct({
  bool? enabled,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    AvailabilityTodayStruct(
      enabled: enabled,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

AvailabilityTodayStruct? updateAvailabilityTodayStruct(
  AvailabilityTodayStruct? availabilityToday, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    availabilityToday
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addAvailabilityTodayStructData(
  Map<String, dynamic> firestoreData,
  AvailabilityTodayStruct? availabilityToday,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (availabilityToday == null) {
    return;
  }
  if (availabilityToday.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && availabilityToday.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final availabilityTodayData =
      getAvailabilityTodayFirestoreData(availabilityToday, forFieldValue);
  final nestedData =
      availabilityTodayData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = availabilityToday.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getAvailabilityTodayFirestoreData(
  AvailabilityTodayStruct? availabilityToday, [
  bool forFieldValue = false,
]) {
  if (availabilityToday == null) {
    return {};
  }
  final firestoreData = mapToFirestore(availabilityToday.toMap());

  // Add any Firestore field values
  availabilityToday.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getAvailabilityTodayListFirestoreData(
  List<AvailabilityTodayStruct>? availabilityTodays,
) =>
    availabilityTodays
        ?.map((e) => getAvailabilityTodayFirestoreData(e, true))
        .toList() ??
    [];
