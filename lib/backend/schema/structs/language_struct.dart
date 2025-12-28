// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class LanguageStruct extends FFFirebaseStruct {
  LanguageStruct({
    String? code,
    List<String>? alternateCodes,
    String? nameEn,
    String? nameRu,
    String? model,
    bool? isPopular,
    String? ss,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _code = code,
        _alternateCodes = alternateCodes,
        _nameEn = nameEn,
        _nameRu = nameRu,
        _model = model,
        _isPopular = isPopular,
        _ss = ss,
        super(firestoreUtilData);

  // "code" field.
  String? _code;
  String get code => _code ?? '';
  set code(String? val) => _code = val;

  bool hasCode() => _code != null;

  // "alternateCodes" field.
  List<String>? _alternateCodes;
  List<String> get alternateCodes => _alternateCodes ?? const [];
  set alternateCodes(List<String>? val) => _alternateCodes = val;

  void updateAlternateCodes(Function(List<String>) updateFn) {
    updateFn(_alternateCodes ??= []);
  }

  bool hasAlternateCodes() => _alternateCodes != null;

  // "nameEn" field.
  String? _nameEn;
  String get nameEn => _nameEn ?? '';
  set nameEn(String? val) => _nameEn = val;

  bool hasNameEn() => _nameEn != null;

  // "nameRu" field.
  String? _nameRu;
  String get nameRu => _nameRu ?? '';
  set nameRu(String? val) => _nameRu = val;

  bool hasNameRu() => _nameRu != null;

  // "model" field.
  String? _model;
  String get model => _model ?? '';
  set model(String? val) => _model = val;

  bool hasModel() => _model != null;

  // "isPopular" field.
  bool? _isPopular;
  bool get isPopular => _isPopular ?? false;
  set isPopular(bool? val) => _isPopular = val;

  bool hasIsPopular() => _isPopular != null;

  // "ss" field.
  String? _ss;
  String get ss => _ss ?? '';
  set ss(String? val) => _ss = val;

  bool hasSs() => _ss != null;

  static LanguageStruct fromMap(Map<String, dynamic> data) => LanguageStruct(
        code: data['code'] as String?,
        alternateCodes: getDataList(data['alternateCodes']),
        nameEn: data['nameEn'] as String?,
        nameRu: data['nameRu'] as String?,
        model: data['model'] as String?,
        isPopular: data['isPopular'] as bool?,
        ss: data['ss'] as String?,
      );

  static LanguageStruct? maybeFromMap(dynamic data) =>
      data is Map ? LanguageStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'code': _code,
        'alternateCodes': _alternateCodes,
        'nameEn': _nameEn,
        'nameRu': _nameRu,
        'model': _model,
        'isPopular': _isPopular,
        'ss': _ss,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'code': serializeParam(
          _code,
          ParamType.String,
        ),
        'alternateCodes': serializeParam(
          _alternateCodes,
          ParamType.String,
          isList: true,
        ),
        'nameEn': serializeParam(
          _nameEn,
          ParamType.String,
        ),
        'nameRu': serializeParam(
          _nameRu,
          ParamType.String,
        ),
        'model': serializeParam(
          _model,
          ParamType.String,
        ),
        'isPopular': serializeParam(
          _isPopular,
          ParamType.bool,
        ),
        'ss': serializeParam(
          _ss,
          ParamType.String,
        ),
      }.withoutNulls;

  static LanguageStruct fromSerializableMap(Map<String, dynamic> data) =>
      LanguageStruct(
        code: deserializeParam(
          data['code'],
          ParamType.String,
          false,
        ),
        alternateCodes: deserializeParam<String>(
          data['alternateCodes'],
          ParamType.String,
          true,
        ),
        nameEn: deserializeParam(
          data['nameEn'],
          ParamType.String,
          false,
        ),
        nameRu: deserializeParam(
          data['nameRu'],
          ParamType.String,
          false,
        ),
        model: deserializeParam(
          data['model'],
          ParamType.String,
          false,
        ),
        isPopular: deserializeParam(
          data['isPopular'],
          ParamType.bool,
          false,
        ),
        ss: deserializeParam(
          data['ss'],
          ParamType.String,
          false,
        ),
      );

  @override
  String toString() => 'LanguageStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is LanguageStruct &&
        code == other.code &&
        listEquality.equals(alternateCodes, other.alternateCodes) &&
        nameEn == other.nameEn &&
        nameRu == other.nameRu &&
        model == other.model &&
        isPopular == other.isPopular &&
        ss == other.ss;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([code, alternateCodes, nameEn, nameRu, model, isPopular, ss]);
}

LanguageStruct createLanguageStruct({
  String? code,
  String? nameEn,
  String? nameRu,
  String? model,
  bool? isPopular,
  String? ss,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    LanguageStruct(
      code: code,
      nameEn: nameEn,
      nameRu: nameRu,
      model: model,
      isPopular: isPopular,
      ss: ss,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

LanguageStruct? updateLanguageStruct(
  LanguageStruct? language, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    language
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addLanguageStructData(
  Map<String, dynamic> firestoreData,
  LanguageStruct? language,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (language == null) {
    return;
  }
  if (language.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && language.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final languageData = getLanguageFirestoreData(language, forFieldValue);
  final nestedData = languageData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = language.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getLanguageFirestoreData(
  LanguageStruct? language, [
  bool forFieldValue = false,
]) {
  if (language == null) {
    return {};
  }
  final firestoreData = mapToFirestore(language.toMap());

  // Add any Firestore field values
  language.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getLanguageListFirestoreData(
  List<LanguageStruct>? languages,
) =>
    languages?.map((e) => getLanguageFirestoreData(e, true)).toList() ?? [];
