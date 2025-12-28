// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class WordsStruct extends FFFirebaseStruct {
  WordsStruct({
    String? text,
    DocumentReference? ref,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _text = text,
        _ref = ref,
        super(firestoreUtilData);

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  set text(String? val) => _text = val;

  bool hasText() => _text != null;

  // "ref" field.
  DocumentReference? _ref;
  DocumentReference? get ref => _ref;
  set ref(DocumentReference? val) => _ref = val;

  bool hasRef() => _ref != null;

  static WordsStruct fromMap(Map<String, dynamic> data) => WordsStruct(
        text: data['text'] as String?,
        ref: data['ref'] as DocumentReference?,
      );

  static WordsStruct? maybeFromMap(dynamic data) =>
      data is Map ? WordsStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'text': _text,
        'ref': _ref,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'text': serializeParam(
          _text,
          ParamType.String,
        ),
        'ref': serializeParam(
          _ref,
          ParamType.DocumentReference,
        ),
      }.withoutNulls;

  static WordsStruct fromSerializableMap(Map<String, dynamic> data) =>
      WordsStruct(
        text: deserializeParam(
          data['text'],
          ParamType.String,
          false,
        ),
        ref: deserializeParam(
          data['ref'],
          ParamType.DocumentReference,
          false,
          collectionNamePath: ['users', 'userWords'],
        ),
      );

  @override
  String toString() => 'WordsStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is WordsStruct && text == other.text && ref == other.ref;
  }

  @override
  int get hashCode => const ListEquality().hash([text, ref]);
}

WordsStruct createWordsStruct({
  String? text,
  DocumentReference? ref,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    WordsStruct(
      text: text,
      ref: ref,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

WordsStruct? updateWordsStruct(
  WordsStruct? words, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    words
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addWordsStructData(
  Map<String, dynamic> firestoreData,
  WordsStruct? words,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (words == null) {
    return;
  }
  if (words.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && words.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final wordsData = getWordsFirestoreData(words, forFieldValue);
  final nestedData = wordsData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = words.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getWordsFirestoreData(
  WordsStruct? words, [
  bool forFieldValue = false,
]) {
  if (words == null) {
    return {};
  }
  final firestoreData = mapToFirestore(words.toMap());

  // Add any Firestore field values
  words.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getWordsListFirestoreData(
  List<WordsStruct>? wordss,
) =>
    wordss?.map((e) => getWordsFirestoreData(e, true)).toList() ?? [];
