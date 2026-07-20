import '/backend/schema/enums/enums.dart';
import '/backend/schema/users_record.dart';

const partnerLevelRanks = <Level, int>{
  Level.Beginner: 0,
  Level.Basic: 1,
  Level.Intermediate: 2,
  Level.Fluent: 3,
};

List<Level> partnerLevelsAtOrAbove(Level minimumLevel) {
  final minimumRank = partnerLevelRanks[minimumLevel]!;
  return partnerLevelRanks.entries
      .where((entry) => entry.value >= minimumRank)
      .map((entry) => entry.key)
      .toList(growable: false);
}

enum TeacherTrackProfileAction {
  apply,
  reapply,
  none,
}

Map<String, dynamic> _storedMatchProfile(UsersRecord? user) {
  final rawMatchProfile = user?.snapshotData['matchProfile'];
  if (rawMatchProfile is Map<String, dynamic>) {
    return rawMatchProfile;
  }
  if (rawMatchProfile is Map) {
    return rawMatchProfile.map(
      (key, value) => MapEntry(key.toString(), value),
    );
  }
  return const <String, dynamic>{};
}

String? _trimmedValue(Object? value) {
  if (value == null) {
    return null;
  }
  final trimmed = value.toString().trim();
  return trimmed.isEmpty ? null : trimmed;
}

String? _normalizedLanguageCode(Object? value) {
  final trimmed = _trimmedValue(value);
  return trimmed?.toLowerCase();
}

bool _hasLegacyConversationLanguage(UsersRecord? user) {
  if (user?.role == UserRole.native_speaker) {
    return _normalizedLanguageCode(user?.languageInstructionNS.code) != null;
  }
  return _normalizedLanguageCode(user?.learningLanguage.code) != null;
}

List<String> resolveUserSupportedConversationLanguages(UsersRecord? user) {
  final codes = <String>{};

  void addCode(Object? value) {
    final normalized = _normalizedLanguageCode(value);
    if (normalized != null) {
      codes.add(normalized);
    }
  }

  if (user?.role == UserRole.native_speaker) {
    addCode(user?.languageInstructionNS.code);
  } else {
    addCode(user?.learningLanguage.code);
  }

  final matchProfile = _storedMatchProfile(user);
  final supportedLanguages = matchProfile['supportedLanguages'];
  if (supportedLanguages is Iterable) {
    for (final code in supportedLanguages) {
      addCode(code);
    }
  }
  addCode(matchProfile['activeLanguage']);

  return codes.toList(growable: false);
}

String? resolveUserActiveConversationLanguage(UsersRecord? user) {
  final matchProfile = _storedMatchProfile(user);
  final supportedLanguages = resolveUserSupportedConversationLanguages(user);

  if (_hasLegacyConversationLanguage(user) && supportedLanguages.isNotEmpty) {
    return supportedLanguages.first;
  }

  final storedActiveLanguage =
      _normalizedLanguageCode(matchProfile['activeLanguage']);
  if (storedActiveLanguage != null) {
    return storedActiveLanguage;
  }

  return supportedLanguages.isNotEmpty ? supportedLanguages.first : null;
}

String? resolveUserMatchCountryCode(UsersRecord? user) {
  final legacyCountry = _trimmedValue(user?.countryNS.code);
  if (legacyCountry != null) {
    return legacyCountry;
  }

  return _trimmedValue(_storedMatchProfile(user)['country']);
}

Level? resolveUserMatchLevel(UsersRecord? user) {
  if (user?.level != null) {
    return user!.level;
  }

  return deserializeEnum<Level>(_storedMatchProfile(user)['level']);
}

TeacherAccreditationStatus resolveUserTeacherAccreditationStatus(
  UsersRecord? user,
) {
  if (user == null) {
    return TeacherAccreditationStatus.pending;
  }

  return resolveTeacherAccreditationStatusFromData(user.snapshotData);
}

bool isUserApprovedTeacher(UsersRecord? user) =>
    resolveUserTeacherAccreditationStatus(user) ==
    TeacherAccreditationStatus.approved;

bool hasPendingTeacherVerification(UsersRecord? user) =>
    user != null && hasPendingTeacherVerificationFromData(user.snapshotData);

bool canRestoreNativeSpeakerTrack(
  UsersRecord? user, {
  TeacherAccreditationStatus? requestStatus,
}) {
  if (user == null) {
    return false;
  }

  if (isUserApprovedTeacher(user) || hasPendingTeacherVerification(user)) {
    return true;
  }

  return requestStatus == TeacherAccreditationStatus.pending;
}

bool shouldMirrorPendingTeacherStatusOnRestore(
  UsersRecord? user, {
  TeacherAccreditationStatus? requestStatus,
}) {
  if (user == null) {
    return false;
  }

  if (hasPendingTeacherVerification(user)) {
    return true;
  }

  return requestStatus == TeacherAccreditationStatus.pending;
}

bool canUseNativeSpeakerShell(UsersRecord? user) =>
    user?.role == UserRole.native_speaker &&
    (isUserApprovedTeacher(user) || hasPendingTeacherVerification(user));

// Profile balance is a teacher-track state. Money-moving screens stay
// approved-only through canAccessTeacherSurfaces.
bool shouldShowTeacherProfileBalance(UsersRecord? user) =>
    canUseNativeSpeakerShell(user);

bool canAccessTeacherSurfaces(UsersRecord? user) =>
    user?.role == UserRole.native_speaker && isUserApprovedTeacher(user);

TeacherTrackProfileAction resolveTeacherTrackProfileAction(UsersRecord? user) {
  if (user?.role == UserRole.student) {
    return TeacherTrackProfileAction.apply;
  }

  if (user?.role == UserRole.native_speaker &&
      resolveExplicitTeacherAccreditationStatusFromData(user!.snapshotData) ==
          TeacherAccreditationStatus.rejected) {
    return TeacherTrackProfileAction.reapply;
  }

  return TeacherTrackProfileAction.none;
}

double resolveUserMatchRatingAverage(UsersRecord? user) {
  if (user?.snapshotData.containsKey('rating') ?? false) {
    return user?.rating.average ?? 0.0;
  }

  final rawAverage = _storedMatchProfile(user)['ratingAverage'];
  if (rawAverage is num) {
    return rawAverage.toDouble();
  }

  return 0.0;
}

int resolveUserMatchRatingCount(UsersRecord? user) {
  if (user?.snapshotData.containsKey('rating') ?? false) {
    return user?.rating.totalReviews ?? 0;
  }

  final rawCount = _storedMatchProfile(user)['ratingCount'];
  if (rawCount is num) {
    return rawCount.toInt();
  }

  return 0;
}
