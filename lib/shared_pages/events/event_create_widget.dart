import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_action_error_mapper.dart';
import '/services/event_actions_repository.dart';
import '/services/event_city_catalog.dart';
import '/services/event_city_chip_source.dart';
import '/services/event_city_resolution.dart';
import '/services/event_city_selection_source.dart';
import '/services/event_selected_city_state.dart';
import '/services/event_start_time_validation.dart';
import '/services/event_temporary_city_selection.dart';
import '/services/event_language_catalog.dart';
import '/services/event_level_helper.dart';

const ValueKey<String> eventCreateTitleLabelKey =
    ValueKey<String>('event_create_title_label');
const ValueKey<String> eventCreateTitleFieldSemanticsKey =
    ValueKey<String>('event_create_title_field_semantics');
const ValueKey<String> eventCreateTitleFieldKey =
    ValueKey<String>('event_create_title_field');
const ValueKey<String> eventCreateDescriptionLabelKey =
    ValueKey<String>('event_create_description_label');
const ValueKey<String> eventCreateDescriptionFieldSemanticsKey =
    ValueKey<String>('event_create_description_field_semantics');
const ValueKey<String> eventCreateDescriptionFieldKey =
    ValueKey<String>('event_create_description_field');
const ValueKey<String> eventCreateLanguageLabelKey =
    ValueKey<String>('event_create_language_label');
const ValueKey<String> eventCreateLanguageSelectorSemanticsKey =
    ValueKey<String>('event_create_language_selector_semantics');
const ValueKey<String> eventCreateLanguageSelectorKey =
    ValueKey<String>('event_create_language_selector');
const ValueKey<String> eventCreateLanguageSheetKey =
    ValueKey<String>('event_create_language_sheet');
const ValueKey<String> eventCreateLevelLabelKey =
    ValueKey<String>('event_create_level_label');
const ValueKey<String> eventCreateLevelSelectorSemanticsKey =
    ValueKey<String>('event_create_level_selector_semantics');
const ValueKey<String> eventCreateLevelSelectorKey =
    ValueKey<String>('event_create_level_selector');
const ValueKey<String> eventCreateLevelSheetKey =
    ValueKey<String>('event_create_level_sheet');
const ValueKey<String> eventCreateLevelDoneButtonKey =
    ValueKey<String>('event_create_level_done_button');
const ValueKey<String> eventCreateCityLabelKey =
    ValueKey<String>('event_create_city_label');
const ValueKey<String> eventCreateCitySelectorSemanticsKey =
    ValueKey<String>('event_create_city_selector_semantics');
const ValueKey<String> eventCreateCitySelectorKey =
    ValueKey<String>('event_create_city_selector');
const ValueKey<String> eventCreateCitySheetKey =
    ValueKey<String>('event_create_city_sheet');
const ValueKey<String> eventCreateCitySearchFieldKey =
    ValueKey<String>('event_create_city_search_field');
const ValueKey<String> eventCreateLocationLabelKey =
    ValueKey<String>('event_create_location_label');
const ValueKey<String> eventCreateLocationFieldSemanticsKey =
    ValueKey<String>('event_create_location_field_semantics');
const ValueKey<String> eventCreateLocationFieldKey =
    ValueKey<String>('event_create_location_field');
const ValueKey<String> eventCreateDateLabelKey =
    ValueKey<String>('event_create_date_label');
const ValueKey<String> eventCreateDateSelectorSemanticsKey =
    ValueKey<String>('event_create_date_selector_semantics');
const ValueKey<String> eventCreateDateSelectorKey =
    ValueKey<String>('event_create_date_selector');
const ValueKey<String> eventCreateTimeLabelKey =
    ValueKey<String>('event_create_time_label');
const ValueKey<String> eventCreateTimeSelectorSemanticsKey =
    ValueKey<String>('event_create_time_selector_semantics');
const ValueKey<String> eventCreateTimeSelectorKey =
    ValueKey<String>('event_create_time_selector');
const ValueKey<String> eventCreateStartTimeErrorKey =
    ValueKey<String>('event_create_start_time_error');
const ValueKey<String> eventCreateCapacityLabelKey =
    ValueKey<String>('event_create_capacity_label');
const ValueKey<String> eventCreateCapacityFieldSemanticsKey =
    ValueKey<String>('event_create_capacity_field_semantics');
const ValueKey<String> eventCreateCapacityFieldKey =
    ValueKey<String>('event_create_capacity_field');
const ValueKey<String> eventCreateSubmitButtonKey =
    ValueKey<String>('event_create_submit_button');
const ValueKey<String> eventCreateSubmitErrorKey =
    ValueKey<String>('event_create_submit_error');
const ValueKey<String> eventCreateBackButtonKey =
    ValueKey<String>('event_create_back_button');
const ValueKey<String> eventCreateDiscardDialogKey =
    ValueKey<String>('event_create_discard_dialog');
const ValueKey<String> eventCreateDiscardKeepEditingButtonKey =
    ValueKey<String>('event_create_discard_keep_editing_button');
const ValueKey<String> eventCreateDiscardConfirmButtonKey =
    ValueKey<String>('event_create_discard_confirm_button');
const TimeOfDay _eventCreateDefaultTime = TimeOfDay(hour: 18, minute: 0);
const String _eventCreateDefaultLanguageCode = 'en';
const int _eventCreateDefaultCapacity = 10;
const int _eventCreateMinCapacity = 2;
const int _eventCreateMaxCapacity = 50;

ValueKey<String> eventCreateLanguageOptionKey(String code) =>
    ValueKey<String>('event_create_language_option_$code');

ValueKey<String> eventCreateLevelMinOptionKey(String level) =>
    ValueKey<String>('event_create_level_min_option_$level');

ValueKey<String> eventCreateLevelMaxOptionKey(String level) =>
    ValueKey<String>('event_create_level_max_option_$level');

ValueKey<String> eventCreateCityChipKey(EventCity city) => ValueKey<String>(
    'event_create_city_chip_${city.countryCode}_${city.cityKey}');

ValueKey<String> eventCreateCityOptionKey(EventCity city) => ValueKey<String>(
    'event_create_city_option_${city.countryCode}_${city.cityKey}');

class EventCreateLanguageDraft {
  const EventCreateLanguageDraft({
    required this.languageCode,
  });

  final String languageCode;
}

class EventCreateTitleDraft {
  const EventCreateTitleDraft({
    required this.title,
  });

  final String title;
}

class EventCreateDescriptionDraft {
  const EventCreateDescriptionDraft({
    required this.description,
  });

  final String description;
}

class EventCreateLevelDraft {
  const EventCreateLevelDraft({
    required this.levelMin,
    required this.levelMax,
  });

  final String levelMin;
  final String levelMax;
}

class EventCreateCityDraft {
  const EventCreateCityDraft({
    required this.countryCode,
    required this.cityKey,
    required this.timeZoneId,
    required this.citySource,
  });

  final String countryCode;
  final String cityKey;
  final String timeZoneId;
  final String citySource;

  String get identity => '$countryCode:$cityKey';
}

class EventCreateLocationDraft {
  const EventCreateLocationDraft({
    required this.locationName,
    this.locationGeoPoint,
  });

  final String locationName;
  final LatLng? locationGeoPoint;
}

class EventCreateDateDraft {
  const EventCreateDateDraft({
    required this.localDate,
  });

  final DateTime localDate;
}

class EventCreateTimeDraft {
  const EventCreateTimeDraft({
    required this.localTime,
  });

  final TimeOfDay localTime;
}

class EventCreateCapacityDraft {
  const EventCreateCapacityDraft({
    required this.capacity,
  });

  final int capacity;
}

class EventCreateWidget extends StatefulWidget {
  const EventCreateWidget({
    super.key,
    this.languageCatalogOverride,
    this.cityCatalogOverride,
    this.initialTitle,
    this.initialDescription,
    this.initialLanguageCode,
    this.initialLevelMin,
    this.initialLevelMax,
    this.initialSelectedCity,
    this.initialLocationName,
    this.initialDate,
    this.initialTime,
    this.initialCapacity,
    this.currentUtcProvider,
    this.createEventInvoker,
    this.createRequestIdGenerator,
    this.onLanguageCodeChanged,
    this.onTitleDraftChanged,
    this.onDescriptionDraftChanged,
    this.onLanguageDraftChanged,
    this.onLevelDraftChanged,
    this.onCityDraftChanged,
    this.onLocationDraftChanged,
    this.onDateDraftChanged,
    this.onTimeDraftChanged,
    this.onCapacityDraftChanged,
    this.onSubmitFailureChanged,
  });

  static String routeName = 'eventCreate';
  static String routePath = '/events/create';

  final EventLanguageCatalog? languageCatalogOverride;
  final EventCityCatalog? cityCatalogOverride;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialLanguageCode;
  final String? initialLevelMin;
  final String? initialLevelMax;
  final EventSelectedCity? initialSelectedCity;
  final String? initialLocationName;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final int? initialCapacity;
  final DateTime Function()? currentUtcProvider;
  final EventCallableInvoker? createEventInvoker;
  final String Function()? createRequestIdGenerator;
  final ValueChanged<String>? onLanguageCodeChanged;
  final ValueChanged<EventCreateTitleDraft>? onTitleDraftChanged;
  final ValueChanged<EventCreateDescriptionDraft>? onDescriptionDraftChanged;
  final ValueChanged<EventCreateLanguageDraft>? onLanguageDraftChanged;
  final ValueChanged<EventCreateLevelDraft>? onLevelDraftChanged;
  final ValueChanged<EventCreateCityDraft>? onCityDraftChanged;
  final ValueChanged<EventCreateLocationDraft>? onLocationDraftChanged;
  final ValueChanged<EventCreateDateDraft>? onDateDraftChanged;
  final ValueChanged<EventCreateTimeDraft>? onTimeDraftChanged;
  final ValueChanged<EventCreateCapacityDraft>? onCapacityDraftChanged;
  final ValueChanged<EventActionFailure?>? onSubmitFailureChanged;

  @override
  State<EventCreateWidget> createState() => _EventCreateWidgetState();
}

class _EventCreateWidgetState extends State<EventCreateWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleTextController = TextEditingController();
  final _descriptionTextController = TextEditingController();
  final _locationTextController = TextEditingController();
  final _capacityTextController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _descriptionFocusNode = FocusNode();
  final _locationFocusNode = FocusNode();
  final _capacityFocusNode = FocusNode();
  Future<EventLanguageCatalog>? _languageCatalogFuture;
  AssetBundle? _languageCatalogBundle;
  Future<EventCityCatalog>? _cityCatalogFuture;
  AssetBundle? _cityCatalogBundle;
  Future<List<EventCityChip>>? _cityChipsFuture;
  EventCityCatalog? _cityChipsCatalog;
  String? _cityChipsCountryCodeHint;
  String? _cityChipsSelectedIdentity;
  String? _selectedLanguageCode;
  String? _selectedLevelMin;
  String? _selectedLevelMax;
  EventSelectedCity? _selectedCity;
  EventSelectedCity? _lastVisibleSelectedCity;
  late DateTime _selectedDate;
  late DateTime _pristineSelectedDate;
  late TimeOfDay _selectedTime;
  String? _lastEmittedTitleDraftText;
  String? _pendingTitleDraftText;
  bool _titleDraftCallbackScheduled = false;
  String? _lastEmittedDescriptionDraftText;
  String? _pendingDescriptionDraftText;
  bool _descriptionDraftCallbackScheduled = false;
  String? _lastEmittedLanguageDraftCode;
  String? _pendingLanguageDraftCode;
  bool _languageDraftCallbackScheduled = false;
  String? _lastEmittedLevelDraftKey;
  EventLevelRange? _pendingLevelDraftRange;
  bool _levelDraftCallbackScheduled = false;
  String? _lastEmittedCityDraftKey;
  EventSelectedCity? _pendingCityDraft;
  bool _cityDraftCallbackScheduled = false;
  String? _lastEmittedLocationDraftName;
  String? _pendingLocationDraftName;
  bool _locationDraftCallbackScheduled = false;
  String? _lastEmittedDateDraftKey;
  DateTime? _pendingDateDraft;
  bool _dateDraftCallbackScheduled = false;
  String? _lastEmittedTimeDraftKey;
  TimeOfDay? _pendingTimeDraft;
  bool _timeDraftCallbackScheduled = false;
  int? _lastEmittedCapacityDraft;
  int? _pendingCapacityDraft;
  bool _capacityDraftCallbackScheduled = false;
  bool _hasAttemptedSubmit = false;
  bool _isSubmitting = false;
  bool _allowCreateFormExit = false;
  bool _discardDialogOpen = false;
  String? _startTimeErrorText;
  EventActionFailure? _submitFailure;
  String? _activeCreateRequestId;
  String? _activeCreatePayloadSignature;

  @override
  void initState() {
    super.initState();
    _titleTextController.text = widget.initialTitle ?? '';
    _titleTextController.addListener(_handleTitleTextChanged);
    _descriptionTextController.text = widget.initialDescription ?? '';
    _descriptionTextController.addListener(_handleDescriptionTextChanged);
    _selectedLanguageCode = widget.initialLanguageCode;
    _selectedLevelMin = widget.initialLevelMin;
    _selectedLevelMax = widget.initialLevelMax;
    _selectedCity = widget.initialSelectedCity;
    _locationTextController.text =
        _normalizeEventCreateLocationName(widget.initialLocationName ?? '');
    _locationTextController.addListener(_handleLocationTextChanged);
    _selectedDate = _eventCreateDateOnly(widget.initialDate ?? DateTime.now());
    _pristineSelectedDate = _selectedDate;
    _selectedTime = widget.initialTime ?? _eventCreateDefaultTime;
    _capacityTextController.text =
        _eventCreateCapacityText(widget.initialCapacity);
    _capacityTextController.addListener(_handleCapacityTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    final previousLanguageBundle = _languageCatalogBundle;
    final previousCityBundle = _cityCatalogBundle;
    _languageCatalogBundle = bundle;
    _cityCatalogBundle = bundle;
    if (_languageCatalogFuture == null ||
        (widget.languageCatalogOverride == null &&
            previousLanguageBundle != bundle)) {
      _languageCatalogFuture = _loadLanguageCatalog(bundle: bundle);
    }
    if (_cityCatalogFuture == null ||
        (widget.cityCatalogOverride == null && previousCityBundle != bundle)) {
      _cityCatalogFuture = _loadCityCatalog(bundle: bundle);
      _clearCityChipsCache();
    }
  }

  @override
  void didUpdateWidget(covariant EventCreateWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.languageCatalogOverride != widget.languageCatalogOverride) {
      _languageCatalogFuture = _loadLanguageCatalog(
        bundle: _languageCatalogBundle ?? DefaultAssetBundle.of(context),
      );
    }
    if (oldWidget.cityCatalogOverride != widget.cityCatalogOverride) {
      _cityCatalogFuture = _loadCityCatalog(
        bundle: _cityCatalogBundle ?? DefaultAssetBundle.of(context),
      );
      _clearCityChipsCache();
    }
    if (oldWidget.initialTitle != widget.initialTitle) {
      _titleTextController.text = widget.initialTitle ?? '';
    }
    if (oldWidget.initialDescription != widget.initialDescription) {
      _descriptionTextController.text = widget.initialDescription ?? '';
    }
    if (oldWidget.initialLanguageCode != widget.initialLanguageCode) {
      _selectedLanguageCode = widget.initialLanguageCode;
    }
    if (oldWidget.initialLevelMin != widget.initialLevelMin ||
        oldWidget.initialLevelMax != widget.initialLevelMax) {
      _selectedLevelMin = widget.initialLevelMin;
      _selectedLevelMax = widget.initialLevelMax;
    }
    if (oldWidget.initialSelectedCity != widget.initialSelectedCity) {
      _selectedCity = widget.initialSelectedCity;
      _startTimeErrorText = null;
      _clearCityChipsCache();
    }
    if (oldWidget.initialLocationName != widget.initialLocationName) {
      _locationTextController.text =
          _normalizeEventCreateLocationName(widget.initialLocationName ?? '');
    }
    if (oldWidget.initialDate != widget.initialDate) {
      _selectedDate = _eventCreateDateOnly(
        widget.initialDate ?? DateTime.now(),
      );
      _pristineSelectedDate = _selectedDate;
      _startTimeErrorText = null;
    }
    if (oldWidget.initialTime != widget.initialTime) {
      _selectedTime = widget.initialTime ?? _eventCreateDefaultTime;
      _startTimeErrorText = null;
    }
    if (oldWidget.initialCapacity != widget.initialCapacity) {
      _capacityTextController.text =
          _eventCreateCapacityText(widget.initialCapacity);
    }
  }

  @override
  void dispose() {
    _titleTextController.removeListener(_handleTitleTextChanged);
    _descriptionTextController.removeListener(_handleDescriptionTextChanged);
    _locationTextController.removeListener(_handleLocationTextChanged);
    _capacityTextController.removeListener(_handleCapacityTextChanged);
    _titleTextController.dispose();
    _descriptionTextController.dispose();
    _locationTextController.dispose();
    _capacityTextController.dispose();
    _titleFocusNode.dispose();
    _descriptionFocusNode.dispose();
    _locationFocusNode.dispose();
    _capacityFocusNode.dispose();
    super.dispose();
  }

  Future<EventLanguageCatalog> _loadLanguageCatalog({
    AssetBundle? bundle,
  }) async {
    final override = widget.languageCatalogOverride;
    if (override != null) {
      return override;
    }
    return EventLanguageCatalog.loadFromAsset(
      bundle: bundle ?? DefaultAssetBundle.of(context),
    );
  }

  Future<EventCityCatalog> _loadCityCatalog({
    AssetBundle? bundle,
  }) async {
    final override = widget.cityCatalogOverride;
    if (override != null) {
      return override;
    }
    return EventCityCatalog.loadFromAsset(
      bundle: bundle ?? DefaultAssetBundle.of(context),
    );
  }

  String _resolvedSelectedLanguageCode(EventLanguageCatalog catalog) {
    final selected = catalog.resolvePrimaryLanguageCode(_selectedLanguageCode);
    if (selected != null) {
      return selected;
    }
    final popular = catalog.popularLanguages(limit: 1);
    if (popular.isNotEmpty) {
      return popular.first.code;
    }
    return catalog.languages.first.code;
  }

  bool get _isCreateFormDirty {
    if (_titleTextController.text.trim().isNotEmpty ||
        _descriptionTextController.text.trim().isNotEmpty ||
        _normalizeEventCreateLocationName(_locationTextController.text)
            .isNotEmpty) {
      return true;
    }
    final selectedLanguageCode = _selectedLanguageCode?.trim();
    if (selectedLanguageCode != null &&
        selectedLanguageCode.isNotEmpty &&
        !_isEventCreateDefaultLanguageCode(selectedLanguageCode)) {
      return true;
    }
    final selectedLevelRange = _resolvedSelectedLevelRange();
    if (selectedLevelRange.levelMin != 'B1' ||
        selectedLevelRange.levelMax != 'C1') {
      return true;
    }
    final selectedCity = _selectedCity;
    if (selectedCity != null &&
        selectedCity.source != EventCitySelectionSource.profile) {
      return true;
    }
    if (_eventCreateDateDraftKey(_selectedDate) !=
        _eventCreateDateDraftKey(_pristineSelectedDate)) {
      return true;
    }
    if (_eventCreateTimeDraftKey(_selectedTime) !=
        _eventCreateTimeDraftKey(_eventCreateDefaultTime)) {
      return true;
    }
    if (_capacityTextController.text.trim() !=
        _eventCreateDefaultCapacity.toString()) {
      return true;
    }
    return false;
  }

  Future<void> _handleLeavePressed() async {
    if (_discardDialogOpen) {
      return;
    }
    if (!_isCreateFormDirty) {
      _leaveCreateForm();
      return;
    }
    final shouldDiscard = await _showDiscardCreateFormDialog();
    if (!mounted || !shouldDiscard) {
      return;
    }
    _leaveCreateForm();
  }

  void _leaveCreateForm() {
    if (!mounted) {
      return;
    }
    setState(() {
      _allowCreateFormExit = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.safePop();
      }
    });
  }

  Future<bool> _showDiscardCreateFormDialog() async {
    _discardDialogOpen = true;
    try {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: eventCreateDiscardDialogKey,
          title: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Закрыть форму?',
              enText: 'Leave create form?',
            ),
          ),
          content: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Заполненные данные будут потеряны.',
              enText: 'Entered details will be lost.',
            ),
          ),
          actions: [
            TextButton(
              key: eventCreateDiscardKeepEditingButtonKey,
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Остаться',
                  enText: 'Keep editing',
                ),
              ),
            ),
            TextButton(
              key: eventCreateDiscardConfirmButtonKey,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Закрыть',
                  enText: 'Discard',
                ),
              ),
            ),
          ],
        ),
      );
      return shouldDiscard ?? false;
    } finally {
      _discardDialogOpen = false;
    }
  }

  void _emitTitleDraftNow(String title) {
    _pendingTitleDraftText = null;
    if (_lastEmittedTitleDraftText == title) {
      return;
    }
    final onTitleDraftChanged = widget.onTitleDraftChanged;
    if (onTitleDraftChanged == null) {
      return;
    }
    _lastEmittedTitleDraftText = title;
    onTitleDraftChanged(
      EventCreateTitleDraft(title: title),
    );
  }

  void _queueTitleDraft(String title) {
    if (_lastEmittedTitleDraftText == title && _pendingTitleDraftText == null) {
      return;
    }
    _pendingTitleDraftText = title;
    if (_titleDraftCallbackScheduled) {
      return;
    }
    _titleDraftCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleDraftCallbackScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingTitle = _pendingTitleDraftText;
      if (pendingTitle == null || _lastEmittedTitleDraftText == pendingTitle) {
        return;
      }
      _emitTitleDraftNow(pendingTitle);
    });
  }

  void _handleTitleTextChanged() {
    _queueTitleDraft(_titleTextController.text);
  }

  void _emitDescriptionDraftNow(String description) {
    _pendingDescriptionDraftText = null;
    if (_lastEmittedDescriptionDraftText == description) {
      return;
    }
    final onDescriptionDraftChanged = widget.onDescriptionDraftChanged;
    if (onDescriptionDraftChanged == null) {
      return;
    }
    _lastEmittedDescriptionDraftText = description;
    onDescriptionDraftChanged(
      EventCreateDescriptionDraft(description: description),
    );
  }

  void _queueDescriptionDraft(String description) {
    if (_lastEmittedDescriptionDraftText == description &&
        _pendingDescriptionDraftText == null) {
      return;
    }
    _pendingDescriptionDraftText = description;
    if (_descriptionDraftCallbackScheduled) {
      return;
    }
    _descriptionDraftCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _descriptionDraftCallbackScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingDescription = _pendingDescriptionDraftText;
      if (pendingDescription == null ||
          _lastEmittedDescriptionDraftText == pendingDescription) {
        return;
      }
      _emitDescriptionDraftNow(pendingDescription);
    });
  }

  void _handleDescriptionTextChanged() {
    _queueDescriptionDraft(_descriptionTextController.text);
  }

  EventLevelRange _resolvedSelectedLevelRange() {
    final selectedLevelMin = _selectedLevelMin;
    final selectedLevelMax = _selectedLevelMax;
    if (selectedLevelMin != null &&
        selectedLevelMin.trim().isNotEmpty &&
        selectedLevelMax != null &&
        selectedLevelMax.trim().isNotEmpty) {
      final range = tryEventLevelRange(
        levelMin: selectedLevelMin,
        levelMax: selectedLevelMax,
      );
      if (range != null) {
        return range;
      }
    }
    if (selectedLevelMin != null && selectedLevelMin.trim().isNotEmpty) {
      final range = tryEventLevelRange(
        levelMin: selectedLevelMin,
        levelMax: selectedLevelMin,
      );
      if (range != null) {
        return range;
      }
    }
    if (selectedLevelMax != null && selectedLevelMax.trim().isNotEmpty) {
      final range = tryEventLevelRange(
        levelMin: selectedLevelMax,
        levelMax: selectedLevelMax,
      );
      if (range != null) {
        return range;
      }
    }
    return eventLevelRange(levelMin: 'B1', levelMax: 'C1');
  }

  void _emitLanguageDraftNow(String languageCode) {
    _pendingLanguageDraftCode = null;
    final onLanguageDraftChanged = widget.onLanguageDraftChanged;
    if (onLanguageDraftChanged == null) {
      return;
    }
    _lastEmittedLanguageDraftCode = languageCode;
    onLanguageDraftChanged(
      EventCreateLanguageDraft(languageCode: languageCode),
    );
  }

  void _queueLanguageDraft(String languageCode) {
    if (_lastEmittedLanguageDraftCode == languageCode &&
        _pendingLanguageDraftCode == null) {
      return;
    }
    _pendingLanguageDraftCode = languageCode;
    if (_languageDraftCallbackScheduled) {
      return;
    }
    _languageDraftCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _languageDraftCallbackScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingLanguageCode = _pendingLanguageDraftCode;
      if (pendingLanguageCode == null ||
          _lastEmittedLanguageDraftCode == pendingLanguageCode) {
        return;
      }
      _emitLanguageDraftNow(pendingLanguageCode);
    });
  }

  void _emitLevelDraftNow(EventLevelRange range) {
    _pendingLevelDraftRange = null;
    final draftKey = _eventCreateLevelDraftKey(range);
    if (_lastEmittedLevelDraftKey == draftKey) {
      return;
    }
    final onLevelDraftChanged = widget.onLevelDraftChanged;
    if (onLevelDraftChanged == null) {
      return;
    }
    _lastEmittedLevelDraftKey = draftKey;
    onLevelDraftChanged(
      EventCreateLevelDraft(
        levelMin: range.levelMin,
        levelMax: range.levelMax,
      ),
    );
  }

  void _emitCityDraftNow(EventSelectedCity selectedCity) {
    _pendingCityDraft = null;
    final draftKey = _eventCreateCityDraftKey(selectedCity);
    if (_lastEmittedCityDraftKey == draftKey) {
      return;
    }
    final onCityDraftChanged = widget.onCityDraftChanged;
    if (onCityDraftChanged == null) {
      return;
    }
    _lastEmittedCityDraftKey = draftKey;
    onCityDraftChanged(
      EventCreateCityDraft(
        countryCode: selectedCity.city.countryCode,
        cityKey: selectedCity.city.cityKey,
        timeZoneId: selectedCity.city.timeZoneId,
        citySource: selectedCity.source.analyticsValue,
      ),
    );
  }

  void _queueCityDraft(EventSelectedCity selectedCity) {
    final draftKey = _eventCreateCityDraftKey(selectedCity);
    if (_lastEmittedCityDraftKey == draftKey && _pendingCityDraft == null) {
      return;
    }
    _pendingCityDraft = selectedCity;
    if (_cityDraftCallbackScheduled) {
      return;
    }
    _cityDraftCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cityDraftCallbackScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingCity = _pendingCityDraft;
      if (pendingCity == null ||
          _lastEmittedCityDraftKey == _eventCreateCityDraftKey(pendingCity)) {
        return;
      }
      _emitCityDraftNow(pendingCity);
    });
  }

  void _emitLocationDraftNow(String locationName) {
    _pendingLocationDraftName = null;
    if (_lastEmittedLocationDraftName == locationName) {
      return;
    }
    final onLocationDraftChanged = widget.onLocationDraftChanged;
    if (onLocationDraftChanged == null) {
      return;
    }
    _lastEmittedLocationDraftName = locationName;
    onLocationDraftChanged(
      EventCreateLocationDraft(
        locationName: locationName,
        locationGeoPoint: null,
      ),
    );
  }

  void _queueLocationDraft(String locationName) {
    if (_lastEmittedLocationDraftName == locationName &&
        _pendingLocationDraftName == null) {
      return;
    }
    _pendingLocationDraftName = locationName;
    if (_locationDraftCallbackScheduled) {
      return;
    }
    _locationDraftCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _locationDraftCallbackScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingLocationName = _pendingLocationDraftName;
      if (pendingLocationName == null ||
          _lastEmittedLocationDraftName == pendingLocationName) {
        return;
      }
      _emitLocationDraftNow(pendingLocationName);
    });
  }

  void _handleLocationTextChanged() {
    _queueLocationDraft(
      _normalizeEventCreateLocationName(_locationTextController.text),
    );
  }

  void _emitDateDraftNow(DateTime localDate) {
    final normalizedDate = _eventCreateDateOnly(localDate);
    _pendingDateDraft = null;
    final draftKey = _eventCreateDateDraftKey(normalizedDate);
    if (_lastEmittedDateDraftKey == draftKey) {
      return;
    }
    final onDateDraftChanged = widget.onDateDraftChanged;
    if (onDateDraftChanged == null) {
      return;
    }
    _lastEmittedDateDraftKey = draftKey;
    onDateDraftChanged(
      EventCreateDateDraft(localDate: normalizedDate),
    );
  }

  void _queueDateDraft(DateTime localDate) {
    final normalizedDate = _eventCreateDateOnly(localDate);
    final draftKey = _eventCreateDateDraftKey(normalizedDate);
    if (_lastEmittedDateDraftKey == draftKey && _pendingDateDraft == null) {
      return;
    }
    _pendingDateDraft = normalizedDate;
    if (_dateDraftCallbackScheduled) {
      return;
    }
    _dateDraftCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dateDraftCallbackScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingDate = _pendingDateDraft;
      if (pendingDate == null ||
          _lastEmittedDateDraftKey == _eventCreateDateDraftKey(pendingDate)) {
        return;
      }
      _emitDateDraftNow(pendingDate);
    });
  }

  void _emitTimeDraftNow(TimeOfDay localTime) {
    _pendingTimeDraft = null;
    final draftKey = _eventCreateTimeDraftKey(localTime);
    if (_lastEmittedTimeDraftKey == draftKey) {
      return;
    }
    final onTimeDraftChanged = widget.onTimeDraftChanged;
    if (onTimeDraftChanged == null) {
      return;
    }
    _lastEmittedTimeDraftKey = draftKey;
    onTimeDraftChanged(
      EventCreateTimeDraft(localTime: localTime),
    );
  }

  void _queueTimeDraft(TimeOfDay localTime) {
    final draftKey = _eventCreateTimeDraftKey(localTime);
    if (_lastEmittedTimeDraftKey == draftKey && _pendingTimeDraft == null) {
      return;
    }
    _pendingTimeDraft = localTime;
    if (_timeDraftCallbackScheduled) {
      return;
    }
    _timeDraftCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _timeDraftCallbackScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingTime = _pendingTimeDraft;
      if (pendingTime == null ||
          _lastEmittedTimeDraftKey == _eventCreateTimeDraftKey(pendingTime)) {
        return;
      }
      _emitTimeDraftNow(pendingTime);
    });
  }

  void _emitCapacityDraftNow(int capacity) {
    _pendingCapacityDraft = null;
    if (_lastEmittedCapacityDraft == capacity) {
      return;
    }
    final onCapacityDraftChanged = widget.onCapacityDraftChanged;
    if (onCapacityDraftChanged == null) {
      return;
    }
    _lastEmittedCapacityDraft = capacity;
    onCapacityDraftChanged(
      EventCreateCapacityDraft(capacity: capacity),
    );
  }

  void _queueCapacityDraft(int capacity) {
    if (_lastEmittedCapacityDraft == capacity &&
        _pendingCapacityDraft == null) {
      return;
    }
    _pendingCapacityDraft = capacity;
    if (_capacityDraftCallbackScheduled) {
      return;
    }
    _capacityDraftCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _capacityDraftCallbackScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingCapacity = _pendingCapacityDraft;
      if (pendingCapacity == null ||
          _lastEmittedCapacityDraft == pendingCapacity) {
        return;
      }
      _emitCapacityDraftNow(pendingCapacity);
    });
  }

  void _handleCapacityTextChanged() {
    _queueCapacityDraft(
      _eventCreateCapacityFromText(_capacityTextController.text),
    );
  }

  void _queueLevelDraft(EventLevelRange range) {
    final draftKey = _eventCreateLevelDraftKey(range);
    if (_lastEmittedLevelDraftKey == draftKey &&
        _pendingLevelDraftRange == null) {
      return;
    }
    _pendingLevelDraftRange = range;
    if (_levelDraftCallbackScheduled) {
      return;
    }
    _levelDraftCallbackScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _levelDraftCallbackScheduled = false;
      if (!mounted) {
        return;
      }
      final pendingRange = _pendingLevelDraftRange;
      if (pendingRange == null ||
          _lastEmittedLevelDraftKey ==
              _eventCreateLevelDraftKey(pendingRange)) {
        return;
      }
      _emitLevelDraftNow(pendingRange);
    });
  }

  Future<void> _showLanguageSelector(
    EventLanguageCatalog catalog,
    String selectedLanguageCode,
  ) async {
    final selectedCode = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventCreateLanguageSheet(
        catalog: catalog,
        selectedLanguageCode: selectedLanguageCode,
      ),
    );
    if (selectedCode == null || !mounted) {
      return;
    }
    setState(() {
      _selectedLanguageCode = selectedCode;
    });
    widget.onLanguageCodeChanged?.call(selectedCode);
    _emitLanguageDraftNow(selectedCode);
  }

  Future<void> _showLevelSelector(EventLevelRange selectedRange) async {
    final selectedLevelRange = await showModalBottomSheet<EventLevelRange>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventCreateLevelSheet(
        selectedRange: selectedRange,
      ),
    );
    if (selectedLevelRange == null || !mounted) {
      return;
    }
    setState(() {
      _selectedLevelMin = selectedLevelRange.levelMin;
      _selectedLevelMax = selectedLevelRange.levelMax;
    });
    _emitLevelDraftNow(selectedLevelRange);
  }

  Future<void> _showCitySelector({
    required EventCityCatalog catalog,
    required String? countryCodeHint,
  }) async {
    final city = await showModalBottomSheet<EventCity>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _EventCreateCitySheet(
        catalog: catalog,
        countryCodeHint: countryCodeHint,
      ),
    );
    if (city == null || !mounted) {
      return;
    }
    await _selectCity(
      catalog: catalog,
      city: city,
      source: EventCitySelectionSource.manual,
    );
  }

  Future<void> _selectCity({
    required EventCityCatalog catalog,
    required EventCity city,
    required EventCitySelectionSource source,
  }) async {
    final chipSource = await _loadCityChipSource();
    final input = await EventTemporaryCitySelectionService(
      chipSource: chipSource,
    ).selectCity(
      city: city,
      source: source,
    );
    final selectedState = resolveEventSelectedCityState(
      user: currentUserDocument,
      catalog: catalog,
      temporarySelection: input,
    );
    final selectedCity = selectedState.selected;
    if (selectedCity == null || !mounted) {
      return;
    }
    setState(() {
      _selectedCity = selectedCity;
      _startTimeErrorText = null;
      _clearCityChipsCache();
    });
    _emitCityDraftNow(selectedCity);
  }

  Future<List<EventCityChip>> _loadCityChips({
    required EventCityCatalog catalog,
    required EventSelectedCityState selectedState,
  }) {
    final countryCodeHint = selectedState.countryCodeHint;
    final selectedIdentity = selectedState.selected?.city.identity;
    if (_cityChipsFuture == null ||
        _cityChipsCatalog != catalog ||
        _cityChipsCountryCodeHint != countryCodeHint ||
        _cityChipsSelectedIdentity != selectedIdentity) {
      _cityChipsCatalog = catalog;
      _cityChipsCountryCodeHint = countryCodeHint;
      _cityChipsSelectedIdentity = selectedIdentity;
      _cityChipsFuture = _loadCityChipsFromStore(
        catalog: catalog,
        selectedCityToExclude: selectedState.selected?.city,
        countryCodeHint: countryCodeHint,
      );
    }
    return _cityChipsFuture!;
  }

  Future<List<EventCityChip>> _loadCityChipsFromStore({
    required EventCityCatalog catalog,
    required EventCity? selectedCityToExclude,
    required String? countryCodeHint,
  }) async {
    final chipSource = await _loadCityChipSource();
    return chipSource.loadChips(
      catalog: catalog,
      selectedCityToExclude: selectedCityToExclude,
      countryCodeHint: countryCodeHint,
    );
  }

  Future<EventCityChipSource> _loadCityChipSource() async {
    final preferences = await SharedPreferences.getInstance();
    return EventCityChipSource(
      recentStore: SharedPreferencesEventRecentCityStore(
        preferences: preferences,
      ),
    );
  }

  EventSelectedCityState? _resolveVisibleSelectedCityState(
    EventCityCatalog? catalog,
  ) {
    if (_selectedCity != null) {
      return EventSelectedCityState(
        profileStatus: EventCityResolutionStatus.missingProfileCity,
        countryCodeHint: null,
        selected: _selectedCity,
      );
    }
    if (catalog == null) {
      return null;
    }
    return resolveEventSelectedCityState(
      user: currentUserDocument,
      catalog: catalog,
    );
  }

  bool get _isWaitingForCurrentUserDocument =>
      _selectedCity == null &&
      currentUserUid.isNotEmpty &&
      currentUserDocument == null;

  DateTime _currentUtc() {
    final currentUtc =
        widget.currentUtcProvider?.call() ?? DateTime.now().toUtc();
    if (!currentUtc.isUtc) {
      throw ArgumentError.value(
        currentUtc,
        'currentUtcProvider',
        'Expected a UTC DateTime.',
      );
    }
    return currentUtc;
  }

  EventStartTimeValidationResult? _validateSelectedStartTime() {
    final selectedCity = _lastVisibleSelectedCity;
    if (selectedCity == null) {
      setState(() {
        _startTimeErrorText = null;
      });
      return null;
    }
    final validation = validateEventStartTime(
      localDate: _selectedDate,
      localTime: _selectedTime,
      timeZoneId: selectedCity.city.timeZoneId,
      nowUtc: _currentUtc(),
    );
    if (validation.isFuture) {
      setState(() {
        _startTimeErrorText = null;
      });
      return validation;
    }
    setState(() {
      _startTimeErrorText = FFLocalizations.of(context).getVariableText(
        ruText: 'Выберите будущие дату и время.',
        enText: 'Choose a future date and time.',
      );
    });
    return null;
  }

  void _clearCityChipsCache() {
    _cityChipsFuture = null;
    _cityChipsCatalog = null;
    _cityChipsCountryCodeHint = null;
    _cityChipsSelectedIdentity = null;
  }

  Future<void> _showDateSelector(DateTime selectedDate) async {
    final normalizedSelectedDate = _eventCreateDateOnly(selectedDate);
    final currentDate = _eventCreateDateOnly(DateTime.now());
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: normalizedSelectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      currentDate: currentDate,
      locale: Localizations.localeOf(context),
      helpText: FFLocalizations.of(context).getVariableText(
        ruText: 'Выберите дату',
        enText: 'Choose date',
      ),
      cancelText: FFLocalizations.of(context).getVariableText(
        ruText: 'Отмена',
        enText: 'Cancel',
      ),
      confirmText: FFLocalizations.of(context).getVariableText(
        ruText: 'Готово',
        enText: 'Done',
      ),
    );
    if (pickedDate == null || !mounted) {
      return;
    }
    final normalizedPickedDate = _eventCreateDateOnly(pickedDate);
    setState(() {
      _selectedDate = normalizedPickedDate;
      _startTimeErrorText = null;
    });
    _emitDateDraftNow(normalizedPickedDate);
  }

  Future<void> _showTimeSelector(TimeOfDay selectedTime) async {
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: selectedTime,
      initialEntryMode: TimePickerEntryMode.inputOnly,
      helpText: FFLocalizations.of(context).getVariableText(
        ruText: 'Выберите время',
        enText: 'Choose time',
      ),
      cancelText: FFLocalizations.of(context).getVariableText(
        ruText: 'Отмена',
        enText: 'Cancel',
      ),
      confirmText: FFLocalizations.of(context).getVariableText(
        ruText: 'Готово',
        enText: 'Done',
      ),
      builder: (context, child) {
        final mediaQuery = MediaQuery.maybeOf(context);
        if (mediaQuery == null || child == null) {
          return child ?? const SizedBox.shrink();
        }
        return MediaQuery(
          data: mediaQuery.copyWith(alwaysUse24HourFormat: true),
          child: child,
        );
      },
    );
    if (pickedTime == null || !mounted) {
      return;
    }
    setState(() {
      _selectedTime = pickedTime;
      _startTimeErrorText = null;
    });
    _emitTimeDraftNow(pickedTime);
  }

  Future<void> _handleSubmitPressed() async {
    if (_isSubmitting) {
      return;
    }
    setState(() {
      _hasAttemptedSubmit = true;
      _submitFailure = null;
    });
    widget.onSubmitFailureChanged?.call(null);
    final formIsValid = _formKey.currentState?.validate() ?? false;
    final selectedCity = _lastVisibleSelectedCity;
    final startTimeValidation = formIsValid && selectedCity != null
        ? _validateSelectedStartTime()
        : null;
    if (!formIsValid || selectedCity == null || startTimeValidation == null) {
      return;
    }
    final levelRange = _resolvedSelectedLevelRange();
    final capacity = _eventCreateCapacityFromText(_capacityTextController.text);

    setState(() {
      _isSubmitting = true;
    });
    try {
      final languageCatalog = await _languageCatalogFuture;
      if (!mounted) {
        return;
      }
      final languageCode = languageCatalog == null
          ? _selectedLanguageCode
          : _resolvedSelectedLanguageCode(languageCatalog);
      if (languageCode == null || languageCode.trim().isEmpty) {
        throw StateError('Event language catalog is not ready.');
      }

      final fields = EventEditableFields(
        title: _titleTextController.text,
        description: _descriptionTextController.text,
        languageCode: languageCode,
        levelMin: levelRange.levelMin,
        levelMax: levelRange.levelMax,
        countryCode: selectedCity.city.countryCode,
        cityKey: selectedCity.city.cityKey,
        locationName: _normalizeEventCreateLocationName(
          _locationTextController.text,
        ),
        locationGeoPoint: null,
        startsAt: startTimeValidation.startsAtUtc,
        capacity: capacity,
      );
      final payloadSignature = _eventCreatePayloadSignature(fields);
      var createRequestId = _activeCreateRequestId;
      if (createRequestId == null ||
          _activeCreatePayloadSignature != payloadSignature) {
        createRequestId =
            (widget.createRequestIdGenerator ?? newEventCreateRequestId).call();
        _activeCreateRequestId = createRequestId;
        _activeCreatePayloadSignature = payloadSignature;
      }

      await EventActionsRepository.createEvent(
        createRequestId: createRequestId,
        fields: fields,
        invoker: widget.createEventInvoker,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final failure = mapEventActionFailure(error);
      setState(() {
        if (failure.kind == EventActionFailureKind.createRequestConflict) {
          _activeCreateRequestId = null;
          _activeCreatePayloadSignature = null;
        }
        _submitFailure = failure;
      });
      widget.onSubmitFailureChanged?.call(failure);
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedLevelRange = _resolvedSelectedLevelRange();
    final submitFailure = _submitFailure;
    _queueTitleDraft(_titleTextController.text);
    _queueDescriptionDraft(_descriptionTextController.text);
    _queueLevelDraft(selectedLevelRange);
    _queueLocationDraft(
      _normalizeEventCreateLocationName(_locationTextController.text),
    );
    _queueDateDraft(_selectedDate);
    _queueTimeDraft(_selectedTime);
    _queueCapacityDraft(
      _eventCreateCapacityFromText(_capacityTextController.text),
    );
    return PopScope<Object?>(
      canPop: _allowCreateFormExit,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        unawaited(_handleLeavePressed());
      },
      child: AuthUserStreamWidget(
        builder: (context) => Scaffold(
          backgroundColor: ExpatlioDesign.background,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventCreateTopBar(
                  onBackPressed: () {
                    unawaited(_handleLeavePressed());
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space24,
                      ExpatlioDesign.space24,
                      ExpatlioDesign.space24,
                      ExpatlioDesign.space32,
                    ),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 760),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: _hasAttemptedSubmit
                                ? AutovalidateMode.onUserInteraction
                                : AutovalidateMode.disabled,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _EventCreateTextField(
                                  labelKey: eventCreateTitleLabelKey,
                                  semanticsKey:
                                      eventCreateTitleFieldSemanticsKey,
                                  fieldKey: eventCreateTitleFieldKey,
                                  label: FFLocalizations.of(context)
                                      .getVariableText(
                                    ruText: 'Название',
                                    enText: 'Title',
                                  ),
                                  hintText: FFLocalizations.of(context)
                                      .getVariableText(
                                    ruText:
                                        'Разговорный клуб: кофе и английский',
                                    enText:
                                        'Conversation club: coffee and English',
                                  ),
                                  controller: _titleTextController,
                                  focusNode: _titleFocusNode,
                                  textInputAction: TextInputAction.next,
                                  validator: (value) =>
                                      _eventCreateRequiredText(
                                    context,
                                    value,
                                    ruText: 'Введите название',
                                    enText: 'Enter title',
                                  ),
                                  onFieldSubmitted: () {
                                    _descriptionFocusNode.requestFocus();
                                  },
                                ),
                                const SizedBox(height: ExpatlioDesign.space20),
                                _EventCreateTextField(
                                  labelKey: eventCreateDescriptionLabelKey,
                                  semanticsKey:
                                      eventCreateDescriptionFieldSemanticsKey,
                                  fieldKey: eventCreateDescriptionFieldKey,
                                  label: FFLocalizations.of(context)
                                      .getVariableText(
                                    ruText: 'Описание',
                                    enText: 'Description',
                                  ),
                                  hintText: FFLocalizations.of(context)
                                      .getVariableText(
                                    ruText: 'Расскажите, что будет на встрече',
                                    enText:
                                        'Tell people what will happen at the meetup',
                                  ),
                                  controller: _descriptionTextController,
                                  focusNode: _descriptionFocusNode,
                                  textInputAction: TextInputAction.newline,
                                  keyboardType: TextInputType.multiline,
                                  minLines: 4,
                                  maxLines: 8,
                                  validator: (value) =>
                                      _eventCreateRequiredText(
                                    context,
                                    value,
                                    ruText: 'Введите описание',
                                    enText: 'Enter description',
                                  ),
                                ),
                                const SizedBox(height: ExpatlioDesign.space20),
                                FutureBuilder<EventLanguageCatalog>(
                                  future: _languageCatalogFuture,
                                  builder: (context, snapshot) {
                                    final catalog = snapshot.data;
                                    if (catalog == null) {
                                      return _EventCreateLanguageSelector(
                                        state: snapshot.hasError
                                            ? _EventCreateLanguageSelectorState
                                                .error
                                            : _EventCreateLanguageSelectorState
                                                .loading,
                                      );
                                    }
                                    final selectedLanguageCode =
                                        _resolvedSelectedLanguageCode(catalog);
                                    _queueLanguageDraft(selectedLanguageCode);
                                    return _EventCreateLanguageSelector(
                                      state: _EventCreateLanguageSelectorState
                                          .selected,
                                      selectedLabel:
                                          _eventCreateLanguageDisplayName(
                                        context: context,
                                        catalog: catalog,
                                        languageCode: selectedLanguageCode,
                                      ),
                                      onPressed: () => _showLanguageSelector(
                                        catalog,
                                        selectedLanguageCode,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(height: ExpatlioDesign.space20),
                                _EventCreateLevelSelector(
                                  selectedRange: selectedLevelRange,
                                  onPressed: () =>
                                      _showLevelSelector(selectedLevelRange),
                                ),
                                const SizedBox(height: ExpatlioDesign.space20),
                                FutureBuilder<EventCityCatalog>(
                                  future: _cityCatalogFuture,
                                  builder: (context, snapshot) {
                                    final catalog = snapshot.data;
                                    if (catalog == null ||
                                        _isWaitingForCurrentUserDocument) {
                                      _lastVisibleSelectedCity = _selectedCity;
                                      return _EventCreateCitySelector(
                                        state: snapshot.hasError
                                            ? _EventCreateCitySelectorState
                                                .error
                                            : _EventCreateCitySelectorState
                                                .loading,
                                      );
                                    }
                                    final selectedState =
                                        _resolveVisibleSelectedCityState(
                                            catalog);
                                    final selectedCity =
                                        selectedState?.selected;
                                    _lastVisibleSelectedCity = selectedCity;
                                    if (selectedCity != null) {
                                      _queueCityDraft(selectedCity);
                                    }
                                    final showsCityChips = selectedState !=
                                            null &&
                                        selectedState.needsCitySelection &&
                                        !selectedState.hasOutdatedProfileCity;
                                    final cityChipsFuture = showsCityChips
                                        ? _loadCityChips(
                                            catalog: catalog,
                                            selectedState: selectedState,
                                          )
                                        : null;

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _EventCreateCitySelector(
                                          state: _EventCreateCitySelectorState
                                              .ready,
                                          selectedCity: selectedCity,
                                          hasOutdatedProfileCity: selectedState
                                                  ?.hasOutdatedProfileCity ??
                                              false,
                                          errorText: _eventCreateCityErrorText(
                                            context,
                                            selectedCity: selectedCity,
                                            hasAttemptedSubmit:
                                                _hasAttemptedSubmit,
                                          ),
                                          showsMissingLocationPrompt:
                                              selectedState != null &&
                                                  selectedState
                                                      .needsCitySelection &&
                                                  !selectedState
                                                      .hasOutdatedProfileCity,
                                          onPressed: () => _showCitySelector(
                                            catalog: catalog,
                                            countryCodeHint:
                                                selectedState?.countryCodeHint,
                                          ),
                                        ),
                                        if (cityChipsFuture != null) ...[
                                          const SizedBox(
                                              height: ExpatlioDesign.space12),
                                          _EventCreateCityChips(
                                            chipsFuture: cityChipsFuture,
                                            onChipPressed: (chip) {
                                              unawaited(
                                                _selectCity(
                                                  catalog: catalog,
                                                  city: chip.city,
                                                  source: chip.source,
                                                ),
                                              );
                                            },
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: ExpatlioDesign.space20),
                                _EventCreateTextField(
                                  labelKey: eventCreateLocationLabelKey,
                                  semanticsKey:
                                      eventCreateLocationFieldSemanticsKey,
                                  fieldKey: eventCreateLocationFieldKey,
                                  label: FFLocalizations.of(context)
                                      .getVariableText(
                                    ruText: 'Место',
                                    enText: 'Place',
                                  ),
                                  hintText: FFLocalizations.of(context)
                                      .getVariableText(
                                    ruText: 'Кафе, адрес или ориентир',
                                    enText: 'Cafe, address, or landmark',
                                  ),
                                  controller: _locationTextController,
                                  focusNode: _locationFocusNode,
                                  textInputAction: TextInputAction.done,
                                  keyboardType: TextInputType.streetAddress,
                                  minLines: 1,
                                  maxLines: 2,
                                  validator: (value) =>
                                      _eventCreateRequiredText(
                                    context,
                                    value,
                                    ruText: 'Введите место',
                                    enText: 'Enter place',
                                  ),
                                ),
                                const SizedBox(height: ExpatlioDesign.space20),
                                _EventCreateDateSelector(
                                  selectedDate: _selectedDate,
                                  hasError: _startTimeErrorText != null,
                                  onPressed: () =>
                                      _showDateSelector(_selectedDate),
                                ),
                                const SizedBox(height: ExpatlioDesign.space20),
                                _EventCreateTimeSelector(
                                  selectedTime: _selectedTime,
                                  errorText: _startTimeErrorText,
                                  onPressed: () =>
                                      _showTimeSelector(_selectedTime),
                                ),
                                const SizedBox(height: ExpatlioDesign.space20),
                                _EventCreateTextField(
                                  labelKey: eventCreateCapacityLabelKey,
                                  semanticsKey:
                                      eventCreateCapacityFieldSemanticsKey,
                                  fieldKey: eventCreateCapacityFieldKey,
                                  label: FFLocalizations.of(context)
                                      .getVariableText(
                                    ruText: 'Лимит участников',
                                    enText: 'Participant limit',
                                  ),
                                  hintText: '10',
                                  controller: _capacityTextController,
                                  focusNode: _capacityFocusNode,
                                  textInputAction: TextInputAction.done,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) =>
                                      _eventCreateCapacityValidationText(
                                    context,
                                    value,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _EventCreateSubmitBar(
                  errorText: submitFailure == null
                      ? null
                      : eventActionFailureMessageForLocalizations(
                          FFLocalizations.of(context),
                          submitFailure,
                        ),
                  isSubmitting: _isSubmitting,
                  onPressed: () {
                    unawaited(_handleSubmitPressed());
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCreateTextField extends StatelessWidget {
  const _EventCreateTextField({
    required this.labelKey,
    required this.semanticsKey,
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.focusNode,
    this.hintText,
    this.textInputAction,
    this.keyboardType,
    this.inputFormatters,
    this.minLines,
    this.maxLines = 1,
    this.validator,
    this.onFieldSubmitted,
  });

  final Key labelKey;
  final Key semanticsKey;
  final Key fieldKey;
  final String label;
  final String? hintText;
  final TextEditingController controller;
  final FocusNode focusNode;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? minLines;
  final int maxLines;
  final FormFieldValidator<String>? validator;
  final VoidCallback? onFieldSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: labelKey,
          label,
          style: ExpatlioDesign.formLabelStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Semantics(
          key: semanticsKey,
          container: true,
          textField: true,
          multiline: maxLines > 1,
          label: label,
          hint: hintText,
          child: TextFormField(
            key: fieldKey,
            controller: controller,
            focusNode: focusNode,
            autofocus: false,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: textInputAction,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            minLines: minLines,
            maxLines: maxLines,
            validator: validator,
            onFieldSubmitted: (_) => onFieldSubmitted?.call(),
            decoration: ExpatlioDesign.formFieldDecoration(
              context,
              hintText: hintText,
              maxLines: maxLines,
            ),
            style: ExpatlioDesign.formTextStyle(context),
            cursorColor: ExpatlioDesign.primary,
            enableInteractiveSelection: true,
          ),
        ),
      ],
    );
  }
}

class _EventCreateSubmitBar extends StatelessWidget {
  const _EventCreateSubmitBar({
    required this.errorText,
    required this.isSubmitting,
    required this.onPressed,
  });

  final String? errorText;
  final bool isSubmitting;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isSubmitting;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ExpatlioDesign.card,
        border: Border(
          top: BorderSide(color: ExpatlioDesign.separator),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space24,
          ExpatlioDesign.space16,
          ExpatlioDesign.space24,
          ExpatlioDesign.space16,
        ),
        child: Align(
          alignment: AlignmentDirectional.center,
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (errorText != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      errorText!,
                      key: eventCreateSubmitErrorKey,
                      textAlign: TextAlign.center,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.danger,
                        size: 14,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: ExpatlioDesign.space12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    key: eventCreateSubmitButtonKey,
                    onPressed: isEnabled ? onPressed : null,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, ExpatlioDesign.buttonHeight),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ExpatlioDesign.space16,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(ExpatlioDesign.buttonRadius),
                      ),
                      backgroundColor: isEnabled
                          ? ExpatlioDesign.primary
                          : ExpatlioDesign.separator,
                      foregroundColor: Colors.white,
                      disabledForegroundColor: Colors.white,
                    ),
                    child: isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.4,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Text(
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'Создать',
                              enText: 'Create',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: ExpatlioDesign.textStyle(
                              context,
                              color: Colors.white,
                              size: 16,
                              weight: FontWeight.w700,
                            ),
                          ),
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

enum _EventCreateLanguageSelectorState {
  loading,
  error,
  selected,
}

class _EventCreateLanguageSelector extends StatelessWidget {
  const _EventCreateLanguageSelector({
    required this.state,
    this.selectedLabel,
    this.onPressed,
  });

  final _EventCreateLanguageSelectorState state;
  final String? selectedLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fieldLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Язык',
      enText: 'Language',
    );
    final selectorLabel = switch (state) {
      _EventCreateLanguageSelectorState.loading =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Загрузка языков...',
          enText: 'Loading languages...',
        ),
      _EventCreateLanguageSelectorState.error =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось загрузить языки',
          enText: 'Could not load languages',
        ),
      _EventCreateLanguageSelectorState.selected => selectedLabel ??
          FFLocalizations.of(context).getVariableText(
            ruText: 'Выберите язык',
            enText: 'Choose language',
          ),
    };
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Язык события',
      enText: 'Event language',
    );
    final isEnabled = onPressed != null &&
        state == _EventCreateLanguageSelectorState.selected;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: eventCreateLanguageLabelKey,
          fieldLabel,
          style: ExpatlioDesign.formLabelStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Semantics(
          key: eventCreateLanguageSelectorSemanticsKey,
          button: true,
          enabled: isEnabled,
          label: semanticsLabel,
          value: selectorLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: eventCreateLanguageSelectorKey,
              onTap: isEnabled ? onPressed : null,
              borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                ),
                decoration: ExpatlioDesign.cardDecoration(
                  borderColor: ExpatlioDesign.separator,
                  radius: ExpatlioDesign.controlRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.translate_outlined,
                      color: state == _EventCreateLanguageSelectorState.error
                          ? ExpatlioDesign.danger
                          : ExpatlioDesign.primary,
                      size: 20,
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Expanded(
                      child: Text(
                        selectorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: isEnabled
                              ? ExpatlioDesign.text
                              : ExpatlioDesign.muted,
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    if (state == _EventCreateLanguageSelectorState.loading)
                      Icon(
                        Icons.hourglass_empty,
                        color: ExpatlioDesign.muted,
                        size: 20,
                      )
                    else
                      Icon(
                        FFIcons.kchevronDown,
                        color: isEnabled
                            ? ExpatlioDesign.muted
                            : ExpatlioDesign.disabled,
                        size: 20,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventCreateLevelSelector extends StatelessWidget {
  const _EventCreateLevelSelector({
    required this.selectedRange,
    required this.onPressed,
  });

  final EventLevelRange selectedRange;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final fieldLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Уровень',
      enText: 'Level',
    );
    final selectorLabel = _eventCreateLevelRangeLabel(selectedRange);
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Уровень события',
      enText: 'Event level',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: eventCreateLevelLabelKey,
          fieldLabel,
          style: ExpatlioDesign.formLabelStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Semantics(
          key: eventCreateLevelSelectorSemanticsKey,
          button: true,
          enabled: true,
          label: semanticsLabel,
          value: selectorLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: eventCreateLevelSelectorKey,
              onTap: onPressed,
              borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                ),
                decoration: ExpatlioDesign.cardDecoration(
                  borderColor: ExpatlioDesign.separator,
                  radius: ExpatlioDesign.controlRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.school_outlined,
                      color: ExpatlioDesign.primary,
                      size: 20,
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Expanded(
                      child: Text(
                        selectorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: ExpatlioDesign.text,
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Icon(
                      FFIcons.kchevronDown,
                      color: ExpatlioDesign.muted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

enum _EventCreateCitySelectorState {
  loading,
  error,
  ready,
}

class _EventCreateCitySelector extends StatelessWidget {
  const _EventCreateCitySelector({
    required this.state,
    this.selectedCity,
    this.hasOutdatedProfileCity = false,
    this.errorText,
    this.showsMissingLocationPrompt = false,
    this.onPressed,
  });

  final _EventCreateCitySelectorState state;
  final EventSelectedCity? selectedCity;
  final bool hasOutdatedProfileCity;
  final String? errorText;
  final bool showsMissingLocationPrompt;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final fieldLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Город',
      enText: 'City',
    );
    final selectorLabel = _citySelectorLabel(context);
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Город события',
      enText: 'Event city',
    );
    final isEnabled =
        onPressed != null && state == _EventCreateCitySelectorState.ready;
    final hasError =
        errorText != null || state == _EventCreateCitySelectorState.error;
    final iconColor = hasError ? ExpatlioDesign.danger : ExpatlioDesign.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: eventCreateCityLabelKey,
          fieldLabel,
          style: ExpatlioDesign.formLabelStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Semantics(
          key: eventCreateCitySelectorSemanticsKey,
          button: true,
          enabled: isEnabled,
          label: semanticsLabel,
          value: selectorLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: eventCreateCitySelectorKey,
              onTap: isEnabled ? onPressed : null,
              borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                ),
                decoration: ExpatlioDesign.cardDecoration(
                  borderColor: errorText == null
                      ? ExpatlioDesign.separator
                      : ExpatlioDesign.danger,
                  radius: ExpatlioDesign.controlRadius,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: iconColor,
                          size: 20,
                        ),
                        const SizedBox(width: ExpatlioDesign.space8),
                        Expanded(
                          child: Text(
                            selectorLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ExpatlioDesign.textStyle(
                              context,
                              color: selectedCity == null
                                  ? ExpatlioDesign.muted
                                  : ExpatlioDesign.text,
                              size: 16,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: ExpatlioDesign.space8),
                        if (state == _EventCreateCitySelectorState.loading)
                          Icon(
                            Icons.hourglass_empty,
                            color: ExpatlioDesign.muted,
                            size: 20,
                          )
                        else
                          Icon(
                            FFIcons.kchevronDown,
                            color: isEnabled
                                ? ExpatlioDesign.muted
                                : ExpatlioDesign.disabled,
                            size: 20,
                          ),
                      ],
                    ),
                    if (hasOutdatedProfileCity ||
                        showsMissingLocationPrompt) ...[
                      const SizedBox(height: ExpatlioDesign.space8),
                      Text(
                        _helperText(context),
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: ExpatlioDesign.muted,
                          size: 13,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: ExpatlioDesign.space8),
          Text(
            errorText!,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.danger,
              size: 12,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  String _citySelectorLabel(BuildContext context) {
    final city = selectedCity?.city;
    if (state == _EventCreateCitySelectorState.loading) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Загрузка городов...',
        enText: 'Loading cities...',
      );
    }
    if (state == _EventCreateCitySelectorState.error) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Не удалось загрузить города',
        enText: 'Could not load cities',
      );
    }
    if (city == null) {
      if (hasOutdatedProfileCity) {
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Выберите город заново',
          enText: 'Choose city again',
        );
      }
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Выберите город',
        enText: 'Choose city',
      );
    }
    return _eventCreateCityLabel(context, city);
  }

  String _helperText(BuildContext context) {
    if (hasOutdatedProfileCity) {
      return FFLocalizations.of(context).getVariableText(
        ruText:
            'Сохранённый город больше недоступен. Выберите актуальный город для события.',
        enText:
            'Your saved city is no longer available. Choose a current city for the event.',
      );
    }
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Выберите город события или нажмите один из вариантов ниже.',
      enText: 'Choose the event city or tap one of the options below.',
    );
  }
}

class _EventCreateCityChips extends StatelessWidget {
  const _EventCreateCityChips({
    required this.chipsFuture,
    required this.onChipPressed,
  });

  final Future<List<EventCityChip>> chipsFuture;
  final ValueChanged<EventCityChip> onChipPressed;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<EventCityChip>>(
      future: chipsFuture,
      builder: (context, snapshot) {
        final chips = snapshot.data;
        if (chips == null || chips.isEmpty) {
          return const SizedBox.shrink();
        }
        return Wrap(
          spacing: ExpatlioDesign.space8,
          runSpacing: ExpatlioDesign.space8,
          children: [
            for (final chip in chips)
              ActionChip(
                key: eventCreateCityChipKey(chip.city),
                label: Text(_eventCreateCityLabel(context, chip.city)),
                onPressed: () => onChipPressed(chip),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: ExpatlioDesign.secondarySystemBackground,
                side: BorderSide(color: ExpatlioDesign.separator),
                labelStyle: ExpatlioDesign.textStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w600,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _EventCreateDateSelector extends StatelessWidget {
  const _EventCreateDateSelector({
    required this.selectedDate,
    required this.onPressed,
    this.hasError = false,
  });

  final DateTime selectedDate;
  final VoidCallback onPressed;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final fieldLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Дата',
      enText: 'Date',
    );
    final selectorLabel = _eventCreateDateLabel(
      context,
      localDate: selectedDate,
    );
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Дата события',
      enText: 'Event date',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: eventCreateDateLabelKey,
          fieldLabel,
          style: ExpatlioDesign.formLabelStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Semantics(
          key: eventCreateDateSelectorSemanticsKey,
          button: true,
          enabled: true,
          label: semanticsLabel,
          value: selectorLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: eventCreateDateSelectorKey,
              onTap: onPressed,
              borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                ),
                decoration: ExpatlioDesign.cardDecoration(
                  borderColor: hasError
                      ? ExpatlioDesign.danger
                      : ExpatlioDesign.separator,
                  radius: ExpatlioDesign.controlRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: hasError
                          ? ExpatlioDesign.danger
                          : ExpatlioDesign.primary,
                      size: 20,
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Expanded(
                      child: Text(
                        selectorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: ExpatlioDesign.text,
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Icon(
                      FFIcons.kchevronDown,
                      color: ExpatlioDesign.muted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _EventCreateTimeSelector extends StatelessWidget {
  const _EventCreateTimeSelector({
    required this.selectedTime,
    required this.onPressed,
    this.errorText,
  });

  final TimeOfDay selectedTime;
  final VoidCallback onPressed;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final fieldLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Время',
      enText: 'Time',
    );
    final selectorLabel = _eventCreateTimeLabel(selectedTime);
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Время события',
      enText: 'Event time',
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: eventCreateTimeLabelKey,
          fieldLabel,
          style: ExpatlioDesign.formLabelStyle(context),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Semantics(
          key: eventCreateTimeSelectorSemanticsKey,
          button: true,
          enabled: true,
          label: semanticsLabel,
          value: selectorLabel,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: eventCreateTimeSelectorKey,
              onTap: onPressed,
              borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space12,
                ),
                decoration: ExpatlioDesign.cardDecoration(
                  borderColor: errorText == null
                      ? ExpatlioDesign.separator
                      : ExpatlioDesign.danger,
                  radius: ExpatlioDesign.controlRadius,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.schedule_outlined,
                      color: errorText == null
                          ? ExpatlioDesign.primary
                          : ExpatlioDesign.danger,
                      size: 20,
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Expanded(
                      child: Text(
                        selectorLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: ExpatlioDesign.text,
                          size: 16,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Icon(
                      FFIcons.kchevronDown,
                      color: ExpatlioDesign.muted,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: ExpatlioDesign.space8),
          Text(
            key: eventCreateStartTimeErrorKey,
            errorText!,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.danger,
              size: 12,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _EventCreateLevelSheet extends StatefulWidget {
  const _EventCreateLevelSheet({
    required this.selectedRange,
  });

  final EventLevelRange selectedRange;

  @override
  State<_EventCreateLevelSheet> createState() => _EventCreateLevelSheetState();
}

class _EventCreateLevelSheetState extends State<_EventCreateLevelSheet> {
  late EventLevelRange _selectedRange;

  @override
  void initState() {
    super.initState();
    _selectedRange = widget.selectedRange;
  }

  void _selectLevelMin(String level) {
    final selectedRank = eventLevelRanks[level]!;
    final maxLevel =
        selectedRank > _selectedRange.maxRank ? level : _selectedRange.levelMax;
    setState(() {
      _selectedRange = eventLevelRange(
        levelMin: level,
        levelMax: maxLevel,
      );
    });
  }

  void _selectLevelMax(String level) {
    final selectedRank = eventLevelRanks[level]!;
    final minLevel =
        selectedRank < _selectedRange.minRank ? level : _selectedRange.levelMin;
    setState(() {
      _selectedRange = eventLevelRange(
        levelMin: minLevel,
        levelMax: level,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      top: false,
      child: Container(
        key: eventCreateLevelSheetKey,
        decoration: ExpatlioDesign.sheetDecoration(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space20,
              ExpatlioDesign.space20,
              ExpatlioDesign.space20,
              ExpatlioDesign.space24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Выберите уровень',
                    enText: 'Choose level',
                  ),
                  style: ExpatlioDesign.bottomSheetTitleStyle(context),
                ),
                const SizedBox(height: ExpatlioDesign.space20),
                _EventCreateLevelChipGroup(
                  label: FFLocalizations.of(context).getVariableText(
                    ruText: 'От',
                    enText: 'From',
                  ),
                  selectedLevel: _selectedRange.levelMin,
                  optionKeyBuilder: eventCreateLevelMinOptionKey,
                  onChanged: _selectLevelMin,
                ),
                const SizedBox(height: ExpatlioDesign.space16),
                _EventCreateLevelChipGroup(
                  label: FFLocalizations.of(context).getVariableText(
                    ruText: 'До',
                    enText: 'To',
                  ),
                  selectedLevel: _selectedRange.levelMax,
                  optionKeyBuilder: eventCreateLevelMaxOptionKey,
                  onChanged: _selectLevelMax,
                ),
                const SizedBox(height: ExpatlioDesign.space24),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: eventCreateLevelDoneButtonKey,
                    onTap: () => Navigator.of(context).pop(_selectedRange),
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.controlRadius),
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ExpatlioDesign.primary,
                        borderRadius:
                            BorderRadius.circular(ExpatlioDesign.controlRadius),
                      ),
                      child: Text(
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'Готово',
                          enText: 'Done',
                        ),
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: Colors.white,
                          size: 16,
                          weight: FontWeight.w700,
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
    );
  }
}

class _EventCreateLevelChipGroup extends StatelessWidget {
  const _EventCreateLevelChipGroup({
    required this.label,
    required this.selectedLevel,
    required this.optionKeyBuilder,
    required this.onChanged,
  });

  final String label;
  final String selectedLevel;
  final ValueKey<String> Function(String level) optionKeyBuilder;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.muted,
            size: 14,
            weight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space8),
        Wrap(
          spacing: ExpatlioDesign.space8,
          runSpacing: ExpatlioDesign.space8,
          children: [
            for (final level in eventLevelRanks.keys)
              ChoiceChip(
                key: optionKeyBuilder(level),
                label: Text(level),
                selected: selectedLevel == level,
                onSelected: (_) => onChanged(level),
                showCheckmark: false,
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: ExpatlioDesign.secondarySystemBackground,
                selectedColor: ExpatlioDesign.primary.withValues(alpha: 0.12),
                side: BorderSide(
                  color: selectedLevel == level
                      ? ExpatlioDesign.primary
                      : ExpatlioDesign.separator,
                ),
                labelStyle: ExpatlioDesign.textStyle(
                  context,
                  color: selectedLevel == level
                      ? ExpatlioDesign.primary
                      : ExpatlioDesign.text,
                  size: 14,
                  weight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _EventCreateCitySheet extends StatefulWidget {
  const _EventCreateCitySheet({
    required this.catalog,
    required this.countryCodeHint,
  });

  final EventCityCatalog catalog;
  final String? countryCodeHint;

  @override
  State<_EventCreateCitySheet> createState() => _EventCreateCitySheetState();
}

class _EventCreateCitySheetState extends State<_EventCreateCitySheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final options = _options;
    final maxHeight = MediaQuery.sizeOf(context).height * 0.78;

    return SafeArea(
      top: false,
      child: Container(
        key: eventCreateCitySheetKey,
        decoration: ExpatlioDesign.sheetDecoration(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space20,
              ExpatlioDesign.space20,
              ExpatlioDesign.space20,
              ExpatlioDesign.space20 + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Выберите город',
                    enText: 'Choose city',
                  ),
                  style: ExpatlioDesign.bottomSheetTitleStyle(context),
                ),
                const SizedBox(height: ExpatlioDesign.space12),
                TextField(
                  key: eventCreateCitySearchFieldKey,
                  controller: _searchController,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: FFLocalizations.of(context).getVariableText(
                      ruText: 'Поиск города',
                      enText: 'Search city',
                    ),
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: ExpatlioDesign.secondarySystemBackground,
                    border: OutlineInputBorder(
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.controlRadius),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space16,
                      ExpatlioDesign.space12,
                      ExpatlioDesign.space16,
                      ExpatlioDesign.space12,
                    ),
                  ),
                  onChanged: (value) => setState(() {
                    _query = value;
                  }),
                ),
                const SizedBox(height: ExpatlioDesign.space12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: options.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: ExpatlioDesign.space8),
                    itemBuilder: (context, index) {
                      final option = options[index];
                      return _EventCreateCityOptionTile(
                        option: option,
                        onTap: () => Navigator.of(context).pop(option.city),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<EventCitySearchOption> get _options {
    if (_query.trim().isEmpty) {
      return widget.catalog
          .popularCities(countryCodeHint: widget.countryCodeHint)
          .map((city) => EventCitySearchOption(city: city))
          .toList(growable: false);
    }
    return widget.catalog.searchOptions(
      _query,
      countryCodeHint: widget.countryCodeHint,
    );
  }
}

class _EventCreateCityOptionTile extends StatelessWidget {
  const _EventCreateCityOptionTile({
    required this.option,
    required this.onTap,
  });

  final EventCitySearchOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: _eventCreateCityLabel(context, option.city),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: eventCreateCityOptionKey(option.city),
          onTap: onTap,
          borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
          child: Container(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
            ),
            decoration: ExpatlioDesign.cardDecoration(
              borderColor: ExpatlioDesign.separator,
              radius: ExpatlioDesign.controlRadius,
            ),
            child: Text(
              _eventCreateCityLabel(context, option.city),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.textStyle(
                context,
                size: 16,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCreateLanguageSheet extends StatelessWidget {
  const _EventCreateLanguageSheet({
    required this.catalog,
    required this.selectedLanguageCode,
  });

  final EventLanguageCatalog catalog;
  final String selectedLanguageCode;

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      top: false,
      child: Container(
        key: eventCreateLanguageSheetKey,
        decoration: ExpatlioDesign.sheetDecoration(),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space20,
                  ExpatlioDesign.space20,
                  ExpatlioDesign.space20,
                  ExpatlioDesign.space12,
                ),
                child: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Выберите язык',
                    enText: 'Choose language',
                  ),
                  style: ExpatlioDesign.bottomSheetTitleStyle(context),
                ),
              ),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space8,
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space24,
                  ),
                  itemCount: catalog.languages.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: ExpatlioDesign.space8),
                  itemBuilder: (context, index) {
                    final language = catalog.languages[index];
                    return _EventCreateLanguageOptionTile(
                      language: language,
                      label: _eventCreateLanguageDisplayName(
                        context: context,
                        catalog: catalog,
                        languageCode: language.code,
                      ),
                      selected: language.code == selectedLanguageCode,
                      onTap: () => Navigator.of(context).pop(language.code),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventCreateLanguageOptionTile extends StatelessWidget {
  const _EventCreateLanguageOptionTile({
    required this.language,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final EventLanguage language;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: eventCreateLanguageOptionKey(language.code),
          onTap: onTap,
          borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
            ),
            decoration: ExpatlioDesign.cardDecoration(
              borderColor:
                  selected ? ExpatlioDesign.primary : ExpatlioDesign.separator,
              radius: ExpatlioDesign.controlRadius,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 16,
                      weight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space8),
                if (selected)
                  Icon(
                    Icons.check_circle,
                    color: ExpatlioDesign.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventCreateTopBar extends StatelessWidget {
  const _EventCreateTopBar({
    required this.onBackPressed,
  });

  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ExpatlioDesign.pageHeaderHeight,
      child: Row(
        children: [
          FlutterFlowIconButton(
            key: eventCreateBackButtonKey,
            borderColor: Colors.transparent,
            borderRadius: 24,
            buttonSize: 48,
            icon: Icon(
              FFIcons.kchevronLeft,
              color: ExpatlioDesign.text,
              size: 24,
            ),
            onPressed: onBackPressed,
          ),
          Expanded(
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Создать событие',
                enText: 'Create event',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.pageHeaderTitleStyle(context),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

String _eventCreateLanguageDisplayName({
  required BuildContext context,
  required EventLanguageCatalog catalog,
  required String languageCode,
}) {
  return catalog.localizedDisplayName(
    languageCode: languageCode,
    localeCode: FFLocalizations.of(context).languageCode,
  );
}

String _eventCreateLevelRangeLabel(EventLevelRange range) =>
    range.levelMin == range.levelMax
        ? range.levelMin
        : '${range.levelMin}-${range.levelMax}';

String _eventCreateLevelDraftKey(EventLevelRange range) =>
    '${range.levelMin}:${range.levelMax}';

String _eventCreateCityLabel(BuildContext context, EventCity city) {
  final isRu = FFLocalizations.of(context).languageCode == 'ru';
  final cityName = isRu ? city.cityNameRu : city.cityNameEn;
  return '$cityName · ${city.cityDisplayContext}';
}

String _eventCreateCityDraftKey(EventSelectedCity selectedCity) {
  return '${selectedCity.city.identity}:'
      '${selectedCity.city.timeZoneId}:'
      '${selectedCity.source.analyticsValue}';
}

String _normalizeEventCreateLocationName(String value) =>
    value.trim().replaceAll(RegExp(r'\s+'), ' ');

DateTime _eventCreateDateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

String _eventCreateDateLabel(
  BuildContext context, {
  required DateTime localDate,
}) {
  return dateTimeFormat(
    'd MMM y',
    _eventCreateDateOnly(localDate),
    locale: FFLocalizations.of(context).languageCode,
  );
}

String _eventCreateDateDraftKey(DateTime localDate) {
  final date = _eventCreateDateOnly(localDate);
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _eventCreateTimeLabel(TimeOfDay localTime) =>
    _eventCreateTimeDraftKey(localTime);

String _eventCreateTimeDraftKey(TimeOfDay localTime) {
  final hour = localTime.hour.toString().padLeft(2, '0');
  final minute = localTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _eventCreateCapacityText(int? capacity) =>
    (capacity ?? _eventCreateDefaultCapacity).toString();

int _eventCreateCapacityFromText(String value) =>
    int.tryParse(value) ?? _eventCreateDefaultCapacity;

String _eventCreatePayloadSignature(EventEditableFields fields) {
  final payload = fields.toCreatePayload(
    createRequestId: '00000000-0000-4000-8000-000000000000',
  )..remove('createRequestId');
  return jsonEncode(payload);
}

bool _isEventCreateDefaultLanguageCode(String value) {
  final languageCode = value.trim().toLowerCase();
  return languageCode == _eventCreateDefaultLanguageCode ||
      languageCode.startsWith('$_eventCreateDefaultLanguageCode-');
}

String? _eventCreateCapacityValidationText(
  BuildContext context,
  String? value,
) {
  final requiredText = _eventCreateRequiredText(
    context,
    value,
    ruText: 'Введите лимит участников',
    enText: 'Enter participant limit',
  );
  if (requiredText != null) {
    return requiredText;
  }

  final capacity = int.tryParse(value!.trim());
  if (capacity != null && capacity < _eventCreateMinCapacity) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Укажите минимум 2 участника',
      enText: 'Enter at least 2 participants',
    );
  }
  if (capacity != null && capacity > _eventCreateMaxCapacity) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Укажите максимум 50 участников',
      enText: 'Enter no more than 50 participants',
    );
  }

  return null;
}

String? _eventCreateRequiredText(
  BuildContext context,
  String? value, {
  required String ruText,
  required String enText,
}) {
  if (value == null || value.trim().isEmpty) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ruText,
      enText: enText,
    );
  }
  return null;
}

String? _eventCreateCityErrorText(
  BuildContext context, {
  required EventSelectedCity? selectedCity,
  required bool hasAttemptedSubmit,
}) {
  if (!hasAttemptedSubmit || selectedCity != null) {
    return null;
  }
  return FFLocalizations.of(context).getVariableText(
    ruText: 'Выберите город события',
    enText: 'Choose event city',
  );
}
