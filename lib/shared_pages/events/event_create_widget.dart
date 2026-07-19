import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/components/profile_dropdown_menu_item.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/events/event_detail_widget.dart';
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
import '/services/event_list_cache_invalidation.dart';
import '/services/event_level_helper.dart';
import '/services/events_analytics_service.dart';

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
const double _eventCreateContentMaxWidth = 760;

ValueKey<String> eventCreateLanguageOptionKey(String code) =>
    ValueKey<String>('event_create_language_option_$code');

ValueKey<String> eventCreateLevelMinOptionKey(String level) =>
    ValueKey<String>('event_create_level_min_option_$level');

ValueKey<String> eventCreateLevelMaxOptionKey(String level) =>
    ValueKey<String>('event_create_level_max_option_$level');

ValueKey<String> eventCreateLevelRangeOptionKey(
  String levelMin,
  String levelMax,
) =>
    ValueKey<String>('event_create_level_range_option_${levelMin}_$levelMax');

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

enum EventFormMode {
  create,
  edit,
}

class EventCreateWidget extends StatefulWidget {
  const EventCreateWidget({
    super.key,
    this.formMode = EventFormMode.create,
    this.languageCatalogOverride,
    this.cityCatalogOverride,
    this.initialTitle,
    this.initialDescription,
    this.initialLanguageCode,
    this.initialLevelMin,
    this.initialLevelMax,
    this.initialSelectedCity,
    this.initialLocationName,
    this.initialLocationGeoPoint,
    this.initialDate,
    this.initialTime,
    this.initialCapacity,
    this.minimumCapacity,
    this.eventId,
    this.currentUtcProvider,
    this.createEventInvoker,
    this.editEventInvoker,
    this.analyticsTracker,
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

  final EventFormMode formMode;
  final EventLanguageCatalog? languageCatalogOverride;
  final EventCityCatalog? cityCatalogOverride;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialLanguageCode;
  final String? initialLevelMin;
  final String? initialLevelMax;
  final EventSelectedCity? initialSelectedCity;
  final String? initialLocationName;
  final LatLng? initialLocationGeoPoint;
  final DateTime? initialDate;
  final TimeOfDay? initialTime;
  final int? initialCapacity;
  final int? minimumCapacity;
  final String? eventId;
  final DateTime Function()? currentUtcProvider;
  final EventCallableInvoker? createEventInvoker;
  final EventCallableInvoker? editEventInvoker;
  final EventsAnalyticsTracker? analyticsTracker;
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
  late final Listenable _textControllersListenable;
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
  bool _allowEventFormExit = false;
  bool _isLeavingEventForm = false;
  bool _discardDialogOpen = false;
  String? _startTimeErrorText;
  EventActionFailure? _submitFailure;
  String? _activeCreateRequestId;
  String? _activeCreatePayloadSignature;
  String? _lastTrackedCreatedEventId;
  String? _lastTrackedEditedEventId;
  _EventFormDirtySnapshot? _editDirtyBaseline;

  @override
  void initState() {
    super.initState();
    _textControllersListenable = Listenable.merge([
      _titleTextController,
      _descriptionTextController,
      _locationTextController,
      _capacityTextController,
    ]);
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
    _resetEditDirtyBaseline();
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
    final shouldResetEditDirtyBaseline =
        oldWidget.formMode != widget.formMode ||
            oldWidget.initialTitle != widget.initialTitle ||
            oldWidget.initialDescription != widget.initialDescription ||
            oldWidget.initialLanguageCode != widget.initialLanguageCode ||
            oldWidget.initialLevelMin != widget.initialLevelMin ||
            oldWidget.initialLevelMax != widget.initialLevelMax ||
            oldWidget.initialSelectedCity != widget.initialSelectedCity ||
            oldWidget.initialLocationName != widget.initialLocationName ||
            oldWidget.initialDate != widget.initialDate ||
            oldWidget.initialTime != widget.initialTime ||
            oldWidget.initialCapacity != widget.initialCapacity;
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
    if (shouldResetEditDirtyBaseline) {
      _resetEditDirtyBaseline();
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

  bool get _isEventFormDirty {
    if (widget.formMode == EventFormMode.edit) {
      final baseline = _editDirtyBaseline;
      if (baseline == null) {
        return false;
      }
      return baseline != _EventFormDirtySnapshot.fromState(this);
    }
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

  void _resetEditDirtyBaseline() {
    _editDirtyBaseline = widget.formMode == EventFormMode.edit
        ? _EventFormDirtySnapshot.fromState(this)
        : null;
  }

  Future<void> _handleLeavePressed() async {
    if (_discardDialogOpen) {
      return;
    }
    if (!_isEventFormDirty) {
      _leaveEventForm();
      return;
    }
    final shouldDiscard = await _showDiscardEventFormDialog();
    if (!mounted || !shouldDiscard) {
      return;
    }
    _leaveEventForm();
  }

  void _leaveEventForm() {
    if (!mounted) {
      return;
    }
    _isLeavingEventForm = true;
    setState(() {
      _allowEventFormExit = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.safePop();
      }
    });
  }

  Future<bool> _showDiscardEventFormDialog() async {
    _discardDialogOpen = true;
    final isEditMode = widget.formMode == EventFormMode.edit;
    try {
      final shouldDiscard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          key: eventCreateDiscardDialogKey,
          title: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: isEditMode ? 'Закрыть редактирование?' : 'Закрыть форму?',
              enText: isEditMode ? 'Leave edit form?' : 'Leave create form?',
            ),
          ),
          content: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: isEditMode
                  ? 'Изменения будут потеряны.'
                  : 'Заполненные данные будут потеряны.',
              enText: isEditMode
                  ? 'Entered changes will be lost.'
                  : 'Entered details will be lost.',
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
    BuildContext anchorContext,
    EventLanguageCatalog catalog,
    String selectedLanguageCode,
  ) async {
    final selectedCode = await _showEventCreateDropdownMenu<String>(
      anchorContext,
      options: [
        for (final language in catalog.languages)
          _EventCreateDropdownMenuOption<String>(
            key: eventCreateLanguageOptionKey(language.code),
            value: language.code,
            label: _eventCreateLanguageDisplayName(
              context: context,
              catalog: catalog,
              languageCode: language.code,
            ),
            selected: language.code == selectedLanguageCode,
          ),
      ],
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

  Future<void> _showLevelSelector(
    BuildContext anchorContext,
    EventLevelRange selectedRange,
  ) async {
    final selectedLevelRange =
        await _showEventCreateDropdownMenu<EventLevelRange>(
      anchorContext,
      options: [
        for (final range in _eventCreateLevelRangeOptions())
          _EventCreateDropdownMenuOption<EventLevelRange>(
            key: eventCreateLevelRangeOptionKey(
              range.levelMin,
              range.levelMax,
            ),
            value: range,
            label: _eventCreateLevelRangeLabel(range),
            selected: _eventCreateLevelDraftKey(range) ==
                _eventCreateLevelDraftKey(selectedRange),
          ),
      ],
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
    required BuildContext anchorContext,
    required EventCityCatalog catalog,
    required EventSelectedCity? selectedCity,
    required String? countryCodeHint,
  }) async {
    final options = await _loadCityMenuOptions(
      catalog: catalog,
      countryCodeHint: countryCodeHint,
      selectedCity: selectedCity,
    );
    if (!mounted) {
      return;
    }
    final selectedOption = await _showEventCreateDropdownMenu<EventCityChip>(
      anchorContext,
      options: [
        for (final option in options)
          _EventCreateDropdownMenuOption<EventCityChip>(
            key: eventCreateCityOptionKey(option.city),
            value: option,
            label: _eventCreateCityLabel(context, option.city),
            selected: selectedCity?.city.identity == option.city.identity,
          ),
      ],
    );
    if (selectedOption == null || !mounted) {
      return;
    }
    if (selectedCity?.city.identity == selectedOption.city.identity) {
      return;
    }
    await _selectCity(
      catalog: catalog,
      city: selectedOption.city,
      source: selectedOption.source,
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
      recordRecentCity: widget.formMode == EventFormMode.create,
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

  Future<List<EventCityChip>> _loadCityMenuOptions({
    required EventCityCatalog catalog,
    required String? countryCodeHint,
    required EventSelectedCity? selectedCity,
  }) {
    final selectedIdentity = selectedCity?.city.identity;
    if (_cityChipsFuture == null ||
        _cityChipsCatalog != catalog ||
        _cityChipsCountryCodeHint != countryCodeHint ||
        _cityChipsSelectedIdentity != selectedIdentity) {
      _cityChipsCatalog = catalog;
      _cityChipsCountryCodeHint = countryCodeHint;
      _cityChipsSelectedIdentity = selectedIdentity;
      _cityChipsFuture = _loadCityMenuOptionsFromStore(
        catalog: catalog,
        countryCodeHint: countryCodeHint,
      );
    }
    return _cityChipsFuture!;
  }

  Future<List<EventCityChip>> _loadCityMenuOptionsFromStore({
    required EventCityCatalog catalog,
    required String? countryCodeHint,
  }) async {
    final chipSource = await _loadCityChipSource();
    return chipSource.loadChips(
      catalog: catalog,
      countryCodeHint: countryCodeHint,
      maxChips: catalog.cities.length,
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
    if (widget.formMode == EventFormMode.edit) {
      return const EventSelectedCityState(
        profileStatus: EventCityResolutionStatus.missingProfileCity,
        countryCodeHint: null,
      );
    }
    return resolveEventSelectedCityState(
      user: currentUserDocument,
      catalog: catalog,
    );
  }

  bool get _isWaitingForCurrentUserDocument =>
      widget.formMode == EventFormMode.create &&
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

  EventStartTimeValidationResult? _validateCurrentEventForm() {
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
      return null;
    }
    return startTimeValidation;
  }

  LatLng? _currentLocationGeoPointForSubmit() {
    if (widget.formMode != EventFormMode.edit) {
      return null;
    }
    final baseline = _editDirtyBaseline;
    final current = _EventFormDirtySnapshot.fromState(this);
    if (baseline == null ||
        baseline.cityIdentity != current.cityIdentity ||
        baseline.locationName != current.locationName) {
      return null;
    }
    return widget.initialLocationGeoPoint;
  }

  Future<void> _handleSubmitPressed() async {
    if (_isSubmitting) {
      return;
    }
    final startTimeValidation = _validateCurrentEventForm();
    if (startTimeValidation == null) {
      return;
    }
    final selectedCity = _lastVisibleSelectedCity;
    if (selectedCity == null) {
      return;
    }
    final levelRange = _resolvedSelectedLevelRange();
    final capacity = _eventCreateCapacityFromText(_capacityTextController.text);
    final analyticsTracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;

    setState(() {
      _isSubmitting = true;
    });
    String? savedEventId;
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
        locationGeoPoint: _currentLocationGeoPointForSubmit(),
        startsAt: startTimeValidation.startsAtUtc,
        capacity: capacity,
      );
      if (widget.formMode == EventFormMode.create) {
        final payloadSignature = _eventCreatePayloadSignature(fields);
        var createRequestId = _activeCreateRequestId;
        if (createRequestId == null ||
            _activeCreatePayloadSignature != payloadSignature) {
          createRequestId =
              (widget.createRequestIdGenerator ?? newEventCreateRequestId)
                  .call();
          _activeCreateRequestId = createRequestId;
          _activeCreatePayloadSignature = payloadSignature;
        }

        final createResult = await EventActionsRepository.createEvent(
          createRequestId: createRequestId,
          fields: fields,
          invoker: widget.createEventInvoker,
        );
        savedEventId = createResult.eventId;
        _trackEventCreatedIfNeeded(
          eventId: createResult.eventId,
          selectedCity: selectedCity,
          tracker: analyticsTracker,
        );
      } else {
        final editEventId = widget.eventId?.trim();
        if (editEventId == null || editEventId.isEmpty) {
          throw StateError('Event id is required to edit an event.');
        }
        final editResult = await EventActionsRepository.editEvent(
          eventId: editEventId,
          fields: fields,
          invoker: widget.editEventInvoker,
        );
        savedEventId = editResult.eventId;
        _trackEventEditedIfNeeded(
          eventId: editResult.eventId,
          selectedCity: selectedCity,
          tracker: analyticsTracker,
        );
      }
      EventListCacheInvalidation.invalidate();
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
      if (mounted && savedEventId == null) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
    if (savedEventId == null || !mounted || _isLeavingEventForm) {
      return;
    }
    setState(() {
      _allowEventFormExit = true;
    });
    context.goNamed(
      EventDetailWidget.routeName,
      pathParameters: <String, String>{
        'eventId': savedEventId,
      },
    );
  }

  void _trackEventCreatedIfNeeded({
    required String eventId,
    required EventSelectedCity selectedCity,
    required EventsAnalyticsTracker tracker,
  }) {
    if (_lastTrackedCreatedEventId == eventId) {
      return;
    }
    _lastTrackedCreatedEventId = eventId;
    unawaited(
      Future<void>.sync(
        () => tracker.trackEventCreated(
          countryCode: selectedCity.city.countryCode,
          cityKey: selectedCity.city.cityKey,
          citySource: selectedCity.source.analyticsValue,
        ),
      ).catchError(
        (Object error, StackTrace stackTrace) {},
      ),
    );
  }

  void _trackEventEditedIfNeeded({
    required String eventId,
    required EventSelectedCity selectedCity,
    required EventsAnalyticsTracker tracker,
  }) {
    if (_lastTrackedEditedEventId == eventId) {
      return;
    }
    _lastTrackedEditedEventId = eventId;
    unawaited(
      Future<void>.sync(
        () => tracker.trackEventEdited(
          countryCode: selectedCity.city.countryCode,
          cityKey: selectedCity.city.cityKey,
        ),
      ).catchError(
        (Object error, StackTrace stackTrace) {},
      ),
    );
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
    return ListenableBuilder(
      listenable: _textControllersListenable,
      child: AuthUserStreamWidget(
        builder: (context) => Scaffold(
          backgroundColor: ExpatlioDesign.background,
          body: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _EventCreateTopBar(
                  formMode: widget.formMode,
                  onBackPressed: () {
                    unawaited(_handleLeavePressed());
                  },
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.pageTopSpacing,
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.space32,
                    ),
                    children: [
                      Align(
                        alignment: AlignmentDirectional.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _eventCreateContentMaxWidth,
                          ),
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
                                const SizedBox(
                                  height: ExpatlioDesign.sectionSpacing,
                                ),
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
                                const SizedBox(
                                  height: ExpatlioDesign.sectionSpacing,
                                ),
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
                                      onPressed: (anchorContext) =>
                                          _showLanguageSelector(
                                        anchorContext,
                                        catalog,
                                        selectedLanguageCode,
                                      ),
                                    );
                                  },
                                ),
                                const SizedBox(
                                  height: ExpatlioDesign.sectionSpacing,
                                ),
                                _EventCreateLevelSelector(
                                  selectedRange: selectedLevelRange,
                                  onPressed: (anchorContext) =>
                                      _showLevelSelector(
                                    anchorContext,
                                    selectedLevelRange,
                                  ),
                                ),
                                const SizedBox(
                                  height: ExpatlioDesign.sectionSpacing,
                                ),
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
                                          onPressed: (anchorContext) =>
                                              _showCitySelector(
                                            anchorContext: anchorContext,
                                            catalog: catalog,
                                            selectedCity: selectedCity,
                                            countryCodeHint:
                                                selectedState?.countryCodeHint,
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(
                                  height: ExpatlioDesign.sectionSpacing,
                                ),
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
                                  maxLines: 1,
                                  validator: (value) =>
                                      _eventCreateRequiredText(
                                    context,
                                    value,
                                    ruText: 'Введите место',
                                    enText: 'Enter place',
                                  ),
                                ),
                                const SizedBox(
                                  height: ExpatlioDesign.sectionSpacing,
                                ),
                                _EventCreateDateSelector(
                                  selectedDate: _selectedDate,
                                  hasError: _startTimeErrorText != null,
                                  onPressed: () =>
                                      _showDateSelector(_selectedDate),
                                ),
                                const SizedBox(
                                  height: ExpatlioDesign.sectionSpacing,
                                ),
                                _EventCreateTimeSelector(
                                  selectedTime: _selectedTime,
                                  errorText: _startTimeErrorText,
                                  onPressed: () =>
                                      _showTimeSelector(_selectedTime),
                                ),
                                const SizedBox(
                                  height: ExpatlioDesign.sectionSpacing,
                                ),
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
                                    minimumCapacity: widget.minimumCapacity,
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
                  formMode: widget.formMode,
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
      builder: (context, child) => PopScope<Object?>(
        canPop: _allowEventFormExit || !_isEventFormDirty,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) {
            return;
          }
          unawaited(_handleLeavePressed());
        },
        child: child!,
      ),
    );
  }
}

class _EventFormDirtySnapshot {
  const _EventFormDirtySnapshot({
    required this.title,
    required this.description,
    required this.languageCode,
    required this.levelKey,
    required this.cityIdentity,
    required this.locationName,
    required this.dateKey,
    required this.timeKey,
    required this.capacityText,
  });

  factory _EventFormDirtySnapshot.fromState(_EventCreateWidgetState state) {
    final city = state._selectedCity?.city;
    return _EventFormDirtySnapshot(
      title: state._titleTextController.text,
      description: state._descriptionTextController.text,
      languageCode: state._selectedLanguageCode?.trim().toLowerCase() ?? '',
      levelKey: _eventCreateLevelDraftKey(state._resolvedSelectedLevelRange()),
      cityIdentity: city == null ? '' : city.identity,
      locationName:
          _normalizeEventCreateLocationName(state._locationTextController.text),
      dateKey: _eventCreateDateDraftKey(state._selectedDate),
      timeKey: _eventCreateTimeDraftKey(state._selectedTime),
      capacityText: state._capacityTextController.text.trim(),
    );
  }

  final String title;
  final String description;
  final String languageCode;
  final String levelKey;
  final String cityIdentity;
  final String locationName;
  final String dateKey;
  final String timeKey;
  final String capacityText;

  @override
  bool operator ==(Object other) {
    return other is _EventFormDirtySnapshot &&
        other.title == title &&
        other.description == description &&
        other.languageCode == languageCode &&
        other.levelKey == levelKey &&
        other.cityIdentity == cityIdentity &&
        other.locationName == locationName &&
        other.dateKey == dateKey &&
        other.timeKey == timeKey &&
        other.capacityText == capacityText;
  }

  @override
  int get hashCode => Object.hash(
        title,
        description,
        languageCode,
        levelKey,
        cityIdentity,
        locationName,
        dateKey,
        timeKey,
        capacityText,
      );
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
    required this.formMode,
    required this.isSubmitting,
    required this.onPressed,
  });

  final String? errorText;
  final EventFormMode formMode;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isEnabled = !isSubmitting && onPressed != null;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ExpatlioDesign.background,
        border: Border(
          top: BorderSide(color: ExpatlioDesign.separator),
        ),
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.pagePadding,
            ExpatlioDesign.space16,
            ExpatlioDesign.pagePadding,
            ExpatlioDesign.space16 +
                ExpatlioDesign.bottomBarSafePadding(context),
          ),
          child: Align(
            alignment: AlignmentDirectional.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _eventCreateContentMaxWidth,
              ),
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
                          borderRadius: BorderRadius.circular(
                              ExpatlioDesign.buttonRadius),
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
                                ruText: formMode == EventFormMode.create
                                    ? 'Создать'
                                    : 'Сохранить',
                                enText: formMode == EventFormMode.create
                                    ? 'Create'
                                    : 'Save',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: ExpatlioDesign.textStyle(
                                context,
                                color: Colors.white,
                                size: 16,
                                weight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
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
  final Future<void> Function(BuildContext context)? onPressed;

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
        Builder(
          builder: (fieldContext) => Semantics(
            key: eventCreateLanguageSelectorSemanticsKey,
            button: true,
            enabled: isEnabled,
            label: semanticsLabel,
            value: selectorLabel,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: eventCreateLanguageSelectorKey,
                onTap: isEnabled
                    ? () async {
                        await onPressed?.call(fieldContext);
                      }
                    : null,
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.controlRadius),
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
                            weight: FontWeight.w400,
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
  final Future<void> Function(BuildContext context) onPressed;

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
        Builder(
          builder: (fieldContext) => Semantics(
            key: eventCreateLevelSelectorSemanticsKey,
            button: true,
            enabled: true,
            label: semanticsLabel,
            value: selectorLabel,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: eventCreateLevelSelectorKey,
                onTap: () async {
                  await onPressed(fieldContext);
                },
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.controlRadius),
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
                            weight: FontWeight.w400,
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
  final Future<void> Function(BuildContext context)? onPressed;

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
        Builder(
          builder: (fieldContext) => Semantics(
            key: eventCreateCitySelectorSemanticsKey,
            button: true,
            enabled: isEnabled,
            label: semanticsLabel,
            value: selectorLabel,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: eventCreateCitySelectorKey,
                onTap: isEnabled
                    ? () async {
                        await onPressed?.call(fieldContext);
                      }
                    : null,
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.controlRadius),
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
                                weight: FontWeight.w400,
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
      ruText: 'Выберите город события из списка.',
      enText: 'Choose the event city from the list.',
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
                          weight: FontWeight.w400,
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
                          weight: FontWeight.w400,
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

class _EventCreateDropdownMenuOption<T> {
  const _EventCreateDropdownMenuOption({
    required this.key,
    required this.value,
    required this.label,
    required this.selected,
  });

  final Key key;
  final T value;
  final String label;
  final bool selected;
}

Future<T?> _showEventCreateDropdownMenu<T>(
  BuildContext anchorContext, {
  required List<_EventCreateDropdownMenuOption<T>> options,
}) {
  final anchorBox = anchorContext.findRenderObject() as RenderBox?;
  final overlayBox =
      Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;

  if (anchorBox == null || overlayBox == null || !anchorBox.attached) {
    return Future<T?>.value(null);
  }

  const viewportMargin = 16.0;
  const minMenuWidth = 206.0;
  final anchorOffset =
      anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
  final availableMenuWidth =
      math.max(0.0, overlayBox.size.width - (viewportMargin * 2));
  final menuWidth = math
      .min(math.max(anchorBox.size.width, minMenuWidth), availableMenuWidth)
      .toDouble();
  final maxMenuLeft = math.max(
    viewportMargin,
    overlayBox.size.width - menuWidth - viewportMargin,
  );
  final menuLeft =
      anchorOffset.dx.clamp(viewportMargin, maxMenuLeft).toDouble();
  final anchorRect = Rect.fromLTWH(
    menuLeft,
    anchorOffset.dy + anchorBox.size.height + 8.0,
    menuWidth,
    0.0,
  );

  return showMenu<T>(
    context: anchorContext,
    position: RelativeRect.fromRect(anchorRect, Offset.zero & overlayBox.size),
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
      maxHeight: math.min(360.0, overlayBox.size.height * 0.58),
    ),
    items: [
      for (final option in options)
        PopupMenuItem<T>(
          value: option.value,
          height: 42.0,
          padding: EdgeInsets.zero,
          child: ProfileDropdownMenuItem(
            key: option.key,
            label: option.label,
            selected: option.selected,
          ),
        ),
    ],
  );
}

List<EventLevelRange> _eventCreateLevelRangeOptions() {
  final levels = eventLevelRanks.keys.toList(growable: false);
  return [
    for (var minIndex = 0; minIndex < levels.length; minIndex += 1)
      for (var maxIndex = minIndex + 1; maxIndex < levels.length; maxIndex += 1)
        eventLevelRange(
          levelMin: levels[minIndex],
          levelMax: levels[maxIndex],
        ),
  ];
}

class _EventCreateTopBar extends StatelessWidget {
  const _EventCreateTopBar({
    required this.formMode,
    required this.onBackPressed,
  });

  final EventFormMode formMode;
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
                ruText: formMode == EventFormMode.create
                    ? 'Создать событие'
                    : 'Редактировать событие',
                enText: formMode == EventFormMode.create
                    ? 'Create event'
                    : 'Edit event',
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
  String? value, {
  int? minimumCapacity,
}) {
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
  final resolvedMinimumCapacity = minimumCapacity == null
      ? null
      : minimumCapacity < 0
          ? 0
          : minimumCapacity;
  if (capacity != null &&
      resolvedMinimumCapacity != null &&
      capacity < resolvedMinimumCapacity) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Лимит не может быть меньше текущих участников '
          '($resolvedMinimumCapacity)',
      enText: 'Capacity cannot be below current participants '
          '($resolvedMinimumCapacity)',
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
