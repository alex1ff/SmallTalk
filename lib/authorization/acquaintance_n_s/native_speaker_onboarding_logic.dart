import '/backend/schema/enums/enums.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/users_record.dart';
import '/authorization/shared/onboarding_selection_utils.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/uploaded_file.dart';

const Object _nativeSpeakerNoChange = Object();
const List<String> kNativeSpeakerQualificationProofOrder = <String>[
  'degree',
  'certificate',
  'other_document',
  'experience_only',
  'none',
];
const Set<String> _nativeSpeakerExclusiveQualificationProofs = <String>{
  'experience_only',
  'none',
};
const Set<String> _nativeSpeakerQualificationProofsRequiringFiles = <String>{
  'degree',
  'certificate',
  'other_document',
};

enum NativeSpeakerOnboardingEntrySource {
  auth,
  profile,
}

enum NativeSpeakerOnboardingPage {
  name,
  languageInstruction,
  nativeLanguage,
  gender,
  country,
  aboutMe,
  accreditation,
  photo,
}

class NativeSpeakerEvidenceFile {
  const NativeSpeakerEvidenceFile({
    required this.name,
    required this.storagePath,
  });

  final String name;
  final String storagePath;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'name': name.trim(),
        'storagePath': storagePath.trim(),
      };

  NativeSpeakerEvidenceFile copyWith({
    String? name,
    String? storagePath,
  }) {
    return NativeSpeakerEvidenceFile(
      name: (name ?? this.name).trim(),
      storagePath: (storagePath ?? this.storagePath).trim(),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NativeSpeakerEvidenceFile &&
        other.name == name &&
        other.storagePath == storagePath;
  }

  @override
  int get hashCode => Object.hash(name, storagePath);
}

class NativeSpeakerHydratedAccreditationState {
  const NativeSpeakerHydratedAccreditationState({
    required this.teachingExperience,
    required this.qualificationProofs,
    required this.evidenceFiles,
  });

  final String? teachingExperience;
  final List<String> qualificationProofs;
  final List<NativeSpeakerEvidenceFile> evidenceFiles;
}

class NativeSpeakerOnboardingDraft {
  NativeSpeakerOnboardingDraft({
    required this.displayName,
    required this.languageInstruction,
    required this.nativeLanguage,
    Gender? gender,
    bool? genderMale,
    required this.country,
    required this.aboutMe,
    required this.teachingExperience,
    List<String>? qualificationProofs,
    String? qualificationProof,
    required this.localQualificationFiles,
    required this.existingQualificationFiles,
    required this.localPhoto,
    required this.existingPhotoUrl,
  })  : _gender = gender ??
            (genderMale == null
                ? null
                : (genderMale ? Gender.male : Gender.female)),
        _qualificationProofs = normalizeNativeSpeakerQualificationProofs(
          qualificationProofs,
          fallbackQualificationProof: qualificationProof,
        );

  final String displayName;
  final LanguageStruct? languageInstruction;
  final LanguageStruct? nativeLanguage;
  final Gender? _gender;
  final CountryStruct? country;
  final String aboutMe;
  final String? teachingExperience;
  final List<String> _qualificationProofs;
  final List<FFUploadedFile> localQualificationFiles;
  final List<NativeSpeakerEvidenceFile> existingQualificationFiles;
  final FFUploadedFile? localPhoto;
  final String existingPhotoUrl;

  Gender? get gender => _gender;
  bool get genderMale => _gender != Gender.female;
  List<String> get qualificationProofs =>
      List<String>.unmodifiable(_qualificationProofs);
  String? get qualificationProof =>
      _qualificationProofs.isEmpty ? null : _qualificationProofs.first;

  NativeSpeakerOnboardingDraft copyWith({
    Object? displayName = _nativeSpeakerNoChange,
    Object? languageInstruction = _nativeSpeakerNoChange,
    Object? nativeLanguage = _nativeSpeakerNoChange,
    Object? gender = _nativeSpeakerNoChange,
    Object? country = _nativeSpeakerNoChange,
    Object? aboutMe = _nativeSpeakerNoChange,
    Object? teachingExperience = _nativeSpeakerNoChange,
    Object? qualificationProofs = _nativeSpeakerNoChange,
    Object? qualificationProof = _nativeSpeakerNoChange,
    Object? localQualificationFiles = _nativeSpeakerNoChange,
    Object? existingQualificationFiles = _nativeSpeakerNoChange,
    Object? localPhoto = _nativeSpeakerNoChange,
    Object? existingPhotoUrl = _nativeSpeakerNoChange,
  }) {
    final nextQualificationProofs =
        qualificationProofs != _nativeSpeakerNoChange
            ? normalizeNativeSpeakerQualificationProofs(
                qualificationProofs as List<String>?,
              )
            : qualificationProof != _nativeSpeakerNoChange
                ? normalizeNativeSpeakerQualificationProofs(
                    null,
                    fallbackQualificationProof: qualificationProof as String?,
                  )
                : this.qualificationProofs;
    return NativeSpeakerOnboardingDraft(
      displayName: displayName == _nativeSpeakerNoChange
          ? this.displayName
          : ((displayName as String?) ?? '').trim(),
      languageInstruction: languageInstruction == _nativeSpeakerNoChange
          ? cloneNativeSpeakerLanguageSelection(this.languageInstruction)
          : cloneNativeSpeakerLanguageSelection(
              languageInstruction as LanguageStruct?,
            ),
      nativeLanguage: nativeLanguage == _nativeSpeakerNoChange
          ? cloneNativeSpeakerLanguageSelection(this.nativeLanguage)
          : cloneNativeSpeakerLanguageSelection(
              nativeLanguage as LanguageStruct?),
      gender:
          gender == _nativeSpeakerNoChange ? this.gender : gender as Gender?,
      country: country == _nativeSpeakerNoChange
          ? cloneNativeSpeakerCountrySelection(this.country)
          : cloneNativeSpeakerCountrySelection(country as CountryStruct?),
      aboutMe: aboutMe == _nativeSpeakerNoChange
          ? this.aboutMe
          : ((aboutMe as String?) ?? '').trim(),
      teachingExperience: teachingExperience == _nativeSpeakerNoChange
          ? this.teachingExperience
          : (teachingExperience as String?)?.trim(),
      qualificationProofs: nextQualificationProofs,
      localQualificationFiles: localQualificationFiles == _nativeSpeakerNoChange
          ? cloneNativeSpeakerUploadedFiles(this.localQualificationFiles)
          : cloneNativeSpeakerUploadedFiles(
              localQualificationFiles as List<FFUploadedFile>?,
            ),
      existingQualificationFiles: existingQualificationFiles ==
              _nativeSpeakerNoChange
          ? cloneNativeSpeakerEvidenceFiles(this.existingQualificationFiles)
          : cloneNativeSpeakerEvidenceFiles(
              existingQualificationFiles as List<NativeSpeakerEvidenceFile>?,
            ),
      localPhoto: localPhoto == _nativeSpeakerNoChange
          ? this.localPhoto
          : localPhoto as FFUploadedFile?,
      existingPhotoUrl: existingPhotoUrl == _nativeSpeakerNoChange
          ? this.existingPhotoUrl
          : ((existingPhotoUrl as String?) ?? '').trim(),
    );
  }
}

class NativeSpeakerOnboardingValidation {
  const NativeSpeakerOnboardingValidation({
    required this.missingPages,
  });

  final List<NativeSpeakerOnboardingPage> missingPages;

  bool get isComplete => missingPages.isEmpty;
}

class NativeSpeakerOnboardingPayload {
  const NativeSpeakerOnboardingPayload({
    required this.displayName,
    required this.gender,
    required this.languageInstruction,
    required this.nativeLanguage,
    required this.country,
    required this.aboutMe,
    required this.photoUrl,
    required this.accreditation,
  });

  final String? displayName;
  final Gender gender;
  final LanguageStruct? languageInstruction;
  final LanguageStruct? nativeLanguage;
  final CountryStruct? country;
  final String aboutMe;
  final String photoUrl;
  final Map<String, dynamic>? accreditation;
}

class NativeSpeakerOnboardingInitialState {
  const NativeSpeakerOnboardingInitialState({
    required this.draft,
  });

  final NativeSpeakerOnboardingDraft draft;

  String get displayName => draft.displayName;
  bool get genderMale => draft.gender != Gender.female;
  LanguageStruct? get languageInstruction => draft.languageInstruction;
  LanguageStruct? get nativeLanguage => draft.nativeLanguage;
  CountryStruct? get country => draft.country;
  String get aboutMe => draft.aboutMe;
  String get existingPhotoUrl => draft.existingPhotoUrl;
}

NativeSpeakerOnboardingEntrySource resolveNativeSpeakerEntrySource(
  String? rawEntrySource,
) {
  switch ((rawEntrySource ?? '').trim().toLowerCase()) {
    case 'profile':
      return NativeSpeakerOnboardingEntrySource.profile;
    case 'auth':
    default:
      return NativeSpeakerOnboardingEntrySource.auth;
  }
}

NativeSpeakerOnboardingDraft buildNativeSpeakerOnboardingDraft({
  required String? displayName,
  required LanguageStruct? languageInstruction,
  required LanguageStruct? nativeLanguage,
  required Gender? gender,
  required CountryStruct? country,
  required String? aboutMe,
  required String? teachingExperience,
  List<String>? qualificationProofs,
  required String? qualificationProof,
  List<FFUploadedFile>? localQualificationFiles,
  List<NativeSpeakerEvidenceFile>? existingQualificationFiles,
  required FFUploadedFile? localPhoto,
  required String? existingPhotoUrl,
}) {
  return NativeSpeakerOnboardingDraft(
    displayName: (displayName ?? '').trim(),
    languageInstruction:
        cloneNativeSpeakerLanguageSelection(languageInstruction),
    nativeLanguage: cloneNativeSpeakerLanguageSelection(nativeLanguage),
    gender: gender,
    country: cloneNativeSpeakerCountrySelection(country),
    aboutMe: (aboutMe ?? '').trim(),
    teachingExperience: teachingExperience?.trim(),
    qualificationProofs: qualificationProofs,
    qualificationProof: qualificationProof?.trim(),
    localQualificationFiles:
        cloneNativeSpeakerUploadedFiles(localQualificationFiles),
    existingQualificationFiles:
        cloneNativeSpeakerEvidenceFiles(existingQualificationFiles),
    localPhoto: localPhoto,
    existingPhotoUrl: (existingPhotoUrl ?? '').trim(),
  );
}

NativeSpeakerOnboardingInitialState buildNativeSpeakerOnboardingInitialState({
  required String? displayName,
  required LanguageStruct? languageInstruction,
  required LanguageStruct? nativeLanguage,
  required Gender? gender,
  required CountryStruct? country,
  required String? aboutMe,
  required String? existingPhotoUrl,
}) {
  return NativeSpeakerOnboardingInitialState(
    draft: buildNativeSpeakerOnboardingDraft(
      displayName: displayName,
      languageInstruction: languageInstruction,
      nativeLanguage: nativeLanguage,
      gender: gender,
      country: country,
      aboutMe: aboutMe,
      teachingExperience: null,
      qualificationProof: null,
      localQualificationFiles: const <FFUploadedFile>[],
      existingQualificationFiles: const <NativeSpeakerEvidenceFile>[],
      localPhoto: null,
      existingPhotoUrl: existingPhotoUrl,
    ),
  );
}

NativeSpeakerOnboardingDraft updateNativeSpeakerOnboardingDraft(
  NativeSpeakerOnboardingDraft draft, {
  Object? displayName = _nativeSpeakerNoChange,
  Object? languageInstruction = _nativeSpeakerNoChange,
  Object? nativeLanguage = _nativeSpeakerNoChange,
  Object? gender = _nativeSpeakerNoChange,
  Object? country = _nativeSpeakerNoChange,
  Object? aboutMe = _nativeSpeakerNoChange,
  Object? teachingExperience = _nativeSpeakerNoChange,
  Object? qualificationProofs = _nativeSpeakerNoChange,
  Object? qualificationProof = _nativeSpeakerNoChange,
  Object? localQualificationFiles = _nativeSpeakerNoChange,
  Object? existingQualificationFiles = _nativeSpeakerNoChange,
  Object? localPhoto = _nativeSpeakerNoChange,
  Object? existingPhotoUrl = _nativeSpeakerNoChange,
}) {
  return draft.copyWith(
    displayName: displayName,
    languageInstruction: languageInstruction,
    nativeLanguage: nativeLanguage,
    gender: gender,
    country: country,
    aboutMe: aboutMe,
    teachingExperience: teachingExperience,
    qualificationProofs: qualificationProofs,
    qualificationProof: qualificationProof,
    localQualificationFiles: localQualificationFiles,
    existingQualificationFiles: existingQualificationFiles,
    localPhoto: localPhoto,
    existingPhotoUrl: existingPhotoUrl,
  );
}

NativeSpeakerOnboardingValidation validateNativeSpeakerOnboardingDraft(
  NativeSpeakerOnboardingDraft draft,
) {
  return NativeSpeakerOnboardingValidation(
    missingPages: <NativeSpeakerOnboardingPage>[
      if (draft.displayName.trim().isEmpty ||
          !functions.isValidName(draft.displayName.trim()))
        NativeSpeakerOnboardingPage.name,
      if (!hasNativeSpeakerLanguageSelection(draft.languageInstruction))
        NativeSpeakerOnboardingPage.languageInstruction,
      if (!hasNativeSpeakerLanguageSelection(draft.nativeLanguage))
        NativeSpeakerOnboardingPage.nativeLanguage,
      if (!hasNativeSpeakerCountrySelection(draft.country))
        NativeSpeakerOnboardingPage.country,
      if (draft.aboutMe.trim().isEmpty) NativeSpeakerOnboardingPage.aboutMe,
      if (!hasNativeSpeakerAccreditationAnswers(draft))
        NativeSpeakerOnboardingPage.accreditation,
      if (!hasNativeSpeakerCompletionPhoto(
        localPhoto: draft.localPhoto,
        existingPhotoUrl: draft.existingPhotoUrl,
      ))
        NativeSpeakerOnboardingPage.photo,
    ],
  );
}

Map<String, dynamic>? buildNativeSpeakerAccreditationData(
  NativeSpeakerOnboardingDraft draft,
) {
  final accreditation = <String, dynamic>{
    'teachingExperience': draft.teachingExperience?.trim(),
    'qualificationProof':
        draft.qualificationProofs.isEmpty ? null : draft.qualificationProof,
    'qualificationProofs':
        draft.qualificationProofs.isEmpty ? null : draft.qualificationProofs,
    'qualificationProofFiles':
        shouldRequireNativeSpeakerQualificationFiles(draft.qualificationProofs)
            ? draft.existingQualificationFiles
                .map((file) => file.toMap())
                .toList(growable: false)
            : null,
  }..removeWhere((_, value) {
      if (value == null) {
        return true;
      }
      if (value is String) {
        return value.trim().isEmpty;
      }
      if (value is Iterable) {
        return value.isEmpty;
      }
      return false;
    });

  return accreditation.isEmpty ? null : accreditation;
}

NativeSpeakerOnboardingPayload buildNativeSpeakerOnboardingPayload({
  required NativeSpeakerOnboardingDraft draft,
  required String photoUrl,
}) {
  final normalizedDisplayName = draft.displayName.trim();
  return NativeSpeakerOnboardingPayload(
    displayName: normalizedDisplayName.isEmpty ? null : normalizedDisplayName,
    gender: draft.gender ?? Gender.male,
    languageInstruction:
        cloneNativeSpeakerLanguageSelection(draft.languageInstruction),
    nativeLanguage: cloneNativeSpeakerLanguageSelection(draft.nativeLanguage),
    country: cloneNativeSpeakerCountrySelection(draft.country),
    aboutMe: draft.aboutMe.trim(),
    photoUrl: photoUrl.trim(),
    accreditation: buildNativeSpeakerAccreditationData(draft),
  );
}

Map<String, dynamic> buildNativeSpeakerOnboardingUpdateData({
  required NativeSpeakerOnboardingPayload payload,
  required bool markProfileComplete,
  bool switchToNativeSpeakerRole = false,
  TeacherAccreditationStatus? teacherAccreditationStatus,
}) {
  final shouldMirrorPendingTeacherStatus =
      teacherAccreditationStatus == TeacherAccreditationStatus.pending;

  return createUsersRecordData(
    displayName: payload.displayName,
    isProfileComplete: markProfileComplete ? true : null,
    role: switchToNativeSpeakerRole || shouldMirrorPendingTeacherStatus
        ? UserRole.native_speaker
        : null,
    teacherAccreditationStatus: shouldMirrorPendingTeacherStatus
        ? TeacherAccreditationStatus.pending
        : null,
    verifNS: shouldMirrorPendingTeacherStatus ? false : null,
    gender: payload.gender,
    aboutMe: payload.aboutMe,
    photoUrl: payload.photoUrl,
    acquaintance: true,
    languageInstructionNS: payload.languageInstruction != null
        ? updateLanguageStruct(
            payload.languageInstruction,
            clearUnsetFields: false,
          )
        : null,
    countryNS: payload.country != null
        ? updateCountryStruct(
            payload.country,
            clearUnsetFields: false,
          )
        : null,
    nativeLanguageNS: payload.nativeLanguage != null
        ? updateLanguageStruct(
            payload.nativeLanguage,
            clearUnsetFields: false,
          )
        : null,
  );
}

String? validateNativeSpeakerOnboardingPage({
  required NativeSpeakerOnboardingPage page,
  required NativeSpeakerOnboardingDraft draft,
}) {
  switch (page) {
    case NativeSpeakerOnboardingPage.name:
      if (draft.displayName.trim().isEmpty) {
        return 'Пожалуйста, представьтесь';
      }
      return functions.isValidName(draft.displayName.trim())
          ? null
          : 'Неверное имя';
    case NativeSpeakerOnboardingPage.languageInstruction:
    case NativeSpeakerOnboardingPage.nativeLanguage:
      return hasNativeSpeakerLanguageSelection(
        page == NativeSpeakerOnboardingPage.languageInstruction
            ? draft.languageInstruction
            : draft.nativeLanguage,
      )
          ? null
          : 'Выберите язык из списка';
    case NativeSpeakerOnboardingPage.country:
      return hasNativeSpeakerCountrySelection(draft.country)
          ? null
          : 'Выберите страну из списка';
    case NativeSpeakerOnboardingPage.aboutMe:
      return draft.aboutMe.trim().isNotEmpty
          ? null
          : 'Напишите хотя бы пару слов';
    case NativeSpeakerOnboardingPage.accreditation:
      if (draft.teachingExperience?.trim().isNotEmpty != true) {
        return 'Выберите опыт преподавания';
      }
      if (draft.qualificationProofs.isEmpty) {
        return 'Выберите подтверждение квалификации';
      }
      if (shouldRequireNativeSpeakerQualificationFiles(
            draft.qualificationProofs,
          ) &&
          !hasNativeSpeakerQualificationEvidenceFiles(draft)) {
        return 'Добавьте файлы подтверждения';
      }
      return null;
    case NativeSpeakerOnboardingPage.photo:
      return hasNativeSpeakerCompletionPhoto(
        localPhoto: draft.localPhoto,
        existingPhotoUrl: draft.existingPhotoUrl,
      )
          ? null
          : 'Загрузите фото профиля';
    case NativeSpeakerOnboardingPage.gender:
      return null;
  }
}

bool hasNativeSpeakerLanguageSelection(LanguageStruct? language) {
  return hasOnboardingLanguageSelection(language);
}

bool hasNativeSpeakerCountrySelection(CountryStruct? country) {
  return hasOnboardingCountrySelection(country);
}

bool hasNativeSpeakerAccreditationAnswers(NativeSpeakerOnboardingDraft draft) {
  return (draft.teachingExperience?.trim().isNotEmpty ?? false) &&
      draft.qualificationProofs.isNotEmpty &&
      (!shouldRequireNativeSpeakerQualificationFiles(
            draft.qualificationProofs,
          ) ||
          hasNativeSpeakerQualificationEvidenceFiles(draft));
}

bool shouldRequireNativeSpeakerQualificationFiles(List<String> proofs) {
  return proofs.any(_nativeSpeakerQualificationProofsRequiringFiles.contains);
}

bool hasNativeSpeakerQualificationEvidenceFiles(
  NativeSpeakerOnboardingDraft draft,
) {
  return draft.localQualificationFiles.isNotEmpty ||
      draft.existingQualificationFiles.isNotEmpty;
}

List<String> normalizeNativeSpeakerQualificationProofs(
  List<String>? proofs, {
  String? fallbackQualificationProof,
}) {
  final orderedProofs = <String>[];
  final rawValues = <String>[
    ...?proofs,
    if ((fallbackQualificationProof ?? '').trim().isNotEmpty)
      fallbackQualificationProof!,
  ];

  for (final proof in rawValues) {
    final normalizedProof = proof.trim();
    if (!kNativeSpeakerQualificationProofOrder.contains(normalizedProof) ||
        orderedProofs.contains(normalizedProof)) {
      continue;
    }
    orderedProofs.add(normalizedProof);
  }

  final exclusiveProof = orderedProofs.firstWhere(
    _nativeSpeakerExclusiveQualificationProofs.contains,
    orElse: () => '',
  );
  if (exclusiveProof.isNotEmpty) {
    return <String>[exclusiveProof];
  }

  orderedProofs.sort(
    (left, right) => kNativeSpeakerQualificationProofOrder
        .indexOf(left)
        .compareTo(kNativeSpeakerQualificationProofOrder.indexOf(right)),
  );
  return orderedProofs;
}

List<String> toggleNativeSpeakerQualificationProof(
  List<String> currentProofs,
  String proof,
) {
  final normalizedProof = proof.trim();
  if (!kNativeSpeakerQualificationProofOrder.contains(normalizedProof)) {
    return normalizeNativeSpeakerQualificationProofs(currentProofs);
  }

  final nextProofs = currentProofs.toList(growable: true);
  final alreadySelected = nextProofs.contains(normalizedProof);
  if (alreadySelected) {
    nextProofs.remove(normalizedProof);
    return normalizeNativeSpeakerQualificationProofs(nextProofs);
  }

  if (_nativeSpeakerExclusiveQualificationProofs.contains(normalizedProof)) {
    return <String>[normalizedProof];
  }

  nextProofs.removeWhere(_nativeSpeakerExclusiveQualificationProofs.contains);
  nextProofs.add(normalizedProof);
  return normalizeNativeSpeakerQualificationProofs(nextProofs);
}

List<FFUploadedFile> cloneNativeSpeakerUploadedFiles(
  List<FFUploadedFile>? files,
) {
  if (files == null || files.isEmpty) {
    return const <FFUploadedFile>[];
  }

  return files
      .map(
        (file) => FFUploadedFile(
          name: file.name,
          bytes: file.bytes,
          height: file.height,
          width: file.width,
          blurHash: file.blurHash,
          originalFilename: file.originalFilename,
        ),
      )
      .toList(growable: false);
}

List<NativeSpeakerEvidenceFile> cloneNativeSpeakerEvidenceFiles(
  List<NativeSpeakerEvidenceFile>? files,
) {
  if (files == null || files.isEmpty) {
    return const <NativeSpeakerEvidenceFile>[];
  }

  return files
      .map((file) => file.copyWith())
      .where((file) => file.storagePath.isNotEmpty)
      .toList(growable: false);
}

List<NativeSpeakerEvidenceFile> mergeNativeSpeakerEvidenceFiles(
  List<NativeSpeakerEvidenceFile>? primaryFiles,
  List<NativeSpeakerEvidenceFile>? secondaryFiles,
) {
  final mergedFiles = <NativeSpeakerEvidenceFile>[
    ...cloneNativeSpeakerEvidenceFiles(primaryFiles),
  ];

  for (final file in cloneNativeSpeakerEvidenceFiles(secondaryFiles)) {
    final alreadyIncluded = mergedFiles.any(
      (existingFile) => existingFile.storagePath == file.storagePath,
    );
    if (!alreadyIncluded) {
      mergedFiles.add(file);
    }
  }

  return mergedFiles;
}

NativeSpeakerHydratedAccreditationState parseNativeSpeakerAccreditationState(
  Object? rawAccreditation,
) {
  if (rawAccreditation is! Map) {
    return const NativeSpeakerHydratedAccreditationState(
      teachingExperience: null,
      qualificationProofs: <String>[],
      evidenceFiles: <NativeSpeakerEvidenceFile>[],
    );
  }

  final accreditation = rawAccreditation.map(
    (key, value) => MapEntry(key.toString(), value),
  );
  final teachingExperience =
      accreditation['teachingExperience']?.toString().trim();
  final qualificationProofs = normalizeNativeSpeakerQualificationProofs(
    (accreditation['qualificationProofs'] as List?)
        ?.map((item) => item.toString())
        .toList(growable: false),
    fallbackQualificationProof:
        accreditation['qualificationProof']?.toString().trim(),
  );
  final evidenceFiles = nativeSpeakerEvidenceFilesFromDynamic(
    accreditation['qualificationProofFiles'],
  );

  return NativeSpeakerHydratedAccreditationState(
    teachingExperience:
        teachingExperience?.isEmpty ?? true ? null : teachingExperience,
    qualificationProofs: qualificationProofs,
    evidenceFiles: evidenceFiles,
  );
}

List<NativeSpeakerEvidenceFile> nativeSpeakerEvidenceFilesFromDynamic(
  Object? rawFiles,
) {
  if (rawFiles is! Iterable) {
    return const <NativeSpeakerEvidenceFile>[];
  }

  final files = <NativeSpeakerEvidenceFile>[];
  for (final rawFile in rawFiles) {
    if (rawFile is! Map) {
      continue;
    }
    final normalizedMap = rawFile.map(
      (key, value) => MapEntry(key.toString(), value),
    );
    final storagePath = normalizedMap['storagePath']?.toString().trim() ??
        _nativeSpeakerEvidenceStoragePathFromLegacyUrl(
          normalizedMap['url']?.toString().trim(),
        );
    if (storagePath.isEmpty) {
      continue;
    }
    final derivedName = normalizedMap['name']?.toString().trim() ??
        _nativeSpeakerEvidenceFileNameFromStoragePath(storagePath);
    files.add(
      NativeSpeakerEvidenceFile(
        name: derivedName.isEmpty ? 'File' : derivedName,
        storagePath: storagePath,
      ),
    );
  }
  return cloneNativeSpeakerEvidenceFiles(files);
}

String _nativeSpeakerEvidenceStoragePathFromLegacyUrl(String? url) {
  final trimmedUrl = (url ?? '').trim();
  if (trimmedUrl.isEmpty) {
    return '';
  }

  final parsedUrl = Uri.tryParse(trimmedUrl);
  if (parsedUrl == null || parsedUrl.pathSegments.isEmpty) {
    return '';
  }

  final objectIndex = parsedUrl.pathSegments.indexOf('o');
  if (objectIndex == -1 || objectIndex + 1 >= parsedUrl.pathSegments.length) {
    return '';
  }

  return Uri.decodeComponent(parsedUrl.pathSegments[objectIndex + 1]).trim();
}

String _nativeSpeakerEvidenceFileNameFromStoragePath(String storagePath) {
  final normalizedPath = storagePath.trim();
  if (normalizedPath.isEmpty) {
    return '';
  }

  final pathSegments = normalizedPath.split('/');
  if (pathSegments.isEmpty) {
    return '';
  }

  return pathSegments.last.trim();
}

LanguageStruct? cloneNativeSpeakerLanguageSelection(LanguageStruct? language) {
  return cloneOnboardingLanguageSelection(language);
}

CountryStruct? cloneNativeSpeakerCountrySelection(CountryStruct? country) {
  return cloneOnboardingCountrySelection(country);
}

List<NativeSpeakerOnboardingPage> buildVisibleNativeSpeakerPages({
  required bool showName,
  required bool showPhoto,
}) {
  return NativeSpeakerOnboardingPage.values.where((page) {
    switch (page) {
      case NativeSpeakerOnboardingPage.name:
        return showName;
      case NativeSpeakerOnboardingPage.photo:
        return showPhoto;
      default:
        return true;
    }
  }).toList(growable: false);
}

int resolveNativeSpeakerInitialPage({
  required int requestedRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  if (visiblePages.isEmpty) {
    return 0;
  }

  final targetIndex = requestedRawIndex.clamp(
    0,
    NativeSpeakerOnboardingPage.values.length - 1,
  );

  for (final page in visiblePages) {
    if (page.index >= targetIndex) {
      return page.index;
    }
  }

  return visiblePages.last.index;
}

int resolveNativeSpeakerEntryInitialPage({
  required int requestedRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
  required NativeSpeakerOnboardingEntrySource entrySource,
}) {
  return resolveNativeSpeakerInitialPage(
    requestedRawIndex: entrySource == NativeSpeakerOnboardingEntrySource.profile
        ? 0
        : requestedRawIndex,
    visiblePages: visiblePages,
  );
}

int? nextVisibleNativeSpeakerPage({
  required int currentRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  for (final page in visiblePages) {
    if (page.index > currentRawIndex) {
      return page.index;
    }
  }
  return null;
}

int? previousVisibleNativeSpeakerPage({
  required int currentRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  for (final page in visiblePages.reversed) {
    if (page.index < currentRawIndex) {
      return page.index;
    }
  }
  return null;
}

int nativeSpeakerDisplayedTotalSteps({
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  return visiblePages.length;
}

int nativeSpeakerDisplayedStep({
  required int currentRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  return visiblePages.where((page) => page.index <= currentRawIndex).length;
}

bool isFirstVisibleNativeSpeakerPage({
  required int currentRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  return visiblePages.isNotEmpty && visiblePages.first.index == currentRawIndex;
}

bool isNativeSpeakerLastVisiblePage({
  required int currentRawIndex,
  required List<NativeSpeakerOnboardingPage> visiblePages,
}) {
  return visiblePages.isNotEmpty && visiblePages.last.index == currentRawIndex;
}

bool hasNativeSpeakerCompletionPhoto({
  required FFUploadedFile? localPhoto,
  required String? existingPhotoUrl,
}) {
  return (localPhoto?.bytes?.isNotEmpty ?? false) ||
      (existingPhotoUrl?.trim().isNotEmpty ?? false);
}
