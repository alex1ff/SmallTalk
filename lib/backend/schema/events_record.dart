import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class EventsRecord extends FirestoreRecord {
  EventsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "languageCode" field.
  String? _languageCode;
  String get languageCode => _languageCode ?? '';
  bool hasLanguageCode() => _languageCode != null;

  // "languageNameEn" field.
  String? _languageNameEn;
  String get languageNameEn => _languageNameEn ?? '';
  bool hasLanguageNameEn() => _languageNameEn != null;

  // "languageNameRu" field.
  String? _languageNameRu;
  String get languageNameRu => _languageNameRu ?? '';
  bool hasLanguageNameRu() => _languageNameRu != null;

  // "levelMin" field.
  String? _levelMin;
  String get levelMin => _levelMin ?? '';
  bool hasLevelMin() => _levelMin != null;

  // "levelMax" field.
  String? _levelMax;
  String get levelMax => _levelMax ?? '';
  bool hasLevelMax() => _levelMax != null;

  // "countryCode" field.
  String? _countryCode;
  String get countryCode => _countryCode ?? '';
  bool hasCountryCode() => _countryCode != null;

  // "cityKey" field.
  String? _cityKey;
  String get cityKey => _cityKey ?? '';
  bool hasCityKey() => _cityKey != null;

  // "cityNameRu" field.
  String? _cityNameRu;
  String get cityNameRu => _cityNameRu ?? '';
  bool hasCityNameRu() => _cityNameRu != null;

  // "cityNameEn" field.
  String? _cityNameEn;
  String get cityNameEn => _cityNameEn ?? '';
  bool hasCityNameEn() => _cityNameEn != null;

  // "cityDisplayContext" field.
  String? _cityDisplayContext;
  String get cityDisplayContext => _cityDisplayContext ?? '';
  bool hasCityDisplayContext() => _cityDisplayContext != null;

  // "locationName" field.
  String? _locationName;
  String get locationName => _locationName ?? '';
  bool hasLocationName() => _locationName != null;

  // "locationGeoPoint" field.
  LatLng? _locationGeoPoint;
  LatLng? get locationGeoPoint => _locationGeoPoint;
  bool hasLocationGeoPoint() => _locationGeoPoint != null;

  // "startsAt" field.
  DateTime? _startsAt;
  DateTime? get startsAt => _startsAt;
  bool hasStartsAt() => _startsAt != null;

  // "timeZoneId" field.
  String? _timeZoneId;
  String get timeZoneId => _timeZoneId ?? '';
  bool hasTimeZoneId() => _timeZoneId != null;

  // "capacity" field.
  int? _capacity;
  int get capacity => _capacity ?? 0;
  bool hasCapacity() => _capacity != null;

  // "participantsCount" field.
  int? _participantsCount;
  int get participantsCount => _participantsCount ?? 0;
  bool hasParticipantsCount() => _participantsCount != null;

  // "organizerId" field.
  String? _organizerId;
  String get organizerId => _organizerId ?? '';
  bool hasOrganizerId() => _organizerId != null;

  // "organizerDisplayName" field.
  String? _organizerDisplayName;
  String get organizerDisplayName => _organizerDisplayName ?? '';
  bool hasOrganizerDisplayName() => _organizerDisplayName != null;

  // "organizerPhotoUrl" field.
  String? _organizerPhotoUrl;
  String get organizerPhotoUrl => _organizerPhotoUrl ?? '';
  bool hasOrganizerPhotoUrl() => _organizerPhotoUrl != null;

  // "chatId" field.
  String? _chatId;
  String get chatId => _chatId ?? '';
  bool hasChatId() => _chatId != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "createdAt" field.
  DateTime? _createdAt;
  DateTime? get createdAt => _createdAt;
  bool hasCreatedAt() => _createdAt != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  // "canceledAt" field.
  DateTime? _canceledAt;
  DateTime? get canceledAt => _canceledAt;
  bool hasCanceledAt() => _canceledAt != null;

  void _initializeFields() {
    _title = snapshotData['title'] as String?;
    _description = snapshotData['description'] as String?;
    _languageCode = snapshotData['languageCode'] as String?;
    _languageNameEn = snapshotData['languageNameEn'] as String?;
    _languageNameRu = snapshotData['languageNameRu'] as String?;
    _levelMin = snapshotData['levelMin'] as String?;
    _levelMax = snapshotData['levelMax'] as String?;
    _countryCode = snapshotData['countryCode'] as String?;
    _cityKey = snapshotData['cityKey'] as String?;
    _cityNameRu = snapshotData['cityNameRu'] as String?;
    _cityNameEn = snapshotData['cityNameEn'] as String?;
    _cityDisplayContext = snapshotData['cityDisplayContext'] as String?;
    _locationName = snapshotData['locationName'] as String?;
    _locationGeoPoint = snapshotData['locationGeoPoint'] as LatLng?;
    _startsAt = snapshotData['startsAt'] as DateTime?;
    _timeZoneId = snapshotData['timeZoneId'] as String?;
    _capacity = castToType<int>(snapshotData['capacity']);
    _participantsCount = castToType<int>(snapshotData['participantsCount']);
    _organizerId = snapshotData['organizerId'] as String?;
    _organizerDisplayName = snapshotData['organizerDisplayName'] as String?;
    _organizerPhotoUrl = snapshotData['organizerPhotoUrl'] as String?;
    _chatId = snapshotData['chatId'] as String?;
    _status = snapshotData['status'] as String?;
    _createdAt = snapshotData['createdAt'] as DateTime?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
    _canceledAt = snapshotData['canceledAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('events');

  static Stream<EventsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => EventsRecord.fromSnapshot(s));

  static Future<EventsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => EventsRecord.fromSnapshot(s));

  static EventsRecord fromSnapshot(DocumentSnapshot snapshot) => EventsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static EventsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      EventsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'EventsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is EventsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createEventsRecordData({
  String? title,
  String? description,
  String? languageCode,
  String? languageNameEn,
  String? languageNameRu,
  String? levelMin,
  String? levelMax,
  String? countryCode,
  String? cityKey,
  String? cityNameRu,
  String? cityNameEn,
  String? cityDisplayContext,
  String? locationName,
  LatLng? locationGeoPoint,
  DateTime? startsAt,
  String? timeZoneId,
  int? capacity,
  int? participantsCount,
  String? organizerId,
  String? organizerDisplayName,
  String? organizerPhotoUrl,
  String? chatId,
  String? status,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? canceledAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'title': title,
      'description': description,
      'languageCode': languageCode,
      'languageNameEn': languageNameEn,
      'languageNameRu': languageNameRu,
      'levelMin': levelMin,
      'levelMax': levelMax,
      'countryCode': countryCode,
      'cityKey': cityKey,
      'cityNameRu': cityNameRu,
      'cityNameEn': cityNameEn,
      'cityDisplayContext': cityDisplayContext,
      'locationName': locationName,
      'locationGeoPoint': locationGeoPoint,
      'startsAt': startsAt,
      'timeZoneId': timeZoneId,
      'capacity': capacity,
      'participantsCount': participantsCount,
      'organizerId': organizerId,
      'organizerDisplayName': organizerDisplayName,
      'organizerPhotoUrl': organizerPhotoUrl,
      'chatId': chatId,
      'status': status,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'canceledAt': canceledAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class EventsRecordDocumentEquality implements Equality<EventsRecord> {
  const EventsRecordDocumentEquality();

  @override
  bool equals(EventsRecord? e1, EventsRecord? e2) {
    return e1?.title == e2?.title &&
        e1?.description == e2?.description &&
        e1?.languageCode == e2?.languageCode &&
        e1?.languageNameEn == e2?.languageNameEn &&
        e1?.languageNameRu == e2?.languageNameRu &&
        e1?.levelMin == e2?.levelMin &&
        e1?.levelMax == e2?.levelMax &&
        e1?.countryCode == e2?.countryCode &&
        e1?.cityKey == e2?.cityKey &&
        e1?.cityNameRu == e2?.cityNameRu &&
        e1?.cityNameEn == e2?.cityNameEn &&
        e1?.cityDisplayContext == e2?.cityDisplayContext &&
        e1?.locationName == e2?.locationName &&
        e1?.locationGeoPoint == e2?.locationGeoPoint &&
        e1?.startsAt == e2?.startsAt &&
        e1?.timeZoneId == e2?.timeZoneId &&
        e1?.capacity == e2?.capacity &&
        e1?.participantsCount == e2?.participantsCount &&
        e1?.organizerId == e2?.organizerId &&
        e1?.organizerDisplayName == e2?.organizerDisplayName &&
        e1?.organizerPhotoUrl == e2?.organizerPhotoUrl &&
        e1?.chatId == e2?.chatId &&
        e1?.status == e2?.status &&
        e1?.createdAt == e2?.createdAt &&
        e1?.updatedAt == e2?.updatedAt &&
        e1?.canceledAt == e2?.canceledAt;
  }

  @override
  int hash(EventsRecord? e) => const ListEquality().hash([
        e?.title,
        e?.description,
        e?.languageCode,
        e?.languageNameEn,
        e?.languageNameRu,
        e?.levelMin,
        e?.levelMax,
        e?.countryCode,
        e?.cityKey,
        e?.cityNameRu,
        e?.cityNameEn,
        e?.cityDisplayContext,
        e?.locationName,
        e?.locationGeoPoint,
        e?.startsAt,
        e?.timeZoneId,
        e?.capacity,
        e?.participantsCount,
        e?.organizerId,
        e?.organizerDisplayName,
        e?.organizerPhotoUrl,
        e?.chatId,
        e?.status,
        e?.createdAt,
        e?.updatedAt,
        e?.canceledAt,
      ]);

  @override
  bool isValidKey(Object? o) => o is EventsRecord;
}
