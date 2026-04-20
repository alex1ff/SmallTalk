import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import 'package:collection/collection.dart';

const teacherVerificationRequestsCollectionName = 'teacherVerificationRequests';

CollectionReference<Map<String, dynamic>>
    get teacherVerificationRequestsCollection => FirebaseFirestore.instance
        .collection(teacherVerificationRequestsCollectionName);

DocumentReference<Map<String, dynamic>> teacherVerificationRequestRefForUser(
  String userId,
) =>
    teacherVerificationRequestsCollection.doc(userId);

class TeacherVerificationRequestWriteDecision {
  const TeacherVerificationRequestWriteDecision({
    required this.status,
    required this.shouldWrite,
    this.requestData,
  });

  final TeacherAccreditationStatus? status;
  final bool shouldWrite;
  final Map<String, dynamic>? requestData;
}

const DeepCollectionEquality _teacherVerificationRequestEquality =
    DeepCollectionEquality();

Map<String, dynamic> buildTeacherVerificationRequestData({
  required String userId,
  required DocumentReference userRef,
  required String displayName,
  required String photoUrl,
  required String aboutMe,
  required LanguageStruct? languageInstruction,
  required LanguageStruct? nativeLanguage,
  required CountryStruct? country,
  required Map<String, dynamic>? accreditation,
  required Object timestamp,
  bool includeCreatedAt = false,
  Object? createdAtOverride,
}) {
  final data = <String, dynamic>{
    'userId': userId,
    'userRef': userRef,
    'status': TeacherAccreditationStatus.pending.name,
    'displayName': displayName.trim(),
    'photoUrl': photoUrl.trim(),
    'aboutMe': aboutMe.trim(),
    'languageInstruction': languageInstruction?.toMap(),
    'nativeLanguage': nativeLanguage?.toMap(),
    'country': country?.toMap(),
    'updatedAt': timestamp,
  };
  if (accreditation != null && accreditation.isNotEmpty) {
    data['accreditation'] = accreditation;
  }

  final createdAt = createdAtOverride ?? (includeCreatedAt ? timestamp : null);
  if (createdAt != null) {
    data['createdAt'] = createdAt;
  }

  data.removeWhere((_, value) {
    if (value == null) {
      return true;
    }
    if (value is String) {
      return value.trim().isEmpty;
    }
    if (value is Map) {
      return value.isEmpty;
    }
    return false;
  });

  return data;
}

TeacherAccreditationStatus? resolveTeacherVerificationRequestStatus(
  Map<String, dynamic>? data,
) {
  if (data == null) {
    return null;
  }

  return deserializeEnum<TeacherAccreditationStatus>(data['status']) ??
      deserializeEnum<TeacherAccreditationStatus>(
        data['teacherAccreditationStatus'],
      ) ??
      deserializeEnum<TeacherAccreditationStatus>(
        data['teacherVerificationStatus'],
      ) ??
      deserializeEnum<TeacherAccreditationStatus>(data['verificationStatus']);
}

bool shouldReuseExistingTeacherVerificationStatus(
  TeacherAccreditationStatus? existingStatus,
) {
  return existingStatus == TeacherAccreditationStatus.approved;
}

bool isTeacherVerificationRequestSubmissionError(Object error) {
  return error is FirebaseException &&
      const <String>{
        'permission-denied',
        'deadline-exceeded',
        'unavailable',
        'aborted',
      }.contains(error.code);
}

bool isTeacherVerificationRequestAmbiguousWriteError(Object error) {
  return error is FirebaseException &&
      const <String>{
        'deadline-exceeded',
        'unavailable',
        'aborted',
      }.contains(error.code);
}

Object? _normalizeTeacherVerificationComparableValue(Object? value) {
  if (value is DocumentReference) {
    return value.path;
  }
  if (value is Map) {
    return value.map(
      (key, nestedValue) => MapEntry(
        key.toString(),
        _normalizeTeacherVerificationComparableValue(nestedValue),
      ),
    );
  }
  if (value is Iterable) {
    return value
        .map(_normalizeTeacherVerificationComparableValue)
        .toList(growable: false);
  }
  if (value is String) {
    return value.trim();
  }
  return value;
}

Map<String, dynamic> buildComparableTeacherVerificationRequestData(
  Map<String, dynamic>? data,
) {
  if (data == null) {
    return const <String, dynamic>{};
  }

  return <String, dynamic>{
    'userId': _normalizeTeacherVerificationComparableValue(data['userId']),
    'userRef': _normalizeTeacherVerificationComparableValue(data['userRef']),
    'status': _normalizeTeacherVerificationComparableValue(data['status']),
    'displayName':
        _normalizeTeacherVerificationComparableValue(data['displayName']),
    'photoUrl': _normalizeTeacherVerificationComparableValue(data['photoUrl']),
    'aboutMe': _normalizeTeacherVerificationComparableValue(data['aboutMe']),
    'languageInstruction': _normalizeTeacherVerificationComparableValue(
      data['languageInstruction'],
    ),
    'nativeLanguage': _normalizeTeacherVerificationComparableValue(
      data['nativeLanguage'],
    ),
    'country': _normalizeTeacherVerificationComparableValue(data['country']),
    'accreditation': _normalizeTeacherVerificationComparableValue(
      data['accreditation'],
    ),
  }..removeWhere((_, value) => value == null);
}

bool teacherVerificationRequestMatchesExpected({
  required Map<String, dynamic>? actualData,
  required Map<String, dynamic> expectedData,
}) {
  return _teacherVerificationRequestEquality.equals(
    buildComparableTeacherVerificationRequestData(actualData),
    buildComparableTeacherVerificationRequestData(expectedData),
  );
}

TeacherAccreditationStatus? recoverTeacherVerificationRequestWriteStatus({
  required Map<String, dynamic>? actualData,
  required Map<String, dynamic> expectedData,
  required TeacherAccreditationStatus? expectedStatus,
}) {
  final recoveredStatus = resolveTeacherVerificationRequestStatus(actualData);
  if (recoveredStatus == TeacherAccreditationStatus.approved) {
    return recoveredStatus;
  }
  if (recoveredStatus == expectedStatus &&
      teacherVerificationRequestMatchesExpected(
        actualData: actualData,
        expectedData: expectedData,
      )) {
    return recoveredStatus;
  }
  return null;
}

TeacherVerificationRequestWriteDecision prepareTeacherVerificationRequestWrite({
  required String userId,
  required DocumentReference userRef,
  required Map<String, dynamic>? existingData,
  required String displayName,
  required String photoUrl,
  required String aboutMe,
  required LanguageStruct? languageInstruction,
  required LanguageStruct? nativeLanguage,
  required CountryStruct? country,
  required Map<String, dynamic>? accreditation,
  required Object timestamp,
}) {
  final existingStatus = resolveTeacherVerificationRequestStatus(existingData);
  if (shouldReuseExistingTeacherVerificationStatus(existingStatus)) {
    return TeacherVerificationRequestWriteDecision(
      status: existingStatus,
      shouldWrite: false,
    );
  }

  return TeacherVerificationRequestWriteDecision(
    status: TeacherAccreditationStatus.pending,
    shouldWrite: true,
    requestData: buildTeacherVerificationRequestData(
      userId: userId,
      userRef: userRef,
      displayName: displayName,
      photoUrl: photoUrl,
      aboutMe: aboutMe,
      languageInstruction: languageInstruction,
      nativeLanguage: nativeLanguage,
      country: country,
      accreditation: accreditation,
      timestamp: timestamp,
      includeCreatedAt: existingData == null,
      createdAtOverride: existingData?['createdAt'],
    ),
  );
}

Future<TeacherAccreditationStatus?> submitTeacherVerificationRequest({
  required DocumentReference userRef,
  required String displayName,
  required String photoUrl,
  required String aboutMe,
  required LanguageStruct? languageInstruction,
  required LanguageStruct? nativeLanguage,
  required CountryStruct? country,
  required Map<String, dynamic>? accreditation,
}) async {
  final userId = userRef.id.trim();
  if (userId.isEmpty) {
    throw ArgumentError.value(userRef.path, 'userRef', 'Missing user id');
  }

  final requestRef = teacherVerificationRequestRefForUser(userId);
  final existingRequest = await requestRef.get();
  final existingData = existingRequest.data();
  final decision = prepareTeacherVerificationRequestWrite(
    userId: userId,
    userRef: userRef,
    existingData: existingData,
    displayName: displayName,
    photoUrl: photoUrl,
    aboutMe: aboutMe,
    languageInstruction: languageInstruction,
    nativeLanguage: nativeLanguage,
    country: country,
    accreditation: accreditation,
    timestamp: FieldValue.serverTimestamp(),
  );
  if (!decision.shouldWrite) {
    return decision.status;
  }

  try {
    // Overwrite the document on resubmission so old review metadata and
    // removed accreditation fields do not leak into the new pending request.
    await requestRef.set(decision.requestData!);
    return decision.status;
  } catch (error, stackTrace) {
    if (!isTeacherVerificationRequestSubmissionError(error)) {
      rethrow;
    }

    try {
      final recoveredSnapshot = await requestRef.get();
      final recoveredData = recoveredSnapshot.data();
      final recoveredStatus = recoverTeacherVerificationRequestWriteStatus(
        actualData: recoveredData,
        expectedData: decision.requestData!,
        expectedStatus: decision.status,
      );
      if (recoveredStatus != null) {
        return recoveredStatus;
      }
    } catch (_) {
      Error.throwWithStackTrace(error, stackTrace);
    }
    rethrow;
  }
}
