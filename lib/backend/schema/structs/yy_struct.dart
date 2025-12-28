// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class YyStruct extends FFFirebaseStruct {
  YyStruct({
    List<EntryStruct>? def,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _def = def,
        super(firestoreUtilData);

  // "def" field.
  List<EntryStruct>? _def;
  List<EntryStruct> get def => _def ?? const [];
  set def(List<EntryStruct>? val) => _def = val;

  void updateDef(Function(List<EntryStruct>) updateFn) {
    updateFn(_def ??= []);
  }

  bool hasDef() => _def != null;

  static YyStruct fromMap(Map<String, dynamic> data) => YyStruct(
        def: getStructList(
          data['def'],
          EntryStruct.fromMap,
        ),
      );

  static YyStruct? maybeFromMap(dynamic data) =>
      data is Map ? YyStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'def': _def?.map((e) => e.toMap()).toList(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'def': serializeParam(
          _def,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static YyStruct fromSerializableMap(Map<String, dynamic> data) => YyStruct(
        def: deserializeStructParam<EntryStruct>(
          data['def'],
          ParamType.DataStruct,
          true,
          structBuilder: EntryStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'YyStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is YyStruct && listEquality.equals(def, other.def);
  }

  @override
  int get hashCode => const ListEquality().hash([def]);
}

YyStruct createYyStruct({
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    YyStruct(
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

YyStruct? updateYyStruct(
  YyStruct? yy, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    yy
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addYyStructData(
  Map<String, dynamic> firestoreData,
  YyStruct? yy,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (yy == null) {
    return;
  }
  if (yy.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields = !forFieldValue && yy.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final yyData = getYyFirestoreData(yy, forFieldValue);
  final nestedData = yyData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = yy.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getYyFirestoreData(
  YyStruct? yy, [
  bool forFieldValue = false,
]) {
  if (yy == null) {
    return {};
  }
  final firestoreData = mapToFirestore(yy.toMap());

  // Add any Firestore field values
  yy.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getYyListFirestoreData(
  List<YyStruct>? yys,
) =>
    yys?.map((e) => getYyFirestoreData(e, true)).toList() ?? [];
