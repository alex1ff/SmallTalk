import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/enums/enums.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

Map<String, dynamic> _asStringKeyedMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) => MapEntry(key.toString(), value));
  }
  return const <String, dynamic>{};
}

TeacherAccreditationStatus? _teacherAccreditationStatusFrom(Object? value) {
  return value is TeacherAccreditationStatus
      ? value
      : deserializeEnum<TeacherAccreditationStatus>(value);
}

TeacherAccreditationStatus? resolveExplicitTeacherAccreditationStatusFromData(
  Map<String, dynamic> data,
) {
  final canonicalStatus =
      _teacherAccreditationStatusFrom(data['teacherAccreditationStatus']);
  if (canonicalStatus != null) {
    return canonicalStatus;
  }

  final teacherVerificationStatus =
      _teacherAccreditationStatusFrom(data['teacherVerificationStatus']);
  if (teacherVerificationStatus != null) {
    return teacherVerificationStatus;
  }

  return _teacherAccreditationStatusFrom(data['verificationStatus']);
}

TeacherAccreditationStatus resolveTeacherAccreditationStatusFromData(
  Map<String, dynamic> data,
) {
  final canonicalStatus =
      resolveExplicitTeacherAccreditationStatusFromData(data);
  if (canonicalStatus != null) {
    return canonicalStatus;
  }

  if (data['verif_NS'] == true) {
    return TeacherAccreditationStatus.approved;
  }

  final matchProfile = _asStringKeyedMap(data['matchProfile']);
  final matchProfileStatus = _teacherAccreditationStatusFrom(
      matchProfile['teacherAccreditationStatus']);
  if (matchProfileStatus != null) {
    return matchProfileStatus;
  }
  if (matchProfile['approvedTeacher'] == true) {
    return TeacherAccreditationStatus.approved;
  }

  return TeacherAccreditationStatus.pending;
}

bool isTeacherAccreditationApprovedFromData(Map<String, dynamic> data) =>
    resolveTeacherAccreditationStatusFromData(data) ==
    TeacherAccreditationStatus.approved;

bool hasPendingTeacherVerificationFromData(Map<String, dynamic> data) =>
    resolveExplicitTeacherAccreditationStatusFromData(data) ==
    TeacherAccreditationStatus.pending;

class UsersRecord extends FirestoreRecord {
  UsersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "uid" field.
  String? _uid;
  String get uid => _uid ?? '';
  bool hasUid() => _uid != null;

  // "created_time" field.
  DateTime? _createdTime;
  DateTime? get createdTime => _createdTime;
  bool hasCreatedTime() => _createdTime != null;

  // "phone_number" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  // "display_name" field.
  String? _displayName;
  String get displayName => _displayName ?? '';
  bool hasDisplayName() => _displayName != null;

  // "role" field.
  UserRole? _role;
  UserRole? get role => _role;
  bool hasRole() => _role != null;

  // "isInCall" field.
  bool? _isInCall;
  bool get isInCall => _isInCall ?? false;
  bool hasIsInCall() => _isInCall != null;

  // "currentSessionId" field.
  String? _currentSessionId;
  String get currentSessionId => _currentSessionId ?? '';
  bool hasCurrentSessionId() => _currentSessionId != null;

  // "gender" field.
  Gender? _gender;
  Gender? get gender => _gender;
  bool hasGender() => _gender != null;

  // "aboutMe" field.
  String? _aboutMe;
  String get aboutMe => _aboutMe ?? '';
  bool hasAboutMe() => _aboutMe != null;

  // "isProfileComplete" field.
  bool? _isProfileComplete;
  bool get isProfileComplete => _isProfileComplete ?? false;
  bool hasIsProfileComplete() => _isProfileComplete != null;

  // "preferences" field.
  PreferencesStruct? _preferences;
  PreferencesStruct get preferences => _preferences ?? PreferencesStruct();
  bool hasPreferences() => _preferences != null;

  // "queuePriority" field.
  int? _queuePriority;
  int get queuePriority => _queuePriority ?? 0;
  bool hasQueuePriority() => _queuePriority != null;

  // "earnings" field.
  EarningsStruct? _earnings;
  EarningsStruct get earnings => _earnings ?? EarningsStruct();
  bool hasEarnings() => _earnings != null;

  // "friends" field.
  List<DocumentReference>? _friends;
  List<DocumentReference> get friends =>
      _friends ?? _favoriteNativeSpeakers ?? const [];
  bool hasFriends() => _friends != null;

  // "favoriteNativeSpeakers" field.
  List<DocumentReference>? _favoriteNativeSpeakers;
  List<DocumentReference> get favoriteNativeSpeakers =>
      _favoriteNativeSpeakers ?? const [];
  bool hasFavoriteNativeSpeakers() => _favoriteNativeSpeakers != null;

  // "learningLanguage" field.
  LanguageStruct? _learningLanguage;
  LanguageStruct get learningLanguage => _learningLanguage ?? LanguageStruct();
  bool hasLearningLanguage() => _learningLanguage != null;

  // "dateofbirth" field.
  DateTime? _dateofbirth;
  DateTime? get dateofbirth => _dateofbirth;
  bool hasDateofbirth() => _dateofbirth != null;

  // "purpose" field.
  List<String>? _purpose;
  List<String> get purpose => _purpose ?? const [];
  bool hasPurpose() => _purpose != null;

  // "rating" field.
  URatingStruct? _rating;
  URatingStruct get rating => _rating ?? URatingStruct();
  bool hasRating() => _rating != null;

  // "photo_url" field.
  String? _photoUrl;
  String get photoUrl => _photoUrl ?? '';
  bool hasPhotoUrl() => _photoUrl != null;

  // "level" field.
  Level? _level;
  Level? get level => _level;
  bool hasLevel() => _level != null;

  // "Acquaintance" field.
  bool? _acquaintance;
  bool get acquaintance => _acquaintance ?? false;
  bool hasAcquaintance() => _acquaintance != null;

  // "Country_NS" field.
  CountryStruct? _countryNS;
  CountryStruct get countryNS => _countryNS ?? CountryStruct();
  bool hasCountryNS() => _countryNS != null;

  // "verif_NS" field.
  bool? _verifNS;
  bool get verifNS => _verifNS ?? false;
  bool hasVerifNS() => _verifNS != null;

  // "teacherAccreditationStatus" field.
  TeacherAccreditationStatus? _teacherAccreditationStatus;
  TeacherAccreditationStatus? get teacherAccreditationStatus =>
      _teacherAccreditationStatus;
  bool hasTeacherAccreditationStatus() => _teacherAccreditationStatus != null;

  TeacherAccreditationStatus get effectiveTeacherAccreditationStatus =>
      resolveTeacherAccreditationStatusFromData(snapshotData);
  bool get isTeacherAccreditationApproved =>
      effectiveTeacherAccreditationStatus ==
      TeacherAccreditationStatus.approved;
  bool get hasPendingTeacherVerification =>
      hasPendingTeacherVerificationFromData(snapshotData);

  // "selectedAvatarDocRef" field.
  DocumentReference? _selectedAvatarDocRef;
  DocumentReference? get selectedAvatarDocRef => _selectedAvatarDocRef;
  bool hasSelectedAvatarDocRef() => _selectedAvatarDocRef != null;

  // "balanceST" field.
  BalanceStruct? _balanceST;
  BalanceStruct get balanceST => _balanceST ?? BalanceStruct();
  bool hasBalanceST() => _balanceST != null;

  // "balance_NS" field.
  double? _balanceNS;
  double get balanceNS => _balanceNS ?? 0.0;
  bool hasBalanceNS() => _balanceNS != null;

  // "blockedUsers" field.
  List<DocumentReference>? _blockedUsers;
  List<DocumentReference> get blockedUsers => _blockedUsers ?? const [];
  bool hasBlockedUsers() => _blockedUsers != null;

  // "availabilityToday" field.
  AvailabilityTodayStruct? _availabilityToday;
  AvailabilityTodayStruct get availabilityToday =>
      _availabilityToday ?? AvailabilityTodayStruct();
  bool hasAvailabilityToday() => _availabilityToday != null;

  // "totalCalls" field.
  int? _totalCalls;
  int get totalCalls => _totalCalls ?? 0;
  bool hasTotalCalls() => _totalCalls != null;

  // "language_instruction_NS" field.
  LanguageStruct? _languageInstructionNS;
  LanguageStruct get languageInstructionNS =>
      _languageInstructionNS ?? LanguageStruct();
  bool hasLanguageInstructionNS() => _languageInstructionNS != null;

  // "native_language_NS" field.
  LanguageStruct? _nativeLanguageNS;
  LanguageStruct get nativeLanguageNS => _nativeLanguageNS ?? LanguageStruct();
  bool hasNativeLanguageNS() => _nativeLanguageNS != null;

  void _initializeFields() {
    _email = snapshotData['email'] as String?;
    _uid = snapshotData['uid'] as String?;
    _createdTime = snapshotData['created_time'] as DateTime?;
    _phoneNumber = snapshotData['phone_number'] as String?;
    _displayName = snapshotData['display_name'] as String?;
    _role = snapshotData['role'] is UserRole
        ? snapshotData['role']
        : deserializeEnum<UserRole>(snapshotData['role']);
    _isInCall = snapshotData['isInCall'] as bool?;
    _currentSessionId = snapshotData['currentSessionId'] as String?;
    _gender = snapshotData['gender'] is Gender
        ? snapshotData['gender']
        : deserializeEnum<Gender>(snapshotData['gender']);
    _aboutMe = snapshotData['aboutMe'] as String?;
    _isProfileComplete = snapshotData['isProfileComplete'] as bool?;
    _preferences = snapshotData['preferences'] is PreferencesStruct
        ? snapshotData['preferences']
        : PreferencesStruct.maybeFromMap(snapshotData['preferences']);
    _queuePriority = castToType<int>(snapshotData['queuePriority']);
    _earnings = snapshotData['earnings'] is EarningsStruct
        ? snapshotData['earnings']
        : EarningsStruct.maybeFromMap(snapshotData['earnings']);
    _friends = getDataList(snapshotData['friends']);
    _favoriteNativeSpeakers =
        getDataList(snapshotData['favoriteNativeSpeakers']);
    _learningLanguage = snapshotData['learningLanguage'] is LanguageStruct
        ? snapshotData['learningLanguage']
        : LanguageStruct.maybeFromMap(snapshotData['learningLanguage']);
    _dateofbirth = snapshotData['dateofbirth'] as DateTime?;
    _purpose = getDataList(snapshotData['purpose']);
    _rating = snapshotData['rating'] is URatingStruct
        ? snapshotData['rating']
        : URatingStruct.maybeFromMap(snapshotData['rating']);
    _photoUrl = snapshotData['photo_url'] as String?;
    _level = snapshotData['level'] is Level
        ? snapshotData['level']
        : deserializeEnum<Level>(snapshotData['level']);
    _acquaintance = snapshotData['Acquaintance'] as bool?;
    _countryNS = snapshotData['Country_NS'] is CountryStruct
        ? snapshotData['Country_NS']
        : CountryStruct.maybeFromMap(snapshotData['Country_NS']);
    _verifNS = snapshotData['verif_NS'] as bool?;
    _teacherAccreditationStatus = _teacherAccreditationStatusFrom(
        snapshotData['teacherAccreditationStatus']);
    _selectedAvatarDocRef =
        snapshotData['selectedAvatarDocRef'] as DocumentReference?;
    _balanceST = snapshotData['balanceST'] is BalanceStruct
        ? snapshotData['balanceST']
        : BalanceStruct.maybeFromMap(snapshotData['balanceST']);
    _balanceNS = castToType<double>(snapshotData['balance_NS']);
    _blockedUsers = getDataList(snapshotData['blockedUsers']);
    _availabilityToday =
        snapshotData['availabilityToday'] is AvailabilityTodayStruct
            ? snapshotData['availabilityToday']
            : AvailabilityTodayStruct.maybeFromMap(
                snapshotData['availabilityToday']);
    _totalCalls = castToType<int>(snapshotData['totalCalls']);
    _languageInstructionNS = snapshotData['language_instruction_NS']
            is LanguageStruct
        ? snapshotData['language_instruction_NS']
        : LanguageStruct.maybeFromMap(snapshotData['language_instruction_NS']);
    _nativeLanguageNS = snapshotData['native_language_NS'] is LanguageStruct
        ? snapshotData['native_language_NS']
        : LanguageStruct.maybeFromMap(snapshotData['native_language_NS']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('users');

  static Stream<UsersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UsersRecord.fromSnapshot(s));

  static Future<UsersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UsersRecord.fromSnapshot(s));

  static UsersRecord fromSnapshot(DocumentSnapshot snapshot) => UsersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UsersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UsersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UsersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UsersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUsersRecordData({
  String? email,
  String? uid,
  DateTime? createdTime,
  String? phoneNumber,
  String? displayName,
  UserRole? role,
  bool? isInCall,
  String? currentSessionId,
  Gender? gender,
  String? aboutMe,
  bool? isProfileComplete,
  PreferencesStruct? preferences,
  int? queuePriority,
  EarningsStruct? earnings,
  List<DocumentReference>? friends,
  List<DocumentReference>? favoriteNativeSpeakers,
  LanguageStruct? learningLanguage,
  DateTime? dateofbirth,
  URatingStruct? rating,
  String? photoUrl,
  Level? level,
  bool? acquaintance,
  CountryStruct? countryNS,
  bool? verifNS,
  TeacherAccreditationStatus? teacherAccreditationStatus,
  DocumentReference? selectedAvatarDocRef,
  BalanceStruct? balanceST,
  double? balanceNS,
  AvailabilityTodayStruct? availabilityToday,
  int? totalCalls,
  LanguageStruct? languageInstructionNS,
  LanguageStruct? nativeLanguageNS,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'email': email,
      'uid': uid,
      'created_time': createdTime,
      'phone_number': phoneNumber,
      'display_name': displayName,
      'role': role,
      'isInCall': isInCall,
      'currentSessionId': currentSessionId,
      'gender': gender,
      'aboutMe': aboutMe,
      'isProfileComplete': isProfileComplete,
      'preferences': PreferencesStruct().toMap(),
      'queuePriority': queuePriority,
      'earnings': EarningsStruct().toMap(),
      'friends': friends,
      'favoriteNativeSpeakers': favoriteNativeSpeakers,
      'learningLanguage': LanguageStruct().toMap(),
      'dateofbirth': dateofbirth,
      'rating': URatingStruct().toMap(),
      'photo_url': photoUrl,
      'level': level,
      'Acquaintance': acquaintance,
      'Country_NS': CountryStruct().toMap(),
      'verif_NS': verifNS,
      'teacherAccreditationStatus': teacherAccreditationStatus,
      'selectedAvatarDocRef': selectedAvatarDocRef,
      'balanceST': BalanceStruct().toMap(),
      'balance_NS': balanceNS,
      'availabilityToday': AvailabilityTodayStruct().toMap(),
      'totalCalls': totalCalls,
      'language_instruction_NS': LanguageStruct().toMap(),
      'native_language_NS': LanguageStruct().toMap(),
    }.withoutNulls,
  );

  // Handle nested data for "preferences" field.
  addPreferencesStructData(firestoreData, preferences, 'preferences');

  // Handle nested data for "earnings" field.
  addEarningsStructData(firestoreData, earnings, 'earnings');

  // Handle nested data for "learningLanguage" field.
  addLanguageStructData(firestoreData, learningLanguage, 'learningLanguage');

  // Handle nested data for "rating" field.
  addURatingStructData(firestoreData, rating, 'rating');

  // Handle nested data for "Country_NS" field.
  addCountryStructData(firestoreData, countryNS, 'Country_NS');

  // Handle nested data for "balanceST" field.
  addBalanceStructData(firestoreData, balanceST, 'balanceST');

  // Handle nested data for "availabilityToday" field.
  addAvailabilityTodayStructData(
      firestoreData, availabilityToday, 'availabilityToday');

  // Handle nested data for "language_instruction_NS" field.
  addLanguageStructData(
      firestoreData, languageInstructionNS, 'language_instruction_NS');

  // Handle nested data for "native_language_NS" field.
  addLanguageStructData(firestoreData, nativeLanguageNS, 'native_language_NS');

  return firestoreData;
}

class UsersRecordDocumentEquality implements Equality<UsersRecord> {
  const UsersRecordDocumentEquality();

  @override
  bool equals(UsersRecord? e1, UsersRecord? e2) {
    const listEquality = ListEquality();
    return e1?.email == e2?.email &&
        e1?.uid == e2?.uid &&
        e1?.createdTime == e2?.createdTime &&
        e1?.phoneNumber == e2?.phoneNumber &&
        e1?.displayName == e2?.displayName &&
        e1?.role == e2?.role &&
        e1?.isInCall == e2?.isInCall &&
        e1?.currentSessionId == e2?.currentSessionId &&
        e1?.gender == e2?.gender &&
        e1?.aboutMe == e2?.aboutMe &&
        e1?.isProfileComplete == e2?.isProfileComplete &&
        e1?.preferences == e2?.preferences &&
        e1?.queuePriority == e2?.queuePriority &&
        e1?.earnings == e2?.earnings &&
        listEquality.equals(e1?.friends, e2?.friends) &&
        listEquality.equals(
            e1?.favoriteNativeSpeakers, e2?.favoriteNativeSpeakers) &&
        e1?.learningLanguage == e2?.learningLanguage &&
        e1?.dateofbirth == e2?.dateofbirth &&
        listEquality.equals(e1?.purpose, e2?.purpose) &&
        e1?.rating == e2?.rating &&
        e1?.photoUrl == e2?.photoUrl &&
        e1?.level == e2?.level &&
        e1?.acquaintance == e2?.acquaintance &&
        e1?.countryNS == e2?.countryNS &&
        e1?.verifNS == e2?.verifNS &&
        e1?.teacherAccreditationStatus == e2?.teacherAccreditationStatus &&
        e1?.selectedAvatarDocRef == e2?.selectedAvatarDocRef &&
        e1?.balanceST == e2?.balanceST &&
        e1?.balanceNS == e2?.balanceNS &&
        listEquality.equals(e1?.blockedUsers, e2?.blockedUsers) &&
        e1?.availabilityToday == e2?.availabilityToday &&
        e1?.totalCalls == e2?.totalCalls &&
        e1?.languageInstructionNS == e2?.languageInstructionNS &&
        e1?.nativeLanguageNS == e2?.nativeLanguageNS;
  }

  @override
  int hash(UsersRecord? e) => const ListEquality().hash([
        e?.email,
        e?.uid,
        e?.createdTime,
        e?.phoneNumber,
        e?.displayName,
        e?.role,
        e?.isInCall,
        e?.currentSessionId,
        e?.gender,
        e?.aboutMe,
        e?.isProfileComplete,
        e?.preferences,
        e?.queuePriority,
        e?.earnings,
        e?.friends,
        e?.favoriteNativeSpeakers,
        e?.learningLanguage,
        e?.dateofbirth,
        e?.purpose,
        e?.rating,
        e?.photoUrl,
        e?.level,
        e?.acquaintance,
        e?.countryNS,
        e?.verifNS,
        e?.teacherAccreditationStatus,
        e?.selectedAvatarDocRef,
        e?.balanceST,
        e?.balanceNS,
        e?.blockedUsers,
        e?.availabilityToday,
        e?.totalCalls,
        e?.languageInstructionNS,
        e?.nativeLanguageNS
      ]);

  @override
  bool isValidKey(Object? o) => o is UsersRecord;
}
