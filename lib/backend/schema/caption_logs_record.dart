import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class CaptionLogsRecord extends FirestoreRecord {
  CaptionLogsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "speakerId" field.
  String? _speakerId;
  String get speakerId => _speakerId ?? '';
  bool hasSpeakerId() => _speakerId != null;

  // "speakerName" field.
  String? _speakerName;
  String get speakerName => _speakerName ?? '';
  bool hasSpeakerName() => _speakerName != null;

  // "speakerRole" field.
  String? _speakerRole;
  String get speakerRole => _speakerRole ?? '';
  bool hasSpeakerRole() => _speakerRole != null;

  // "utteranceId" field.
  int? _utteranceId;
  int get utteranceId => _utteranceId ?? 0;
  bool hasUtteranceId() => _utteranceId != null;

  // "text" field.
  String? _text;
  String get text => _text ?? '';
  bool hasText() => _text != null;

  // "language" field.
  String? _language;
  String get language => _language ?? '';
  bool hasLanguage() => _language != null;

  // "source" field.
  String? _source;
  String get source => _source ?? '';
  bool hasSource() => _source != null;

  // "capturedAtClient" field.
  DateTime? _capturedAtClient;
  DateTime? get capturedAtClient => _capturedAtClient;
  bool hasCapturedAtClient() => _capturedAtClient != null;

  // "createdAtServer" field.
  DateTime? _createdAtServer;
  DateTime? get createdAtServer => _createdAtServer;
  bool hasCreatedAtServer() => _createdAtServer != null;

  // "confidence" field.
  double? _confidence;
  double get confidence => _confidence ?? 0.0;
  bool hasConfidence() => _confidence != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _speakerId = snapshotData['speakerId'] as String?;
    _speakerName = snapshotData['speakerName'] as String?;
    _speakerRole = snapshotData['speakerRole'] as String?;
    _utteranceId = castToType<int>(snapshotData['utteranceId']);
    _text = snapshotData['text'] as String?;
    _language = snapshotData['language'] as String?;
    _source = snapshotData['source'] as String?;
    _capturedAtClient = snapshotData['capturedAtClient'] as DateTime?;
    _createdAtServer = snapshotData['createdAtServer'] as DateTime?;
    _confidence = castToType<double>(snapshotData['confidence']);
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('captionLogs')
          : FirebaseFirestore.instance.collectionGroup('captionLogs');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('captionLogs').doc(id);

  static Stream<CaptionLogsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => CaptionLogsRecord.fromSnapshot(s));

  static Future<CaptionLogsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => CaptionLogsRecord.fromSnapshot(s));

  static CaptionLogsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      CaptionLogsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static CaptionLogsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      CaptionLogsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'CaptionLogsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is CaptionLogsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createCaptionLogsRecordData({
  String? speakerId,
  String? speakerName,
  String? speakerRole,
  int? utteranceId,
  String? text,
  String? language,
  String? source,
  DateTime? capturedAtClient,
  DateTime? createdAtServer,
  double? confidence,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'speakerId': speakerId,
      'speakerName': speakerName,
      'speakerRole': speakerRole,
      'utteranceId': utteranceId,
      'text': text,
      'language': language,
      'source': source,
      'capturedAtClient': capturedAtClient,
      'createdAtServer': createdAtServer,
      'confidence': confidence,
    }.withoutNulls,
  );

  return firestoreData;
}

class CaptionLogsRecordDocumentEquality implements Equality<CaptionLogsRecord> {
  const CaptionLogsRecordDocumentEquality();

  @override
  bool equals(CaptionLogsRecord? e1, CaptionLogsRecord? e2) {
    return e1?.speakerId == e2?.speakerId &&
        e1?.speakerName == e2?.speakerName &&
        e1?.speakerRole == e2?.speakerRole &&
        e1?.utteranceId == e2?.utteranceId &&
        e1?.text == e2?.text &&
        e1?.language == e2?.language &&
        e1?.source == e2?.source &&
        e1?.capturedAtClient == e2?.capturedAtClient &&
        e1?.createdAtServer == e2?.createdAtServer &&
        e1?.confidence == e2?.confidence;
  }

  @override
  int hash(CaptionLogsRecord? e) => const ListEquality().hash([
        e?.speakerId,
        e?.speakerName,
        e?.speakerRole,
        e?.utteranceId,
        e?.text,
        e?.language,
        e?.source,
        e?.capturedAtClient,
        e?.createdAtServer,
        e?.confidence,
      ]);

  @override
  bool isValidKey(Object? o) => o is CaptionLogsRecord;
}
