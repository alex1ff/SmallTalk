import 'dart:math' as math;

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/components/onboarding_dropdown_field.dart';
import '/components/onboarding_form_section.dart';
import '/components/onboarding_gender_chips.dart';
import '/components/profile_dropdown_menu_item.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'acquaintance_s_t_u_d_e_n_t_model.dart';
import 'student_onboarding_logic.dart';
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
  final _formKey = GlobalKey<FormState>();
  final ValueNotifier<bool> _genderMaleNotifier = ValueNotifier<bool>(true);
  final ValueNotifier<LanguageStruct?> _selectedLanguageNotifier =
      ValueNotifier<LanguageStruct?>(null);
  final ValueNotifier<CountryStruct?> _countryNotifier =
      ValueNotifier<CountryStruct?>(null);
  final ValueNotifier<Level> _levelNotifier =
      ValueNotifier<Level>(defaultStudentOnboardingLevel);
  final ValueNotifier<bool> _formCompleteNotifier = ValueNotifier<bool>(false);

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isSubmitting = false;
  bool _isLanguageMenuOpen = false;
  bool _isCountryMenuOpen = false;
  bool _isLevelMenuOpen = false;

  StudentOnboardingDraft get _draft => buildStudentOnboardingDraft(
        displayName: _model.nameTextController?.text,
        gender: _genderMaleNotifier.value ? Gender.male : Gender.female,
        learningLanguage: _selectedLanguageNotifier.value,
        level: _levelNotifier.value,
        country: _countryNotifier.value,
      );

  bool get _isFormComplete {
    for (final page in StudentOnboardingPage.values) {
      if (validateStudentOnboardingPage(page: page, draft: _draft) != null) {
        return false;
      }
    }
    return true;
  }

  void _refreshFormCompletion() {
    final nextValue = _isFormComplete;
    if (_formCompleteNotifier.value != nextValue) {
      _formCompleteNotifier.value = nextValue;
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
    _ensureDefaultLearningLanguage();
    _refreshFormCompletion();
  }

  void _ensureDefaultLearningLanguage() {
    if (hasLanguageSelection(_selectedLanguageNotifier.value)) {
      return;
    }

    final defaultLanguage = _defaultEnglishLanguage();
    _selectedLanguageNotifier.value = defaultLanguage;
    _model.selectedLangLearn = defaultLanguage;
  }

  LanguageStruct _defaultEnglishLanguage() {
    for (final language in FFAppState().languagesList) {
      final codes = <String>[
        language.code,
        ...language.alternateCodes,
      ].map(_normalizeLanguageCode);
      if (codes.contains('en')) {
        return cloneLanguageSelection(language) ?? language;
      }
    }

    return LanguageStruct(
      code: 'en',
      nameEn: 'English',
      nameRu: 'Английский',
    );
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

  Future<void> _handleSubmit() async {
    _closeKeyboard();
    _formKey.currentState?.validate();

    for (final page in StudentOnboardingPage.values) {
      final validationMessage = validateStudentOnboardingPage(
        page: page,
        draft: _draft,
      );
      if (validationMessage != null) {
        await _showValidationError(validationMessage);
        return;
      }
    }

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
  }

  Future<void> _openLanguagePicker(BuildContext anchorContext) async {
    _closeKeyboard();
    safeSetState(() => _isLanguageMenuOpen = true);
    final selectedLanguage = _selectedLanguageNotifier.value;
    final selected = await _showOnboardingOptionsMenu<LanguageStruct>(
      anchorContext,
      options: _learningLanguageOptions()
          .map(
            (language) => _OnboardingMenuOption<LanguageStruct>(
              value: language,
              label: _languageTitle(context, language),
              selected: language == selectedLanguage,
            ),
          )
          .toList(growable: false),
    );
    if (mounted) {
      safeSetState(() => _isLanguageMenuOpen = false);
    }

    if (!mounted || selected == null) {
      return;
    }

    final nextLanguage = cloneLanguageSelection(selected);
    _selectedLanguageNotifier.value = nextLanguage;
    _model.selectedLangLearn = nextLanguage;
  }

  Future<void> _openCountryPicker(BuildContext anchorContext) async {
    _closeKeyboard();
    safeSetState(() => _isCountryMenuOpen = true);
    final selectedCountry = _countryNotifier.value;
    final selected = await _showOnboardingOptionsMenu<CountryStruct>(
      anchorContext,
      options: _countryOptions()
          .map(
            (country) => _OnboardingMenuOption<CountryStruct>(
              value: country,
              label: _countryTitle(context, country),
              selected: country == selectedCountry,
            ),
          )
          .toList(growable: false),
    );
    if (mounted) {
      safeSetState(() => _isCountryMenuOpen = false);
    }

    if (!mounted || selected == null) {
      return;
    }

    final nextCountry = cloneCountrySelection(selected);
    _countryNotifier.value = nextCountry;
    _model.country = nextCountry;
  }

  Future<void> _openLevelPicker(BuildContext anchorContext) async {
    _closeKeyboard();
    safeSetState(() => _isLevelMenuOpen = true);
    final selectedLevel = _levelNotifier.value;
    final selected = await _showOnboardingOptionsMenu<Level>(
      anchorContext,
      options: _availableLevels
          .map(
            (level) => _OnboardingMenuOption<Level>(
              value: level,
              label: _levelDropdownLabel(level),
              selected: level == selectedLevel,
            ),
          )
          .toList(growable: false),
    );
    if (mounted) {
      safeSetState(() => _isLevelMenuOpen = false);
    }

    if (!mounted || selected == null) {
      return;
    }

    _levelNotifier.value = selected;
    _model.level = selected;
  }

  Future<T?> _showOnboardingOptionsMenu<T>(
    BuildContext anchorContext, {
    required List<_OnboardingMenuOption<T>> options,
  }) {
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;

    if (anchorBox == null || overlayBox == null || !anchorBox.attached) {
      return Future<T?>.value(null);
    }

    const viewportMargin = 16.0;
    const minMenuWidth = 206.0;
    const preferredMenuWidth = 280.0;
    final anchorOffset =
        anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final availableMenuWidth =
        math.max(0.0, overlayBox.size.width - (viewportMargin * 2));
    final menuWidth = math.max(
      math.min(minMenuWidth, availableMenuWidth),
      math.min(preferredMenuWidth, availableMenuWidth),
    );
    final maxMenuLeft = math.max(
        viewportMargin, overlayBox.size.width - menuWidth - viewportMargin);
    final menuLeft = (anchorOffset.dx + anchorBox.size.width - menuWidth)
        .clamp(viewportMargin, maxMenuLeft)
        .toDouble();
    final anchorRect = Rect.fromLTWH(
      menuLeft,
      anchorOffset.dy + anchorBox.size.height + 8.0,
      menuWidth,
      0.0,
    );

    return showMenu<T>(
      context: anchorContext,
      position:
          RelativeRect.fromRect(anchorRect, Offset.zero & overlayBox.size),
      color: ExpatlioDesign.card,
      elevation: 8.0,
      shadowColor: const Color(0x12000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        side: const BorderSide(color: ExpatlioDesign.border),
      ),
      clipBehavior: Clip.antiAlias,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
        maxHeight: 320.0,
      ),
      items: [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            height: 42.0,
            padding: EdgeInsets.zero,
            child: ProfileDropdownMenuItem(
              label: option.label,
              selected: option.selected,
            ),
          ),
      ],
    );
  }

  List<LanguageStruct> _learningLanguageOptions() {
    final allowedCodes = allowedStudentLearningLanguageCodes
        .map(_normalizeLanguageCode)
        .where((code) => code.isNotEmpty)
        .toSet();
    final options = FFAppState()
        .languagesList
        .where(
          (language) => <String>[
            language.code,
            ...language.alternateCodes,
          ].map(_normalizeLanguageCode).any(allowedCodes.contains),
        )
        .toList(growable: true);

    if (options.isEmpty) {
      options.addAll(
        [
          LanguageStruct(
            code: 'en',
            nameEn: 'English',
            nameRu: 'Английский',
          ),
          LanguageStruct(
            code: 'ru',
            nameEn: 'Russian',
            nameRu: 'Русский',
          ),
        ],
      );
    }

    final selectedLanguage = _selectedLanguageNotifier.value;
    if (selectedLanguage != null &&
        !options.any((language) => language == selectedLanguage)) {
      options.insert(0, selectedLanguage);
    }

    return options;
  }

  List<CountryStruct> _countryOptions() {
    final countries = functions.countriesList().toList(growable: true)
      ..sort((left, right) => left.index.compareTo(right.index));
    final selectedCountry = _countryNotifier.value;
    if (selectedCountry != null &&
        !countries.any((country) => country == selectedCountry)) {
      countries.insert(0, selectedCountry);
    }
    return countries;
  }

  String _normalizeLanguageCode(String code) {
    return code.trim().toLowerCase().replaceAll('_', '-').split('-').first;
  }

  String _levelDropdownLabel(Level level) {
    switch (level) {
      case Level.Beginner:
        return 'A1 — Beginner';
      case Level.Basic:
        return 'A2 — Basic';
      case Level.Intermediate:
        return 'B1 — Intermediate';
      case Level.Fluent:
        return 'C1 — Fluent';
    }
  }

  String _languageTitle(BuildContext context, LanguageStruct? language) {
    if (language == null) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Выберите язык изучения',
        enText: 'Select learning language',
      );
    }

    return valueOrDefault<String>(
      FFLocalizations.of(context).getVariableText(
        ruText: language.nameRu,
        enText: language.nameEn,
      ),
      language.code.toUpperCase(),
    );
  }

  String _countryTitle(BuildContext context, CountryStruct? country) {
    if (country == null) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Выберите вашу страну',
        enText: 'Select your country',
      );
    }

    return valueOrDefault<String>(
      FFLocalizations.of(context).getVariableText(
        ruText: country.nameRu,
        enText: country.nameEn,
      ),
      country.code.toUpperCase(),
    );
  }

  String _levelTitle(BuildContext context, Level level) {
    switch (level) {
      case Level.Beginner:
        return FFLocalizations.of(context)
            .getVariableText(ruText: 'Начальный', enText: 'Beginner');
      case Level.Basic:
        return FFLocalizations.of(context)
            .getVariableText(ruText: 'Базовый', enText: 'Basic');
      case Level.Intermediate:
        return FFLocalizations.of(context)
            .getVariableText(ruText: 'Уверенный', enText: 'Intermediate');
      case Level.Fluent:
        return FFLocalizations.of(context)
            .getVariableText(ruText: 'Свободно', enText: 'Fluent');
    }
  }

  String _levelSubtitle(BuildContext context, Level level) {
    switch (level) {
      case Level.Beginner:
        return 'A1-A2';
      case Level.Basic:
        return 'A2-B1';
      case Level.Intermediate:
        return 'B1-B2';
      case Level.Fluent:
        return 'C1-C2';
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AcquaintanceSTUDENTModel());
    _model.nameTextController ??= TextEditingController();
    _model.nameFocusNode ??= FocusNode();
    _model.nameTextController?.addListener(_refreshFormCompletion);
    _genderMaleNotifier.addListener(_refreshFormCompletion);
    _selectedLanguageNotifier.addListener(_refreshFormCompletion);
    _countryNotifier.addListener(_refreshFormCompletion);
    _levelNotifier.addListener(_refreshFormCompletion);
    _hydrateStudentStateFromProfile();
  }

  @override
  void dispose() {
    _model.nameTextController?.removeListener(_refreshFormCompletion);
    _genderMaleNotifier.removeListener(_refreshFormCompletion);
    _selectedLanguageNotifier.removeListener(_refreshFormCompletion);
    _countryNotifier.removeListener(_refreshFormCompletion);
    _levelNotifier.removeListener(_refreshFormCompletion);
    _genderMaleNotifier.dispose();
    _selectedLanguageNotifier.dispose();
    _countryNotifier.dispose();
    _levelNotifier.dispose();
    _formCompleteNotifier.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _closeKeyboard,
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              key: const ValueKey<String>('student_onboarding_single_form'),
              padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.pagePadding,
                ExpatlioDesign.space20,
                ExpatlioDesign.pagePadding,
                ExpatlioDesign.space24,
              ),
              children: [
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Знакомство',
                    enText: 'Introduction',
                  ),
                  style: ExpatlioDesign.textStyle(
                    context,
                    size: 34.0,
                    weight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space8),
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText:
                        'Заполните короткую форму, чтобы мы подобрали собеседников.',
                    enText:
                        'Fill in this short form so we can match conversation partners.',
                  ),
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.muted,
                    size: 15.0,
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space24),
                Container(
                  decoration: ExpatlioDesign.formGroupDecoration(),
                  padding: ExpatlioDesign.formGroupPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OnboardingFormSection(
                        key: const ValueKey<String>(
                          'student_onboarding_step_name',
                        ),
                        title: FFLocalizations.of(context).getVariableText(
                          ruText: 'Имя',
                          enText: 'Name',
                        ),
                        child: TextFormField(
                          key: const ValueKey<String>(
                            'student_onboarding_name_field',
                          ),
                          controller: _model.nameTextController,
                          focusNode: _model.nameFocusNode,
                          autofocus: false,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleSubmit(),
                          decoration: ExpatlioDesign.formFieldDecoration(
                            context,
                            hintText:
                                FFLocalizations.of(context).getVariableText(
                              ruText: 'Как вас зовут?',
                              enText: 'What is your name?',
                            ),
                          ),
                          style: ExpatlioDesign.formTextStyle(context),
                          cursorColor: ExpatlioDesign.primary,
                        ),
                      ),
                      const SizedBox(height: ExpatlioDesign.sectionSpacing),
                      ValueListenableBuilder<bool>(
                        valueListenable: _genderMaleNotifier,
                        builder: (context, genderMale, _) =>
                            OnboardingFormSection(
                          key: const ValueKey<String>(
                            'student_onboarding_step_gender',
                          ),
                          title: FFLocalizations.of(context).getVariableText(
                            ruText: 'Пол',
                            enText: 'Gender',
                          ),
                          child: OnboardingGenderChips(
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
                      ),
                      const SizedBox(height: ExpatlioDesign.sectionSpacing),
                      ValueListenableBuilder<LanguageStruct?>(
                        valueListenable: _selectedLanguageNotifier,
                        builder: (context, selectedLanguage, _) =>
                            OnboardingFormSection(
                          key: const ValueKey<String>(
                            'student_onboarding_step_language',
                          ),
                          title: FFLocalizations.of(context).getVariableText(
                            ruText: 'Язык изучения',
                            enText: 'Learning language',
                          ),
                          child: OnboardingDropdownField(
                            key: const ValueKey<String>(
                              'student_onboarding_language_picker',
                            ),
                            value: _languageTitle(context, selectedLanguage),
                            placeholder: selectedLanguage == null,
                            icon: Icons.language_rounded,
                            menuOpen: _isLanguageMenuOpen,
                            onTap: _openLanguagePicker,
                          ),
                        ),
                      ),
                      const SizedBox(height: ExpatlioDesign.sectionSpacing),
                      ValueListenableBuilder<CountryStruct?>(
                        valueListenable: _countryNotifier,
                        builder: (context, selectedCountry, _) =>
                            OnboardingFormSection(
                          key: const ValueKey<String>(
                            'student_onboarding_step_country',
                          ),
                          title: FFLocalizations.of(context).getVariableText(
                            ruText: 'Ваша страна',
                            enText: 'Your country',
                          ),
                          child: OnboardingDropdownField(
                            key: const ValueKey<String>(
                              'student_onboarding_country_picker',
                            ),
                            value: _countryTitle(context, selectedCountry),
                            placeholder: selectedCountry == null,
                            icon: Icons.location_on_outlined,
                            menuOpen: _isCountryMenuOpen,
                            onTap: _openCountryPicker,
                          ),
                        ),
                      ),
                      const SizedBox(height: ExpatlioDesign.sectionSpacing),
                      ValueListenableBuilder<Level>(
                        valueListenable: _levelNotifier,
                        builder: (context, level, _) => OnboardingFormSection(
                          key: const ValueKey<String>(
                            'student_onboarding_step_level',
                          ),
                          title: FFLocalizations.of(context).getVariableText(
                            ruText: 'Уровень',
                            enText: 'Level',
                          ),
                          child: OnboardingDropdownField(
                            key: const ValueKey<String>(
                              'student_onboarding_level_picker',
                            ),
                            value:
                                '${_levelTitle(context, level)} · ${_levelSubtitle(context, level)}',
                            icon: Icons.school_outlined,
                            menuOpen: _isLevelMenuOpen,
                            onTap: _openLevelPicker,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space20),
                ValueListenableBuilder<bool>(
                  valueListenable: _formCompleteNotifier,
                  builder: (context, isFormComplete, _) => ButtonWidget(
                    key: const ValueKey<String>(
                      'student_onboarding_finish_button',
                    ),
                    text: FFLocalizations.of(context).getVariableText(
                      ruText: 'Готово',
                      enText: 'Done',
                    ),
                    loadingText: FFLocalizations.of(context).getVariableText(
                      ruText: 'Сохраняем...',
                      enText: 'Saving...',
                    ),
                    busyStyle: ButtonBusyStyle.spinner,
                    enabled: !_isSubmitting && isFormComplete,
                    action: _handleSubmit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const _availableLevels = <Level>[
  Level.Beginner,
  Level.Basic,
  Level.Intermediate,
  Level.Fluent,
];

class _OnboardingMenuOption<T> {
  const _OnboardingMenuOption({
    required this.value,
    required this.label,
    this.selected = false,
  });

  final T value;
  final String label;
  final bool selected;
}
