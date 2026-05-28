import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/enums/enums.dart';
import '/backend/schema/util/firestore_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart';

class UserPublicProfilesRecord extends FirestoreRecord {
  UserPublicProfilesRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "userId" field.
  String? _userId;
  String get userId => _userId ?? '';
  bool hasUserId() => _userId != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "photo_url" field.
  String? _photoUrl;
  String get photoUrl => _photoUrl ?? '';
  bool hasPhotoUrl() => _photoUrl != null;

  // "role" field.
  UserRole? _role;
  UserRole? get role => _role;
  bool hasRole() => _role != null;

  // "isProfileComplete" field.
  bool? _isProfileComplete;
  bool get isProfileComplete => _isProfileComplete ?? false;
  bool hasIsProfileComplete() => _isProfileComplete != null;

  // "aboutMe" field.
  String? _aboutMe;
  String get aboutMe => _aboutMe ?? '';
  bool hasAboutMe() => _aboutMe != null;

  // "language_instruction_NS" field.
  LanguageStruct? _languageInstructionNS;
  LanguageStruct get languageInstructionNS =>
      _languageInstructionNS ?? LanguageStruct();
  bool hasLanguageInstructionNS() => _languageInstructionNS != null;

  // "language_instruction_NS.code" field.
  String? _languageInstructionCode;
  String get languageInstructionCode => _languageInstructionCode ?? '';
  bool hasLanguageInstructionCode() => _languageInstructionCode != null;

  // "native_language_NS" field.
  LanguageStruct? _nativeLanguageNS;
  LanguageStruct get nativeLanguageNS => _nativeLanguageNS ?? LanguageStruct();
  bool hasNativeLanguageNS() => _nativeLanguageNS != null;

  // "Country_NS" field.
  CountryStruct? _countryNS;
  CountryStruct get countryNS => _countryNS ?? CountryStruct();
  bool hasCountryNS() => _countryNS != null;

  // "Country_NS.code" field.
  String? _countryCode;
  String get countryCode => _countryCode ?? '';
  bool hasCountryCode() => _countryCode != null;

  // "level" field.
  Level? _level;
  Level? get level => _level;
  bool hasLevel() => _level != null;

  // "ratingAverage" field.
  double? _ratingAverage;
  double get ratingAverage => _ratingAverage ?? 0.0;
  bool hasRatingAverage() => _ratingAverage != null;

  // "ratingCount" field.
  int? _ratingCount;
  int get ratingCount => _ratingCount ?? 0;
  bool hasRatingCount() => _ratingCount != null;

  URatingStruct get rating => URatingStruct(
        average: ratingAverage,
        totalReviews: ratingCount,
      );

  // "approvedTeacher" field.
  bool? _approvedTeacher;
  bool get approvedTeacher => _approvedTeacher ?? false;
  bool hasApprovedTeacher() => _approvedTeacher != null;

  // "updatedAt" field.
  DateTime? _updatedAt;
  DateTime? get updatedAt => _updatedAt;
  bool hasUpdatedAt() => _updatedAt != null;

  void _initializeFields() {
    _userId = snapshotData['userId'] as String?;
    _displayName = snapshotData['display_name'] as String? ??
        snapshotData['displayName'] as String?;
    _photoUrl = snapshotData['photo_url'] as String? ??
        snapshotData['photoUrl'] as String?;
    _role = snapshotData['role'] is UserRole
        ? snapshotData['role']
        : deserializeEnum<UserRole>(snapshotData['role']);
    _isProfileComplete = snapshotData['isProfileComplete'] as bool?;
    _aboutMe = snapshotData['aboutMe'] as String?;
    _languageInstructionNS =
        LanguageStruct.maybeFromMap(snapshotData['language_instruction_NS']);
    _languageInstructionCode = _languageInstructionNS?.code.isNotEmpty == true
        ? _languageInstructionNS!.code
        : _readNestedString(snapshotData['language_instruction_NS'], 'code');
    _nativeLanguageNS =
        LanguageStruct.maybeFromMap(snapshotData['native_language_NS']);
    _countryNS = CountryStruct.maybeFromMap(snapshotData['Country_NS']);
    _countryCode = _countryNS?.code.isNotEmpty == true
        ? _countryNS!.code
        : _readNestedString(snapshotData['Country_NS'], 'code');
    _level = snapshotData['level'] is Level
        ? snapshotData['level']
        : deserializeEnum<Level>(snapshotData['level']);
    final ratingData = snapshotData['rating'];
    final ratingMap =
        ratingData is Map ? ratingData.cast<String, dynamic>() : null;
    _ratingAverage = castToType<double>(
      snapshotData['ratingAverage'] ?? ratingMap?['average'],
    );
    _ratingCount = castToType<int>(
      snapshotData['ratingCount'] ?? ratingMap?['totalReviews'],
    );
    _approvedTeacher = snapshotData['approvedTeacher'] as bool?;
    _updatedAt = snapshotData['updatedAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('userPublicProfiles');

  static Stream<UserPublicProfilesRecord> getDocument(
    DocumentReference ref,
  ) =>
      ref.snapshots().map((s) => UserPublicProfilesRecord.fromSnapshot(s));

  static Stream<UserPublicProfilesRecord?> maybeGetDocument(
    DocumentReference ref,
  ) =>
      ref.snapshots().map(
            (s) => s.exists ? UserPublicProfilesRecord.fromSnapshot(s) : null,
          );

  static Future<UserPublicProfilesRecord> getDocumentOnce(
    DocumentReference ref,
  ) =>
      ref.get().then((s) => UserPublicProfilesRecord.fromSnapshot(s));

  static Future<UserPublicProfilesRecord?> maybeGetDocumentOnce(
    DocumentReference ref,
  ) async {
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      return null;
    }
    return UserPublicProfilesRecord.fromSnapshot(snapshot);
  }

  static UserPublicProfilesRecord fromSnapshot(DocumentSnapshot snapshot) =>
      UserPublicProfilesRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UserPublicProfilesRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UserPublicProfilesRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UserPublicProfilesRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UserPublicProfilesRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

class UserPublicProfilesRecordDocumentEquality
    implements Equality<UserPublicProfilesRecord> {
  const UserPublicProfilesRecordDocumentEquality();

  @override
  bool equals(UserPublicProfilesRecord? e1, UserPublicProfilesRecord? e2) {
    return e1?.userId == e2?.userId &&
        e1?.displayName == e2?.displayName &&
        e1?.photoUrl == e2?.photoUrl &&
        e1?.role == e2?.role &&
        e1?.isProfileComplete == e2?.isProfileComplete &&
        e1?.aboutMe == e2?.aboutMe &&
        e1?.languageInstructionNS == e2?.languageInstructionNS &&
        e1?.languageInstructionCode == e2?.languageInstructionCode &&
        e1?.nativeLanguageNS == e2?.nativeLanguageNS &&
        e1?.countryNS == e2?.countryNS &&
        e1?.countryCode == e2?.countryCode &&
        e1?.level == e2?.level &&
        e1?.ratingAverage == e2?.ratingAverage &&
        e1?.ratingCount == e2?.ratingCount &&
        e1?.approvedTeacher == e2?.approvedTeacher &&
        e1?.updatedAt == e2?.updatedAt;
  }

  @override
  int hash(UserPublicProfilesRecord? e) => const ListEquality().hash([
        e?.userId,
        e?.displayName,
        e?.photoUrl,
        e?.role,
        e?.isProfileComplete,
        e?.aboutMe,
        e?.languageInstructionNS,
        e?.languageInstructionCode,
        e?.nativeLanguageNS,
        e?.countryNS,
        e?.countryCode,
        e?.level,
        e?.ratingAverage,
        e?.ratingCount,
        e?.approvedTeacher,
        e?.updatedAt,
      ]);

  @override
  bool isValidKey(Object? o) => o is UserPublicProfilesRecord;
}

String? _readNestedString(Object? value, String key) {
  if (value is Map<String, dynamic>) {
    return value[key] as String?;
  }
  if (value is Map) {
    final nestedValue = value[key];
    return nestedValue is String ? nestedValue : null;
  }
  return null;
}
