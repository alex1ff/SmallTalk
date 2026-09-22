// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class ProfileCityStruct extends FFFirebaseStruct {
  ProfileCityStruct({
    String? countryCode,
    String? cityKey,
    String? cityNameRu,
    String? cityNameEn,
    String? cityDisplayContext,
    String? regionCode,
    String? regionNameRu,
    String? regionNameEn,
    String? catalogVersion,
    DateTime? updatedAt,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _countryCode = countryCode,
        _cityKey = cityKey,
        _cityNameRu = cityNameRu,
        _cityNameEn = cityNameEn,
        _cityDisplayContext = cityDisplayContext,
        _regionCode = regionCode,
        _regionNameRu = regionNameRu,
        _regionNameEn = regionNameEn,
        _catalogVersion = catalogVersion,
        _updatedAt = updatedAt,
        super(firestoreUtilData);

  // "countryCode" field.
  String? _countryCode;
  String get countryCode => _countryCode ?? '';
  set countryCode(String? val) => _countryCode = val;

  bool hasCountryCode() => _countryCode != null;

  // "cityKey" field.
  String? _cityKey;
  String get cityKey => _cityKey ?? '';
  set cityKey(String? val) => _cityKey = val;

  bool hasCityKey() => _cityKey != null;

  // "cityNameRu" field.
  String? _cityNameRu;
  String get cityNameRu => _cityNameRu ?? '';
  set cityNameRu(String? val) => _cityNameRu = val;

  bool hasCityNameRu() => _cityNameRu != null;

  // "cityNameEn" field.
  String? _cityNameEn;
  String get cityNameEn => _cityNameEn ?? '';
  set cityNameEn(String? val) => _cityNameEn = val;

  bool hasCityNameEn() => _cityNameEn != null;

  // "cityDisplayContext" field.
  String? _cityDisplayContext;
  String get cityDisplayContext => _cityDisplayContext ?? '';
  set cityDisplayContext(String? val) => _cityDisplayContext = val;

  bool hasCityDisplayContext() => _cityDisplayContext != null;

  // "regionCode" field.
  String? _regionCode;
  String get regionCode => _regionCode ?? '';
  set regionCode(String? val) => _regionCode = val;

  bool hasRegionCode() => _regionCode != null;

  // "regionNameRu" field.
  String? _regionNameRu;
  String get regionNameRu => _regionNameRu ?? '';
  set regionNameRu(String? val) => _regionNameRu = val;

  bool hasRegionNameRu() => _regionNameRu != null;

  // "regionNameEn" field.
  String? _regionNameEn;
  String get regionNameEn => _regionNameEn ?? '';
  set regionNameEn(String? val) => _regionNameEn = val;

  bool hasRegionNameEn() => _regionNameEn != null;

  // "catalogVersion" field.
  String? _catalogVersion;
  String get catalogVersion => _catalogVersion ?? '';
  set catalogVersion(String? val) => _catalogVersion = val;

  bool hasCatalogVersion() => _catalogVersion != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  set updatedAt(DateTime? val) => _updatedAt = val;

  bool hasUpdatedAt() => _updatedAt != null;

  static ProfileCityStruct fromMap(Map<String, dynamic> data) =>
      ProfileCityStruct(
        countryCode: data['countryCode'] as String?,
        cityKey: data['cityKey'] as String?,
        cityNameRu: data['cityNameRu'] as String?,
        cityNameEn: data['cityNameEn'] as String?,
        cityDisplayContext: data['cityDisplayContext'] as String?,
        regionCode: data['regionCode'] as String?,
        regionNameRu: data['regionNameRu'] as String?,
        regionNameEn: data['regionNameEn'] as String?,
        catalogVersion: data['catalogVersion'] as String?,
        updatedAt: data['updatedAt'] as DateTime?,
      );

  static ProfileCityStruct? maybeFromMap(dynamic data) => data is Map
      ? ProfileCityStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'countryCode': _countryCode,
        'cityKey': _cityKey,
        'cityNameRu': _cityNameRu,
        'cityNameEn': _cityNameEn,
        'cityDisplayContext': _cityDisplayContext,
        'regionCode': _regionCode,
        'regionNameRu': _regionNameRu,
        'regionNameEn': _regionNameEn,
        'catalogVersion': _catalogVersion,
        'updatedAt': _updatedAt,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'countryCode': serializeParam(_countryCode, ParamType.String),
        'cityKey': serializeParam(_cityKey, ParamType.String),
        'cityNameRu': serializeParam(_cityNameRu, ParamType.String),
        'cityNameEn': serializeParam(_cityNameEn, ParamType.String),
        'cityDisplayContext':
            serializeParam(_cityDisplayContext, ParamType.String),
        'regionCode': serializeParam(_regionCode, ParamType.String),
        'regionNameRu': serializeParam(_regionNameRu, ParamType.String),
        'regionNameEn': serializeParam(_regionNameEn, ParamType.String),
        'catalogVersion': serializeParam(_catalogVersion, ParamType.String),
        'updatedAt': serializeParam(_updatedAt, ParamType.DateTime),
      }.withoutNulls;

  static ProfileCityStruct fromSerializableMap(Map<String, dynamic> data) =>
      ProfileCityStruct(
        countryCode:
            deserializeParam(data['countryCode'], ParamType.String, false),
        cityKey: deserializeParam(data['cityKey'], ParamType.String, false),
        cityNameRu:
            deserializeParam(data['cityNameRu'], ParamType.String, false),
        cityNameEn:
            deserializeParam(data['cityNameEn'], ParamType.String, false),
        cityDisplayContext: deserializeParam(
            data['cityDisplayContext'], ParamType.String, false),
        regionCode:
            deserializeParam(data['regionCode'], ParamType.String, false),
        regionNameRu:
            deserializeParam(data['regionNameRu'], ParamType.String, false),
        regionNameEn:
            deserializeParam(data['regionNameEn'], ParamType.String, false),
        catalogVersion:
            deserializeParam(data['catalogVersion'], ParamType.String, false),
        updatedAt:
            deserializeParam(data['updatedAt'], ParamType.DateTime, false),
      );

  @override
  String toString() => 'ProfileCityStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is ProfileCityStruct &&
        countryCode == other.countryCode &&
        cityKey == other.cityKey &&
        cityNameRu == other.cityNameRu &&
        cityNameEn == other.cityNameEn &&
        cityDisplayContext == other.cityDisplayContext &&
        regionCode == other.regionCode &&
        regionNameRu == other.regionNameRu &&
        regionNameEn == other.regionNameEn &&
        catalogVersion == other.catalogVersion &&
        updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => const ListEquality().hash([
        countryCode,
        cityKey,
        cityNameRu,
        cityNameEn,
        cityDisplayContext,
        regionCode,
        regionNameRu,
        regionNameEn,
        catalogVersion,
        updatedAt,
      ]);
}

ProfileCityStruct createProfileCityStruct({
  String? countryCode,
  String? cityKey,
  String? cityNameRu,
  String? cityNameEn,
  String? cityDisplayContext,
  String? regionCode,
  String? regionNameRu,
  String? regionNameEn,
  String? catalogVersion,
  DateTime? updatedAt,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    ProfileCityStruct(
      countryCode: countryCode,
      cityKey: cityKey,
      cityNameRu: cityNameRu,
      cityNameEn: cityNameEn,
      cityDisplayContext: cityDisplayContext,
      regionCode: regionCode,
      regionNameRu: regionNameRu,
      regionNameEn: regionNameEn,
      catalogVersion: catalogVersion,
      updatedAt: updatedAt,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

ProfileCityStruct? updateProfileCityStruct(
  ProfileCityStruct? profileCity, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    profileCity
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addProfileCityStructData(
  Map<String, dynamic> firestoreData,
  ProfileCityStruct? profileCity,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (profileCity == null) {
    return;
  }
  if (profileCity.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && profileCity.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final profileCityData =
      getProfileCityFirestoreData(profileCity, forFieldValue);
  final nestedData =
      profileCityData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = profileCity.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getProfileCityFirestoreData(
  ProfileCityStruct? profileCity, [
  bool forFieldValue = false,
]) {
  if (profileCity == null) {
    return {};
  }
  final firestoreData = mapToFirestore(profileCity.toMap());

  profileCity.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getProfileCityListFirestoreData(
  List<ProfileCityStruct>? profileCitys,
) =>
    profileCitys?.map((e) => getProfileCityFirestoreData(e, true)).toList() ??
    [];
