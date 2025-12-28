// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class TranslationStruct extends FFFirebaseStruct {
  TranslationStruct({
    String? text,
    String? pos,
    String? gen,
    int? fr,
    List<SynonymStruct>? syn,
    List<MeaningStruct>? mean,
    String? asp,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _text = text,
        _pos = pos,
        _gen = gen,
        _fr = fr,
        _syn = syn,
        _mean = mean,
        _asp = asp,
        super(firestoreUtilData);

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  set text(String? val) => _text = val;

  bool hasText() => _text != null;

  // "pos" field.
  String? _pos;
  String get pos => _pos ?? '';
  set pos(String? val) => _pos = val;

  bool hasPos() => _pos != null;

  // "gen" field.
  String? _gen;
  String get gen => _gen ?? '';
  set gen(String? val) => _gen = val;

  bool hasGen() => _gen != null;

  // "fr" field.
  int? _fr;
  int get fr => _fr ?? 0;
  set fr(int? val) => _fr = val;

  void incrementFr(int amount) => fr = fr + amount;

  bool hasFr() => _fr != null;

  // "syn" field.
  List<SynonymStruct>? _syn;
  List<SynonymStruct> get syn => _syn ?? const [];
  set syn(List<SynonymStruct>? val) => _syn = val;

  void updateSyn(Function(List<SynonymStruct>) updateFn) {
    updateFn(_syn ??= []);
  }

  bool hasSyn() => _syn != null;

  // "mean" field.
  List<MeaningStruct>? _mean;
  List<MeaningStruct> get mean => _mean ?? const [];
  set mean(List<MeaningStruct>? val) => _mean = val;

  void updateMean(Function(List<MeaningStruct>) updateFn) {
    updateFn(_mean ??= []);
  }

  bool hasMean() => _mean != null;

  // "asp" field.
  String? _asp;
  String get asp => _asp ?? '';
  set asp(String? val) => _asp = val;

  bool hasAsp() => _asp != null;

  static TranslationStruct fromMap(Map<String, dynamic> data) =>
      TranslationStruct(
        text: data['text'] as String?,
        pos: data['pos'] as String?,
        gen: data['gen'] as String?,
        fr: castToType<int>(data['fr']),
        syn: getStructList(
          data['syn'],
          SynonymStruct.fromMap,
        ),
        mean: getStructList(
          data['mean'],
          MeaningStruct.fromMap,
        ),
        asp: data['asp'] as String?,
      );

  static TranslationStruct? maybeFromMap(dynamic data) => data is Map
      ? TranslationStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'text': _text,
        'pos': _pos,
        'gen': _gen,
        'fr': _fr,
        'syn': _syn?.map((e) => e.toMap()).toList(),
        'mean': _mean?.map((e) => e.toMap()).toList(),
        'asp': _asp,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'text': serializeParam(
          _text,
          ParamType.String,
        ),
        'pos': serializeParam(
          _pos,
          ParamType.String,
        ),
        'gen': serializeParam(
          _gen,
          ParamType.String,
        ),
        'fr': serializeParam(
          _fr,
          ParamType.int,
        ),
        'syn': serializeParam(
          _syn,
          ParamType.DataStruct,
          isList: true,
        ),
        'mean': serializeParam(
          _mean,
          ParamType.DataStruct,
          isList: true,
        ),
        'asp': serializeParam(
          _asp,
          ParamType.String,
        ),
      }.withoutNulls;

  static TranslationStruct fromSerializableMap(Map<String, dynamic> data) =>
      TranslationStruct(
        text: deserializeParam(
          data['text'],
          ParamType.String,
          false,
        ),
        pos: deserializeParam(
          data['pos'],
          ParamType.String,
          false,
        ),
        gen: deserializeParam(
          data['gen'],
          ParamType.String,
          false,
        ),
        fr: deserializeParam(
          data['fr'],
          ParamType.int,
          false,
        ),
        syn: deserializeStructParam<SynonymStruct>(
          data['syn'],
          ParamType.DataStruct,
          true,
          structBuilder: SynonymStruct.fromSerializableMap,
        ),
        mean: deserializeStructParam<MeaningStruct>(
          data['mean'],
          ParamType.DataStruct,
          true,
          structBuilder: MeaningStruct.fromSerializableMap,
        ),
        asp: deserializeParam(
          data['asp'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'TranslationStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is TranslationStruct &&
        text == other.text &&
        pos == other.pos &&
        gen == other.gen &&
        fr == other.fr &&
        listEquality.equals(syn, other.syn) &&
        listEquality.equals(mean, other.mean) &&
        asp == other.asp;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([text, pos, gen, fr, syn, mean, asp]);
}

TranslationStruct createTranslationStruct({
  String? text,
  String? pos,
  String? gen,
  int? fr,
  String? asp,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    TranslationStruct(
      text: text,
      pos: pos,
      gen: gen,
      fr: fr,
      asp: asp,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

TranslationStruct? updateTranslationStruct(
  TranslationStruct? translation, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    translation
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addTranslationStructData(
  Map<String, dynamic> firestoreData,
  TranslationStruct? translation,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (translation == null) {
    return;
  }
  if (translation.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && translation.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final translationData =
      getTranslationFirestoreData(translation, forFieldValue);
  final nestedData =
      translationData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = translation.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getTranslationFirestoreData(
  TranslationStruct? translation, [
  bool forFieldValue = false,
]) {
  if (translation == null) {
    return {};
  }
  final firestoreData = mapToFirestore(translation.toMap());

  // Add any Firestore field values
  translation.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getTranslationListFirestoreData(
  List<TranslationStruct>? translations,
) =>
    translations?.map((e) => getTranslationFirestoreData(e, true)).toList() ??
    [];
