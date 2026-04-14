import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';

const teacherVerificationRequestsCollectionName = 'teacherVerificationRequests';

CollectionReference<Map<String, dynamic>>
    get teacherVerificationRequestsCollection => FirebaseFirestore.instance
        .collection(teacherVerificationRequestsCollectionName);

DocumentReference<Map<String, dynamic>> teacherVerificationRequestRefForUser(
  String userId,
) =>
    teacherVerificationRequestsCollection.doc(userId);

Map<String, dynamic> buildTeacherVerificationRequestData({
  required String userId,
  required DocumentReference userRef,
  required String displayName,
  required String photoUrl,
  required String aboutMe,
  required LanguageStruct? languageInstruction,
  required LanguageStruct? nativeLanguage,
  required CountryStruct? country,
  required Object timestamp,
  bool includeCreatedAt = false,
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

  if (includeCreatedAt) {
    data['createdAt'] = timestamp;
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

Future<TeacherAccreditationStatus?> submitTeacherVerificationRequest({
  required DocumentReference userRef,
  required String displayName,
  required String photoUrl,
  required String aboutMe,
  required LanguageStruct? languageInstruction,
  required LanguageStruct? nativeLanguage,
  required CountryStruct? country,
}) async {
  final userId = userRef.id.trim();
  if (userId.isEmpty) {
    throw ArgumentError.value(userRef.path, 'userRef', 'Missing user id');
  }

  final requestRef = teacherVerificationRequestRefForUser(userId);
  final existingRequest = await requestRef.get();
  final existingStatus =
      resolveTeacherVerificationRequestStatus(existingRequest.data());
  if (existingRequest.exists &&
      existingStatus != TeacherAccreditationStatus.pending) {
    return existingStatus;
  }

  final timestamp = FieldValue.serverTimestamp();

  await requestRef.set(
    buildTeacherVerificationRequestData(
      userId: userId,
      userRef: userRef,
      displayName: displayName,
      photoUrl: photoUrl,
      aboutMe: aboutMe,
      languageInstruction: languageInstruction,
      nativeLanguage: nativeLanguage,
      country: country,
      timestamp: timestamp,
      includeCreatedAt: !existingRequest.exists,
    ),
    SetOptions(merge: true),
  );
  return TeacherAccreditationStatus.pending;
}
