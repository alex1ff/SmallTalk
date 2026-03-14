import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/chips/chips_widget.dart';
import '/authorization/components/country/country_widget.dart';
import '/authorization/components/lang/lang_widget.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:async';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/permissions_util.dart';
import '/index.dart';
import 'student_onboarding_logic.dart';
import 'dart:math' as math;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'acquaintance_s_t_u_d_e_n_t_model.dart';
export 'acquaintance_s_t_u_d_e_n_t_model.dart';

class AcquaintanceSTUDENTWidget extends StatefulWidget {
  const AcquaintanceSTUDENTWidget({
    super.key,
    required this.index,
  });

  final int? index;

  static String routeName = 'Acquaintance_STUDENT';
  static String routePath = '/acquaintanceSTUDENT';

  @override
  State<AcquaintanceSTUDENTWidget> createState() =>
      _AcquaintanceSTUDENTWidgetState();
}

class _AcquaintanceSTUDENTWidgetState extends State<AcquaintanceSTUDENTWidget> {
  late AcquaintanceSTUDENTModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSubmitting = false;
  String _existingPhotoUrl = '';

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

  List<StudentOnboardingPage> get _visiblePages => buildVisibleStudentPages(
        showName: _shouldShowNameStep,
        showPhoto: _shouldShowPhotoStep,
      );

  int get _effectiveInitialPage => resolveStudentInitialPage(
        requestedRawIndex: valueOrDefault<int>(widget.index, 0),
        visiblePages: _visiblePages,
      );

  StudentOnboardingPage get _currentPage =>
      StudentOnboardingPage.values[_model.pageViewCurrentIndex];

  int get _displayedCurrentStep => studentDisplayedCurrentStep(
        currentRawIndex: _model.pageViewCurrentIndex,
        visiblePages: _visiblePages,
      );

  int get _displayedTotalSteps => studentDisplayedTotalSteps(
        visiblePages: _visiblePages,
      );

  bool get _isLastVisiblePage => isStudentLastVisiblePage(
        currentRawIndex: _model.pageViewCurrentIndex,
        visiblePages: _visiblePages,
      );

  bool get _shouldShowSkipAction =>
      _visiblePages.contains(_currentPage) &&
      _currentPage.index > StudentOnboardingPage.interstitial.index;

  String _resolvedStudentName() {
    final typedName = _model.nameTextController.text.trim();
    if (typedName.isNotEmpty) {
      return typedName;
    }
    return currentUserDisplayName.trim();
  }

  Gender _resolvedStudentGender() =>
      _model.genderMALE ? Gender.male : Gender.female;

  Level _resolvedStudentLevel() =>
      _model.level ?? currentUserDocument?.level ?? Level.Basic;

  LanguageStruct? _resolvedLearningLanguage() =>
      cloneLanguageSelection(_model.selectedLangLearn) ??
      cloneLanguageSelection(currentUserDocument?.learningLanguage);

  LanguageStruct? _resolvedPreferredNativeLanguage() =>
      cloneLanguageSelection(_model.langNS) ??
      cloneLanguageSelection(
        (currentUserDocument != null &&
                currentUserDocument!.hasPreferences() &&
                currentUserDocument!.preferences.hasPreferredNativeLanguage())
            ? currentUserDocument!.preferences.preferredNativeLanguage
            : null,
      );

  CountryStruct? _resolvedPreferredLocation() =>
      cloneCountrySelection(_model.counntryNS) ??
      cloneCountrySelection(
        (currentUserDocument != null &&
                currentUserDocument!.hasPreferences() &&
                currentUserDocument!.preferences.hasPreferredLocation())
            ? currentUserDocument!.preferences.preferredLocation
            : null,
      );

  void _hydrateStudentStateFromProfile() {
    final initialState = buildStudentOnboardingInitialState(
      displayName: currentUserDisplayName,
      gender: currentUserDocument?.gender,
      level: currentUserDocument?.level,
      learningLanguage: currentUserDocument?.learningLanguage,
      purpose: currentUserDocument?.purpose,
      preferences:
          currentUserDocument != null && currentUserDocument!.hasPreferences()
              ? currentUserDocument!.preferences
              : null,
      photoUrl: currentUserPhoto,
    );

    if (_model.nameTextController.text.trim().isEmpty &&
        initialState.displayName.isNotEmpty) {
      _model.nameTextController.text = initialState.displayName;
    }
    _model.genderMALE = initialState.genderMale;
    _model.level = initialState.level;
    _model.selectedLangLearn = initialState.learningLanguage;
    _model.purpose = List<String>.from(initialState.purpose);
    _model.langNS = initialState.preferredNativeLanguage;
    _model.counntryNS = initialState.preferredLocation;
    _existingPhotoUrl = initialState.photoUrl;
  }

  Future<String?> _uploadStudentPhotoIfNeeded() async {
    if (!(_model.avatarPhooto?.bytes?.isNotEmpty ?? false)) {
      return _existingPhotoUrl.trim().isEmpty ? null : _existingPhotoUrl.trim();
    }

    safeSetState(() => _model.isDataUploading_uploadDataY2w = true);
    final selectedUploadedFiles = <FFUploadedFile>[_model.avatarPhooto!];
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
        safeSetState(() => _model.isDataUploading_uploadDataY2w = false);
      }
    }

    if (downloadUrls.length != selectedMedia.length) {
      return null;
    }

    final uploadedUrl = downloadUrls.first;
    safeSetState(() {
      _model.uploadedLocalFile_uploadDataY2w = selectedUploadedFiles.first;
      _model.uploadedFileUrl_uploadDataY2w = uploadedUrl;
    });
    return uploadedUrl;
  }

  Future<bool> _saveStudentProfile({
    required bool markProfileComplete,
  }) async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return false;
    }
    if (_isSubmitting) {
      return false;
    }

    safeSetState(() => _isSubmitting = true);
    try {
      String? photoUrl;
      if (markProfileComplete) {
        if (!hasStudentCompletionPhoto(
          localPhoto: _model.avatarPhooto,
          existingPhotoUrl: _existingPhotoUrl,
        )) {
          await actions.showTopNotification(
            context,
            'Загрузите фото профиля',
            '',
            true,
          );
          return false;
        }

        photoUrl = await _uploadStudentPhotoIfNeeded();
        if (photoUrl == null || photoUrl.isEmpty) {
          await actions.showTopNotification(
            context,
            'Не удалось загрузить фото профиля',
            '',
            true,
          );
          return false;
        }
      }

      final learningLanguage = _resolvedLearningLanguage();
      final preferences = markProfileComplete &&
              (hasLanguageSelection(_resolvedPreferredNativeLanguage()) ||
                  hasCountrySelection(_resolvedPreferredLocation()))
          ? updatePreferencesStruct(
              PreferencesStruct(
                preferredNativeLanguage: _resolvedPreferredNativeLanguage(),
                preferredLocation: _resolvedPreferredLocation(),
              ),
              clearUnsetFields: false,
            )
          : null;

      final updateData = <String, dynamic>{
        ...createUsersRecordData(
          displayName:
              _resolvedStudentName().isEmpty ? null : _resolvedStudentName(),
          gender: _resolvedStudentGender(),
          level: _resolvedStudentLevel(),
          acquaintance: true,
          isProfileComplete: markProfileComplete ? true : null,
          learningLanguage: learningLanguage != null
              ? updateLanguageStruct(
                  learningLanguage,
                  clearUnsetFields: false,
                )
              : null,
          photoUrl: markProfileComplete ? photoUrl : null,
          preferences: preferences,
        ),
      };

      if (markProfileComplete && _model.purpose.isNotEmpty) {
        updateData.addAll(mapToFirestore({'purpose': _model.purpose}));
      }

      await userRef.update(updateData);
      if (photoUrl != null && photoUrl.isNotEmpty) {
        _existingPhotoUrl = photoUrl;
      }
      return true;
    } catch (_) {
      await actions.showTopNotification(
        context,
        'Не удалось сохранить профиль',
        '',
        true,
      );
      return false;
    } finally {
      if (mounted) {
        safeSetState(() => _isSubmitting = false);
      }
    }
  }

  void _goToStudentsDashboard({
    required bool showCelebration,
    required bool done,
  }) {
    if (showCelebration) {
      context.goNamed(
        StudentsDashboardWidget.routeName,
        queryParameters: {
          'zn': serializeParam(
            true,
            ParamType.bool,
          ),
          'done': serializeParam(
            done,
            ParamType.bool,
          ),
        }.withoutNulls,
      );
      return;
    }

    context.goNamed(StudentsDashboardWidget.routeName);
  }

  Future<void> _finishStudentOnboarding({
    required bool showCelebration,
    required bool done,
  }) async {
    final saved = await _saveStudentProfile(markProfileComplete: true);
    if (!mounted || !saved) {
      return;
    }
    _goToStudentsDashboard(
      showCelebration: showCelebration,
      done: done,
    );
  }

  Future<void> _deferStudentOnboarding() async {
    final saved = await _saveStudentProfile(markProfileComplete: false);
    if (!mounted || !saved) {
      return;
    }
    _goToStudentsDashboard(
      showCelebration: widget.index != 4,
      done: false,
    );
  }

  Future<void> _handleStudentSkipAction() async {
    if (_isSubmitting) {
      return;
    }
    if (_isLastVisiblePage) {
      await _finishStudentOnboarding(
        showCelebration: true,
        done: true,
      );
      return;
    }
    await _goToNextVisiblePage();
  }

  Future<void> _goToNextVisiblePage() async {
    final nextPage = nextVisibleStudentPage(
      currentRawIndex: _model.pageViewCurrentIndex,
      visiblePages: _visiblePages,
    );
    if (nextPage == null) {
      return;
    }

    await _model.pageViewController?.animateToPage(
      nextPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  Future<void> _goToPreviousVisiblePage() async {
    final previousPage = previousVisibleStudentPage(
      currentRawIndex: _model.pageViewCurrentIndex,
      visiblePages: _visiblePages,
    );
    if (previousPage == null) {
      return;
    }

    await _model.pageViewController?.animateToPage(
      previousPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.ease,
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AcquaintanceSTUDENTModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      safeSetState(() {});
      await requestPermission(cameraPermission);
      await requestPermission(microphonePermission);
    });

    _model.nameTextController ??=
        TextEditingController(text: currentUserDisplayName);
    _model.nameFocusNode ??= FocusNode();
    _hydrateStudentStateFromProfile();
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Stack(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 4.0, 0.0),
                    child: Container(
                      width: double.infinity,
                      height: 70.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(100.0),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(2.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              width: 66.0,
                              height: 66.0,
                              decoration: BoxDecoration(
                                color: Colors.black,
                                shape: BoxShape.circle,
                              ),
                              child: Stack(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                children: [
                                  Padding(
                                    padding: EdgeInsets.all(2.0),
                                    child: Container(
                                      width: double.infinity,
                                      height: double.infinity,
                                      child: custom_widgets.ProggresBar(
                                        width: double.infinity,
                                        height: double.infinity,
                                        currentStep: _displayedCurrentStep,
                                        totalSteps: _displayedTotalSteps,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '$_displayedCurrentStep/$_displayedTotalSteps',
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: Colors.white,
                                          fontSize: 14.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            if (_shouldShowSkipAction)
                              InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: _isSubmitting
                                    ? null
                                    : () async {
                                        await _handleStudentSkipAction();
                                      },
                                child: Row(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          12.0, 0.0, 12.0, 0.0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          'bqppzscm' /* Пропустить */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                    Container(
                                      width: 66.0,
                                      height: 66.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Icon(
                                          Icons.close_rounded,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 20.0,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      height: double.infinity,
                      child: PageView(
                        physics: const NeverScrollableScrollPhysics(),
                        controller: _model.pageViewController ??=
                            PageController(initialPage: _effectiveInitialPage),
                        onPageChanged: (_) => safeSetState(() {}),
                        scrollDirection: Axis.horizontal,
                        children: [
                          _shouldShowNameStep
                              ? Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      6.0, 0.0, 6.0, 0.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.start,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            10.0, 16.0, 0.0, 0.0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'ip2rlf3r' /* Как вас зовут? */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'Cool',
                                                fontSize: 43.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.normal,
                                              ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            10.0, 4.0, 0.0, 0.0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'f55kpaxg' /* Лучше написать настоящее имя */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 16.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.normal,
                                              ),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0.0, 60.0, 0.0, 0.0),
                                        child: Container(
                                          width: double.infinity,
                                          height: 60.0,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(100.0),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(2.0),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Container(
                                                  width: 56.0,
                                                  height: 56.0,
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryBackground,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Align(
                                                    alignment:
                                                        AlignmentDirectional(
                                                            0.0, 0.0),
                                                    child: Icon(
                                                      FFIcons.kuser03,
                                                      color:
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryText,
                                                      size: 20.0,
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(8.0, 0.0,
                                                                8.0, 0.0),
                                                    child: Container(
                                                      width: double.infinity,
                                                      child: TextFormField(
                                                        controller: _model
                                                            .nameTextController,
                                                        focusNode: _model
                                                            .nameFocusNode,
                                                        onFieldSubmitted:
                                                            (_) async {
                                                          if (_model
                                                                  .nameTextController
                                                                  .text !=
                                                              '') {
                                                            if (functions
                                                                .isValidName(_model
                                                                    .nameTextController
                                                                    .text)) {
                                                              await _goToNextVisiblePage();
                                                            } else {
                                                              await actions
                                                                  .showTopNotification(
                                                                context,
                                                                'Неверное имя',
                                                                '',
                                                                true,
                                                              );
                                                              return;
                                                            }
                                                          } else {
                                                            await actions
                                                                .showTopNotification(
                                                              context,
                                                              'Пожалуйста, представьтесь',
                                                              '',
                                                              true,
                                                            );
                                                            return;
                                                          }
                                                        },
                                                        autofocus: true,
                                                        textCapitalization:
                                                            TextCapitalization
                                                                .sentences,
                                                        textInputAction:
                                                            TextInputAction
                                                                .next,
                                                        obscureText: false,
                                                        decoration:
                                                            InputDecoration(
                                                          isDense: false,
                                                          labelText:
                                                              FFLocalizations.of(
                                                                      context)
                                                                  .getText(
                                                            'aty6z85z' /* Ваше имя */,
                                                          ),
                                                          labelStyle:
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    fontFamily:
                                                                        'sf pro display',
                                                                    color: FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                    fontSize:
                                                                        16.0,
                                                                    letterSpacing:
                                                                        0.0,
                                                                  ),
                                                          enabledBorder:
                                                              InputBorder.none,
                                                          focusedBorder:
                                                              InputBorder.none,
                                                          errorBorder:
                                                              InputBorder.none,
                                                          focusedErrorBorder:
                                                              InputBorder.none,
                                                        ),
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'sf pro display',
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                            ),
                                                        cursorColor:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        enableInteractiveSelection:
                                                            true,
                                                        validator: _model
                                                            .nameTextControllerValidator
                                                            .asValidator(
                                                                context),
                                                        inputFormatters: [
                                                          if (!isAndroid &&
                                                              !isiOS)
                                                            TextInputFormatter
                                                                .withFunction(
                                                                    (oldValue,
                                                                        newValue) {
                                                              return TextEditingValue(
                                                                selection: newValue
                                                                    .selection,
                                                                text: newValue
                                                                    .text
                                                                    .toCapitalization(
                                                                        TextCapitalization
                                                                            .sentences),
                                                              );
                                                            }),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
                          Stack(
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 60.0, 0.0, 0.0),
                                child: FlutterFlowSwipeableStack(
                                  onSwipeFn: (index) async {
                                    _model.genderMALE = !_model.genderMALE;
                                    safeSetState(() {});
                                  },
                                  onLeftSwipe: (index) {},
                                  onRightSwipe: (index) {},
                                  onUpSwipe: (index) {},
                                  onDownSwipe: (index) {},
                                  itemBuilder: (context, index) {
                                    return [
                                      () => Align(
                                            alignment:
                                                AlignmentDirectional(0.0, 0.0),
                                            child: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      12.0, 0.0, 0.0, 0.0),
                                              child: Transform.rotate(
                                                angle: 15.0 * (math.pi / 180),
                                                child: ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20.0),
                                                  child: Image.asset(
                                                    FFLocalizations.of(context)
                                                                .languageCode ==
                                                            'ru'
                                                        ? 'assets/images/group_11712753102.webp'
                                                        : 'assets/images/group_1171275311.webp',
                                                    width: 280.0,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      () => Align(
                                            alignment:
                                                AlignmentDirectional(0.0, 0.0),
                                            child: Transform.rotate(
                                              angle: 350.0 * (math.pi / 180),
                                              child: ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(20.0),
                                                child: Image.asset(
                                                  FFLocalizations.of(context)
                                                              .languageCode ==
                                                          'ru'
                                                      ? 'assets/images/33_2.webp'
                                                      : 'assets/images/33_.webp',
                                                  width: 280.0,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                    ][index]();
                                  },
                                  itemCount: 2,
                                  controller: _model.swipeableStackController,
                                  loop: true,
                                  cardDisplayCount: 2,
                                  scale: 0.9,
                                  backCardOffset: const Offset(100.0, 0.0),
                                  allowedSwipeDirection:
                                      AllowedSwipeDirection.symmetric(
                                          horizontal: true),
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 16.0, 16.0, 0.0),
                                child: AutoSizeText(
                                  FFLocalizations.of(context).getText(
                                    '53phc019' /* Как вы себя 
идентифицируете? */
                                    ,
                                  ),
                                  maxLines: 2,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'Cool',
                                        color: Colors.black,
                                        fontSize: 43.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.normal,
                                        lineHeight: 1.1,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 0.0, 10.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'tqqp6x5t' /* Какой язык хотите практиковать... */,
                                      ),
                                      maxLines: 2,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '1crdpxrp' /* Сможете изменить позднее */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 60.0, 0.0, 0.0),
                                    child: wrapWithModel(
                                      model: _model.langModel1,
                                      updateCallback: () => safeSetState(() {}),
                                      child: LangWidget(
                                        selected: _model.selectedLangLearn,
                                        action: (lang) async {
                                          _model.selectedLangLearn = lang;
                                          safeSetState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ]
                                    .addToStart(SizedBox(height: 16.0))
                                    .addToEnd(SizedBox(height: 120.0)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10.0, 16.0, 10.0, 0.0),
                                  child: AutoSizeText(
                                    FFLocalizations.of(context).getText(
                                      'gs6ylhnl' /* Ваш текущий уровень */,
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'Cool',
                                          color: Colors.black,
                                          fontSize: 43.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          lineHeight: 1.1,
                                        ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 30.0, 0.0, 0.0),
                                  child: Stack(
                                    alignment: AlignmentDirectional(0.0, 1.0),
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        height: 350.0,
                                        child: custom_widgets.SemiCircleSlider(
                                          width: double.infinity,
                                          height: 350.0,
                                          initialLevel: _model.level,
                                          onChanged: (level) async {
                                            _model.level = level;
                                            safeSetState(() {});
                                          },
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0.0, 0.0, 0.0, 12.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      0.0, 0.0, 0.0, 30.0),
                                              child: Builder(
                                                builder: (context) {
                                                  if (_model.level ==
                                                      Level.Beginner) {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      0.0,
                                                                      12.0),
                                                          child: Image.asset(
                                                            'assets/images/34kgr_.png',
                                                            width: 100.0,
                                                            height: 70.0,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'zst66ylu' /* Начальный */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 21.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            '5dx8dgam' /* Знаю базовые фразы и слова
A1-... */
                                                            ,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  } else if (_model.level ==
                                                      Level.Basic) {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      0.0,
                                                                      12.0),
                                                          child: Image.asset(
                                                            'assets/images/iom0u_.png',
                                                            width: 100.0,
                                                            height: 70.0,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'f84pr2gx' /* Базовый */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 21.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            '9o39d1jb' /* Могу поддержать простой разгов... */,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  } else if (_model.level ==
                                                      Level.Intermediate) {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      0.0,
                                                                      12.0),
                                                          child: Image.asset(
                                                            'assets/images/g08g4_.png',
                                                            width: 100.0,
                                                            height: 70.0,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'yxe8e00i' /* Уверенный */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 21.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'b0keg79q' /* Говорю свободно на большинство... */,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  } else {
                                                    return Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      0.0,
                                                                      12.0),
                                                          child: Image.asset(
                                                            'assets/images/e1xjd_.png',
                                                            width: 100.0,
                                                            height: 70.0,
                                                            fit: BoxFit.contain,
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'pqgno6ti' /* Свободно */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 21.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            's4ycikzv' /* Владею как родным
Native */
                                                            ,
                                                          ),
                                                          textAlign:
                                                              TextAlign.center,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                            Stack(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              children: [
                                                Container(
                                                  width: double.infinity,
                                                  height: 22.0,
                                                  decoration: BoxDecoration(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50.0),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsets.all(2.0),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      Expanded(
                                                        child: InkWell(
                                                          splashColor: Colors
                                                              .transparent,
                                                          focusColor: Colors
                                                              .transparent,
                                                          hoverColor: Colors
                                                              .transparent,
                                                          highlightColor: Colors
                                                              .transparent,
                                                          onTap: () async {
                                                            _model.level =
                                                                Level.Beginner;
                                                            safeSetState(() {});
                                                          },
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Container(
                                                                width:
                                                                    valueOrDefault<
                                                                        double>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Beginner
                                                                      ? 32.0
                                                                      : 18.0,
                                                                  32.0,
                                                                ),
                                                                height:
                                                                    valueOrDefault<
                                                                        double>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Beginner
                                                                      ? 32.0
                                                                      : 18.0,
                                                                  32.0,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color:
                                                                      valueOrDefault<
                                                                          Color>(
                                                                    _model.level ==
                                                                            Level
                                                                                .Beginner
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primaryBackground
                                                                        : FlutterFlowTheme.of(context)
                                                                            .secondaryBackground,
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryBackground,
                                                                  ),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  border: Border
                                                                      .all(
                                                                    color: valueOrDefault<
                                                                        Color>(
                                                                      _model.level ==
                                                                              Level
                                                                                  .Beginner
                                                                          ? Color(
                                                                              0xFF6657E6)
                                                                          : Colors
                                                                              .transparent,
                                                                      Color(
                                                                          0xFF6657E6),
                                                                    ),
                                                                    width: 6.0,
                                                                  ),
                                                                ),
                                                                child:
                                                                    Visibility(
                                                                  visible: _model
                                                                          .level !=
                                                                      Level
                                                                          .Beginner,
                                                                  child: Align(
                                                                    alignment:
                                                                        AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                    child:
                                                                        Container(
                                                                      width:
                                                                          2.0,
                                                                      height:
                                                                          2.0,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .primaryText,
                                                                        shape: BoxShape
                                                                            .circle,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      6.0,
                                                                      0.0),
                                                          child: InkWell(
                                                            splashColor: Colors
                                                                .transparent,
                                                            focusColor: Colors
                                                                .transparent,
                                                            hoverColor: Colors
                                                                .transparent,
                                                            highlightColor:
                                                                Colors
                                                                    .transparent,
                                                            onTap: () async {
                                                              _model.level =
                                                                  Level.Basic;
                                                              safeSetState(
                                                                  () {});
                                                            },
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Container(
                                                                  width:
                                                                      valueOrDefault<
                                                                          double>(
                                                                    _model.level ==
                                                                            Level.Basic
                                                                        ? 32.0
                                                                        : 18.0,
                                                                    32.0,
                                                                  ),
                                                                  height:
                                                                      valueOrDefault<
                                                                          double>(
                                                                    _model.level ==
                                                                            Level.Basic
                                                                        ? 32.0
                                                                        : 18.0,
                                                                    32.0,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: valueOrDefault<
                                                                        Color>(
                                                                      _model.level ==
                                                                              Level
                                                                                  .Basic
                                                                          ? FlutterFlowTheme.of(context)
                                                                              .primaryBackground
                                                                          : FlutterFlowTheme.of(context)
                                                                              .secondaryBackground,
                                                                      FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryBackground,
                                                                    ),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: valueOrDefault<
                                                                          Color>(
                                                                        _model.level ==
                                                                                Level.Basic
                                                                            ? Color(0xFF6657E6)
                                                                            : Colors.transparent,
                                                                        Color(
                                                                            0xFF6657E6),
                                                                      ),
                                                                      width:
                                                                          6.0,
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      Visibility(
                                                                    visible: _model
                                                                            .level !=
                                                                        Level
                                                                            .Basic,
                                                                    child:
                                                                        Align(
                                                                      alignment:
                                                                          AlignmentDirectional(
                                                                              0.0,
                                                                              0.0),
                                                                      child:
                                                                          Container(
                                                                        width:
                                                                            2.0,
                                                                        height:
                                                                            2.0,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          shape:
                                                                              BoxShape.circle,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      6.0,
                                                                      0.0,
                                                                      0.0,
                                                                      0.0),
                                                          child: InkWell(
                                                            splashColor: Colors
                                                                .transparent,
                                                            focusColor: Colors
                                                                .transparent,
                                                            hoverColor: Colors
                                                                .transparent,
                                                            highlightColor:
                                                                Colors
                                                                    .transparent,
                                                            onTap: () async {
                                                              _model.level = Level
                                                                  .Intermediate;
                                                              safeSetState(
                                                                  () {});
                                                            },
                                                            child: Column(
                                                              mainAxisSize:
                                                                  MainAxisSize
                                                                      .max,
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .center,
                                                              children: [
                                                                Container(
                                                                  width:
                                                                      valueOrDefault<
                                                                          double>(
                                                                    _model.level ==
                                                                            Level.Intermediate
                                                                        ? 32.0
                                                                        : 18.0,
                                                                    32.0,
                                                                  ),
                                                                  height:
                                                                      valueOrDefault<
                                                                          double>(
                                                                    _model.level ==
                                                                            Level.Intermediate
                                                                        ? 32.0
                                                                        : 18.0,
                                                                    32.0,
                                                                  ),
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    color: valueOrDefault<
                                                                        Color>(
                                                                      _model.level ==
                                                                              Level
                                                                                  .Intermediate
                                                                          ? FlutterFlowTheme.of(context)
                                                                              .primaryBackground
                                                                          : FlutterFlowTheme.of(context)
                                                                              .secondaryBackground,
                                                                      FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryBackground,
                                                                    ),
                                                                    shape: BoxShape
                                                                        .circle,
                                                                    border:
                                                                        Border
                                                                            .all(
                                                                      color: valueOrDefault<
                                                                          Color>(
                                                                        _model.level ==
                                                                                Level.Intermediate
                                                                            ? Color(0xFF6657E6)
                                                                            : Colors.transparent,
                                                                        Color(
                                                                            0xFF6657E6),
                                                                      ),
                                                                      width:
                                                                          6.0,
                                                                    ),
                                                                  ),
                                                                  child:
                                                                      Visibility(
                                                                    visible: _model
                                                                            .level !=
                                                                        Level
                                                                            .Intermediate,
                                                                    child:
                                                                        Align(
                                                                      alignment:
                                                                          AlignmentDirectional(
                                                                              0.0,
                                                                              0.0),
                                                                      child:
                                                                          Container(
                                                                        width:
                                                                            2.0,
                                                                        height:
                                                                            2.0,
                                                                        decoration:
                                                                            BoxDecoration(
                                                                          color:
                                                                              FlutterFlowTheme.of(context).primaryText,
                                                                          shape:
                                                                              BoxShape.circle,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      Expanded(
                                                        child: InkWell(
                                                          splashColor: Colors
                                                              .transparent,
                                                          focusColor: Colors
                                                              .transparent,
                                                          hoverColor: Colors
                                                              .transparent,
                                                          highlightColor: Colors
                                                              .transparent,
                                                          onTap: () async {
                                                            _model.level =
                                                                Level.Fluent;
                                                            safeSetState(() {});
                                                          },
                                                          child: Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .end,
                                                            children: [
                                                              Container(
                                                                width:
                                                                    valueOrDefault<
                                                                        double>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Fluent
                                                                      ? 32.0
                                                                      : 18.0,
                                                                  32.0,
                                                                ),
                                                                height:
                                                                    valueOrDefault<
                                                                        double>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Fluent
                                                                      ? 32.0
                                                                      : 18.0,
                                                                  32.0,
                                                                ),
                                                                decoration:
                                                                    BoxDecoration(
                                                                  color:
                                                                      valueOrDefault<
                                                                          Color>(
                                                                    _model.level ==
                                                                            Level
                                                                                .Fluent
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primaryBackground
                                                                        : FlutterFlowTheme.of(context)
                                                                            .secondaryBackground,
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryBackground,
                                                                  ),
                                                                  shape: BoxShape
                                                                      .circle,
                                                                  border: Border
                                                                      .all(
                                                                    color: valueOrDefault<
                                                                        Color>(
                                                                      _model.level ==
                                                                              Level
                                                                                  .Fluent
                                                                          ? Color(
                                                                              0xFF6657E6)
                                                                          : Colors
                                                                              .transparent,
                                                                      Color(
                                                                          0xFF6657E6),
                                                                    ),
                                                                    width: 6.0,
                                                                  ),
                                                                ),
                                                                child:
                                                                    Visibility(
                                                                  visible: _model
                                                                          .level !=
                                                                      Level
                                                                          .Fluent,
                                                                  child: Align(
                                                                    alignment:
                                                                        AlignmentDirectional(
                                                                            0.0,
                                                                            0.0),
                                                                    child:
                                                                        Container(
                                                                      width:
                                                                          2.0,
                                                                      height:
                                                                          2.0,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .primaryText,
                                                                        shape: BoxShape
                                                                            .circle,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(0.0, 4.0, 0.0, 0.0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'sj0rn6q7' /* Начальный */,
                                                          ),
                                                          textAlign:
                                                              TextAlign.start,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color:
                                                                    valueOrDefault<
                                                                        Color>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Beginner
                                                                      ? FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                                ),
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  0.0,
                                                                  0.0,
                                                                  6.0,
                                                                  0.0),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Text(
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                              'rm8zot80' /* Базовый */,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  color:
                                                                      valueOrDefault<
                                                                          Color>(
                                                                    _model.level ==
                                                                            Level
                                                                                .Basic
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primaryText
                                                                        : FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                  ),
                                                                  fontSize:
                                                                      13.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  6.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        children: [
                                                          Text(
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                              'onxzn6lu' /* Уверенный */,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  color:
                                                                      valueOrDefault<
                                                                          Color>(
                                                                    _model.level ==
                                                                            Level
                                                                                .Intermediate
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primaryText
                                                                        : FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .secondaryText,
                                                                  ),
                                                                  fontSize:
                                                                      13.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Column(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .end,
                                                      children: [
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'qspamhah' /* Свободно */,
                                                          ),
                                                          textAlign:
                                                              TextAlign.end,
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color:
                                                                    valueOrDefault<
                                                                        Color>(
                                                                  _model.level ==
                                                                          Level
                                                                              .Fluent
                                                                      ? FlutterFlowTheme.of(
                                                                              context)
                                                                          .primaryText
                                                                      : FlutterFlowTheme.of(
                                                                              context)
                                                                          .secondaryText,
                                                                  FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                ),
                                                                fontSize: 13.0,
                                                                letterSpacing:
                                                                    0.0,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 0.0, 10.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'lrja9u6c' /* Отличное начало! */,
                                      ),
                                      maxLines: 2,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '553cq9o6' /* Основная информация готова
Ост... */
                                        ,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 100.0, 0.0, 0.0),
                                    child: Container(
                                      height: 213.21,
                                      child: Stack(
                                        children: [
                                          Container(
                                            width: double.infinity,
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              borderRadius:
                                                  BorderRadius.circular(38.0),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.all(24.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'aq1oqs5h' /* Завершите заполнение 
профиля ... */
                                                      ,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily: 'Cool',
                                                          fontSize: 20.0,
                                                          letterSpacing: 0.0,
                                                        ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 24.0,
                                                                0.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      8.0,
                                                                      0.0),
                                                          child: Container(
                                                            width: 20.0,
                                                            height: 20.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primary,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Align(
                                                              alignment:
                                                                  AlignmentDirectional(
                                                                      0.0, 0.0),
                                                              child: Icon(
                                                                FFIcons.kcheck,
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                                size: 12.0,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'dr0r3uyi' /* Более точный подбор собеседник... */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 15.0,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 12.0,
                                                                0.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      8.0,
                                                                      0.0),
                                                          child: Container(
                                                            width: 20.0,
                                                            height: 20.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primary,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Align(
                                                              alignment:
                                                                  AlignmentDirectional(
                                                                      0.0, 0.0),
                                                              child: Icon(
                                                                FFIcons.kcheck,
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                                size: 12.0,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'angeqklx' /* До 10 минут бесплатного общени... */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 15.0,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 12.0,
                                                                0.0, 0.0),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      0.0,
                                                                      0.0,
                                                                      8.0,
                                                                      0.0),
                                                          child: Container(
                                                            width: 20.0,
                                                            height: 20.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primary,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                            child: Align(
                                                              alignment:
                                                                  AlignmentDirectional(
                                                                      0.0, 0.0),
                                                              child: Icon(
                                                                FFIcons.kcheck,
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                                size: 12.0,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          FFLocalizations.of(
                                                                  context)
                                                              .getText(
                                                            'pcdwhfh6' /* Приоритет в поиске */,
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                fontSize: 15.0,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Align(
                                            alignment: AlignmentDirectional(
                                                1.35, -2.66),
                                            child: Container(
                                              width: 150.0,
                                              height: 150.0,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFFC3EFC3),
                                                    Color(0xFFA5FE72)
                                                  ],
                                                  stops: [0.0, 1.0],
                                                  begin: AlignmentDirectional(
                                                      0.0, -1.0),
                                                  end: AlignmentDirectional(
                                                      0, 1.0),
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Align(
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: Image.asset(
                                                  'assets/images/sticker_8.png',
                                                  width: 130.0,
                                                  height: 130.1,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Align(
                                    alignment: AlignmentDirectional(0.0, -1.0),
                                    child: FFButtonWidget(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () async {
                                              await _deferStudentOnboarding();
                                            },
                                      text: FFLocalizations.of(context).getText(
                                        'ybk9bjx6' /* Заполню позже */,
                                      ),
                                      options: FFButtonOptions(
                                        height: 40.0,
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            16.0, 0.0, 16.0, 0.0),
                                        iconPadding:
                                            EdgeInsetsDirectional.fromSTEB(
                                                0.0, 0.0, 0.0, 0.0),
                                        color: Colors.transparent,
                                        textStyle: FlutterFlowTheme.of(context)
                                            .titleSmall
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                        elevation: 0.0,
                                        borderRadius:
                                            BorderRadius.circular(8.0),
                                      ),
                                    ),
                                  ),
                                ]
                                    .addToStart(SizedBox(height: 16.0))
                                    .addToEnd(SizedBox(height: 120.0)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 0.0, 10.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        '69cq0mzr' /* Зачем вам нужен этот язык? */,
                                      ),
                                      maxLines: 2,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '4yfkc6aa' /* Можно выбрать несколько */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 60.0, 0.0, 0.0),
                                    child: Container(
                                      width: double.infinity,
                                      height: 583.87,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryBackground,
                                      ),
                                      child: GridView(
                                        padding: EdgeInsets.zero,
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 3,
                                          crossAxisSpacing: 6.0,
                                          mainAxisSpacing: 6.0,
                                          childAspectRatio: 0.8,
                                        ),
                                        scrollDirection: Axis.vertical,
                                        children: [
                                          wrapWithModel(
                                            model: _model.chipsModel1,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/5tvth2denlpx/%E2%9C%88%EF%B8%8F.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                '45xgftn8' /* Путешествия */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Путешествия'),
                                              actionadd: (select) async {
                                                _model.addToPurpose(
                                                    'Путешествия');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Путешествия');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel2,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/lerjql614l6t/%F0%9F%92%BC.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'b81l5ck6' /* Работа */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Работа'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Работа');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Работа');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel3,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/aacr3gooehck/%F0%9F%93%9A.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'nvzre0x5' /* Учеба */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Учеба'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Учеба');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model
                                                    .removeFromPurpose('Учеба');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel4,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/zn3jlcka2lbc/%F0%9F%92%A1.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                '3bbpj9jw' /* Культура */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Культура'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Культура');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Культура');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel5,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/odie4pcem3fn/%F0%9F%92%AC.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'psmff4a8' /* Общение */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Общение'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Общение');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Общение');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                          wrapWithModel(
                                            model: _model.chipsModel6,
                                            updateCallback: () =>
                                                safeSetState(() {}),
                                            child: ChipsWidget(
                                              icon:
                                                  'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/68cdtneygm0v/%F0%9F%9A%80.png',
                                              text: FFLocalizations.of(context)
                                                  .getText(
                                                'r19vqfh2' /* Другое */,
                                              ),
                                              selected: _model.purpose
                                                  .contains('Другое'),
                                              actionadd: (select) async {
                                                _model.addToPurpose('Другое');
                                                safeSetState(() {});
                                              },
                                              actiondeelete: (select) async {
                                                _model.removeFromPurpose(
                                                    'Другое');
                                                safeSetState(() {});
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ]
                                    .addToStart(SizedBox(height: 16.0))
                                    .addToEnd(SizedBox(height: 120.0)),
                              ),
                            ),
                          ),
                          _shouldShowPhotoStep
                              ? Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      6.0, 0.0, 6.0, 0.0),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  10.0, 0.0, 10.0, 0.0),
                                          child: Text(
                                            FFLocalizations.of(context)
                                                .getVariableText(
                                              ruText: 'Загрузите фото',
                                              enText: 'Upload a photo',
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'Cool',
                                                  fontSize: 43.0,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.normal,
                                                  lineHeight: 1.1,
                                                ),
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  0.0, 60.0, 0.0, 0.0),
                                          child: InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () async {
                                              if (_isSubmitting) {
                                                return;
                                              }
                                              final selectedMedia =
                                                  await selectMedia(
                                                maxWidth: 500.00,
                                                maxHeight: 500.00,
                                                imageQuality: 95,
                                                mediaSource:
                                                    MediaSource.photoGallery,
                                                multiImage: false,
                                              );
                                              if (selectedMedia != null &&
                                                  selectedMedia.every((m) =>
                                                      validateFileFormat(
                                                          m.storagePath,
                                                          context))) {
                                                final selectedUploadedFiles =
                                                    selectedMedia
                                                        .map((m) =>
                                                            FFUploadedFile(
                                                              name: m
                                                                  .storagePath
                                                                  .split('/')
                                                                  .last,
                                                              bytes: m.bytes,
                                                              height: m
                                                                  .dimensions
                                                                  ?.height,
                                                              width: m
                                                                  .dimensions
                                                                  ?.width,
                                                              blurHash:
                                                                  m.blurHash,
                                                              originalFilename:
                                                                  m.originalFilename,
                                                            ))
                                                        .toList();
                                                if (selectedUploadedFiles
                                                        .length ==
                                                    selectedMedia.length) {
                                                  _model.avatarPhooto =
                                                      selectedUploadedFiles
                                                          .first;
                                                  safeSetState(() {});
                                                }
                                              }
                                            },
                                            child: Container(
                                              width: double.infinity,
                                              height: 479.1,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                                borderRadius:
                                                    BorderRadius.circular(26.0),
                                              ),
                                              child: Align(
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: Builder(
                                                  builder: (context) {
                                                    if (_model.avatarPhooto !=
                                                            null &&
                                                        (_model
                                                                .avatarPhooto
                                                                ?.bytes
                                                                ?.isNotEmpty ??
                                                            false)) {
                                                      return ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(26.0),
                                                        child: Image.memory(
                                                          _model.avatarPhooto
                                                                  ?.bytes ??
                                                              Uint8List
                                                                  .fromList([]),
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      );
                                                    }
                                                    if (_existingPhotoUrl
                                                        .isNotEmpty) {
                                                      return ClipRRect(
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(26.0),
                                                        child: Image.network(
                                                          _existingPhotoUrl,
                                                          width:
                                                              double.infinity,
                                                          height:
                                                              double.infinity,
                                                          fit: BoxFit.cover,
                                                        ),
                                                      );
                                                    }
                                                    return Row(
                                                      mainAxisSize:
                                                          MainAxisSize.max,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .center,
                                                      children: [
                                                        Container(
                                                          width: 45.0,
                                                          height: 45.0,
                                                          decoration:
                                                              BoxDecoration(
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryBackground,
                                                            borderRadius:
                                                                BorderRadius
                                                                    .circular(
                                                                        20.0),
                                                          ),
                                                          child: Icon(
                                                            FFIcons.kcameraPlus,
                                                            color: FlutterFlowTheme
                                                                    .of(context)
                                                                .primaryText,
                                                            size: 20.0,
                                                          ),
                                                        ),
                                                        Padding(
                                                          padding:
                                                              EdgeInsetsDirectional
                                                                  .fromSTEB(
                                                                      12.0,
                                                                      0.0,
                                                                      0.0,
                                                                      0.0),
                                                          child: AutoSizeText(
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getVariableText(
                                                              ruText:
                                                                  'Выбрать из галереи',
                                                              enText:
                                                                  'Choose from gallery',
                                                            ),
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  color: FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                                  fontSize:
                                                                      16.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ]
                                          .addToStart(SizedBox(height: 16.0))
                                          .addToEnd(SizedBox(height: 120.0)),
                                    ),
                                  ),
                                )
                              : const SizedBox.shrink(),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 16.0, 10.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'abc33q9h' /* С носителем какого языка хотит... */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'kpfa0ujl' /* Сможете изменить позднее */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 60.0, 0.0, 0.0),
                                    child: wrapWithModel(
                                      model: _model.langModel2,
                                      updateCallback: () => safeSetState(() {}),
                                      child: LangWidget(
                                        selected: _model.langNS,
                                        action: (lang) async {
                                          _model.langNS = null;
                                          safeSetState(() {});
                                          _model.langNS = lang;
                                          safeSetState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ].addToEnd(SizedBox(height: 111.0)),
                              ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                6.0, 0.0, 6.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        8.0, 16.0, 8.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'dvafgdbh' /* Местоположение собеседника */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            color: Colors.black,
                                            fontSize: 43.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                            lineHeight: 1.1,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '4pay67d3' /* Находите новых друзей в интере... */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 60.0, 0.0, 0.0),
                                    child: wrapWithModel(
                                      model: _model.countryModel,
                                      updateCallback: () => safeSetState(() {}),
                                      child: CountryWidget(
                                        selected: _model.counntryNS,
                                        action: (lang) async {
                                          _model.counntryNS = lang;
                                          safeSetState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ].addToEnd(SizedBox(height: 111.0)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0.0, 1.0),
              child: Container(
                width: double.infinity,
                height: 100.0,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0x00F2F2F7),
                      FlutterFlowTheme.of(context).secondaryBackground
                    ],
                    stops: [0.0, 1.0],
                    begin: AlignmentDirectional(0.0, -1.0),
                    end: AlignmentDirectional(0, 1.0),
                  ),
                ),
                child: Align(
                  alignment: AlignmentDirectional(0.0, 1.0),
                  child: Builder(
                    builder: (context) {
                      if (_currentPage != StudentOnboardingPage.interstitial) {
                        return AnimatedPadding(
                          duration: const Duration(milliseconds: 160),
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsetsDirectional.fromSTEB(
                              0.0, 0.0, 0.0, keyboardVisible ? 8.0 : 35.0),
                          child: Container(
                            height: 60.0,
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(100.0),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(2.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  FlutterFlowIconButton(
                                    borderRadius: 60.0,
                                    buttonSize: 56.0,
                                    fillColor: Color(0xFF2E2E2E),
                                    icon: Icon(
                                      FFIcons.karrowLeft,
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      size: 24.0,
                                    ),
                                    onPressed: (previousVisibleStudentPage(
                                              currentRawIndex:
                                                  _model.pageViewCurrentIndex,
                                              visiblePages: _visiblePages,
                                            ) ==
                                            null)
                                        ? null
                                        : () async {
                                            await _goToPreviousVisiblePage();
                                          },
                                  ),
                                  Builder(
                                    builder: (context) {
                                      if (_isLastVisiblePage) {
                                        return FlutterFlowIconButton(
                                          borderRadius: 60.0,
                                          buttonSize: 56.0,
                                          fillColor:
                                              FlutterFlowTheme.of(context)
                                                  .success,
                                          icon: _isSubmitting
                                              ? SizedBox(
                                                  width: 20.0,
                                                  height: 20.0,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      Colors.black,
                                                    ),
                                                  ),
                                                )
                                              : Icon(
                                                  Icons.check,
                                                  color: Colors.black,
                                                  size: 24.0,
                                                ),
                                          onPressed: _isSubmitting
                                              ? null
                                              : () async {
                                                  await _finishStudentOnboarding(
                                                    showCelebration: true,
                                                    done: true,
                                                  );
                                                },
                                        );
                                      } else {
                                        return FlutterFlowIconButton(
                                          borderRadius: 60.0,
                                          buttonSize: 56.0,
                                          fillColor:
                                              FlutterFlowTheme.of(context)
                                                  .primaryBackground,
                                          icon: Icon(
                                            FFIcons.karrowRight,
                                            color: Colors.black,
                                            size: 24.0,
                                          ),
                                          onPressed: () async {
                                            unawaited(
                                              () async {
                                                await actions.closeKeyboard();
                                              }(),
                                            );
                                            switch (_currentPage) {
                                              case StudentOnboardingPage.name:
                                                if (_model.nameTextController
                                                        .text !=
                                                    '') {
                                                  if (!functions.isValidName(
                                                      _model.nameTextController
                                                          .text)) {
                                                    await actions
                                                        .showTopNotification(
                                                      context,
                                                      'Неверное имя',
                                                      '',
                                                      true,
                                                    );
                                                    return;
                                                  }
                                                } else {
                                                  await actions
                                                      .showTopNotification(
                                                    context,
                                                    'Пожалуйста, представьтесь',
                                                    '',
                                                    true,
                                                  );
                                                  return;
                                                }
                                                break;
                                              case StudentOnboardingPage.gender:
                                                break;
                                              case StudentOnboardingPage
                                                    .learningLanguage:
                                                if (!hasLanguageSelection(
                                                    _model.selectedLangLearn)) {
                                                  await actions
                                                      .showTopNotification(
                                                    context,
                                                    'Выберите язык из списка',
                                                    '',
                                                    true,
                                                  );
                                                  return;
                                                }
                                                break;
                                              case StudentOnboardingPage.level:
                                                break;
                                              case StudentOnboardingPage
                                                    .interstitial:
                                                break;
                                              case StudentOnboardingPage
                                                    .purpose:
                                                if (!(_model
                                                    .purpose.isNotEmpty)) {
                                                  await actions
                                                      .showTopNotification(
                                                    context,
                                                    'Выберите минимум одну цель',
                                                    '',
                                                    true,
                                                  );
                                                  return;
                                                }
                                                break;
                                              case StudentOnboardingPage.photo:
                                                if (!hasStudentCompletionPhoto(
                                                  localPhoto:
                                                      _model.avatarPhooto,
                                                  existingPhotoUrl:
                                                      _existingPhotoUrl,
                                                )) {
                                                  await actions
                                                      .showTopNotification(
                                                    context,
                                                    'Загрузите фото профиля',
                                                    '',
                                                    true,
                                                  );
                                                  return;
                                                }
                                                break;
                                              case StudentOnboardingPage
                                                    .preferredNativeLanguage:
                                                if (!hasLanguageSelection(
                                                    _model.langNS)) {
                                                  await actions
                                                      .showTopNotification(
                                                    context,
                                                    'Выберите язык из списка',
                                                    '',
                                                    true,
                                                  );
                                                  return;
                                                }
                                                break;
                                              case StudentOnboardingPage
                                                    .preferredLocation:
                                                break;
                                            }

                                            await _goToNextVisiblePage();
                                          },
                                        );
                                      }
                                    },
                                  ),
                                ].divide(SizedBox(width: 2.0)),
                              ),
                            ),
                          ),
                        );
                      } else {
                        return wrapWithModel(
                          model: _model.buttonModel,
                          updateCallback: () => safeSetState(() {}),
                          child: ButtonWidget(
                            text: FFLocalizations.of(context).getText(
                              'tkv7vhn7' /* Продолжить */,
                            ),
                            action: () async {
                              await _goToNextVisiblePage();
                            },
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
