// GiftMinutesStruct — short-lived free minutes outside of the subscription
// pool, primarily for registration trial calls and promo-code grants.
//
// ─── SUBSCRIPTION REWORK (gift extension) ──────────────────────────────
// Hand-maintained — preserve through FlutterFlow regenerations.
// Replaces the legacy "first minute free + 1 SmallTalk registration
// bonus" mechanic with: "10 free minutes that expire in 24 hours".
//
// Source of truth: users/{uid}.giftMinutes. Server (Cloud Functions)
// reads and decrements; client only reads for UI display.

// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import '/flutter_flow/flutter_flow_util.dart';

class GiftMinutesStruct extends FFFirebaseStruct {
  GiftMinutesStruct({
    double? minutes,
    DateTime? grantedAt,
    DateTime? expiresAt,
    String? source,
    double? totalGranted,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _minutes = minutes,
        _grantedAt = grantedAt,
        _expiresAt = expiresAt,
        _source = source,
        _totalGranted = totalGranted,
        super(firestoreUtilData);

  // "minutes" field — current remaining gift minutes. Decremented in
  // end_session.js as calls are completed.
  double? _minutes;
  double get minutes => _minutes ?? 0.0;
  set minutes(double? val) => _minutes = val;

  void incrementMinutes(double amount) => minutes = minutes + amount;

  bool hasMinutes() => _minutes != null;

  // "grantedAt" field — when the current gift bucket was issued.
  DateTime? _grantedAt;
  DateTime? get grantedAt => _grantedAt;
  set grantedAt(DateTime? val) => _grantedAt = val;

  bool hasGrantedAt() => _grantedAt != null;

  // "expiresAt" field — TTL. After this point minutes are unusable and
  // server gating rejects calls.
  DateTime? _expiresAt;
  DateTime? get expiresAt => _expiresAt;
  set expiresAt(DateTime? val) => _expiresAt = val;

  bool hasExpiresAt() => _expiresAt != null;

  // "source" field — "registration" | "promocode" | "admin_grant".
  String? _source;
  String get source => _source ?? '';
  set source(String? val) => _source = val;

  bool hasSource() => _source != null;

  // "totalGranted" field — original size of the bucket (useful for UI
  // showing "X / 10 минут осталось").
  double? _totalGranted;
  double get totalGranted => _totalGranted ?? 0.0;
  set totalGranted(double? val) => _totalGranted = val;

  bool hasTotalGranted() => _totalGranted != null;

  static GiftMinutesStruct fromMap(Map<String, dynamic> data) =>
      GiftMinutesStruct(
        minutes: castToType<double>(data['minutes']),
        grantedAt: data['grantedAt'] as DateTime?,
        expiresAt: data['expiresAt'] as DateTime?,
        source: data['source'] as String?,
        totalGranted: castToType<double>(data['totalGranted']),
      );

  static GiftMinutesStruct? maybeFromMap(dynamic data) => data is Map
      ? GiftMinutesStruct.fromMap(data.cast<String, dynamic>())
      : null;

  Map<String, dynamic> toMap() => {
        'minutes': _minutes,
        'grantedAt': _grantedAt,
        'expiresAt': _expiresAt,
        'source': _source,
        'totalGranted': _totalGranted,
      }.withoutNulls;

  @override
  Map<String, dynamic> toSerializableMap() => {
        'minutes': serializeParam(_minutes, ParamType.double),
        'grantedAt': serializeParam(_grantedAt, ParamType.DateTime),
        'expiresAt': serializeParam(_expiresAt, ParamType.DateTime),
        'source': serializeParam(_source, ParamType.String),
        'totalGranted': serializeParam(_totalGranted, ParamType.double),
      }.withoutNulls;

  static GiftMinutesStruct fromSerializableMap(Map<String, dynamic> data) =>
      GiftMinutesStruct(
        minutes: deserializeParam(data['minutes'], ParamType.double, false),
        grantedAt:
            deserializeParam(data['grantedAt'], ParamType.DateTime, false),
        expiresAt:
            deserializeParam(data['expiresAt'], ParamType.DateTime, false),
        source: deserializeParam(data['source'], ParamType.String, false),
        totalGranted:
            deserializeParam(data['totalGranted'], ParamType.double, false),
      );

  @override
  String toString() => 'GiftMinutesStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    return other is GiftMinutesStruct &&
        minutes == other.minutes &&
        grantedAt == other.grantedAt &&
        expiresAt == other.expiresAt &&
        source == other.source &&
        totalGranted == other.totalGranted;
  }

  @override
  int get hashCode => const ListEquality().hash(
        [minutes, grantedAt, expiresAt, source, totalGranted],
      );
}

GiftMinutesStruct createGiftMinutesStruct({
  double? minutes,
  DateTime? grantedAt,
  DateTime? expiresAt,
  String? source,
  double? totalGranted,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    GiftMinutesStruct(
      minutes: minutes,
      grantedAt: grantedAt,
      expiresAt: expiresAt,
      source: source,
      totalGranted: totalGranted,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

GiftMinutesStruct? updateGiftMinutesStruct(
  GiftMinutesStruct? gift, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    gift
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addGiftMinutesStructData(
  Map<String, dynamic> firestoreData,
  GiftMinutesStruct? gift,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (gift == null) {
    return;
  }
  if (gift.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && gift.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final giftData = getGiftMinutesFirestoreData(gift, forFieldValue);
  final nestedData = giftData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = gift.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getGiftMinutesFirestoreData(
  GiftMinutesStruct? gift, [
  bool forFieldValue = false,
]) {
  if (gift == null) {
    return {};
  }
  final firestoreData = mapToFirestore(gift.toMap());
  gift.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);
  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getGiftMinutesListFirestoreData(
  List<GiftMinutesStruct>? gifts,
) =>
    gifts?.map((e) => getGiftMinutesFirestoreData(e, true)).toList() ?? [];
