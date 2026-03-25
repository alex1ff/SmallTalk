// ignore_for_file: unnecessary_getters_setters

import 'package:cloud_firestore/cloud_firestore.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EntryStruct extends FFFirebaseStruct {
  EntryStruct({
    String? text,
    String? pos,
    String? ts,
    List<SynonymStruct>? syn,
    List<TranslationStruct>? tr,
    FirestoreUtilData firestoreUtilData = const FirestoreUtilData(),
  })  : _text = text,
        _pos = pos,
        _ts = ts,
        _syn = syn,
        _tr = tr,
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

  // "ts" field.
  String? _ts;
  String get ts => _ts ?? '';
  set ts(String? val) => _ts = val;

  bool hasTs() => _ts != null;

  // "syn" field.
  List<SynonymStruct>? _syn;
  List<SynonymStruct> get syn => _syn ?? const [];
  set syn(List<SynonymStruct>? val) => _syn = val;

  void updateSyn(Function(List<SynonymStruct>) updateFn) {
    updateFn(_syn ??= []);
  }

  bool hasSyn() => _syn != null;

  // "tr" field.
  List<TranslationStruct>? _tr;
  List<TranslationStruct> get tr => _tr ?? const [];
  set tr(List<TranslationStruct>? val) => _tr = val;

  void updateTr(Function(List<TranslationStruct>) updateFn) {
    updateFn(_tr ??= []);
  }

  bool hasTr() => _tr != null;

  static EntryStruct fromMap(Map<String, dynamic> data) => EntryStruct(
        text: data['text'] as String?,
        pos: data['pos'] as String?,
        ts: data['ts'] as String?,
        syn: getStructList(
          data['syn'],
          SynonymStruct.fromMap,
        ),
        tr: getStructList(
          data['tr'],
          TranslationStruct.fromMap,
        ),
      );

  static EntryStruct? maybeFromMap(dynamic data) =>
      data is Map ? EntryStruct.fromMap(data.cast<String, dynamic>()) : null;

  Map<String, dynamic> toMap() => {
        'text': _text,
        'pos': _pos,
        'ts': _ts,
        'syn': _syn?.map((e) => e.toMap()).toList(),
        'tr': _tr?.map((e) => e.toMap()).toList(),
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
        'ts': serializeParam(
          _ts,
          ParamType.String,
        ),
        'syn': serializeParam(
          _syn,
          ParamType.DataStruct,
          isList: true,
        ),
        'tr': serializeParam(
          _tr,
          ParamType.DataStruct,
          isList: true,
        ),
      }.withoutNulls;

  static EntryStruct fromSerializableMap(Map<String, dynamic> data) =>
      EntryStruct(
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
        ts: deserializeParam(
          data['ts'],
          ParamType.String,
          false,
        ),
        syn: deserializeStructParam<SynonymStruct>(
          data['syn'],
          ParamType.DataStruct,
          true,
          structBuilder: SynonymStruct.fromSerializableMap,
        ),
        tr: deserializeStructParam<TranslationStruct>(
          data['tr'],
          ParamType.DataStruct,
          true,
          structBuilder: TranslationStruct.fromSerializableMap,
        ),
      );

  @override
  String toString() => 'EntryStruct(${toMap()})';

  @override
  bool operator ==(Object other) {
    const listEquality = ListEquality();
    return other is EntryStruct &&
        text == other.text &&
        pos == other.pos &&
        ts == other.ts &&
        listEquality.equals(syn, other.syn) &&
        listEquality.equals(tr, other.tr);
  }

  @override
  int get hashCode => const ListEquality().hash([text, pos, ts, syn, tr]);
}

EntryStruct createEntryStruct({
  String? text,
  String? pos,
  String? ts,
  List<SynonymStruct>? syn,
  List<TranslationStruct>? tr,
  Map<String, dynamic> fieldValues = const {},
  bool clearUnsetFields = true,
  bool create = false,
  bool delete = false,
}) =>
    EntryStruct(
      text: text,
      pos: pos,
      ts: ts,
      syn: syn,
      tr: tr,
      firestoreUtilData: FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
        delete: delete,
        fieldValues: fieldValues,
      ),
    );

EntryStruct? updateEntryStruct(
  EntryStruct? entry, {
  bool clearUnsetFields = true,
  bool create = false,
}) =>
    entry
      ?..firestoreUtilData = FirestoreUtilData(
        clearUnsetFields: clearUnsetFields,
        create: create,
      );

void addEntryStructData(
  Map<String, dynamic> firestoreData,
  EntryStruct? entry,
  String fieldName, [
  bool forFieldValue = false,
]) {
  firestoreData.remove(fieldName);
  if (entry == null) {
    return;
  }
  if (entry.firestoreUtilData.delete) {
    firestoreData[fieldName] = FieldValue.delete();
    return;
  }
  final clearFields =
      !forFieldValue && entry.firestoreUtilData.clearUnsetFields;
  if (clearFields) {
    firestoreData[fieldName] = <String, dynamic>{};
  }
  final entryData = getEntryFirestoreData(entry, forFieldValue);
  final nestedData = entryData.map((k, v) => MapEntry('$fieldName.$k', v));

  final mergeFields = entry.firestoreUtilData.create || clearFields;
  firestoreData
      .addAll(mergeFields ? mergeNestedFields(nestedData) : nestedData);
}

Map<String, dynamic> getEntryFirestoreData(
  EntryStruct? entry, [
  bool forFieldValue = false,
]) {
  if (entry == null) {
    return {};
  }
  final firestoreData = mapToFirestore(entry.toMap());

  // Add any Firestore field values
  entry.firestoreUtilData.fieldValues.forEach((k, v) => firestoreData[k] = v);

  return forFieldValue ? mergeNestedFields(firestoreData) : firestoreData;
}

List<Map<String, dynamic>> getEntryListFirestoreData(
  List<EntryStruct>? entrys,
) =>
    entrys?.map((e) => getEntryFirestoreData(e, true)).toList() ?? [];
