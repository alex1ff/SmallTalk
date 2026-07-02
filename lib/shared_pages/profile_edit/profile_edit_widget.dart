import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/firebase_storage/storage.dart';
import '/backend/schema/enums/enums.dart';
import '/components/profile_avatar_picker.dart';
import '/components/profile_dropdown_menu_item.dart';
import '/components/profile_edit_fields.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/upload_data.dart';
import '/components/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'dart:async';
import 'dart:math' as math;
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter/material.dart';
import 'profile_edit_model.dart';
export 'profile_edit_model.dart';

class ProfileEditWidget extends StatefulWidget {
  const ProfileEditWidget({super.key});

  static String routeName = 'Profile_edit';
  static String routePath = '/profileEdit';

  @override
  State<ProfileEditWidget> createState() => _ProfileEditWidgetState();
}

class _ProfileEditWidgetState extends State<ProfileEditWidget> {
  late ProfileEditModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  Gender? _selectedGender;
  CountryStruct? _selectedCountry;
  LanguageStruct? _selectedLearningLanguage;
  LanguageStruct? _selectedInstructionLanguage;
  LanguageStruct? _selectedNativeLanguage;
  Level? _selectedLevel;
  List<String> _selectedPurpose = [];
  bool _hasSyncedUserSnapshot = false;
  bool _isGenderMenuOpen = false;
  bool _isCountryMenuOpen = false;
  bool _isLearningLanguageMenuOpen = false;
  bool _isInstructionLanguageMenuOpen = false;
  bool _isNativeLanguageMenuOpen = false;
  bool _isLevelMenuOpen = false;
  bool _isPurposeMenuOpen = false;
  bool _isSyncingUserSnapshot = false;
  Timer? _nameSaveDebounce;
  Timer? _aboutSaveDebounce;
  String _lastSavedNameText = '';
  String _lastSavedAboutText = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileEditModel());

    _model.nameTextController1 ??=
        TextEditingController(text: currentUserDisplayName);
    _lastSavedNameText = currentUserDisplayName.trim();
    _model.nameTextController1?.addListener(_handleNameTextChanged);
    _model.nameFocusNode1 ??= FocusNode();
    _model.nameFocusNode1?.addListener(_handleNameFocusChanged);

    _model.genderTextController1 ??= TextEditingController();
    _model.genderFocusNode1 ??= FocusNode();

    _model.langLTextController ??= TextEditingController();
    _model.langLFocusNode ??= FocusNode();

    _model.levelLTextController ??= TextEditingController();
    _model.levelLFocusNode ??= FocusNode();

    _model.targTextController ??= TextEditingController(
      text: _formatPurpose(currentUserDocument?.purpose.toList() ?? []),
    );
    _model.targFocusNode ??= FocusNode();

    _model.nameTextController2 ??=
        TextEditingController(text: currentUserDisplayName);
    _model.nameTextController2?.addListener(_handleNameTextChanged);
    _model.nameFocusNode2 ??= FocusNode();
    _model.nameFocusNode2?.addListener(_handleNameFocusChanged);

    _model.genderTextController2 ??= TextEditingController();
    _model.genderFocusNode2 ??= FocusNode();

    _model.aboutTextController ??= TextEditingController(
      text: valueOrDefault(currentUserDocument?.aboutMe, ''),
    );
    _lastSavedAboutText = _model.aboutTextController?.text ?? '';
    _model.aboutTextController?.addListener(_handleAboutTextChanged);
    _model.aboutFocusNode ??= FocusNode();
    _model.aboutFocusNode?.addListener(_handleAboutFocusChanged);

    _model.nSLangTextController ??= TextEditingController();
    _model.nSLangFocusNode ??= FocusNode();

    _model.nSLang2TextController ??= TextEditingController();
    _model.nSLang2FocusNode ??= FocusNode();

    _model.countryNSTextController ??= TextEditingController();
    _model.countryNSFocusNode ??= FocusNode();

    WidgetsBinding.instance.addPostFrameCallback((_) => safeSetState(() {
          _syncTextControllersFromUser();
        }));
  }

  @override
  void dispose() {
    unawaited(_saveNameIfNeeded(showError: false));
    unawaited(_saveAboutIfNeeded(showError: false));
    _nameSaveDebounce?.cancel();
    _aboutSaveDebounce?.cancel();
    _model.nameTextController1?.removeListener(_handleNameTextChanged);
    _model.nameTextController2?.removeListener(_handleNameTextChanged);
    _model.nameFocusNode1?.removeListener(_handleNameFocusChanged);
    _model.nameFocusNode2?.removeListener(_handleNameFocusChanged);
    _model.aboutTextController?.removeListener(_handleAboutTextChanged);
    _model.aboutFocusNode?.removeListener(_handleAboutFocusChanged);
    _model.dispose();
    super.dispose();
  }

  void _syncTextControllersFromUser() {
    _isSyncingUserSnapshot = true;
    _model.nameTextController1?.text = currentUserDisplayName;
    _model.nameTextController2?.text = currentUserDisplayName;
    _selectedGender = currentUserDocument?.gender;
    _selectedCountry = currentUserDocument?.countryNS;
    _selectedLevel = currentUserDocument?.level;
    _selectedPurpose = currentUserDocument?.purpose.toList() ?? [];
    _model.genderTextController1?.text = _localizedGender(_selectedGender);
    _model.langLTextController?.text =
        _localizedLanguage(currentUserDocument?.learningLanguage);
    _selectedLearningLanguage = currentUserDocument?.learningLanguage;
    _model.levelLTextController?.text = _localizedLevel(_selectedLevel);
    _model.targTextController?.text = _formatPurpose(_selectedPurpose);
    _model.genderTextController2?.text = _localizedGender(_selectedGender);
    _lastSavedNameText = currentUserDisplayName.trim();
    _lastSavedAboutText = valueOrDefault(currentUserDocument?.aboutMe, '');
    _model.aboutTextController?.text = _lastSavedAboutText;
    _model.nSLangTextController?.text =
        _localizedLanguage(currentUserDocument?.languageInstructionNS);
    _selectedInstructionLanguage = currentUserDocument?.languageInstructionNS;
    _model.nSLang2TextController?.text =
        _localizedLanguage(currentUserDocument?.nativeLanguageNS);
    _selectedNativeLanguage = currentUserDocument?.nativeLanguageNS;
    _model.countryNSTextController?.text = _localizedCountry(_selectedCountry);
    _isSyncingUserSnapshot = false;
  }

  void _handleNameTextChanged() {
    if (_isSyncingUserSnapshot) {
      return;
    }
    _nameSaveDebounce?.cancel();
    _nameSaveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveNameIfNeeded());
    });
  }

  void _handleNameFocusChanged() {
    if ((_model.nameFocusNode1?.hasFocus ?? false) ||
        (_model.nameFocusNode2?.hasFocus ?? false)) {
      return;
    }

    _nameSaveDebounce?.cancel();
    unawaited(_saveNameIfNeeded());
  }

  TextEditingController? _currentNameController() {
    final isStudent = currentUserDocument?.role == UserRole.student;
    return isStudent ? _model.nameTextController1 : _model.nameTextController2;
  }

  Map<String, dynamic> _profileUserUpdate(Map<String, dynamic> data) {
    if (currentUserDocument?.role != UserRole.student) {
      return data;
    }

    return {
      ...data,
      'availabilityToday': FieldValue.delete(),
    };
  }

  Future<bool> _saveNameIfNeeded({bool showError = true}) async {
    final name = _currentNameController()?.text.trim() ?? '';
    if (name == _lastSavedNameText || currentUserReference == null) {
      return true;
    }

    if (name.isEmpty) {
      if (showError && mounted) {
        await actions.showTopNotification(
          context,
          'Пожалуйста, представьтесь',
          '',
          true,
        );
      }
      return false;
    }

    if (!functions.isValidName(name)) {
      if (showError && mounted) {
        await actions.showTopNotification(context, 'Неверное имя', '', true);
      }
      return false;
    }

    try {
      await currentUserReference!.update(_profileUserUpdate(
        createUsersRecordData(
          displayName: name,
        ),
      ));
      _lastSavedNameText = name;
      return true;
    } catch (error) {
      if (showError && mounted) {
        await actions.showTopNotification(
          context,
          'Не удалось сохранить имя',
          '',
          true,
        );
      }
      return false;
    }
  }

  void _handleAboutTextChanged() {
    if (_isSyncingUserSnapshot ||
        currentUserDocument?.role == UserRole.student) {
      return;
    }

    _aboutSaveDebounce?.cancel();
    _aboutSaveDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(_saveAboutIfNeeded());
    });
  }

  void _handleAboutFocusChanged() {
    if (_model.aboutFocusNode?.hasFocus ?? false) {
      return;
    }

    _aboutSaveDebounce?.cancel();
    unawaited(_saveAboutIfNeeded());
  }

  Future<bool> _saveAboutIfNeeded({bool showError = true}) async {
    final about = _model.aboutTextController?.text.trim() ?? '';
    if (about == _lastSavedAboutText.trim() ||
        currentUserReference == null ||
        currentUserDocument?.role == UserRole.student) {
      return true;
    }

    try {
      await currentUserReference!.update(_profileUserUpdate(
        createUsersRecordData(aboutMe: about),
      ));
      _lastSavedAboutText = about;
      return true;
    } catch (error) {
      if (showError && mounted) {
        await actions.showTopNotification(
          context,
          'Не удалось сохранить описание',
          '',
          true,
        );
      }
      return false;
    }
  }

  Future<void> _runOptimisticProfileUpdate({
    required VoidCallback apply,
    required VoidCallback restore,
    required Future<void> Function() persist,
    required String errorMessage,
  }) async {
    safeSetState(apply);
    try {
      await persist();
    } catch (error) {
      if (!mounted) {
        return;
      }
      safeSetState(restore);
      await actions.showTopNotification(context, errorMessage, '', true);
    }
  }

  String _localizedGender(Gender? gender) {
    if (gender == null) {
      return '';
    }
    return FFLocalizations.of(context).getVariableText(
      ruText: gender == Gender.male ? 'Мужской' : 'Женский',
      enText: gender.name,
    );
  }

  String _localizedLanguage(LanguageStruct? language) {
    if (language == null) {
      return '';
    }
    return FFLocalizations.of(context).getVariableText(
      ruText: language.nameRu,
      enText: language.nameEn,
    );
  }

  String _localizedCountry(CountryStruct? country) {
    if (country == null) {
      return '';
    }
    return FFLocalizations.of(context).getVariableText(
      ruText: country.nameRu,
      enText: country.nameEn,
    );
  }

  String _localizedLevel(Level? level) {
    return FFLocalizations.of(context).getVariableText(
      ruText: () {
        if (level == Level.Beginner) {
          return 'Начальный';
        } else if (level == Level.Basic) {
          return 'Базовый';
        } else if (level == Level.Intermediate) {
          return 'Уверенный';
        } else if (level == Level.Fluent) {
          return 'Свободно';
        }
        return '';
      }(),
      enText: level?.name ?? '',
    );
  }

  String _formatPurpose(List<String> purpose) {
    if (purpose.isEmpty) {
      return '';
    }
    if (purpose.length == 1) {
      return purpose.first;
    }
    return '${purpose.first}, +${purpose.length - 1}';
  }

  Future<void> _pickPhoto() async {
    final selectedMedia = await selectMedia(
      maxWidth: 500.00,
      maxHeight: 500.00,
      imageQuality: 95,
      mediaSource: MediaSource.photoGallery,
      multiImage: false,
    );
    if (selectedMedia == null ||
        !selectedMedia
            .every((m) => validateFileFormat(m.storagePath, context))) {
      return;
    }

    safeSetState(() => _model.isDataUploading_uploadData4bs = true);
    var selectedUploadedFiles = <FFUploadedFile>[];
    var downloadUrls = <String>[];
    try {
      selectedUploadedFiles = selectedMedia
          .map(
            (m) => FFUploadedFile(
              name: m.storagePath.split('/').last,
              bytes: m.bytes,
              height: m.dimensions?.height,
              width: m.dimensions?.width,
              blurHash: m.blurHash,
              originalFilename: m.originalFilename,
            ),
          )
          .toList();

      downloadUrls = (await Future.wait(
        selectedMedia.map((m) async => uploadData(m.storagePath, m.bytes)),
      ))
          .where((u) => u != null)
          .map((u) => u!)
          .toList();
    } finally {
      safeSetState(() => _model.isDataUploading_uploadData4bs = false);
    }

    if (selectedUploadedFiles.length != selectedMedia.length ||
        downloadUrls.length != selectedMedia.length) {
      safeSetState(() {});
      return;
    }

    safeSetState(() {
      _model.uploadedLocalFile_uploadData4bs = selectedUploadedFiles.first;
      _model.uploadedFileUrl_uploadData4bs = downloadUrls.first;
    });

    if (_model.uploadedFileUrl_uploadData4bs.isNotEmpty) {
      await currentUserReference!.update(
        _profileUserUpdate(
          createUsersRecordData(
            photoUrl: _model.uploadedFileUrl_uploadData4bs,
          ),
        ),
      );
    }
  }

  Future<T?> _showProfileEditOptionsMenu<T>(
    BuildContext anchorContext, {
    required List<_ProfileEditMenuOption<T>> options,
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

  List<CountryStruct> _countryOptions() {
    final countries = functions.countriesList().toList(growable: true)
      ..sort((left, right) => left.index.compareTo(right.index));
    final selectedCountry = _selectedCountry ?? currentUserDocument?.countryNS;
    if (selectedCountry != null &&
        !countries.any((country) => _sameCountry(country, selectedCountry))) {
      countries.insert(0, selectedCountry);
    }
    return countries;
  }

  List<LanguageStruct> _languageOptions(LanguageStruct? selectedLanguage) {
    final languages = FFAppState().languagesList.toList(growable: true);
    if (languages.isEmpty) {
      languages.addAll([
        LanguageStruct(code: 'en', nameEn: 'English', nameRu: 'Английский'),
        LanguageStruct(code: 'ru', nameEn: 'Russian', nameRu: 'Русский'),
      ]);
    }
    if (selectedLanguage != null &&
        !languages
            .any((language) => _sameLanguage(language, selectedLanguage))) {
      languages.insert(0, selectedLanguage);
    }
    return languages;
  }

  List<_ProfilePurposeOption> _purposeOptions() {
    return const [
      _ProfilePurposeOption(
        value: 'Путешествия',
        ruLabel: 'Путешествия',
        enLabel: 'Travel',
      ),
      _ProfilePurposeOption(
        value: 'Работа',
        ruLabel: 'Работа',
        enLabel: 'Work',
      ),
      _ProfilePurposeOption(
        value: 'Учеба',
        ruLabel: 'Учеба',
        enLabel: 'Study',
      ),
      _ProfilePurposeOption(
        value: 'Культура',
        ruLabel: 'Культура',
        enLabel: 'Culture',
      ),
      _ProfilePurposeOption(
        value: 'Общение',
        ruLabel: 'Общение',
        enLabel: 'Communication',
      ),
      _ProfilePurposeOption(
        value: 'Другое',
        ruLabel: 'Другое',
        enLabel: 'Other',
      ),
    ];
  }

  bool _sameCountry(CountryStruct? left, CountryStruct? right) {
    if (left == null || right == null) {
      return false;
    }
    final leftCode = left.code.trim().toLowerCase();
    final rightCode = right.code.trim().toLowerCase();
    return leftCode.isNotEmpty && leftCode == rightCode;
  }

  bool _sameLanguage(LanguageStruct? left, LanguageStruct? right) {
    if (left == null || right == null) {
      return false;
    }
    final leftCode = left.code.trim().toLowerCase();
    final rightCode = right.code.trim().toLowerCase();
    return leftCode.isNotEmpty && leftCode == rightCode;
  }

  String _countryMenuLabel(CountryStruct country) {
    final label = _localizedCountry(country);
    return label.trim().isNotEmpty ? label : country.code.toUpperCase();
  }

  String _languageMenuLabel(LanguageStruct language) {
    final label = _localizedLanguage(language);
    return label.trim().isNotEmpty ? label : language.code.toUpperCase();
  }

  String _levelMenuLabel(Level level) {
    final prefix = switch (level) {
      Level.Beginner => 'A1',
      Level.Basic => 'A2',
      Level.Intermediate => 'B1',
      Level.Fluent => 'C1',
    };
    return '$prefix — ${_localizedLevel(level)}';
  }

  String _purposeMenuLabel(_ProfilePurposeOption option) {
    return FFLocalizations.of(context).getVariableText(
      ruText: option.ruLabel,
      enText: option.enLabel,
    );
  }

  Future<void> _editGender(BuildContext anchorContext, bool isStudent) async {
    safeSetState(() => _isGenderMenuOpen = true);
    final selected = await _showProfileEditOptionsMenu<Gender>(
      anchorContext,
      options: [
        _ProfileEditMenuOption<Gender>(
          value: Gender.female,
          label: _localizedGender(Gender.female),
          selected:
              (_selectedGender ?? currentUserDocument?.gender) == Gender.female,
        ),
        _ProfileEditMenuOption<Gender>(
          value: Gender.male,
          label: _localizedGender(Gender.male),
          selected:
              (_selectedGender ?? currentUserDocument?.gender) == Gender.male,
        ),
      ],
    );
    if (mounted) {
      safeSetState(() => _isGenderMenuOpen = false);
    }
    if (!mounted || selected == null || currentUserReference == null) {
      return;
    }

    if (selected != currentUserDocument?.gender) {
      await currentUserReference!.update(_profileUserUpdate(
        createUsersRecordData(
          gender: selected,
        ),
      ));
    }
    if (!mounted) {
      return;
    }
    safeSetState(() {
      _selectedGender = selected;
      final text = _localizedGender(selected);
      if (isStudent) {
        _model.genderTextController1?.text = text;
      } else {
        _model.genderTextController2?.text = text;
      }
    });
  }

  Future<void> _editCountry(BuildContext anchorContext) async {
    final currentCountry = _selectedCountry ?? currentUserDocument?.countryNS;
    safeSetState(() => _isCountryMenuOpen = true);
    final selected = await _showProfileEditOptionsMenu<CountryStruct>(
      anchorContext,
      options: _countryOptions()
          .map(
            (country) => _ProfileEditMenuOption<CountryStruct>(
              value: country,
              label: _countryMenuLabel(country),
              selected: _sameCountry(country, currentCountry),
            ),
          )
          .toList(growable: false),
    );
    if (mounted) {
      safeSetState(() => _isCountryMenuOpen = false);
    }
    if (!mounted || selected == null || currentUserReference == null) {
      return;
    }

    await _runOptimisticProfileUpdate(
      apply: () {
        _selectedCountry = selected;
        _model.countryNSTextController?.text = _localizedCountry(selected);
      },
      restore: () {
        _selectedCountry = currentCountry;
        _model.countryNSTextController?.text =
            _localizedCountry(currentCountry);
      },
      persist: () async {
        if (_sameCountry(selected, currentUserDocument?.countryNS)) {
          return;
        }
        await currentUserReference!.update(_profileUserUpdate(
          createUsersRecordData(
            countryNS: updateCountryStruct(
              selected,
              clearUnsetFields: false,
            ),
          ),
        ));
      },
      errorMessage: 'Не удалось обновить страну',
    );
  }

  Future<void> _editLearningLanguage(BuildContext anchorContext) async {
    final currentLanguage =
        _selectedLearningLanguage ?? currentUserDocument?.learningLanguage;
    safeSetState(() => _isLearningLanguageMenuOpen = true);
    final selected = await _showProfileEditOptionsMenu<LanguageStruct>(
      anchorContext,
      options: _languageOptions(currentLanguage)
          .map(
            (language) => _ProfileEditMenuOption<LanguageStruct>(
              value: language,
              label: _languageMenuLabel(language),
              selected: _sameLanguage(language, currentLanguage),
            ),
          )
          .toList(growable: false),
    );
    if (mounted) {
      safeSetState(() => _isLearningLanguageMenuOpen = false);
    }
    if (!mounted || selected == null || currentUserReference == null) {
      return;
    }

    await _runOptimisticProfileUpdate(
      apply: () {
        _selectedLearningLanguage = selected;
        _model.langLTextController?.text = _localizedLanguage(selected);
      },
      restore: () {
        _selectedLearningLanguage = currentLanguage;
        _model.langLTextController?.text = _localizedLanguage(currentLanguage);
      },
      persist: () async {
        if (_sameLanguage(selected, currentUserDocument?.learningLanguage)) {
          return;
        }
        await currentUserReference!.update(_profileUserUpdate(
          createUsersRecordData(
            learningLanguage: updateLanguageStruct(
              selected,
              clearUnsetFields: false,
            ),
          ),
        ));
      },
      errorMessage: 'Не удалось обновить язык изучения',
    );
  }

  Future<void> _editLevel(BuildContext anchorContext) async {
    final currentLevel = _selectedLevel ?? currentUserDocument?.level;
    safeSetState(() => _isLevelMenuOpen = true);
    final selected = await _showProfileEditOptionsMenu<Level>(
      anchorContext,
      options: Level.values
          .map(
            (level) => _ProfileEditMenuOption<Level>(
              value: level,
              label: _levelMenuLabel(level),
              selected: level == currentLevel,
            ),
          )
          .toList(growable: false),
    );
    if (mounted) {
      safeSetState(() => _isLevelMenuOpen = false);
    }
    if (!mounted || selected == null || currentUserReference == null) {
      return;
    }

    if (selected != currentUserDocument?.level) {
      await currentUserReference!.update(_profileUserUpdate(
        createUsersRecordData(
          level: selected,
        ),
      ));
    }
    if (!mounted) {
      return;
    }
    safeSetState(() {
      _selectedLevel = selected;
      _model.levelLTextController?.text = _localizedLevel(selected);
    });
  }

  Future<void> _editTarget(BuildContext anchorContext) async {
    final currentPurpose = (_selectedPurpose.isNotEmpty
            ? _selectedPurpose
            : currentUserDocument?.purpose.toList() ?? <String>[])
        .toList(growable: true);
    safeSetState(() => _isPurposeMenuOpen = true);
    final selected = await _showProfileEditOptionsMenu<String>(
      anchorContext,
      options: _purposeOptions()
          .map(
            (option) => _ProfileEditMenuOption<String>(
              value: option.value,
              label: _purposeMenuLabel(option),
              selected: currentPurpose.contains(option.value),
            ),
          )
          .toList(growable: false),
    );
    if (mounted) {
      safeSetState(() => _isPurposeMenuOpen = false);
    }
    if (!mounted || selected == null || currentUserReference == null) {
      return;
    }

    final nextPurpose = currentPurpose.toList(growable: true);
    if (nextPurpose.contains(selected)) {
      nextPurpose.remove(selected);
    } else {
      nextPurpose.add(selected);
    }

    if (nextPurpose.isEmpty) {
      await actions.showTopNotification(
        context,
        'Выберите минимум одну цель',
        '',
        true,
      );
      return;
    }

    await currentUserReference!.update(_profileUserUpdate({
      ...mapToFirestore({'purpose': nextPurpose}),
    }));
    if (!mounted) {
      return;
    }
    safeSetState(() {
      _selectedPurpose = nextPurpose;
      _model.targTextController?.text = _formatPurpose(nextPurpose);
    });
  }

  Future<void> _editInstructionLanguage(BuildContext anchorContext) async {
    final currentLanguage = _selectedInstructionLanguage ??
        currentUserDocument?.languageInstructionNS;
    safeSetState(() => _isInstructionLanguageMenuOpen = true);
    final selected = await _showProfileEditOptionsMenu<LanguageStruct>(
      anchorContext,
      options: _languageOptions(currentLanguage)
          .map(
            (language) => _ProfileEditMenuOption<LanguageStruct>(
              value: language,
              label: _languageMenuLabel(language),
              selected: _sameLanguage(language, currentLanguage),
            ),
          )
          .toList(growable: false),
    );
    if (mounted) {
      safeSetState(() => _isInstructionLanguageMenuOpen = false);
    }
    if (!mounted || selected == null || currentUserReference == null) {
      return;
    }

    await _runOptimisticProfileUpdate(
      apply: () {
        _selectedInstructionLanguage = selected;
        _model.nSLangTextController?.text = _localizedLanguage(selected);
      },
      restore: () {
        _selectedInstructionLanguage = currentLanguage;
        _model.nSLangTextController?.text = _localizedLanguage(currentLanguage);
      },
      persist: () async {
        if (_sameLanguage(
            selected, currentUserDocument?.languageInstructionNS)) {
          return;
        }
        await currentUserReference!.update(_profileUserUpdate(
          createUsersRecordData(
            languageInstructionNS: updateLanguageStruct(
              selected,
              clearUnsetFields: false,
            ),
          ),
        ));
      },
      errorMessage: 'Не удалось обновить язык обучения',
    );
  }

  Future<void> _editNativeLanguage(BuildContext anchorContext) async {
    final currentLanguage =
        _selectedNativeLanguage ?? currentUserDocument?.nativeLanguageNS;
    safeSetState(() => _isNativeLanguageMenuOpen = true);
    final selected = await _showProfileEditOptionsMenu<LanguageStruct>(
      anchorContext,
      options: _languageOptions(currentLanguage)
          .map(
            (language) => _ProfileEditMenuOption<LanguageStruct>(
              value: language,
              label: _languageMenuLabel(language),
              selected: _sameLanguage(language, currentLanguage),
            ),
          )
          .toList(growable: false),
    );
    if (mounted) {
      safeSetState(() => _isNativeLanguageMenuOpen = false);
    }
    if (!mounted || selected == null || currentUserReference == null) {
      return;
    }

    await _runOptimisticProfileUpdate(
      apply: () {
        _selectedNativeLanguage = selected;
        _model.nSLang2TextController?.text = _localizedLanguage(selected);
      },
      restore: () {
        _selectedNativeLanguage = currentLanguage;
        _model.nSLang2TextController?.text =
            _localizedLanguage(currentLanguage);
      },
      persist: () async {
        if (_sameLanguage(selected, currentUserDocument?.nativeLanguageNS)) {
          return;
        }
        await currentUserReference!.update(_profileUserUpdate(
          createUsersRecordData(
            nativeLanguageNS: updateLanguageStruct(
              selected,
              clearUnsetFields: false,
            ),
          ),
        ));
      },
      errorMessage: 'Не удалось обновить родной язык',
    );
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
        backgroundColor: ExpatlioDesign.background,
        body: AuthUserStreamWidget(
          builder: (context) {
            if (!_hasSyncedUserSnapshot && currentUserDocument != null) {
              _hasSyncedUserSnapshot = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  safeSetState(() => _syncTextControllersFromUser());
                }
              });
            }
            final isStudent = currentUserDocument?.role == UserRole.student;
            return Column(
              children: [
                BasicPageHeader(
                  title: FFLocalizations.of(context).getVariableText(
                    ruText: 'Редактировать профиль',
                    enText: 'Edit profile',
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    primary: false,
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760.0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                            ExpatlioDesign.pagePadding,
                            ExpatlioDesign.space24,
                            ExpatlioDesign.pagePadding,
                            ExpatlioDesign.space24,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ProfileAvatarPicker(onTap: _pickPhoto),
                              const SizedBox(height: ExpatlioDesign.space32),
                              Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'ЛИЧНЫЕ ДАННЫЕ',
                                  enText: 'PERSONAL DATA',
                                ),
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  color: ExpatlioDesign.inactive,
                                  size: 14.0,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: ExpatlioDesign.space12),
                              Container(
                                decoration: BoxDecoration(
                                  color: ExpatlioDesign.card,
                                  borderRadius: BorderRadius.circular(
                                      ExpatlioDesign.radiusLarge),
                                  border: Border.all(
                                    color: ExpatlioDesign.border,
                                    width: 1.0,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                      ExpatlioDesign.space16,
                                      ExpatlioDesign.space16,
                                      ExpatlioDesign.space16,
                                      ExpatlioDesign.space20),
                                  child: Column(
                                    children: isStudent
                                        ? _studentFields(context)
                                        : _nativeSpeakerFields(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _studentFields(BuildContext context) {
    return [
      ProfileNameField(
        controller: _model.nameTextController1,
        focusNode: _model.nameFocusNode1,
      ),
      ProfileReadOnlyField(
        label: 'Email',
        value: currentUserEmail,
        enabled: false,
      ),
      ProfileReadOnlyField(
        label: FFLocalizations.of(context).getText('qupouufi' /* Пол */),
        value: _model.genderTextController1?.text ?? '',
        menuOpen: _isGenderMenuOpen,
        onTap: (fieldContext) => _editGender(fieldContext, true),
      ),
      ProfileReadOnlyField(
        label: FFLocalizations.of(context).getText('kem0gdl9' /* Страна */),
        value: _model.countryNSTextController?.text ?? '',
        menuOpen: _isCountryMenuOpen,
        onTap: _editCountry,
      ),
      ProfileReadOnlyField(
        label: FFLocalizations.of(context).getText(
          'ro4cvtou' /* Язык изучения */,
        ),
        value: _model.langLTextController?.text ?? '',
        menuOpen: _isLearningLanguageMenuOpen,
        onTap: _editLearningLanguage,
      ),
      ProfileReadOnlyField(
        label: FFLocalizations.of(context).getText('bo9k12fd' /* Уровень */),
        value: _model.levelLTextController?.text ?? '',
        menuOpen: _isLevelMenuOpen,
        onTap: _editLevel,
      ),
      ProfileReadOnlyField(
        label: FFLocalizations.of(context).getText(
          '3um2nt3q' /* Цели изучения */,
        ),
        value: _model.targTextController?.text ?? '',
        menuOpen: _isPurposeMenuOpen,
        onTap: _editTarget,
      ),
    ].divide(const SizedBox(height: ExpatlioDesign.space16));
  }

  List<Widget> _nativeSpeakerFields(BuildContext context) {
    return [
      ProfileNameField(
        controller: _model.nameTextController2,
        focusNode: _model.nameFocusNode2,
      ),
      ProfileReadOnlyField(
        label: 'Email',
        value: currentUserEmail,
        enabled: false,
      ),
      ProfileReadOnlyField(
        label: FFLocalizations.of(context).getText('qupouufi' /* Пол */),
        value: _model.genderTextController2?.text ?? '',
        menuOpen: _isGenderMenuOpen,
        onTap: (fieldContext) => _editGender(fieldContext, false),
      ),
      ProfileMultilineTextField(
        label: FFLocalizations.of(context).getText('53sloz8g' /* О себе */),
        controller: _model.aboutTextController,
        focusNode: _model.aboutFocusNode,
        hintText: FFLocalizations.of(context).getText(
          'tjmgsp1u' /* Люблю готовить, изучаю испанск... */,
        ),
      ),
      ProfileReadOnlyField(
        label: FFLocalizations.of(context).getText(
          '5s3nn50b' /* Язык, которому обучаю */,
        ),
        value: _model.nSLangTextController?.text ?? '',
        menuOpen: _isInstructionLanguageMenuOpen,
        onTap: _editInstructionLanguage,
      ),
      ProfileReadOnlyField(
        label: FFLocalizations.of(context).getText('vi9zv6jp' /* Мой язык */),
        value: _model.nSLang2TextController?.text ?? '',
        menuOpen: _isNativeLanguageMenuOpen,
        onTap: _editNativeLanguage,
      ),
      ProfileReadOnlyField(
        label: FFLocalizations.of(context).getText('kem0gdl9' /* Страна */),
        value: _model.countryNSTextController?.text ?? '',
        menuOpen: _isCountryMenuOpen,
        onTap: _editCountry,
      ),
    ].divide(const SizedBox(height: ExpatlioDesign.space16));
  }
}

class _ProfileEditMenuOption<T> {
  const _ProfileEditMenuOption({
    required this.value,
    required this.label,
    this.selected = false,
  });

  final T value;
  final String label;
  final bool selected;
}

class _ProfilePurposeOption {
  const _ProfilePurposeOption({
    required this.value,
    required this.ruLabel,
    required this.enLabel,
  });

  final String value;
  final String ruLabel;
  final String enLabel;
}
