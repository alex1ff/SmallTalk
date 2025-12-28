// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class Translation2Struct extends FFFirebaseStruct {
  Translation2Struct({
    int? id,
    String? text,
    String? lang,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _id = id,
        _text = text,
        _lang = lang,
        super(firestoreUtilData);

  // "id" field.
  int? _id;
  int get id => _id ?? 0;
  set id(int? val) => _id = val;

  void incrementId(int amount) => id = id + amount;

  bool hasId() => _id != null;

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  set text(String? val) => _text = val;

  bool hasText() => _text != null;

  // "lang" field.
  String? _lang;
  String get lang => _lang ?? '';
  set lang(String? val) => _lang = val;

  bool hasLang() => _lang != null;

  static Translation2Struct fromMap(Map<String, dynamic> data) =>
      Translation2Struct(
        id: castToType<int>(data['id']),
        text: data['text'] as String?,
        lang: data['lang'] as String?,
      );

  static Translation2Struct? maybeFromMap(dynamic data) => data is Map
      ? Translation2Struct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'text': _text,
        'lang': _lang,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'id': serializeParam(
          _id,
          ParamType.int,
        ),
        'text': serializeParam(
          _text,
          ParamType.String,
        ),
        'lang': serializeParam(
          _lang,
          ParamType.String,
        ),
      }.withoutNulls;

  static Translation2Struct fromSerializableMap(Map<String, dynamic> data) =>
      Translation2Struct(
        id: deserializeParam(
          data['id'],
          ParamType.int,
          false,
        ),
        text: deserializeParam(
          data['text'],
          ParamType.String,
          false,
        ),
        lang: deserializeParam(
          data['lang'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'Translation2Struct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is Translation2Struct &&
        id == other.id &&
        text == other.text &&
        lang == other.lang;
  }

  @override
  int get hashCode => const ListEquality().hash([id, text, lang]);
}

Translation2Struct createTranslation2Struct({
  int? id,
  String? text,
  String? lang,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    Translation2Struct(
      id: id,
      text: text,
      lang: lang,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

Translation2Struct? updateTranslation2Struct(
  Translation2Struct? translation2, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    translation2
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addTranslation2StructData(
  Map<String, dynamic> firestoreData,
  Translation2Struct? translation2,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (translation2 == null) {
    return;
  }
  if (translation2.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && translation2.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final translation2Data =
      getTranslation2FirestoreData(translation2, forFieldValue);
  final nestedData =
      translation2Data.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = translation2.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getTranslation2FirestoreData(
  Translation2Struct? translation2, [
  bool forFieldValue = false,
]) {
  if (translation2 == null) {
    return {};
  }
  final firestoreData = mapToFirestore(translation2.toMap());

  // Add any Firestore field values
  translation2.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getTranslation2ListFirestoreData(
  List<Translation2Struct>? translation2s,
) =>
    translation2s?.map((e) => getTranslation2FirestoreData(e, true)).toList() ??
    [];
