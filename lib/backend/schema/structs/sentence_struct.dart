// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class SentenceStruct extends FFFirebaseStruct {
  SentenceStruct({
    int? id,
    String? text,
    String? lang,
    List<Translation2Struct>? translations,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _id = id,
        _text = text,
        _lang = lang,
        _translations = translations,
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

  // "translations" field.
  List<Translation2Struct>? _translations;
  List<Translation2Struct> get translations => _translations ?? const [];
  set translations(List<Translation2Struct>? val) => _translations = val;

  void updateTranslations(Function(List<Translation2Struct>) updateFn) {
    updateFn(_translations ??= []);
  }

  bool hasTranslations() => _translations != null;

  static SentenceStruct fromMap(Map<String, dynamic> data) => SentenceStruct(
        id: castToType<int>(data['id']),
        text: data['text'] as String?,
        lang: data['lang'] as String?,
        translations: getStructList(
          data['translations'],
          Translation2Struct.fromMap,
        ),
      );

  static SentenceStruct? maybeFromMap(dynamic data) =>
      data is Map ? SentenceStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'id': _id,
        'text': _text,
        'lang': _lang,
        'translations': _translations?.map((e) => e.toMap()).toList(),
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
        'translations': serializeParam(
          _translations,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static SentenceStruct fromSerializableMap(Map<String, dynamic> data) =>
      SentenceStruct(
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
        translations: deserializeStructParam<Translation2Struct>(
          data['translations'],
          ParamType.DataStruct,
          true,
          structBuilder: Translation2Struct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'SentenceStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is SentenceStruct &&
        id == other.id &&
        text == other.text &&
        lang == other.lang &&
        listEquality.equals(translations, other.translations);
  }

  @override
  int get hashCode => const ListEquality().hash([id, text, lang, translations]);
}

SentenceStruct createSentenceStruct({
  int? id,
  String? text,
  String? lang,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    SentenceStruct(
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

SentenceStruct? updateSentenceStruct(
  SentenceStruct? sentence, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    sentence
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addSentenceStructData(
  Map<String, dynamic> firestoreData,
  SentenceStruct? sentence,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (sentence == null) {
    return;
  }
  if (sentence.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && sentence.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final sentenceData = getSentenceFirestoreData(sentence, forFieldValue);
  final nestedData = sentenceData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = sentence.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getSentenceFirestoreData(
  SentenceStruct? sentence, [
  bool forFieldValue = false,
]) {
  if (sentence == null) {
    return {};
  }
  final firestoreData = mapToFirestore(sentence.toMap());

  // Add any Firestore field values
  sentence.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getSentenceListFirestoreData(
  List<SentenceStruct>? sentences,
) =>
    sentences?.map((e) => getSentenceFirestoreData(e, true)).toList() ?? [];
