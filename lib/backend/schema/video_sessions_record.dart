import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class VideoSessionsRecord extends FirestoreRecord {
  VideoSessionsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "language" field.
  String? _language;
  String get language => _language ?? '';
  bool hasLanguage() => _language != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "startedAt" field.
  DateTime? _startedAt;
  DateTime? get startedAt => _startedAt;
  bool hasStartedAt() => _startedAt != null;

  // "endedAt" field.
  DateTime? _endedAt;
  DateTime? get endedAt => _endedAt;
  bool hasEndedAt() => _endedAt != null;

  // "duration" field.
  int? _duration;
  int get duration => _duration ?? 0;
  bool hasDuration() => _duration != null;

  // "status" field.
  String? _status;

  /// ## Статусы сессии:
  /// - `searching` - сессия создана, пара еще не подтверждается
  /// - `pending_confirmation` - пара найдена, ожидается ответ участника
  /// - `connecting` - участники подтверждены, идет вход в комнату
  /// - `active` - оба участника вошли в комнату
  /// - `cancelled` - пара отменена до начала звонка
  /// - `expired` - истек таймаут ответа или входа
  /// - `ended` - звонок завершен
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "tutorId" field.
  String? _tutorId;
  String get tutorId => _tutorId ?? '';
  bool hasTutorId() => _tutorId != null;

  // "studentId" field.
  String? _studentId;
  String get studentId => _studentId ?? '';
  bool hasStudentId() => _studentId != null;

  // "participantIds" field.
  List<String>? _participantIds;
  List<String> get participantIds => _participantIds ?? const [];
  bool hasParticipantIds() => _participantIds != null;

  // "dailyRoomUrl" field.
  String? _dailyRoomUrl;
  String get dailyRoomUrl => _dailyRoomUrl ?? '';
  bool hasDailyRoomUrl() => _dailyRoomUrl != null;

  // "meetingToken" field.
  String? _meetingToken;
  String get meetingToken => _meetingToken ?? '';
  bool hasMeetingToken() => _meetingToken != null;

  // "dailyRoomName" field.
  String? _dailyRoomName;
  String get dailyRoomName => _dailyRoomName ?? '';
  bool hasDailyRoomName() => _dailyRoomName != null;

  // "expiresAt" field.
  DateTime? _expiresAt;
  DateTime? get expiresAt => _expiresAt;
  bool hasExpiresAt() => _expiresAt != null;

  // "currentTutorId" field.
  String? _currentTutorId;
  String get currentTutorId => _currentTutorId ?? '';
  bool hasCurrentTutorId() => _currentTutorId != null;

  // "triedTutors" field.
  List<String>? _triedTutors;
  List<String> get triedTutors => _triedTutors ?? const [];
  bool hasTriedTutors() => _triedTutors != null;

  // "availableTutors" field.
  List<String>? _availableTutors;
  List<String> get availableTutors => _availableTutors ?? const [];
  bool hasAvailableTutors() => _availableTutors != null;

  // "studentInfo" field.
  StudentInfoStruct? _studentInfo;
  StudentInfoStruct get studentInfo => _studentInfo ?? StudentInfoStruct();
  bool hasStudentInfo() => _studentInfo != null;

  // "acceptedAt" field.
  DateTime? _acceptedAt;
  DateTime? get acceptedAt => _acceptedAt;
  bool hasAcceptedAt() => _acceptedAt != null;

  // "tutorInfo" field.
  TutorInfoStruct? _tutorInfo;
  TutorInfoStruct get tutorInfo => _tutorInfo ?? TutorInfoStruct();
  bool hasTutorInfo() => _tutorInfo != null;

  // "version" field.
  String? _version;
  String get version => _version ?? '';
  bool hasVersion() => _version != null;

  // "platform" field.
  String? _platform;
  String get platform => _platform ?? '';
  bool hasPlatform() => _platform != null;

  // "earnings" field.
  int? _earnings;
  int get earnings => _earnings ?? 0;
  bool hasEarnings() => _earnings != null;

  // "studentHasReviewed" field.
  bool? _studentHasReviewed;
  bool get studentHasReviewed => _studentHasReviewed ?? false;
  bool hasStudentHasReviewed() => _studentHasReviewed != null;

  // "tutorHasReviewed" field.
  bool? _tutorHasReviewed;
  bool get tutorHasReviewed => _tutorHasReviewed ?? false;
  bool hasTutorHasReviewed() => _tutorHasReviewed != null;

  // "studentReviewRef" field.
  DocumentReference? _studentReviewRef;
  DocumentReference? get studentReviewRef => _studentReviewRef;
  bool hasStudentReviewRef() => _studentReviewRef != null;

  // "tutorReviewRef" field.
  DocumentReference? _tutorReviewRef;
  DocumentReference? get tutorReviewRef => _tutorReviewRef;
  bool hasTutorReviewRef() => _tutorReviewRef != null;

  void _initializeFields() {
    _language = snapshotData['language'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _startedAt = snapshotData['startedAt'] as DateTime?;
    _endedAt = snapshotData['endedAt'] as DateTime?;
    _duration = castToType<int>(snapshotData['duration']);
    _status = snapshotData['status'] as String?;
    _tutorId = snapshotData['tutorId'] as String?;
    _studentId = snapshotData['studentId'] as String?;
    _participantIds = getDataList(snapshotData['participantIds']);
    _dailyRoomUrl = snapshotData['dailyRoomUrl'] as String?;
    _meetingToken = snapshotData['meetingToken'] as String?;
    _dailyRoomName = snapshotData['dailyRoomName'] as String?;
    _expiresAt = snapshotData['expiresAt'] as DateTime?;
    _currentTutorId = snapshotData['currentTutorId'] as String?;
    _triedTutors = getDataList(snapshotData['triedTutors']);
    _availableTutors = getDataList(snapshotData['availableTutors']);
    _studentInfo = snapshotData['studentInfo'] is StudentInfoStruct
        ? snapshotData['studentInfo']
        : StudentInfoStruct.maybeFromMap(snapshotData['studentInfo']);
    _acceptedAt = snapshotData['acceptedAt'] as DateTime?;
    _tutorInfo = snapshotData['tutorInfo'] is TutorInfoStruct
        ? snapshotData['tutorInfo']
        : TutorInfoStruct.maybeFromMap(snapshotData['tutorInfo']);
    _version = snapshotData['version'] as String?;
    _platform = snapshotData['platform'] as String?;
    _earnings = castToType<int>(snapshotData['earnings']);
    _studentHasReviewed = snapshotData['studentHasReviewed'] as bool?;
    _tutorHasReviewed = snapshotData['tutorHasReviewed'] as bool?;
    _studentReviewRef = snapshotData['studentReviewRef'] as DocumentReference?;
    _tutorReviewRef = snapshotData['tutorReviewRef'] as DocumentReference?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('videoSessions');

  static Stream<VideoSessionsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => VideoSessionsRecord.fromSnapshot(s));

  static Future<VideoSessionsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => VideoSessionsRecord.fromSnapshot(s));

  static VideoSessionsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      VideoSessionsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static VideoSessionsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      VideoSessionsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'VideoSessionsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is VideoSessionsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createVideoSessionsRecordData({
  String? language,
  DateTime? createdAt,
  DateTime? startedAt,
  DateTime? endedAt,
  int? duration,
  String? status,
  String? tutorId,
  String? studentId,
  List<String>? participantIds,
  String? dailyRoomUrl,
  String? meetingToken,
  String? dailyRoomName,
  DateTime? expiresAt,
  String? currentTutorId,
  StudentInfoStruct? studentInfo,
  DateTime? acceptedAt,
  TutorInfoStruct? tutorInfo,
  String? version,
  String? platform,
  int? earnings,
  bool? studentHasReviewed,
  bool? tutorHasReviewed,
  DocumentReference? studentReviewRef,
  DocumentReference? tutorReviewRef,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'language': language,
      'createdAt': createdAt,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'duration': duration,
      'status': status,
      'tutorId': tutorId,
      'studentId': studentId,
      'participantIds': participantIds,
      'dailyRoomUrl': dailyRoomUrl,
      'meetingToken': meetingToken,
      'dailyRoomName': dailyRoomName,
      'expiresAt': expiresAt,
      'currentTutorId': currentTutorId,
      'studentInfo': StudentInfoStruct().toMap(),
      'acceptedAt': acceptedAt,
      'tutorInfo': TutorInfoStruct().toMap(),
      'version': version,
      'platform': platform,
      'earnings': earnings,
      'studentHasReviewed': studentHasReviewed,
      'tutorHasReviewed': tutorHasReviewed,
      'studentReviewRef': studentReviewRef,
      'tutorReviewRef': tutorReviewRef,
    }.withoutNulls,
  );

  // Handle nested data for "studentInfo" field.
  addStudentInfoStructData(firestoreData, studentInfo, 'studentInfo');

  // Handle nested data for "tutorInfo" field.
  addTutorInfoStructData(firestoreData, tutorInfo, 'tutorInfo');

  return firestoreData;
}

class VideoSessionsRecordDocumentEquality
    implements Equality<VideoSessionsRecord> {
  const VideoSessionsRecordDocumentEquality();

  @override
  bool equals(VideoSessionsRecord? e1, VideoSessionsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.language == e2?.language &&
        e1?.createdAt == e2?.createdAt &&
        e1?.startedAt == e2?.startedAt &&
        e1?.endedAt == e2?.endedAt &&
        e1?.duration == e2?.duration &&
        e1?.status == e2?.status &&
        e1?.tutorId == e2?.tutorId &&
        e1?.studentId == e2?.studentId &&
        listEquality.equals(e1?.participantIds, e2?.participantIds) &&
        e1?.dailyRoomUrl == e2?.dailyRoomUrl &&
        e1?.meetingToken == e2?.meetingToken &&
        e1?.dailyRoomName == e2?.dailyRoomName &&
        e1?.expiresAt == e2?.expiresAt &&
        e1?.currentTutorId == e2?.currentTutorId &&
        listEquality.equals(e1?.triedTutors, e2?.triedTutors) &&
        listEquality.equals(e1?.availableTutors, e2?.availableTutors) &&
        e1?.studentInfo == e2?.studentInfo &&
        e1?.acceptedAt == e2?.acceptedAt &&
        e1?.tutorInfo == e2?.tutorInfo &&
        e1?.version == e2?.version &&
        e1?.platform == e2?.platform &&
        e1?.earnings == e2?.earnings &&
        e1?.studentHasReviewed == e2?.studentHasReviewed &&
        e1?.tutorHasReviewed == e2?.tutorHasReviewed &&
        e1?.studentReviewRef == e2?.studentReviewRef &&
        e1?.tutorReviewRef == e2?.tutorReviewRef;
  }

  @override
  int hash(VideoSessionsRecord? e) => const ListEquality().hash([
        e?.language,
        e?.createdAt,
        e?.startedAt,
        e?.endedAt,
        e?.duration,
        e?.status,
        e?.tutorId,
        e?.studentId,
        e?.participantIds,
        e?.dailyRoomUrl,
        e?.meetingToken,
        e?.dailyRoomName,
        e?.expiresAt,
        e?.currentTutorId,
        e?.triedTutors,
        e?.availableTutors,
        e?.studentInfo,
        e?.acceptedAt,
        e?.tutorInfo,
        e?.version,
        e?.platform,
        e?.earnings,
        e?.studentHasReviewed,
        e?.tutorHasReviewed,
        e?.studentReviewRef,
        e?.tutorReviewRef
      ]);

  @override
  bool isValidKey(Object? o) => o is VideoSessionsRecord;
}
