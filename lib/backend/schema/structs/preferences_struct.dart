// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class PreferencesStruct extends FFFirebaseStruct {
  PreferencesStruct({
    LanguageStruct? preferredNativeLanguage,
    CountryStruct? preferredLocation,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _preferredNativeLanguage = preferredNativeLanguage,
        _preferredLocation = preferredLocation,
        super(firestoreUtilData);

  // "preferredNativeLanguage" field.
  LanguageStruct? _preferredNativeLanguage;
  LanguageStruct get preferredNativeLanguage =>
      _preferredNativeLanguage ?? LanguageStruct();
  set preferredNativeLanguage(LanguageStruct? val) =>
      _preferredNativeLanguage = val;

  void updatePreferredNativeLanguage(Function(LanguageStruct) updateFn) {
    updateFn(_preferredNativeLanguage ??= LanguageStruct());
  }

  bool hasPreferredNativeLanguage() => _preferredNativeLanguage != null;

  // "preferredLocation" field.
  CountryStruct? _preferredLocation;
  CountryStruct get preferredLocation => _preferredLocation ?? CountryStruct();
  set preferredLocation(CountryStruct? val) => _preferredLocation = val;

  void updatePreferredLocation(Function(CountryStruct) updateFn) {
    updateFn(_preferredLocation ??= CountryStruct());
  }

  bool hasPreferredLocation() => _preferredLocation != null;

  static PreferencesStruct fromMap(Map<String, dynamic> data) =>
      PreferencesStruct(
        preferredNativeLanguage:
            data['preferredNativeLanguage'] is LanguageStruct
                ? data['preferredNativeLanguage']
                : LanguageStruct.maybeFromMap(data['preferredNativeLanguage']),
        preferredLocation: data['preferredLocation'] is CountryStruct
            ? data['preferredLocation']
            : CountryStruct.maybeFromMap(data['preferredLocation']),
      );

  static PreferencesStruct? maybeFromMap(dynamic data) => data is Map
      ? PreferencesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'preferredNativeLanguage': _preferredNativeLanguage?.toMap(),
        'preferredLocation': _preferredLocation?.toMap(),
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'preferredNativeLanguage': serializeParam(
          _preferredNativeLanguage,
          ParamType.DataStruct,
        ),
        'preferredLocation': serializeParam(
          _preferredLocation,
          ParamType.DataStruct,
        ),
      }.withoutNulls;

  static PreferencesStruct fromSerializableMap(Map<String, dynamic> data) =>
      PreferencesStruct(
        preferredNativeLanguage: deserializeStructParam(
          data['preferredNativeLanguage'],
          ParamType.DataStruct,
          false,
          structBuilder: LanguageStruct.fromSerializableMap,
        ),
        preferredLocation: deserializeStructParam(
          data['preferredLocation'],
          ParamType.DataStruct,
          false,
          structBuilder: CountryStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'PreferencesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is PreferencesStruct &&
        preferredNativeLanguage == other.preferredNativeLanguage &&
        preferredLocation == other.preferredLocation;
  }

  @override
  int get hashCode =>
      const ListEquality().hash([preferredNativeLanguage, preferredLocation]);
}

PreferencesStruct createPreferencesStruct({
  LanguageStruct? preferredNativeLanguage,
  CountryStruct? preferredLocation,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    PreferencesStruct(
      preferredNativeLanguage: preferredNativeLanguage ??
          (clearUnsetFields ? LanguageStruct() : null),
      preferredLocation:
          preferredLocation ?? (clearUnsetFields ? CountryStruct() : null),
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

PreferencesStruct? updatePreferencesStruct(
  PreferencesStruct? preferences, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    preferences
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addPreferencesStructData(
  Map<String, dynamic> firestoreData,
  PreferencesStruct? preferences,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (preferences == null) {
    return;
  }
  if (preferences.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && preferences.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final preferencesData =
      getPreferencesFirestoreData(preferences, forFieldValue);
  final nestedData =
      preferencesData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = preferences.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getPreferencesFirestoreData(
  PreferencesStruct? preferences, [
  bool forFieldValue = false,
]) {
  if (preferences == null) {
    return {};
  }
  final firestoreData = mapToFirestore(preferences.toMap());

  // Handle nested data for "preferredNativeLanguage" field.
  addLanguageStructData(
    firestoreData,
    preferences.hasPreferredNativeLanguage()
        ? preferences.preferredNativeLanguage
        : null,
    'preferredNativeLanguage',
    forFieldValue,
  );

  // Handle nested data for "preferredLocation" field.
  addCountryStructData(
    firestoreData,
    preferences.hasPreferredLocation() ? preferences.preferredLocation : null,
    'preferredLocation',
    forFieldValue,
  );

  // Add any Firestore field values
  preferences.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getPreferencesListFirestoreData(
  List<PreferencesStruct>? preferencess,
) =>
    preferencess?.map((e) => getPreferencesFirestoreData(e, true)).toList() ??
    [];
