import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/schema/enums/enums.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/flutter_flow/permissions_util.dart';
import '/flutter_flow/upload_data.dart';
import '/index.dart';
import '/services/teacher_verification_request_service.dart';
import '/services/user_match_profile.dart';
import 'native_speaker_onboarding_logic.dart';
import 'widgets/native_speaker_onboarding_about_me_step.dart';
import 'widgets/native_speaker_onboarding_accreditation_step.dart';
import 'widgets/native_speaker_onboarding_country_step.dart';
import 'widgets/native_speaker_onboarding_language_instruction_step.dart';
import 'widgets/native_speaker_onboarding_name_step.dart';
import 'widgets/native_speaker_onboarding_native_language_step.dart';
import 'widgets/native_speaker_onboarding_photo_step.dart';
import '/authorization/acquaintance_s_t_u_d_e_n_t/widgets/student_onboarding_bottom_bar.dart';
import '/authorization/acquaintance_s_t_u_d_e_n_t/widgets/student_onboarding_gender_step.dart';
import '/authorization/components/lang/lang_model.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'acquaintance_n_s_model.dart';
export 'acquaintance_n_s_model.dart';

const int _kMaxQualificationEvidenceFiles = 5;
const int _kMaxQualificationEvidenceFileSizeBytes = 10 * 1024 * 1024;

class _NativeSpeakerUploadedPhoto {
  const _NativeSpeakerUploadedPhoto({
    required this.url,
    this.storagePath,
  });

  final String url;
  final String? storagePath;
}

class AcquaintanceNSWidget extends StatefulWidget {
  const AcquaintanceNSWidget({
    super.key,
    required this.index,
    this.entrySource,
    this.teacherVerificationRequestLoader,
  });

  final int? index;
  final String? entrySource;
  final Future<Map<String, dynamic>?> Function()?
      teacherVerificationRequestLoader;

  static String routeName = 'Acquaintance_NS';
  static String routePath = '/acquaintanceNS';

  @override
  State<AcquaintanceNSWidget> createState() => _AcquaintanceNSWidgetState();
}

class _AcquaintanceNSWidgetState extends State<AcquaintanceNSWidget> {
  late AcquaintanceNSModel _model;
  final ValueNotifier<int> _currentPageIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isPageTransitionInProgressNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _genderMaleNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<LanguageStruct?> _languageInstructionNotifier =
      ValueNotifier<LanguageStruct?>(null);
  final ValueNotifier<LanguageStruct?> _nativeLanguageNotifier =
      ValueNotifier<LanguageStruct?>(null);
  final ValueNotifier<CountryStruct?> _countryNotifier =
      ValueNotifier<CountryStruct?>(null);
  final ValueNotifier<String?> _teachingExperienceNotifier =
      ValueNotifier<String?>(null);
  final ValueNotifier<List<String>> _qualificationProofsNotifier =
      ValueNotifier<List<String>>(<String>[]);
  final ValueNotifier<List<NativeSpeakerEvidenceFile>>
      _qualificationEvidenceFilesNotifier =
      ValueNotifier<List<NativeSpeakerEvidenceFile>>(
    const <NativeSpeakerEvidenceFile>[],
  );

  final scaffoldKey = GlobalKey<ScaffoldState>();

  bool _isSubmitting = false;
  bool _didPrecacheOnboardingAssets = false;
  bool _didPrewarmLanguageSelectorCache = false;
  bool _didEditTeachingExperience = false;
  bool _didEditQualificationProofs = false;
  int _currentPageIndex = 0;
  String _existingPhotoUrl = '';
  final Set<String> _removedQualificationEvidenceStoragePaths = <String>{};

  late final NativeSpeakerOnboardingEntrySource _entrySource;
  late final List<NativeSpeakerOnboardingPage> _visiblePages;
  late final int _effectiveInitialPage;

  bool get _hasSocialPrefillProvider =>
      FirebaseAuth.instance.currentUser?.providerData.any(
        (provider) =>
            provider.providerId == 'google.com' ||
            provider.providerId == 'apple.com',
      ) ??
      false;

  bool get _canUseSocialPrefill =>
      _hasSocialPrefillProvider &&
      !(currentUserDocument?.acquaintance ?? false) &&
      !(currentUserDocument?.isProfileComplete ?? false);

  bool get _shouldShowNameStep =>
      !(_canUseSocialPrefill && currentUserDisplayName.trim().isNotEmpty);

  bool get _shouldShowPhotoStep =>
      !(_canUseSocialPrefill && _existingPhotoUrl.trim().isNotEmpty);

  NativeSpeakerOnboardingPage get _currentPage =>
      NativeSpeakerOnboardingPage.values[_currentPageIndex];

  NativeSpeakerOnboardingDraft get _draft => buildNativeSpeakerOnboardingDraft(
        displayName: _model.nameTextController?.text,
        languageInstruction: _languageInstructionNotifier.value,
        nativeLanguage: _nativeLanguageNotifier.value,
        gender: _genderMaleNotifier.value ? Gender.male : Gender.female,
        country: _countryNotifier.value,
        aboutMe: _model.aboutMeTextController?.text,
        teachingExperience: _teachingExperienceNotifier.value,
        qualificationProofs: _qualificationProofsNotifier.value,
        qualificationProof: null,
        localQualificationFiles: _model.qualificationProofFiles,
        existingQualificationFiles: _qualificationEvidenceFilesNotifier.value,
        localPhoto: _model.avatar,
        existingPhotoUrl: _existingPhotoUrl,
      );

  int get _displayedTotalSteps =>
      nativeSpeakerDisplayedTotalSteps(visiblePages: _visiblePages);

  bool get _isLastPage => isNativeSpeakerLastVisiblePage(
        currentRawIndex: _currentPageIndex,
        visiblePages: _visiblePages,
      );

  bool get _isAtFirstVisiblePage => isFirstVisibleNativeSpeakerPage(
        currentRawIndex: _currentPageIndex,
        visiblePages: _visiblePages,
      );

  int? get _previousVisiblePage => previousVisibleNativeSpeakerPage(
        currentRawIndex: _currentPageIndex,
        visiblePages: _visiblePages,
      );

  bool get _canExitOnSystemBack =>
      _entrySource == NativeSpeakerOnboardingEntrySource.profile &&
      _isAtFirstVisiblePage;

  void _setCurrentPageIndex(int index) {
    _currentPageIndex = index;
    if (_currentPageIndexNotifier.value != index) {
      _currentPageIndexNotifier.value = index;
    }
  }

  void _hydrateNativeSpeakerStateFromProfile() {
    final initialState = buildNativeSpeakerOnboardingInitialState(
      displayName: currentUserDisplayName,
      languageInstruction: currentUserDocument?.languageInstructionNS,
      nativeLanguage: currentUserDocument?.nativeLanguageNS,
      gender: currentUserDocument?.gender,
      country: currentUserDocument?.countryNS,
      aboutMe: currentUserDocument?.aboutMe,
      existingPhotoUrl: currentUserPhoto,
    );

    if ((_model.nameTextController?.text.trim().isEmpty ?? true) &&
        initialState.displayName.isNotEmpty) {
      _model.nameTextController?.text = initialState.displayName;
    }

    if ((_model.aboutMeTextController?.text.trim().isEmpty ?? true) &&
        initialState.aboutMe.isNotEmpty) {
      _model.aboutMeTextController?.text = initialState.aboutMe;
    }

    _genderMaleNotifier.value = initialState.genderMale;
    _languageInstructionNotifier.value =
        cloneNativeSpeakerLanguageSelection(initialState.languageInstruction);
    _nativeLanguageNotifier.value =
        cloneNativeSpeakerLanguageSelection(initialState.nativeLanguage);
    _countryNotifier.value =
        cloneNativeSpeakerCountrySelection(initialState.country);
    _existingPhotoUrl = initialState.existingPhotoUrl;
  }

  Future<void> _showValidationError(String message) async {
    await actions.showTopNotification(
      context,
      message,
      '',
      true,
    );
  }

  Future<void> _hydrateAccreditationStateFromVerificationRequest() async {
    try {
      Map<String, dynamic>? snapshotData;
      if (widget.teacherVerificationRequestLoader != null) {
        snapshotData = await widget.teacherVerificationRequestLoader!.call();
      } else {
        final userRef = currentUserReference;
        if (userRef == null) {
          return;
        }
        final snapshot =
            await teacherVerificationRequestRefForUser(userRef.id).get();
        snapshotData = snapshot.data();
      }

      final hydratedState = parseNativeSpeakerAccreditationState(
        snapshotData?['accreditation'],
      );

      if (!mounted) {
        return;
      }

      if (!_didEditTeachingExperience &&
          (_teachingExperienceNotifier.value?.trim().isEmpty ?? true) &&
          hydratedState.teachingExperience != null &&
          hydratedState.teachingExperience!.isNotEmpty) {
        _teachingExperienceNotifier.value = hydratedState.teachingExperience;
      }
      if (!_didEditQualificationProofs &&
          _qualificationProofsNotifier.value.isEmpty &&
          hydratedState.qualificationProofs.isNotEmpty) {
        _qualificationProofsNotifier.value = hydratedState.qualificationProofs;
      }
      if (hydratedState.evidenceFiles.isNotEmpty) {
        final filteredHydratedEvidenceFiles = hydratedState.evidenceFiles
            .where(
              (file) => !_removedQualificationEvidenceStoragePaths.contains(
                file.storagePath,
              ),
            )
            .toList(growable: false);
        final mergedEvidenceFiles = mergeNativeSpeakerEvidenceFiles(
          _qualificationEvidenceFilesNotifier.value,
          filteredHydratedEvidenceFiles,
        );
        if (!listEquals(
          _qualificationEvidenceFilesNotifier.value,
          mergedEvidenceFiles,
        )) {
          _qualificationEvidenceFilesNotifier.value = mergedEvidenceFiles;
        }
      }
    } catch (error) {
      debugPrint(
        'AcquaintanceNSWidget: failed to hydrate accreditation answers: $error',
      );
    }
  }

  void _closeKeyboard() {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _animateToVisiblePage(int? targetPage) async {
    final pageViewController = _model.pageViewController;
    if (targetPage == null ||
        pageViewController == null ||
        _isPageTransitionInProgressNotifier.value) {
      return;
    }

    _isPageTransitionInProgressNotifier.value = true;
    try {
      await pageViewController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.ease,
      );
    } finally {
      if (mounted) {
        _isPageTransitionInProgressNotifier.value = false;
      }
    }
  }

  Future<void> _goToNextPage() async {
    await _animateToVisiblePage(
      nextVisibleNativeSpeakerPage(
        currentRawIndex: _currentPageIndex,
        visiblePages: _visiblePages,
      ),
    );
  }

  Future<void> _goToPreviousPage() async {
    await _animateToVisiblePage(
      previousVisibleNativeSpeakerPage(
        currentRawIndex: _currentPageIndex,
        visiblePages: _visiblePages,
      ),
    );
  }

  Future<void> _handleSystemBack() async {
    if (_isPageTransitionInProgressNotifier.value) {
      return;
    }

    if (_previousVisiblePage != null) {
      _closeKeyboard();
      await _goToPreviousPage();
      return;
    }

    if (_canExitOnSystemBack) {
      await Navigator.of(context).maybePop();
    }
  }

  Future<void> _pickPhoto() async {
    if (_isSubmitting || _model.isPickingAvatar) {
      return;
    }

    final selectedMedia = await selectMedia(
      maxWidth: 500.0,
      maxHeight: 500.0,
      imageQuality: 95,
      mediaSource: MediaSource.photoGallery,
      multiImage: false,
    );
    if (selectedMedia == null ||
        !selectedMedia.every((media) => validateFileFormat(
              media.storagePath,
              context,
            ))) {
      return;
    }

    safeSetState(() => _model.isPickingAvatar = true);
    try {
      final selectedUploadedFiles = selectedMedia
          .map(
            (media) => FFUploadedFile(
              name: media.storagePath.split('/').last,
              bytes: media.bytes,
              height: media.dimensions?.height,
              width: media.dimensions?.width,
              blurHash: media.blurHash,
              originalFilename: media.originalFilename,
            ),
          )
          .toList(growable: false);

      if (selectedUploadedFiles.length == selectedMedia.length &&
          selectedUploadedFiles.isNotEmpty) {
        safeSetState(() {
          _model.pickedAvatarFile = selectedUploadedFiles.first;
          _model.avatar = selectedUploadedFiles.first;
        });
      }
    } finally {
      if (mounted) {
        safeSetState(() => _model.isPickingAvatar = false);
      }
    }
  }

  String? _qualificationProofStorageFolderPath() {
    final userRef = currentUserReference;
    if (userRef == null) {
      return null;
    }
    return 'users/${userRef.id}/teacher_verification/qualification_proofs';
  }

  Future<void> _pickQualificationProofFiles() async {
    if (_isSubmitting || _model.isPickingQualificationFiles) {
      return;
    }

    final storageFolderPath = _qualificationProofStorageFolderPath();
    if (storageFolderPath == null) {
      return;
    }

    final currentAttachedFilesCount =
        _qualificationEvidenceFilesNotifier.value.length +
            _model.qualificationProofFiles.length;
    final remainingSlots =
        _kMaxQualificationEvidenceFiles - currentAttachedFilesCount;
    if (remainingSlots <= 0) {
      await _showValidationError('Можно прикрепить не больше 5 файлов');
      return;
    }

    safeSetState(() => _model.isPickingQualificationFiles = true);
    try {
      final selectedFiles = await selectFiles(
        storageFolderPath: storageFolderPath,
        allowedExtensions: const <String>[
          'pdf',
          'jpg',
          'jpeg',
          'png',
          'heic',
          'heif',
          'doc',
          'docx',
        ],
        multiFile: true,
        maxFiles: remainingSlots,
        maxFileSizeBytes: _kMaxQualificationEvidenceFileSizeBytes,
      );
      if (selectedFiles == null || selectedFiles.isEmpty) {
        await _showValidationError(
          'Файлы не выбраны или превышают 10 МБ',
        );
        return;
      }

      final uploadedFiles = selectedFiles
          .map(
            (file) => FFUploadedFile(
              name: file.storagePath.split('/').last,
              bytes: file.bytes,
              height: file.dimensions?.height,
              width: file.dimensions?.width,
              blurHash: file.blurHash,
              originalFilename: file.originalFilename,
            ),
          )
          .toList(growable: false);
      safeSetState(() {
        _model.qualificationProofFiles = <FFUploadedFile>[
          ..._model.qualificationProofFiles,
          ...uploadedFiles,
        ];
      });
    } finally {
      if (mounted) {
        safeSetState(() => _model.isPickingQualificationFiles = false);
      }
    }
  }

  void _removeLocalQualificationProofFileAt(int index) {
    if (index < 0 || index >= _model.qualificationProofFiles.length) {
      return;
    }
    safeSetState(() {
      final updatedFiles =
          _model.qualificationProofFiles.toList(growable: true);
      updatedFiles.removeAt(index);
      _model.qualificationProofFiles = updatedFiles;
    });
  }

  void _removeExistingQualificationEvidenceFileAt(int index) {
    final currentFiles = _qualificationEvidenceFilesNotifier.value;
    if (index < 0 || index >= currentFiles.length) {
      return;
    }
    _removedQualificationEvidenceStoragePaths
        .add(currentFiles[index].storagePath);
    final updatedFiles = currentFiles.toList(growable: true)..removeAt(index);
    _qualificationEvidenceFilesNotifier.value =
        cloneNativeSpeakerEvidenceFiles(updatedFiles);
  }

  Future<List<NativeSpeakerEvidenceFile>?>
      _uploadQualificationProofFilesIfNeeded() async {
    final existingFiles = cloneNativeSpeakerEvidenceFiles(
      _qualificationEvidenceFilesNotifier.value,
    );
    if (_model.qualificationProofFiles.isEmpty) {
      return existingFiles;
    }

    final storageFolderPath = _qualificationProofStorageFolderPath();
    if (storageFolderPath == null) {
      return null;
    }

    safeSetState(() => _model.isUploadingQualificationFiles = true);
    try {
      final selectedFiles = selectedFilesFromUploadedFiles(
        _model.qualificationProofFiles,
        storageFolderPath: storageFolderPath,
        isMultiData: true,
      );
      final uploadResults = await Future.wait(
        selectedFiles.map(
          (file) async => uploadDataAndGetStoragePath(
            file.storagePath,
            file.bytes,
          ),
        ),
      );
      final uploadedStoragePaths = uploadResults
          .where((path) => path != null)
          .map((path) => path!)
          .toList(growable: false);

      if (uploadedStoragePaths.length != selectedFiles.length) {
        await _deleteQualificationEvidenceFiles(
          uploadedStoragePaths
              .map(
                (storagePath) => NativeSpeakerEvidenceFile(
                  name: '',
                  storagePath: storagePath,
                ),
              )
              .toList(growable: false),
        );
        return null;
      }

      final uploadedFiles = <NativeSpeakerEvidenceFile>[
        ...existingFiles,
        for (var index = 0; index < uploadedStoragePaths.length; index++)
          NativeSpeakerEvidenceFile(
            name: _model.qualificationProofFiles[index].originalFilename
                    .trim()
                    .isNotEmpty
                ? _model.qualificationProofFiles[index].originalFilename.trim()
                : ((_model.qualificationProofFiles[index].name ?? '').trim()),
            storagePath: uploadedStoragePaths[index],
          ),
      ];
      return cloneNativeSpeakerEvidenceFiles(uploadedFiles);
    } finally {
      if (mounted) {
        safeSetState(() => _model.isUploadingQualificationFiles = false);
      }
    }
  }

  Future<void> _deleteQualificationEvidenceFiles(
    Iterable<NativeSpeakerEvidenceFile> files,
  ) async {
    final pathsToDelete = files
        .map((file) => file.storagePath.trim())
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (pathsToDelete.isEmpty) {
      return;
    }

    await Future.wait(
      pathsToDelete.map((storagePath) async {
        try {
          await deleteStorageObject(storagePath);
        } catch (error) {
          debugPrint(
            'AcquaintanceNSWidget: failed to delete evidence file '
            '$storagePath: $error',
          );
        }
      }),
    );
  }

  Future<void> _deleteUploadedNativeSpeakerPhoto(String storagePath) async {
    final normalizedPath = storagePath.trim();
    if (normalizedPath.isEmpty) {
      return;
    }

    try {
      await deleteStorageObject(normalizedPath);
    } catch (error) {
      debugPrint(
        'AcquaintanceNSWidget: failed to delete uploaded profile photo '
        '$normalizedPath: $error',
      );
    }
  }

  bool _isTeacherVerificationRequestError(Object error) =>
      isTeacherVerificationRequestSubmissionError(error);

  Future<_NativeSpeakerUploadedPhoto?>
      _uploadNativeSpeakerPhotoIfNeeded() async {
    if (!(_model.avatar?.bytes?.isNotEmpty ?? false)) {
      final existingUrl = _existingPhotoUrl.trim();
      return existingUrl.isEmpty
          ? null
          : _NativeSpeakerUploadedPhoto(url: existingUrl);
    }

    safeSetState(() => _model.isUploadingAvatar = true);
    final selectedUploadedFiles = <FFUploadedFile>[_model.avatar!];
    final selectedMedia = selectedFilesFromUploadedFiles(selectedUploadedFiles);
    final downloadUrls = <String>[];

    try {
      downloadUrls.addAll(
        (await Future.wait(
          selectedMedia.map(
            (media) async => uploadData(media.storagePath, media.bytes),
          ),
        ))
            .where((url) => url != null)
            .map((url) => url!)
            .toList(),
      );
    } finally {
      if (mounted) {
        safeSetState(() => _model.isUploadingAvatar = false);
      }
    }

    if (downloadUrls.length != selectedMedia.length || downloadUrls.isEmpty) {
      return null;
    }

    final uploadedUrl = downloadUrls.first;
    final uploadedStoragePath = selectedMedia.first.storagePath.trim();
    safeSetState(() {
      _model.uploadedAvatarFile = selectedUploadedFiles.first;
      _model.uploadedAvatarUrl = uploadedUrl;
    });
    return _NativeSpeakerUploadedPhoto(
      url: uploadedUrl,
      storagePath: uploadedStoragePath.isEmpty ? null : uploadedStoragePath,
    );
  }

  Future<TeacherAccreditationStatus?> _saveNativeSpeakerProfile() async {
    final userRef = currentUserReference;
    if (userRef == null || _isSubmitting) {
      return null;
    }

    safeSetState(() => _isSubmitting = true);
    final previousQualificationEvidenceFiles = cloneNativeSpeakerEvidenceFiles(
      _qualificationEvidenceFilesNotifier.value,
    );
    var newlyUploadedQualificationEvidenceFiles =
        const <NativeSpeakerEvidenceFile>[];
    var newlyUploadedPhotoStoragePath = '';
    TeacherAccreditationStatus? savedStatus;
    var verificationRequestWriteFailed = false;
    var shouldPreserveUploadedAssetsOnFailure = false;
    try {
      final shouldUploadQualificationFiles =
          shouldRequireNativeSpeakerQualificationFiles(
        _qualificationProofsNotifier.value,
      );
      final qualificationEvidenceFiles = shouldUploadQualificationFiles
          ? await _uploadQualificationProofFilesIfNeeded()
          : const <NativeSpeakerEvidenceFile>[];
      if (shouldUploadQualificationFiles &&
          qualificationEvidenceFiles == null) {
        await _showValidationError('Не удалось загрузить файлы подтверждения');
        return null;
      }
      final resolvedQualificationEvidenceFiles =
          qualificationEvidenceFiles ?? const <NativeSpeakerEvidenceFile>[];
      newlyUploadedQualificationEvidenceFiles =
          resolvedQualificationEvidenceFiles
              .where(
                (file) => !previousQualificationEvidenceFiles.any(
                  (previousFile) =>
                      previousFile.storagePath == file.storagePath,
                ),
              )
              .toList(growable: false);

      final uploadedPhoto = await _uploadNativeSpeakerPhotoIfNeeded();
      newlyUploadedPhotoStoragePath = uploadedPhoto?.storagePath ?? '';
      final photoUrl = uploadedPhoto?.url ?? '';
      if (photoUrl.isEmpty) {
        await _deleteQualificationEvidenceFiles(
          newlyUploadedQualificationEvidenceFiles,
        );
        await _showValidationError('Не удалось сохранить фото профиля');
        return null;
      }

      final submissionDraft = updateNativeSpeakerOnboardingDraft(
        _draft,
        localQualificationFiles: const <FFUploadedFile>[],
        existingQualificationFiles: resolvedQualificationEvidenceFiles,
      );
      final payload = buildNativeSpeakerOnboardingPayload(
        draft: submissionDraft,
        photoUrl: photoUrl,
      );

      TeacherAccreditationStatus? verificationRequestStatus;
      try {
        verificationRequestStatus = await submitTeacherVerificationRequest(
          userRef: userRef,
          displayName: payload.displayName ?? '',
          photoUrl: payload.photoUrl,
          aboutMe: payload.aboutMe,
          languageInstruction: payload.languageInstruction,
          nativeLanguage: payload.nativeLanguage,
          country: payload.country,
          accreditation: payload.accreditation,
        );
      } catch (error) {
        debugPrint(
          'AcquaintanceNSWidget: teacher verification request write failed: '
          '$error',
        );
        if (_isTeacherVerificationRequestError(error)) {
          verificationRequestWriteFailed = true;
          shouldPreserveUploadedAssetsOnFailure =
              isTeacherVerificationRequestAmbiguousWriteError(error);
          debugPrint(
            'AcquaintanceNSWidget: teacher verification request failed at the '
            'request write phase.',
          );
        }
        rethrow;
      }
      if (verificationRequestStatus == null) {
        await _deleteQualificationEvidenceFiles(
          newlyUploadedQualificationEvidenceFiles,
        );
        await _showValidationError('Не удалось отправить заявку на проверку');
        return null;
      }
      if (verificationRequestStatus == TeacherAccreditationStatus.rejected) {
        await _deleteQualificationEvidenceFiles(
          newlyUploadedQualificationEvidenceFiles,
        );
        await _showValidationError('Заявка на проверку была отклонена');
        return null;
      }
      shouldPreserveUploadedAssetsOnFailure =
          verificationRequestStatus == TeacherAccreditationStatus.pending;

      try {
        await userRef.update(
          buildNativeSpeakerOnboardingUpdateData(
            payload: payload,
            markProfileComplete: true,
            switchToNativeSpeakerRole: true,
            teacherAccreditationStatus:
                verificationRequestStatus == TeacherAccreditationStatus.pending
                    ? TeacherAccreditationStatus.pending
                    : null,
          ),
        );
      } catch (error) {
        debugPrint('AcquaintanceNSWidget: user profile update failed: $error');
        rethrow;
      }

      savedStatus = verificationRequestStatus;
      _existingPhotoUrl = payload.photoUrl;
      _qualificationEvidenceFilesNotifier.value =
          cloneNativeSpeakerEvidenceFiles(
        resolvedQualificationEvidenceFiles,
      );
      _removedQualificationEvidenceStoragePaths.clear();
      safeSetState(() {
        _model.qualificationProofFiles = <FFUploadedFile>[];
      });
      final detachedQualificationEvidenceFiles =
          previousQualificationEvidenceFiles
              .where(
                (file) => !resolvedQualificationEvidenceFiles.any(
                  (currentFile) => currentFile.storagePath == file.storagePath,
                ),
              )
              .toList(growable: false);
      await _deleteQualificationEvidenceFiles(
        detachedQualificationEvidenceFiles,
      );
      return savedStatus;
    } catch (error) {
      if (!shouldPreserveUploadedAssetsOnFailure) {
        await _deleteQualificationEvidenceFiles(
          newlyUploadedQualificationEvidenceFiles,
        );
      }
      debugPrint('AcquaintanceNSWidget: failed to save profile: $error');
      await _showValidationError(
        verificationRequestWriteFailed
            ? 'Не удалось отправить заявку на проверку. Попробуйте позже.'
            : 'Не удалось сохранить профиль',
      );
      return null;
    } finally {
      if (!shouldPreserveUploadedAssetsOnFailure &&
          savedStatus == null &&
          newlyUploadedPhotoStoragePath.isNotEmpty) {
        await _deleteUploadedNativeSpeakerPhoto(newlyUploadedPhotoStoragePath);
      }
      if (mounted) {
        safeSetState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _handleAdvance() async {
    if (_isPageTransitionInProgressNotifier.value) {
      return;
    }

    _closeKeyboard();
    final validationMessage = validateNativeSpeakerOnboardingPage(
      page: _currentPage,
      draft: _draft,
    );
    if (validationMessage != null) {
      await _showValidationError(validationMessage);
      return;
    }

    if (_isLastPage) {
      final savedStatus = await _saveNativeSpeakerProfile();
      if (!mounted || savedStatus == null) {
        return;
      }
      var shouldOpenNativeSpeakerDashboard =
          savedStatus != TeacherAccreditationStatus.rejected;
      if (savedStatus != TeacherAccreditationStatus.rejected &&
          currentUserReference != null) {
        try {
          final refreshedUser = await UsersRecord.getDocumentOnce(
            currentUserReference!,
          );
          shouldOpenNativeSpeakerDashboard =
              canUseNativeSpeakerShell(refreshedUser) ||
                  refreshedUser.isTeacherAccreditationApproved ||
                  shouldOpenNativeSpeakerDashboard;
        } catch (error) {
          debugPrint(
            'AcquaintanceNSWidget: failed to refresh post-save user state: '
            '$error',
          );
        }
      }
      context.goNamed(
        shouldOpenNativeSpeakerDashboard
            ? DashboardNSWidget.routeName
            : StudentsDashboardWidget.routeName,
        queryParameters: {
          'zn': serializeParam(true, ParamType.bool),
        }.withoutNulls,
      );
      return;
    }

    await _goToNextPage();
  }

  List<Widget> _buildStepPages() {
    final accreditationListenable = Listenable.merge(
      <Listenable>[
        _teachingExperienceNotifier,
        _qualificationProofsNotifier,
        _qualificationEvidenceFilesNotifier,
      ],
    );

    return <Widget>[
      _shouldShowNameStep
          ? NativeSpeakerOnboardingNameStep(
              controller: _model.nameTextController!,
              focusNode: _model.nameFocusNode!,
              onSubmitted: _handleAdvance,
            )
          : const SizedBox.shrink(),
      ValueListenableBuilder<LanguageStruct?>(
        valueListenable: _languageInstructionNotifier,
        builder: (context, selectedLanguage, _) =>
            NativeSpeakerOnboardingLanguageInstructionStep(
          selectedLanguage: selectedLanguage,
          onChanged: (lang) async {
            _languageInstructionNotifier.value =
                cloneNativeSpeakerLanguageSelection(lang);
          },
        ),
      ),
      ValueListenableBuilder<LanguageStruct?>(
        valueListenable: _nativeLanguageNotifier,
        builder: (context, selectedLanguage, _) =>
            NativeSpeakerOnboardingNativeLanguageStep(
          selectedLanguage: selectedLanguage,
          onChanged: (lang) async {
            _nativeLanguageNotifier.value =
                cloneNativeSpeakerLanguageSelection(lang);
          },
        ),
      ),
      ValueListenableBuilder<bool>(
        valueListenable: _genderMaleNotifier,
        builder: (context, genderMale, _) => StudentOnboardingGenderStep(
          genderMale: genderMale,
          onChanged: (nextValue) {
            if (_genderMaleNotifier.value == nextValue) {
              return;
            }
            _genderMaleNotifier.value = nextValue;
          },
        ),
      ),
      ValueListenableBuilder<CountryStruct?>(
        valueListenable: _countryNotifier,
        builder: (context, selectedCountry, _) =>
            NativeSpeakerOnboardingCountryStep(
          selectedCountry: selectedCountry,
          onChanged: (country) async {
            _countryNotifier.value =
                cloneNativeSpeakerCountrySelection(country);
          },
        ),
      ),
      NativeSpeakerOnboardingAboutMeStep(
        controller: _model.aboutMeTextController!,
        focusNode: _model.aboutMeFocusNode!,
        onSubmitted: _handleAdvance,
      ),
      AnimatedBuilder(
        animation: accreditationListenable,
        builder: (context, _) => NativeSpeakerOnboardingAccreditationStep(
          teachingExperience: _teachingExperienceNotifier.value,
          qualificationProofs: _qualificationProofsNotifier.value,
          localQualificationFiles: _model.qualificationProofFiles,
          existingQualificationFiles: _qualificationEvidenceFilesNotifier.value,
          isPickingFiles: _model.isPickingQualificationFiles,
          isUploadingFiles:
              _model.isUploadingQualificationFiles || _isSubmitting,
          onTeachingExperienceChanged: (value) {
            _didEditTeachingExperience = true;
            if (_teachingExperienceNotifier.value == value) {
              return;
            }
            _teachingExperienceNotifier.value = value;
          },
          onQualificationProofsChanged: (value) {
            final normalizedProofs =
                normalizeNativeSpeakerQualificationProofs(value);
            _didEditQualificationProofs = true;
            if (listEquals(
                _qualificationProofsNotifier.value, normalizedProofs)) {
              return;
            }
            _qualificationProofsNotifier.value = normalizedProofs;
          },
          onPickFiles: _pickQualificationProofFiles,
          onRemoveLocalFile: _removeLocalQualificationProofFileAt,
          onRemoveExistingFile: _removeExistingQualificationEvidenceFileAt,
        ),
      ),
      _shouldShowPhotoStep
          ? Builder(
              builder: (context) => NativeSpeakerOnboardingPhotoStep(
                localPhoto: _model.avatar,
                existingPhotoUrl: _existingPhotoUrl,
                enabled: !_isSubmitting && !_model.isPickingAvatar,
                onPickPhoto: _pickPhoto,
              ),
            )
          : const SizedBox.shrink(),
    ];
  }

  void _precacheOnboardingAssets() {
    const assetPaths = <String>[
      'assets/images/group_11712753102.webp',
      'assets/images/group_1171275311.webp',
      'assets/images/33_2.webp',
      'assets/images/33_.webp',
    ];

    for (final assetPath in assetPaths) {
      precacheImage(AssetImage(assetPath), context);
    }
  }

  void _prewarmLanguageSelectorCache() {
    final appState = FFAppState();
    LangModel.prewarmSharedCache(
      sourceLanguages: appState.languagesList,
      sourceSignature: appState.languagesListRevision,
      localeCode: FFLocalizations.of(context).languageCode,
    );
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _currentPageIndexNotifier,
      builder: (context, currentPageIndex, _) {
        final previousPage = previousVisibleNativeSpeakerPage(
          currentRawIndex: currentPageIndex,
          visiblePages: _visiblePages,
        );
        final isAtFirstVisiblePage = isFirstVisibleNativeSpeakerPage(
          currentRawIndex: currentPageIndex,
          visiblePages: _visiblePages,
        );
        final canGoBack = previousPage != null ||
            (_entrySource == NativeSpeakerOnboardingEntrySource.profile &&
                isAtFirstVisiblePage);
        final isLastPage = isNativeSpeakerLastVisiblePage(
          currentRawIndex: currentPageIndex,
          visiblePages: _visiblePages,
        );
        final displayedCurrentStep = nativeSpeakerDisplayedStep(
          currentRawIndex: currentPageIndex,
          visiblePages: _visiblePages,
        );

        return ValueListenableBuilder<bool>(
          valueListenable: _isPageTransitionInProgressNotifier,
          builder: (context, isInteractionLocked, _) {
            VoidCallback? onBack;
            if (previousPage != null) {
              onBack = () {
                _goToPreviousPage();
              };
            } else if (_entrySource ==
                    NativeSpeakerOnboardingEntrySource.profile &&
                isAtFirstVisiblePage) {
              onBack = () {
                Navigator.of(context).maybePop();
              };
            }

            return StudentOnboardingBottomBar(
              canGoBack: canGoBack,
              currentStep: displayedCurrentStep,
              isLastPage: isLastPage,
              isSubmitting: _isSubmitting,
              totalSteps: _displayedTotalSteps,
              isInteractionLocked: isInteractionLocked,
              onBack: onBack,
              onNext: _handleAdvance,
              onComplete: _handleAdvance,
            );
          },
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AcquaintanceNSModel());

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await requestPermission(cameraPermission);
      await requestPermission(microphonePermission);
    });

    _entrySource = resolveNativeSpeakerEntrySource(widget.entrySource);
    _model.nameTextController ??= TextEditingController();
    _model.nameFocusNode ??= FocusNode();
    _model.aboutMeTextController ??= TextEditingController();
    _model.aboutMeFocusNode ??= FocusNode();
    _existingPhotoUrl = currentUserPhoto.trim();

    _hydrateNativeSpeakerStateFromProfile();
    _visiblePages = buildVisibleNativeSpeakerPages(
      showName: _shouldShowNameStep,
      showPhoto: _shouldShowPhotoStep,
    );
    _effectiveInitialPage = resolveNativeSpeakerEntryInitialPage(
      requestedRawIndex: valueOrDefault<int>(widget.index, 0),
      visiblePages: _visiblePages,
      entrySource: _entrySource,
    );
    _model.pageViewController ??=
        PageController(initialPage: _effectiveInitialPage);
    _currentPageIndex = _effectiveInitialPage;
    _currentPageIndexNotifier.value = _currentPageIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateAccreditationStateFromVerificationRequest();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didPrecacheOnboardingAssets) {
      _didPrecacheOnboardingAssets = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _precacheOnboardingAssets();
        }
      });
    }
    if (!_didPrewarmLanguageSelectorCache) {
      _didPrewarmLanguageSelectorCache = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _prewarmLanguageSelectorCache();
        }
      });
    }
  }

  @override
  void dispose() {
    _currentPageIndexNotifier.dispose();
    _isPageTransitionInProgressNotifier.dispose();
    _genderMaleNotifier.dispose();
    _languageInstructionNotifier.dispose();
    _nativeLanguageNotifier.dispose();
    _countryNotifier.dispose();
    _teachingExperienceNotifier.dispose();
    _qualificationProofsNotifier.dispose();
    _qualificationEvidenceFilesNotifier.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scaffold = GestureDetector(
      onTap: _closeKeyboard,
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                0.0,
                55.0,
                0.0,
                0.0,
              ),
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _model.pageViewController,
                      onPageChanged: _setCurrentPageIndex,
                      children: _buildStepPages(),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional.bottomCenter,
              child: Container(
                width: double.infinity,
                height: 100.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0x00F2F2F7),
                      ExpatlioDesign.background,
                    ],
                    stops: const [0.0, 1.0],
                    begin: const AlignmentDirectional(0.0, -1.0),
                    end: const AlignmentDirectional(0.0, 1.0),
                  ),
                ),
                child: Align(
                  alignment: AlignmentDirectional.bottomCenter,
                  child: _buildBottomNavigation(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return ValueListenableBuilder<int>(
      valueListenable: _currentPageIndexNotifier,
      child: scaffold,
      builder: (context, _, child) => PopScope(
        canPop: _canExitOnSystemBack,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            return;
          }
          _handleSystemBack();
        },
        child: child!,
      ),
    );
  }
}
