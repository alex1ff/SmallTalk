import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'student_onboarding_logic.dart';
import 'widgets/student_onboarding_bottom_bar.dart';
import 'widgets/student_onboarding_country_step.dart';
import 'widgets/student_onboarding_gender_step.dart';
import 'widgets/student_onboarding_language_step.dart';
import 'widgets/student_onboarding_level_step.dart';
import 'widgets/student_onboarding_name_step.dart';
import 'package:flutter/material.dart';
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
  final ValueNotifier<int> _currentPageIndexNotifier = ValueNotifier<int>(0);
  final ValueNotifier<bool> _isPageTransitionInProgressNotifier =
      ValueNotifier<bool>(false);
  final ValueNotifier<bool> _genderMaleNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<LanguageStruct?> _selectedLanguageNotifier =
      ValueNotifier<LanguageStruct?>(null);
  final ValueNotifier<CountryStruct?> _countryNotifier =
      ValueNotifier<CountryStruct?>(null);
  final ValueNotifier<Level> _levelNotifier =
      ValueNotifier<Level>(defaultStudentOnboardingLevel);

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSubmitting = false;
  int _currentPageIndex = 0;
  bool _didPrecacheOnboardingAssets = false;
  late final List<StudentOnboardingPage> _visiblePages;
  late final int _effectiveInitialPage;
  late final List<Widget> _stepPages;

  StudentOnboardingPage get _currentPage =>
      StudentOnboardingPage.values[_currentPageIndex];

  StudentOnboardingDraft get _draft => buildStudentOnboardingDraft(
        displayName: _model.nameTextController?.text,
        gender: _genderMaleNotifier.value ? Gender.male : Gender.female,
        learningLanguage: _selectedLanguageNotifier.value,
        level: _levelNotifier.value,
        country: _countryNotifier.value,
      );

  int get _displayedTotalSteps => studentDisplayedTotalSteps(
        visiblePages: _visiblePages,
      );

  bool get _isLastPage => isStudentLastVisiblePage(
        currentRawIndex: _currentPageIndex,
        visiblePages: _visiblePages,
      );

  void _setCurrentPageIndex(int index) {
    _currentPageIndex = index;
    if (_currentPageIndexNotifier.value != index) {
      _currentPageIndexNotifier.value = index;
    }
  }

  void _hydrateStudentStateFromProfile() {
    final initialState = buildStudentOnboardingInitialState(
      displayName: currentUserDisplayName,
      gender: currentUserDocument?.gender,
      level: currentUserDocument?.level,
      learningLanguage: currentUserDocument?.learningLanguage,
      country: currentUserDocument?.countryNS,
    );

    if ((_model.nameTextController?.text.trim().isEmpty ?? true) &&
        initialState.displayName.isNotEmpty) {
      _model.nameTextController?.text = initialState.displayName;
    }
    _model.genderMALE = initialState.genderMale;
    _model.level = initialState.level;
    _model.selectedLangLearn = initialState.learningLanguage;
    _model.country = initialState.country;

    _genderMaleNotifier.value = initialState.genderMale;
    _levelNotifier.value = initialState.level;
    _selectedLanguageNotifier.value =
        cloneLanguageSelection(initialState.learningLanguage);
    _countryNotifier.value = cloneCountrySelection(initialState.country);
  }

  Future<void> _showValidationError(String message) async {
    await actions.showTopNotification(
      context,
      message,
      '',
      true,
    );
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
      nextVisibleStudentPage(
        currentRawIndex: _currentPageIndex,
        visiblePages: _visiblePages,
      ),
    );
  }

  Future<void> _goToPreviousPage() async {
    await _animateToVisiblePage(
      previousVisibleStudentPage(
        currentRawIndex: _currentPageIndex,
        visiblePages: _visiblePages,
      ),
    );
  }

  Future<bool> _saveStudentProfile() async {
    final userRef = currentUserReference;
    if (userRef == null || _isSubmitting) {
      return false;
    }

    safeSetState(() => _isSubmitting = true);
    try {
      await userRef.update(
        buildStudentOnboardingUpdateData(
          payload: buildStudentOnboardingPayload(_draft),
          markProfileComplete: true,
        ),
      );
      return true;
    } catch (error) {
      debugPrint('AcquaintanceSTUDENTWidget: failed to save profile: $error');
      if (mounted) {
        await actions.showTopNotification(
          context,
          'Не удалось сохранить профиль',
          '',
          true,
        );
      }
      return false;
    } finally {
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
    final validationMessage = validateStudentOnboardingPage(
      page: _currentPage,
      draft: _draft,
    );
    if (validationMessage != null) {
      await _showValidationError(validationMessage);
      return;
    }

    if (_isLastPage) {
      final saved = await _saveStudentProfile();
      if (!mounted || !saved) {
        return;
      }
      context.goNamed(
        StudentsDashboardWidget.routeName,
        queryParameters: {
          'zn': serializeParam(true, ParamType.bool),
          'done': serializeParam(true, ParamType.bool),
        }.withoutNulls,
      );
      return;
    }

    await _goToNextPage();
  }

  List<Widget> _buildStepPages() {
    return <Widget>[
      StudentOnboardingNameStep(
        controller: _model.nameTextController!,
        focusNode: _model.nameFocusNode!,
        onSubmitted: _handleAdvance,
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
            _model.genderMALE = nextValue;
          },
        ),
      ),
      ValueListenableBuilder<LanguageStruct?>(
        valueListenable: _selectedLanguageNotifier,
        builder: (context, selectedLanguage, _) =>
            StudentOnboardingLanguageStep(
          selectedLanguage: selectedLanguage,
          allowedCodes: allowedStudentLearningLanguageCodes,
          onChanged: (lang) async {
            final nextLanguage = cloneLanguageSelection(lang);
            _selectedLanguageNotifier.value = nextLanguage;
            _model.selectedLangLearn = nextLanguage;
          },
        ),
      ),
      ValueListenableBuilder<CountryStruct?>(
        valueListenable: _countryNotifier,
        builder: (context, selectedCountry, _) => StudentOnboardingCountryStep(
          selectedCountry: selectedCountry,
          onChanged: (country) async {
            final nextCountry = cloneCountrySelection(country);
            _countryNotifier.value = nextCountry;
            _model.country = nextCountry;
          },
        ),
      ),
      ValueListenableBuilder<Level>(
        valueListenable: _levelNotifier,
        builder: (context, level, _) => StudentOnboardingLevelStep(
          level: level,
          onChanged: (nextLevel) {
            if (_levelNotifier.value == nextLevel) {
              return;
            }
            _levelNotifier.value = nextLevel;
            _model.level = nextLevel;
          },
        ),
      ),
    ];
  }

  void _precacheOnboardingAssets() {
    const assetPaths = <String>[
      'assets/images/group_11712753102.webp',
      'assets/images/group_1171275311.webp',
      'assets/images/33_2.webp',
      'assets/images/33_.webp',
      'assets/images/34kgr_.png',
      'assets/images/iom0u_.png',
      'assets/images/g08g4_.png',
      'assets/images/e1xjd_.png',
    ];

    for (final assetPath in assetPaths) {
      precacheImage(AssetImage(assetPath), context);
    }
  }

  Widget _buildBottomNavigation(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: _currentPageIndexNotifier,
      builder: (context, currentPageIndex, _) {
        final canGoBack = previousVisibleStudentPage(
              currentRawIndex: currentPageIndex,
              visiblePages: _visiblePages,
            ) !=
            null;
        final isLastPage = isStudentLastVisiblePage(
          currentRawIndex: currentPageIndex,
          visiblePages: _visiblePages,
        );
        final displayedCurrentStep = studentDisplayedCurrentStep(
          currentRawIndex: currentPageIndex,
          visiblePages: _visiblePages,
        );

        return ValueListenableBuilder<bool>(
          valueListenable: _isPageTransitionInProgressNotifier,
          builder: (context, isInteractionLocked, _) {
            return StudentOnboardingBottomBar(
              canGoBack: canGoBack,
              currentStep: displayedCurrentStep,
              isLastPage: isLastPage,
              isSubmitting: _isSubmitting,
              totalSteps: _displayedTotalSteps,
              isInteractionLocked: isInteractionLocked,
              onBack: _goToPreviousPage,
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
    _model = createModel(context, () => AcquaintanceSTUDENTModel());
    _model.nameTextController ??= TextEditingController();
    _model.nameFocusNode ??= FocusNode();
    _visiblePages = buildVisibleStudentPages(
      showName: true,
      showPhoto: false,
    );
    _effectiveInitialPage = resolveStudentInitialPage(
      requestedRawIndex: valueOrDefault<int>(widget.index, 0),
      visiblePages: _visiblePages,
    );
    _hydrateStudentStateFromProfile();
    _stepPages = _buildStepPages();
    _model.pageViewController ??=
        PageController(initialPage: _effectiveInitialPage);
    _currentPageIndex = _effectiveInitialPage;
    _currentPageIndexNotifier.value = _currentPageIndex;
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
  }

  @override
  void dispose() {
    _currentPageIndexNotifier.dispose();
    _isPageTransitionInProgressNotifier.dispose();
    _genderMaleNotifier.dispose();
    _selectedLanguageNotifier.dispose();
    _countryNotifier.dispose();
    _levelNotifier.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeKeyboard,
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Stack(
          children: [
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
              child: Column(
                children: [
                  Expanded(
                    child: PageView(
                      physics: const NeverScrollableScrollPhysics(),
                      controller: _model.pageViewController,
                      onPageChanged: _setCurrentPageIndex,
                      children: _stepPages,
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
                      FlutterFlowTheme.of(context).secondaryBackground,
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
  }
}
