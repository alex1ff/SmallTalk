// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class CountryStruct extends FFFirebaseStruct {
  CountryStruct({
    String? code,
    String? nameEn,
    String? nameRu,
    String? flag,
    String? languages,
    bool? isPopular,
    int? index,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _code = code,
        _nameEn = nameEn,
        _nameRu = nameRu,
        _flag = flag,
        _languages = languages,
        _isPopular = isPopular,
        _index = index,
        super(firestoreUtilData);

  // "code" field.
  String? _code;
  String get code => _code ?? '';
  set code(String? val) => _code = val;

  bool hasCode() => _code != null;

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

  // "flag" field.
  String? _flag;
  String get flag => _flag ?? '';
  set flag(String? val) => _flag = val;

  bool hasFlag() => _flag != null;

  // "languages" field.
  String? _languages;
  String get languages => _languages ?? '';
  set languages(String? val) => _languages = val;

  bool hasLanguages() => _languages != null;

  // "isPopular" field.
  bool? _isPopular;
  bool get isPopular => _isPopular ?? false;
  set isPopular(bool? val) => _isPopular = val;

  bool hasIsPopular() => _isPopular != null;

  // "index" field.
  int? _index;
  int get index => _index ?? 0;
  set index(int? val) => _index = val;

  void incrementIndex(int amount) => index = index + amount;

  bool hasIndex() => _index != null;

  static CountryStruct fromMap(Map<String, dynamic> data) => CountryStruct(
        code: data['code'] as String?,
        nameEn: data['nameEn'] as String?,
        nameRu: data['nameRu'] as String?,
        flag: data['flag'] as String?,
        languages: data['languages'] as String?,
        isPopular: data['isPopular'] as bool?,
        index: castToType<int>(data['index']),
      );

  static CountryStruct? maybeFromMap(dynamic data) =>
      data is Map ? CountryStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'code': _code,
        'nameEn': _nameEn,
        'nameRu': _nameRu,
        'flag': _flag,
        'languages': _languages,
        'isPopular': _isPopular,
        'index': _index,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'code': serializeParam(
          _code,
          ParamType.String,
        ),
        'nameEn': serializeParam(
          _nameEn,
          ParamType.String,
        ),
        'nameRu': serializeParam(
          _nameRu,
          ParamType.String,
        ),
        'flag': serializeParam(
          _flag,
          ParamType.String,
        ),
        'languages': serializeParam(
          _languages,
          ParamType.String,
        ),
        'isPopular': serializeParam(
          _isPopular,
          ParamType.bool,
        ),
        'index': serializeParam(
          _index,
          ParamType.int,
        ),
      }.withoutNulls;

  static CountryStruct fromSerializableMap(Map<String, dynamic> data) =>
      CountryStruct(
        code: deserializeParam(
          data['code'],
          ParamType.String,
          false,
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
        flag: deserializeParam(
          data['flag'],
          ParamType.String,
          false,
        ),
        languages: deserializeParam(
          data['languages'],
          ParamType.String,
          false,
        ),
        isPopular: deserializeParam(
          data['isPopular'],
          ParamType.bool,
          false,
        ),
        index: deserializeParam(
          data['index'],
          ParamType.int,
          false,
        ),
      );

  @override
  String toString() => 'CountryStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is CountryStruct &&
        code == other.code &&
        nameEn == other.nameEn &&
        nameRu == other.nameRu &&
        flag == other.flag &&
        languages == other.languages &&
        isPopular == other.isPopular &&
        index == other.index;
  }

  @override
  int get hashCode => const ListEquality()
      .hash([code, nameEn, nameRu, flag, languages, isPopular, index]);
}

CountryStruct createCountryStruct({
  String? code,
  String? nameEn,
  String? nameRu,
  String? flag,
  String? languages,
  bool? isPopular,
  int? index,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    CountryStruct(
      code: code,
      nameEn: nameEn,
      nameRu: nameRu,
      flag: flag,
      languages: languages,
      isPopular: isPopular,
      index: index,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

CountryStruct? updateCountryStruct(
  CountryStruct? country, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    country
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addCountryStructData(
  Map<String, dynamic> firestoreData,
  CountryStruct? country,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (country == null) {
    return;
  }
  if (country.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && country.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final countryData = getCountryFirestoreData(country, forFieldValue);
  final nestedData = countryData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = country.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getCountryFirestoreData(
  CountryStruct? country, [
  bool forFieldValue = false,
]) {
  if (country == null) {
    return {};
  }
  final firestoreData = mapToFirestore(country.toMap());

  // Add any Firestore field values
  country.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getCountryListFirestoreData(
  List<CountryStruct>? countrys,
) =>
    countrys?.map((e) => getCountryFirestoreData(e, true)).toList() ?? [];
