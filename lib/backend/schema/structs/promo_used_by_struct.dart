// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class PromoUsedByStruct extends FFFirebaseStruct {
  PromoUsedByStruct({
    DocumentReference? user,
    DateTime? data,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _user = user,
        _data = data,
        super(firestoreUtilData);

  // "user" field.
  DocumentReference? _user;
  DocumentReference? get user => _user;
  set user(DocumentReference? val) => _user = val;

  bool hasUser() => _user != null;

  // "data" field.
  DateTime? _data;
  DateTime? get data => _data;
  set data(DateTime? val) => _data = val;

  bool hasData() => _data != null;

  static PromoUsedByStruct fromMap(Map<String, dynamic> data) =>
      PromoUsedByStruct(
        user: data['user'] as DocumentReference?,
        data: data['data'] as DateTime?,
      );

  static PromoUsedByStruct? maybeFromMap(dynamic data) => data is Map
      ? PromoUsedByStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'user': _user,
        'data': _data,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'user': serializeParam(
          _user,
          ParamType.DocumentReference,
        ),
        'data': serializeParam(
          _data,
          ParamType.DateTime,
        ),
      }.withoutNulls;

  static PromoUsedByStruct fromSerializableMap(Map<String, dynamic> data) =>
      PromoUsedByStruct(
        user: deserializeParam(
          data['user'],
          ParamType.DocumentReference,
          false,
          collectionNamePath: ['users'],
        ),
        data: deserializeParam(
          data['data'],
          ParamType.DateTime,
          false,
        ),
      );

  @override
  String toString() => 'PromoUsedByStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is PromoUsedByStruct &&
        user == other.user &&
        data == other.data;
  }

  @override
  int get hashCode => const ListEquality().hash([user, data]);
}

PromoUsedByStruct createPromoUsedByStruct({
  DocumentReference? user,
  DateTime? data,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    PromoUsedByStruct(
      user: user,
      data: data,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

PromoUsedByStruct? updatePromoUsedByStruct(
  PromoUsedByStruct? promoUsedBy, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    promoUsedBy
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addPromoUsedByStructData(
  Map<String, dynamic> firestoreData,
  PromoUsedByStruct? promoUsedBy,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (promoUsedBy == null) {
    return;
  }
  if (promoUsedBy.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && promoUsedBy.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final promoUsedByData =
      getPromoUsedByFirestoreData(promoUsedBy, forFieldValue);
  final nestedData =
      promoUsedByData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = promoUsedBy.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getPromoUsedByFirestoreData(
  PromoUsedByStruct? promoUsedBy, [
  bool forFieldValue = false,
]) {
  if (promoUsedBy == null) {
    return {};
  }
  final firestoreData = mapToFirestore(promoUsedBy.toMap());

  // Add any Firestore field values
  promoUsedBy.firestoreUtilData.fieldValues
      .forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getPromoUsedByListFirestoreData(
  List<PromoUsedByStruct>? promoUsedBys,
) =>
    promoUsedBys?.map((e) => getPromoUsedByFirestoreData(e, true)).toList() ??
    [];
