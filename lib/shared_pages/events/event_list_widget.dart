import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/events/event_create_widget.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_city_catalog.dart';
import '/services/event_city_chip_source.dart';
import '/services/event_city_resolution.dart';
import '/services/event_city_selection_source.dart';
import '/services/event_selected_city_state.dart';
import '/services/event_temporary_city_selection.dart';
import '/services/event_list_date_bounds.dart';

const ValueKey<String> eventListCreateButtonKey =
    ValueKey<String>('event_list_create_button');
const ValueKey<String> eventListCitySelectorKey =
    ValueKey<String>('event_list_city_selector');
const ValueKey<String> eventManualCitySearchFieldKey =
    ValueKey<String>('event_manual_city_search_field');

class EventListWidget extends StatefulWidget {
  const EventListWidget({
    super.key,
    this.initialSelectedCity,
    this.onCitySelectorPressed,
    this.cityCatalogOverride,
  });

  static String routeName = 'events';
  static String routePath = '/events';

  final EventSelectedCity? initialSelectedCity;
  final VoidCallback? onCitySelectorPressed;
  final EventCityCatalog? cityCatalogOverride;

  @override
  State<EventListWidget> createState() => _EventListWidgetState();
}

class _EventListWidgetState extends State<EventListWidget> {
  late EventSelectedCity? _selectedCity;
  EventListDateFilter _selectedDateFilter = EventListDateFilter.today;
  Future<EventCityCatalog>? _cityCatalogFuture;
  Future<List<EventCityChip>>? _cityChipsFuture;
  EventCityCatalog? _cityChipsCatalog;
  String? _cityChipsCountryCodeHint;
  String? _cityChipsSelectedIdentity;

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.initialSelectedCity;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cityCatalogFuture ??= _loadCityCatalog();
  }

  @override
  void didUpdateWidget(covariant EventListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialSelectedCity != widget.initialSelectedCity) {
      _selectedCity = widget.initialSelectedCity;
    }
    if (oldWidget.cityCatalogOverride != widget.cityCatalogOverride) {
      _cityCatalogFuture = _loadCityCatalog();
      _cityChipsFuture = null;
      _cityChipsCatalog = null;
    }
  }

  Future<EventCityCatalog> _loadCityCatalog() async {
    final override = widget.cityCatalogOverride;
    if (override != null) {
      return override;
    }
    return EventCityCatalog.loadFromAsset(
      bundle: DefaultAssetBundle.of(context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        return FutureBuilder<EventCityCatalog>(
          future: _cityCatalogFuture,
          builder: (context, snapshot) {
            final catalog = snapshot.data;
            final selectedState = _resolveVisibleSelectedCityState(
              catalog,
            );
            final needsCityChips = catalog != null &&
                selectedState != null &&
                selectedState.needsCitySelection &&
                !selectedState.hasOutdatedProfileCity;
            final cityChipsFuture = needsCityChips
                ? _loadCityChips(
                    catalog: catalog,
                    selectedState: selectedState,
                  )
                : null;
            final onCitySelectorPressed = widget.onCitySelectorPressed ??
                (catalog == null
                    ? null
                    : () => _openManualCityPicker(
                          catalog: catalog,
                          countryCodeHint: selectedState?.countryCodeHint,
                        ));

            return Scaffold(
              backgroundColor: ExpatlioDesign.background,
              body: SafeArea(
                child: Padding(
                  padding: ExpatlioDesign.pageScrollPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'События',
                                enText: 'Events',
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ExpatlioDesign.textStyle(
                                context,
                                size: 34,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: ExpatlioDesign.space16),
                          Tooltip(
                            message:
                                FFLocalizations.of(context).getVariableText(
                              ruText: 'Создать событие',
                              enText: 'Create event',
                            ),
                            child: FlutterFlowIconButton(
                              key: eventListCreateButtonKey,
                              borderColor: Colors.transparent,
                              borderRadius: 24,
                              buttonSize: 48,
                              fillColor: ExpatlioDesign.primary,
                              icon: const Icon(
                                Icons.add_sharp,
                                color: Colors.white,
                                size: 24,
                              ),
                              onPressed: () => context.pushNamed(
                                EventCreateWidget.routeName,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: ExpatlioDesign.space16),
                      _EventDateChips(
                        selectedFilter: _selectedDateFilter,
                        onChanged: (filter) => setState(() {
                          _selectedDateFilter = filter;
                        }),
                      ),
                      const SizedBox(height: ExpatlioDesign.space12),
                      _EventCitySelector(
                        selectedCity: selectedState?.selected,
                        hasOutdatedProfileCity:
                            selectedState?.hasOutdatedProfileCity ?? false,
                        showsMissingLocationPrompt: selectedState != null &&
                            selectedState.needsCitySelection &&
                            !selectedState.hasOutdatedProfileCity,
                        onPressed: onCitySelectorPressed,
                      ),
                      if (cityChipsFuture != null && catalog != null) ...[
                        const SizedBox(height: ExpatlioDesign.space12),
                        _EventCityChips(
                          chipsFuture: cityChipsFuture,
                          onChipPressed: (chip) {
                            unawaited(
                              _selectTemporaryCity(
                                catalog: catalog,
                                city: chip.city,
                                source: chip.source,
                              ),
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openManualCityPicker({
    required EventCityCatalog catalog,
    required String? countryCodeHint,
  }) async {
    final city = await showModalBottomSheet<EventCity>(
      context: context,
      isScrollControlled: true,
      backgroundColor: ExpatlioDesign.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(ExpatlioDesign.sheetRadius),
        ),
      ),
      builder: (context) => _EventManualCityPicker(
        catalog: catalog,
        countryCodeHint: countryCodeHint,
      ),
    );
    if (city == null) {
      return;
    }
    await _selectTemporaryCity(
      catalog: catalog,
      city: city,
      source: EventCitySelectionSource.manual,
    );
  }

  Future<void> _selectTemporaryCity({
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
    final selected = selectedState.selected;
    if (selected == null || !mounted) {
      return;
    }
    setState(() {
      _selectedCity = selected;
      _cityChipsFuture = null;
      _cityChipsCatalog = null;
    });
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
}

class _EventDateChips extends StatelessWidget {
  const _EventDateChips({
    required this.selectedFilter,
    required this.onChanged,
  });

  static const List<EventListDateFilter> _filters = [
    EventListDateFilter.today,
    EventListDateFilter.tomorrow,
    EventListDateFilter.currentWeek,
    EventListDateFilter.currentMonth,
  ];

  final EventListDateFilter selectedFilter;
  final ValueChanged<EventListDateFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ExpatlioDesign.space8,
      runSpacing: ExpatlioDesign.space8,
      children: [
        for (final filter in _filters)
          ChoiceChip(
            key: _eventDateFilterChipKey(filter),
            label: Text(_eventDateFilterLabel(context, filter)),
            selected: selectedFilter == filter,
            onSelected: (_) => onChanged(filter),
            showCheckmark: false,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            backgroundColor: ExpatlioDesign.secondarySystemBackground,
            selectedColor: ExpatlioDesign.primary.withValues(alpha: 0.12),
            side: BorderSide(
              color: selectedFilter == filter
                  ? ExpatlioDesign.primary
                  : ExpatlioDesign.separator,
            ),
            labelStyle: ExpatlioDesign.textStyle(
              context,
              color: selectedFilter == filter
                  ? ExpatlioDesign.primary
                  : ExpatlioDesign.text,
              size: 14,
              weight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

ValueKey<String> _eventDateFilterChipKey(EventListDateFilter filter) =>
    ValueKey<String>('event_date_filter_${filter.name}');

String _eventDateFilterLabel(
  BuildContext context,
  EventListDateFilter filter,
) {
  return switch (filter) {
    EventListDateFilter.today => FFLocalizations.of(context).getVariableText(
        ruText: 'Сегодня',
        enText: 'Today',
      ),
    EventListDateFilter.tomorrow => FFLocalizations.of(context).getVariableText(
        ruText: 'Завтра',
        enText: 'Tomorrow',
      ),
    EventListDateFilter.currentWeek =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'На этой неделе',
        enText: 'This week',
      ),
    EventListDateFilter.currentMonth =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'В этом месяце',
        enText: 'This month',
      ),
  };
}

class _EventManualCityPicker extends StatefulWidget {
  const _EventManualCityPicker({
    required this.catalog,
    required this.countryCodeHint,
  });

  final EventCityCatalog catalog;
  final String? countryCodeHint;

  @override
  State<_EventManualCityPicker> createState() => _EventManualCityPickerState();
}

class _EventManualCityPickerState extends State<_EventManualCityPicker> {
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

    return SafeArea(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space16,
          ExpatlioDesign.space16,
          ExpatlioDesign.space16,
          ExpatlioDesign.space16 + bottomInset,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
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
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 22,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ExpatlioDesign.space12),
              TextField(
                key: eventManualCitySearchFieldKey,
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
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: ExpatlioDesign.space8),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    return _EventManualCityOptionTile(
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

class _EventManualCityOptionTile extends StatelessWidget {
  const _EventManualCityOptionTile({
    required this.option,
    required this.onTap,
  });

  final EventCitySearchOption option;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: _eventManualCityOptionKey(option.city),
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
            _cityChipLabel(context, option.city),
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
    );
  }
}

ValueKey<String> _eventManualCityOptionKey(EventCity city) => ValueKey<String>(
    'event_manual_city_option_${city.countryCode}_${city.cityKey}');

class _EventCityChips extends StatelessWidget {
  const _EventCityChips({
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
                key: _eventCityChipKey(chip.city),
                label: Text(_cityChipLabel(context, chip.city)),
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

ValueKey<String> _eventCityChipKey(EventCity city) =>
    ValueKey<String>('event_city_chip_${city.countryCode}_${city.cityKey}');

String _cityChipLabel(BuildContext context, EventCity city) {
  final isRu = FFLocalizations.of(context).languageCode == 'ru';
  final cityName = isRu ? city.cityNameRu : city.cityNameEn;
  return '$cityName · ${city.cityDisplayContext}';
}

class _EventCitySelector extends StatelessWidget {
  const _EventCitySelector({
    required this.selectedCity,
    required this.hasOutdatedProfileCity,
    required this.showsMissingLocationPrompt,
    required this.onPressed,
  });

  final EventSelectedCity? selectedCity;
  final bool hasOutdatedProfileCity;
  final bool showsMissingLocationPrompt;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = _citySelectorLabel(context);
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: FFLocalizations.of(context).getVariableText(
        ruText: 'Выбор города',
        enText: 'City selector',
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: eventListCitySelectorKey,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      color: ExpatlioDesign.primary,
                      size: 20,
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Expanded(
                      child: Text(
                        label,
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
                    Icon(
                      FFIcons.kchevronDown,
                      color: ExpatlioDesign.muted,
                      size: 20,
                    ),
                  ],
                ),
                if (hasOutdatedProfileCity || showsMissingLocationPrompt) ...[
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
    );
  }

  String _citySelectorLabel(BuildContext context) {
    final city = selectedCity?.city;
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
    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    final cityName = isRu ? city.cityNameRu : city.cityNameEn;
    return '$cityName · ${city.cityDisplayContext}';
  }

  String _helperText(BuildContext context) {
    if (hasOutdatedProfileCity) {
      return FFLocalizations.of(context).getVariableText(
        ruText:
            'Сохранённый город больше недоступен. Выберите актуальный город, чтобы увидеть события.',
        enText:
            'Your saved city is no longer available. Choose a current city to see events.',
      );
    }
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Выберите город, чтобы увидеть события.',
      enText: 'Choose a city to see events.',
    );
  }
}
