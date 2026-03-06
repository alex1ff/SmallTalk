import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class StatsRecord extends FirestoreRecord {
  StatsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "totalCalls" field.
  String? _totalCalls;
  String get totalCalls => _totalCalls ?? '0';
  bool hasTotalCalls() => _totalCalls != null;

  // "totalMinutes" field.
  String? _totalMinutes;
  String get totalMinutes => _totalMinutes ?? '0';
  bool hasTotalMinutes() => _totalMinutes != null;

  // "lastUpdated" field.
  DateTime? _lastUpdated;
  DateTime? get lastUpdated => _lastUpdated;
  bool hasLastUpdated() => _lastUpdated != null;

  // "totalEarned" field.
  String? _totalEarned;
  String get totalEarned => _totalEarned ?? '0';
  bool hasTotalEarned() => _totalEarned != null;

  // "callsToday" field.
  String? _callsToday;
  String get callsToday => _callsToday ?? '0';
  bool hasCallsToday() => _callsToday != null;

  // "minutesToday" field.
  String? _minutesToday;
  String get minutesToday => _minutesToday ?? '0';
  bool hasMinutesToday() => _minutesToday != null;

  // "spentToday" field.
  String? _spentToday;
  String get spentToday => _spentToday ?? '0';
  bool hasSpentToday() => _spentToday != null;

  // "earnedToday" field.
  String? _earnedToday;
  String get earnedToday => _earnedToday ?? '0';
  bool hasEarnedToday() => _earnedToday != null;

  // "date" field.
  DateTime? _date;
  DateTime? get date => _date;
  bool hasDate() => _date != null;

  // "isAllTime" field.
  bool? _isAllTime;
  bool get isAllTime => _isAllTime ?? false;
  bool hasIsAllTime() => _isAllTime != null;

  DocumentReference get parentReference => reference.parent.parent!;

  void _initializeFields() {
    _totalCalls = _statString(snapshotData['totalCalls']);
    _totalMinutes = _statString(snapshotData['totalMinutes']);
    _lastUpdated = snapshotData['lastUpdated'] as DateTime?;
    _totalEarned = _statString(snapshotData['totalEarned']);
    _callsToday = _statString(snapshotData['callsToday']);
    _minutesToday = _statString(snapshotData['minutesToday']);
    _spentToday = _statString(snapshotData['spentToday']);
    _earnedToday = _statString(snapshotData['earnedToday']);
    _date = snapshotData['date'] as DateTime?;
    _isAllTime = snapshotData['isAllTime'] as bool?;
  }

  static Query<Map<String, dynamic>> collection([DocumentReference? parent]) =>
      parent != null
          ? parent.collection('stats')
          : FirebaseFirestore.instance.collectionGroup('stats');

  static DocumentReference createDoc(DocumentReference parent, {String? id}) =>
      parent.collection('stats').doc(id);

  static Stream<StatsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => StatsRecord.fromSnapshot(s));

  static Future<StatsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => StatsRecord.fromSnapshot(s));

  static StatsRecord fromSnapshot(DocumentSnapshot snapshot) => StatsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static StatsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      StatsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'StatsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is StatsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

String? _statString(dynamic value) {
  if (value == null) {
    return null;
  }

  return value.toString();
}

Map<String, dynamic> createStatsRecordData({
  String? totalCalls,
  String? totalMinutes,
  DateTime? lastUpdated,
  String? totalEarned,
  String? callsToday,
  String? minutesToday,
  String? spentToday,
  String? earnedToday,
  DateTime? date,
  bool? isAllTime,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'totalCalls': totalCalls,
      'totalMinutes': totalMinutes,
      'lastUpdated': lastUpdated,
      'totalEarned': totalEarned,
      'callsToday': callsToday,
      'minutesToday': minutesToday,
      'spentToday': spentToday,
      'earnedToday': earnedToday,
      'date': date,
      'isAllTime': isAllTime,
    }.withoutNulls,
  );

  return firestoreData;
}

class StatsRecordDocumentEquality implements Equality<StatsRecord> {
  const StatsRecordDocumentEquality();

  @override
  bool equals(StatsRecord? e1, StatsRecord? e2) {
    return e1?.totalCalls == e2?.totalCalls &&
        e1?.totalMinutes == e2?.totalMinutes &&
        e1?.lastUpdated == e2?.lastUpdated &&
        e1?.totalEarned == e2?.totalEarned &&
        e1?.callsToday == e2?.callsToday &&
        e1?.minutesToday == e2?.minutesToday &&
        e1?.spentToday == e2?.spentToday &&
        e1?.earnedToday == e2?.earnedToday &&
        e1?.date == e2?.date &&
        e1?.isAllTime == e2?.isAllTime;
  }

  @override
  int hash(StatsRecord? e) => const ListEquality().hash([
        e?.totalCalls,
        e?.totalMinutes,
        e?.lastUpdated,
        e?.totalEarned,
        e?.callsToday,
        e?.minutesToday,
        e?.spentToday,
        e?.earnedToday,
        e?.date,
        e?.isAllTime
      ]);

  @override
  bool isValidKey(Object? o) => o is StatsRecord;
}
