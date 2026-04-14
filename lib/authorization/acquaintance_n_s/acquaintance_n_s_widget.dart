import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/country/country_widget.dart';
import '/authorization/components/lang/lang_widget.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import 'dart:async';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/permissions_util.dart';
import '/index.dart';
import '/services/teacher_verification_request_service.dart';
import 'native_speaker_onboarding_logic.dart';
import 'dart:math' as math;
import 'package:auto_size_text/auto_size_text.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'acquaintance_n_s_model.dart';
export 'acquaintance_n_s_model.dart';

class AcquaintanceNSWidget extends StatefulWidget {
  const AcquaintanceNSWidget({
    super.key,
    required this.index,
  });

  final int? index;

  static String routeName = 'Acquaintance_NS';
  static String routePath = '/acquaintanceNS';

  @override
  State<AcquaintanceNSWidget> createState() => _AcquaintanceNSWidgetState();
}

class _AcquaintanceNSWidgetState extends State<AcquaintanceNSWidget> {
  late AcquaintanceNSModel _model;

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

  List<NativeSpeakerOnboardingPage> get _visiblePages =>
      buildVisibleNativeSpeakerPages(
        showName: _shouldShowNameStep,
        showPhoto: _shouldShowPhotoStep,
      );

  int get _effectiveInitialPage => resolveNativeSpeakerInitialPage(
        requestedRawIndex: valueOrDefault<int>(widget.index, 0),
        visiblePages: _visiblePages,
      );

  NativeSpeakerOnboardingPage get _currentPage =>
      NativeSpeakerOnboardingPage.values[_model.pageViewCurrentIndex];

  int get _displayedCurrentStep => nativeSpeakerDisplayedStep(
        currentRawIndex: _model.pageViewCurrentIndex,
        visiblePages: _visiblePages,
      );

  int get _displayedTotalSteps => _visiblePages.length;

  bool get _isLastVisiblePage => isNativeSpeakerLastVisiblePage(
        currentRawIndex: _model.pageViewCurrentIndex,
        visiblePages: _visiblePages,
      );

  String _resolvedNativeSpeakerName() {
    final typedName = _model.nameTextController.text.trim();
    if (typedName.isNotEmpty) {
      return typedName;
    }
    return currentUserDisplayName.trim();
  }

  Future<String?> _uploadNativeSpeakerPhotoIfNeeded() async {
    if (!(_model.avatar?.bytes?.isNotEmpty ?? false)) {
      return _existingPhotoUrl.trim().isEmpty ? null : _existingPhotoUrl.trim();
    }

    safeSetState(() => _model.isDataUploading_uploadData5az = true);
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
        safeSetState(() => _model.isDataUploading_uploadData5az = false);
      }
    }

    if (downloadUrls.length != selectedMedia.length || downloadUrls.isEmpty) {
      return null;
    }

    final uploadedUrl = downloadUrls.first;
    safeSetState(() {
      _model.uploadedLocalFile_uploadData5az = selectedUploadedFiles.first;
      _model.uploadedFileUrl_uploadData5az = uploadedUrl;
    });
    return uploadedUrl;
  }

  Future<void> _goToNextVisiblePage() async {
    final nextPage = nextVisibleNativeSpeakerPage(
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
    final previousPage = previousVisibleNativeSpeakerPage(
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

  Future<void> _finishNativeSpeakerOnboarding() async {
    if (_isSubmitting) {
      return;
    }
    if (!hasNativeSpeakerCompletionPhoto(
      localPhoto: _model.avatar,
      existingPhotoUrl: _existingPhotoUrl,
    )) {
      await actions.showTopNotification(
        context,
        'Загрузите фото профиля',
        '',
        true,
      );
      return;
    }

    safeSetState(() => _isSubmitting = true);
    try {
      final photoUrl = await _uploadNativeSpeakerPhotoIfNeeded();
      if (photoUrl == null ||
          photoUrl.isEmpty ||
          currentUserReference == null) {
        await actions.showTopNotification(
          context,
          'Не удалось сохранить фото профиля',
          '',
          true,
        );
        return;
      }

      final displayName = _resolvedNativeSpeakerName();
      final aboutMe = _model.aboutMeTextController.text;

      final verificationRequestStatus = await submitTeacherVerificationRequest(
        userRef: currentUserReference!,
        displayName: displayName,
        photoUrl: photoUrl,
        aboutMe: aboutMe,
        languageInstruction: _model.langLearn,
        nativeLanguage: _model.nativeLang,
        country: _model.country,
      );
      if (verificationRequestStatus == null) {
        await actions.showTopNotification(
          context,
          'Не удалось отправить заявку на проверку',
          '',
          true,
        );
        return;
      }
      if (verificationRequestStatus == TeacherAccreditationStatus.rejected) {
        await actions.showTopNotification(
          context,
          'Заявка на проверку была отклонена',
          '',
          true,
        );
        return;
      }

      await currentUserReference!.update(
        createUsersRecordData(
          displayName: displayName.isEmpty ? null : displayName,
          role: UserRole.native_speaker,
          isProfileComplete: true,
          gender: _model.genderISMALE ? Gender.male : Gender.female,
          aboutMe: aboutMe,
          photoUrl: photoUrl,
          acquaintance: true,
          languageInstructionNS: updateLanguageStruct(
            _model.langLearn,
            clearUnsetFields: false,
          ),
          countryNS: updateCountryStruct(
            _model.country,
            clearUnsetFields: false,
          ),
          nativeLanguageNS: updateLanguageStruct(
            _model.nativeLang,
            clearUnsetFields: false,
          ),
        ),
      );
      _existingPhotoUrl = photoUrl;

      if (!mounted) {
        return;
      }

      context.goNamed(
        DashboardNSWidget.routeName,
        queryParameters: {
          'zn': serializeParam(
            true,
            ParamType.bool,
          ),
        }.withoutNulls,
      );
    } catch (_) {
      await actions.showTopNotification(
        context,
        'Не удалось сохранить профиль',
        '',
        true,
      );
    } finally {
      if (mounted) {
        safeSetState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AcquaintanceNSModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await requestPermission(cameraPermission);
      await requestPermission(microphonePermission);
    });

    _model.nameTextController ??=
        TextEditingController(text: currentUserDisplayName);
    _model.nameFocusNode ??= FocusNode();
    _existingPhotoUrl = currentUserPhoto.trim();

    _model.aboutMeTextController ??= TextEditingController();
    _model.aboutMeFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                                            '5sad5n6l' /* Как вас зовут? */,
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
                                            'qkjbiyki' /* Лучше написать настоящее имя */,
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
                                                    child: AuthUserStreamWidget(
                                                      builder: (context) =>
                                                          Container(
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
                                                                  .done,
                                                          obscureText: false,
                                                          decoration:
                                                              InputDecoration(
                                                            isDense: false,
                                                            labelText:
                                                                FFLocalizations.of(
                                                                        context)
                                                                    .getText(
                                                              'ymvt7z18' /* Ваше имя */,
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
                                                                InputBorder
                                                                    .none,
                                                            focusedBorder:
                                                                InputBorder
                                                                    .none,
                                                            errorBorder:
                                                                InputBorder
                                                                    .none,
                                                            focusedErrorBorder:
                                                                InputBorder
                                                                    .none,
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
                                                                  selection:
                                                                      newValue
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
                                        'uvh46vvg' /* Язык, которому будете обучать */,
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
                                        't67xey72' /* Можно выбрать несколько */,
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
                                        selected: _model.langLearn,
                                        action: (lang) async {
                                          _model.langLearn = lang;
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
                                        'qneb3190' /* На каком языке вы говорите с д... */,
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
                                        0.0, 60.0, 0.0, 0.0),
                                    child: wrapWithModel(
                                      model: _model.langModel2,
                                      updateCallback: () => safeSetState(() {}),
                                      child: LangWidget(
                                        selected: _model.nativeLang,
                                        action: (lang) async {
                                          _model.nativeLang = lang;
                                          safeSetState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ].addToEnd(SizedBox(height: 111.0)),
                              ),
                            ),
                          ),
                          Stack(
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 60.0, 0.0, 0.0),
                                child: FlutterFlowSwipeableStack(
                                  onSwipeFn: (index) async {
                                    _model.genderISMALE = !_model.genderISMALE;
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
                              Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        16.0, 16.0, 16.0, 0.0),
                                    child: AutoSizeText(
                                      FFLocalizations.of(context).getText(
                                        'tsnjs8zf' /* Как вы себя 
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
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        16.0, 4.0, 16.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'zc7cbn38' /* Это поможет ученикам найти под... */,
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
                                ],
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
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'iaxjidcm' /* Где вы сейчас находитесь? */,
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
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        10.0, 4.0, 10.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'h6cyori3' /* Находите новых друзей в интере... */,
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
                                        selected: _model.country,
                                        action: (lang) async {
                                          _model.country = lang;
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
                                      '24v6ef7s' /* Расскажите 
о себе */
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
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      10.0, 4.0, 10.0, 0.0),
                                  child: Text(
                                    FFLocalizations.of(context).getText(
                                      '9c52d7gr' /* Это поможет ученикам узнать ва... */,
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
                                    child: TextFormField(
                                      controller: _model.aboutMeTextController,
                                      focusNode: _model.aboutMeFocusNode,
                                      onFieldSubmitted: (_) async {
                                        if (_model.aboutMeTextController.text !=
                                            '') {
                                          await _goToNextVisiblePage();
                                        } else {
                                          await actions.showTopNotification(
                                            context,
                                            'Напишите хотя бы пару слов',
                                            '',
                                            true,
                                          );
                                          return;
                                        }
                                      },
                                      autofocus: true,
                                      textCapitalization:
                                          TextCapitalization.sentences,
                                      textInputAction: TextInputAction.done,
                                      obscureText: false,
                                      decoration: InputDecoration(
                                        isDense: false,
                                        hintText:
                                            FFLocalizations.of(context).getText(
                                          's8jfyxcp' /* Люблю готовить, изучаю испанск... */,
                                        ),
                                        hintStyle: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 16.0,
                                              letterSpacing: 0.0,
                                            ),
                                        enabledBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16.0),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: Color(0x00000000),
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16.0),
                                        ),
                                        errorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16.0),
                                        ),
                                        focusedErrorBorder: OutlineInputBorder(
                                          borderSide: BorderSide(
                                            color: FlutterFlowTheme.of(context)
                                                .error,
                                            width: 1.0,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(16.0),
                                        ),
                                        filled: true,
                                        fillColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        contentPadding: EdgeInsets.all(16.0),
                                        hoverColor: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                          ),
                                      maxLines: 12,
                                      minLines: 4,
                                      cursorColor: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      enableInteractiveSelection: true,
                                      validator: _model
                                          .aboutMeTextControllerValidator
                                          .asValidator(context),
                                      inputFormatters: [
                                        if (!isAndroid && !isiOS)
                                          TextInputFormatter.withFunction(
                                              (oldValue, newValue) {
                                            return TextEditingValue(
                                              selection: newValue.selection,
                                              text: newValue.text
                                                  .toCapitalization(
                                                      TextCapitalization
                                                          .sentences),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _shouldShowPhotoStep
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
                                            10.0, 16.0, 10.0, 0.0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'gt8x9g31' /* Добавьте фото профиля */,
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
                                      SizedBox(height: 60.0),
                                      InkWell(
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
                                            safeSetState(() => _model
                                                    .isDataUploading_uploadDataIyo2 =
                                                true);
                                            var selectedUploadedFiles =
                                                <FFUploadedFile>[];
                                            try {
                                              selectedUploadedFiles =
                                                  selectedMedia
                                                      .map(
                                                          (m) => FFUploadedFile(
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
                                            } finally {
                                              _model.isDataUploading_uploadDataIyo2 =
                                                  false;
                                            }
                                            if (selectedUploadedFiles.length ==
                                                selectedMedia.length) {
                                              safeSetState(() {
                                                _model.uploadedLocalFile_uploadDataIyo2 =
                                                    selectedUploadedFiles.first;
                                              });
                                            } else {
                                              safeSetState(() {});
                                              return;
                                            }
                                          }
                                          if ((_model
                                                  .uploadedLocalFile_uploadDataIyo2
                                                  .bytes
                                                  ?.isNotEmpty ??
                                              false)) {
                                            _model.avatar = _model
                                                .uploadedLocalFile_uploadDataIyo2;
                                            safeSetState(() {});
                                            safeSetState(() {
                                              _model.isDataUploading_uploadDataIyo2 =
                                                  false;
                                              _model.uploadedLocalFile_uploadDataIyo2 =
                                                  FFUploadedFile(
                                                      bytes: Uint8List.fromList(
                                                          []),
                                                      originalFilename: '');
                                            });
                                          }
                                        },
                                        child: Container(
                                          width: double.infinity,
                                          height: 479.1,
                                          decoration: BoxDecoration(
                                            color: FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                            borderRadius:
                                                BorderRadius.circular(26.0),
                                          ),
                                          child: Builder(
                                            builder: (context) {
                                              if (_model.avatar != null &&
                                                  (_model.avatar?.bytes
                                                          ?.isNotEmpty ??
                                                      false)) {
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          26.0),
                                                  child: Image.memory(
                                                    _model.avatar?.bytes ??
                                                        Uint8List.fromList([]),
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                );
                                              } else if (_existingPhotoUrl
                                                  .isNotEmpty) {
                                                return ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          26.0),
                                                  child: Image.network(
                                                    _existingPhotoUrl,
                                                    width: double.infinity,
                                                    height: double.infinity,
                                                    fit: BoxFit.cover,
                                                  ),
                                                );
                                              } else {
                                                return Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, -1.0),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 0.0,
                                                                0.0, 0.0),
                                                    child: Row(
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
                                                                .getText(
                                                              'uijw0e1q' /* Загрузить фото */,
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
                                                    ),
                                                  ),
                                                );
                                              }
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : const SizedBox.shrink(),
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
                height: 104.0,
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
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 35.0),
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
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                size: 24.0,
                              ),
                              onPressed: (previousVisibleNativeSpeakerPage(
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
                                        FlutterFlowTheme.of(context).success,
                                    icon: _isSubmitting
                                        ? SizedBox(
                                            width: 20.0,
                                            height: 20.0,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
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
                                            await _finishNativeSpeakerOnboarding();
                                          },
                                  );
                                } else {
                                  return FlutterFlowIconButton(
                                    borderRadius: 60.0,
                                    buttonSize: 56.0,
                                    fillColor: FlutterFlowTheme.of(context)
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
                                        case NativeSpeakerOnboardingPage.name:
                                          if (_model.nameTextController.text !=
                                              '') {
                                            if (!functions.isValidName(_model
                                                .nameTextController.text)) {
                                              await actions.showTopNotification(
                                                context,
                                                'Неверное имя',
                                                '',
                                                true,
                                              );
                                              return;
                                            }
                                          } else {
                                            await actions.showTopNotification(
                                              context,
                                              'Пожалуйста, представьтесь',
                                              '',
                                              true,
                                            );
                                            return;
                                          }
                                          break;
                                        case NativeSpeakerOnboardingPage
                                              .languageInstruction:
                                          if (!(_model.langLearn != null)) {
                                            await actions.showTopNotification(
                                              context,
                                              'Выберите язык из списка',
                                              '',
                                              true,
                                            );
                                            return;
                                          }
                                          break;
                                        case NativeSpeakerOnboardingPage
                                              .nativeLanguage:
                                          if (!(_model.nativeLang != null)) {
                                            await actions.showTopNotification(
                                              context,
                                              'Выберите язык из списка',
                                              '',
                                              true,
                                            );
                                            return;
                                          }
                                          break;
                                        case NativeSpeakerOnboardingPage.gender:
                                          break;
                                        case NativeSpeakerOnboardingPage
                                              .country:
                                          if (!(_model.country != null)) {
                                            await actions.showTopNotification(
                                              context,
                                              'Выберите страну из списка',
                                              '',
                                              true,
                                            );
                                            return;
                                          }
                                          break;
                                        case NativeSpeakerOnboardingPage
                                              .aboutMe:
                                          if (!(_model
                                                  .aboutMeTextController.text !=
                                              '')) {
                                            await actions.showTopNotification(
                                              context,
                                              'Напишите хотя бы пару слов',
                                              '',
                                              true,
                                            );
                                            return;
                                          }
                                          break;
                                        case NativeSpeakerOnboardingPage.photo:
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
