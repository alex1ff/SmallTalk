import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as timezone;

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
import '/services/event_level_helper.dart';
import '/services/event_language_catalog.dart';

const ValueKey<String> eventListCreateButtonKey =
    ValueKey<String>('event_list_create_button');
const ValueKey<String> eventListCitySelectorKey =
    ValueKey<String>('event_list_city_selector');
const ValueKey<String> eventManualCitySearchFieldKey =
    ValueKey<String>('event_manual_city_search_field');
const ValueKey<String> eventListCardShellKey =
    ValueKey<String>('event_list_card_shell');
const ValueKey<String> eventListCardHeaderKey =
    ValueKey<String>('event_list_card_header');
const ValueKey<String> eventListCardBodyKey =
    ValueKey<String>('event_list_card_body');
const ValueKey<String> eventListCardMetaKey =
    ValueKey<String>('event_list_card_meta');
const ValueKey<String> eventListCardFooterKey =
    ValueKey<String>('event_list_card_footer');
const ValueKey<String> eventListCardActionsKey =
    ValueKey<String>('event_list_card_actions');
const ValueKey<String> eventListCardOrganizerAvatarKey =
    ValueKey<String>('event_list_card_organizer_avatar');
const ValueKey<String> eventListCardOrganizerNameKey =
    ValueKey<String>('event_list_card_organizer_name');
const ValueKey<String> eventListCardTitleKey =
    ValueKey<String>('event_list_card_title');
const ValueKey<String> eventListCardDescriptionKey =
    ValueKey<String>('event_list_card_description');
const ValueKey<String> eventListCardLevelRangeKey =
    ValueKey<String>('event_list_card_level_range');
const ValueKey<String> eventListCardDateKey =
    ValueKey<String>('event_list_card_date');
const ValueKey<String> eventListCardTimeKey =
    ValueKey<String>('event_list_card_time');
const ValueKey<String> eventListCardPlaceKey =
    ValueKey<String>('event_list_card_place');
const ValueKey<String> eventListCardLanguageBadgeKey =
    ValueKey<String>('event_list_card_language_badge');
const ValueKey<String> eventListParticipantAvatarStackKey =
    ValueKey<String>('event_list_participant_avatar_stack');
const ValueKey<String> eventListParticipantOverflowKey =
    ValueKey<String>('event_list_participant_overflow');
const ValueKey<String> eventListCardOccupancyKey =
    ValueKey<String>('event_list_card_occupancy');

class EventListParticipantViewModel {
  const EventListParticipantViewModel({
    required this.displayName,
    this.photoUrl,
  });

  final String displayName;
  final String? photoUrl;
}

class EventListCardViewModel {
  const EventListCardViewModel({
    required this.organizerDisplayName,
    required this.languageCode,
    required this.title,
    required this.description,
    required this.levelMin,
    required this.levelMax,
    required this.startsAt,
    required this.timeZoneId,
    required this.locationName,
    this.organizerPhotoUrl,
    this.languageNameEn,
    this.languageNameRu,
    this.participants = const <EventListParticipantViewModel>[],
    this.participantsCount,
    this.capacity,
  });

  final String organizerDisplayName;
  final String? organizerPhotoUrl;
  final List<EventListParticipantViewModel> participants;
  final int? participantsCount;
  final int? capacity;
  final String languageCode;
  final String? languageNameEn;
  final String? languageNameRu;
  final String title;
  final String description;
  final String levelMin;
  final String levelMax;
  final DateTime startsAt;
  final String timeZoneId;
  final String locationName;

  bool get hasParticipantPreview =>
      participants.isNotEmpty || (participantsCount ?? 0) > 0;

  bool get hasOccupancy => capacity != null && capacity! > 0;

  bool get hasFooterContent => hasParticipantPreview || hasOccupancy;

  int get resolvedParticipantsCount {
    final count = participantsCount;
    if (count == null) {
      return participants.length;
    }
    return count < participants.length ? participants.length : count;
  }
}

class EventListWidget extends StatefulWidget {
  const EventListWidget({
    super.key,
    this.initialSelectedCity,
    this.onCitySelectorPressed,
    this.cityCatalogOverride,
    this.languageCatalogOverride,
    this.eventCardsOverride,
  });

  static String routeName = 'events';
  static String routePath = '/events';

  final EventSelectedCity? initialSelectedCity;
  final VoidCallback? onCitySelectorPressed;
  final EventCityCatalog? cityCatalogOverride;
  final EventLanguageCatalog? languageCatalogOverride;
  final List<EventListCardViewModel>? eventCardsOverride;

  @override
  State<EventListWidget> createState() => _EventListWidgetState();
}

class _EventListWidgetState extends State<EventListWidget> {
  late EventSelectedCity? _selectedCity;
  EventListDateFilter _selectedDateFilter = EventListDateFilter.today;
  String? _selectedLevel;
  Future<EventCityCatalog>? _cityCatalogFuture;
  Future<EventLanguageCatalog>? _languageCatalogFuture;
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
    _languageCatalogFuture ??= _loadLanguageCatalog();
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
    if (oldWidget.languageCatalogOverride != widget.languageCatalogOverride) {
      _languageCatalogFuture = _loadLanguageCatalog();
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

  Future<EventLanguageCatalog> _loadLanguageCatalog() async {
    final override = widget.languageCatalogOverride;
    if (override != null) {
      return override;
    }
    return EventLanguageCatalog.loadFromAsset(
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
            final canShowEventCards = selectedState?.canLoadEvents ?? false;
            final eventCards = widget.eventCardsOverride ??
                const <EventListCardViewModel?>[
                  null,
                ];
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
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _EventDateChips(
                                selectedFilter: _selectedDateFilter,
                                onChanged: (filter) => setState(() {
                                  _selectedDateFilter = filter;
                                }),
                              ),
                              const SizedBox(height: ExpatlioDesign.space12),
                              _EventLevelChips(
                                selectedLevel: _selectedLevel,
                                onChanged: (level) => setState(() {
                                  _selectedLevel = level;
                                }),
                              ),
                              const SizedBox(height: ExpatlioDesign.space12),
                              _EventCitySelector(
                                selectedCity: selectedState?.selected,
                                hasOutdatedProfileCity:
                                    selectedState?.hasOutdatedProfileCity ??
                                        false,
                                showsMissingLocationPrompt:
                                    selectedState != null &&
                                        selectedState.needsCitySelection &&
                                        !selectedState.hasOutdatedProfileCity,
                                onPressed: onCitySelectorPressed,
                              ),
                              if (cityChipsFuture != null &&
                                  catalog != null) ...[
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
                              if (canShowEventCards) ...[
                                const SizedBox(height: ExpatlioDesign.space16),
                                FutureBuilder<EventLanguageCatalog>(
                                  future: _languageCatalogFuture,
                                  builder: (context, languageSnapshot) {
                                    final languageCatalog =
                                        languageSnapshot.data;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        for (final eventCard in eventCards) ...[
                                          _EventCardShell(
                                            card: eventCard,
                                            languageCatalog: languageCatalog,
                                          ),
                                          if (eventCard != eventCards.last)
                                            const SizedBox(
                                              height: ExpatlioDesign.space12,
                                            ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
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

class _EventCardShell extends StatelessWidget {
  const _EventCardShell({
    required this.card,
    required this.languageCatalog,
  });

  final EventListCardViewModel? card;
  final EventLanguageCatalog? languageCatalog;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: eventListCardShellKey,
      padding: ExpatlioDesign.cardPaddingDirectional,
      decoration: ExpatlioDesign.cardDecoration(
        borderColor: ExpatlioDesign.separator,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EventCardHeaderShell(card: card),
          const SizedBox(height: ExpatlioDesign.space16),
          _EventCardBodyShell(card: card),
          const SizedBox(height: ExpatlioDesign.space16),
          _EventCardMetaShell(
            card: card,
            languageCatalog: languageCatalog,
          ),
          if (card == null || card!.hasFooterContent) ...[
            const SizedBox(height: ExpatlioDesign.space16),
            _EventCardFooterShell(card: card),
          ],
          const SizedBox(height: ExpatlioDesign.space16),
          const _EventCardActionsShell(),
        ],
      ),
    );
  }
}

class _EventCardHeaderShell extends StatelessWidget {
  const _EventCardHeaderShell({
    required this.card,
  });

  final EventListCardViewModel? card;

  @override
  Widget build(BuildContext context) {
    final organizer = card;
    return Row(
      key: eventListCardHeaderKey,
      children: [
        if (organizer == null)
          const _EventCardCirclePlaceholder(dimension: 48)
        else
          _EventOrganizerAvatar(
            photoUrl: organizer.organizerPhotoUrl,
            displayName: organizer.organizerDisplayName,
          ),
        const SizedBox(width: ExpatlioDesign.space12),
        Expanded(
          child: organizer == null
              ? const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _EventCardLinePlaceholder(widthFactor: 0.38, height: 12),
                    SizedBox(height: ExpatlioDesign.space8),
                    _EventCardLinePlaceholder(widthFactor: 0.58, height: 18),
                  ],
                )
              : _EventOrganizerText(
                  displayName: organizer.organizerDisplayName,
                ),
        ),
        const SizedBox(width: ExpatlioDesign.space12),
        if (organizer == null)
          const _EventCardPillPlaceholder(width: 72, height: 32)
        else
          _EventLevelRangeBadge(
            levelMin: organizer.levelMin,
            levelMax: organizer.levelMax,
          ),
      ],
    );
  }
}

class _EventOrganizerText extends StatelessWidget {
  const _EventOrganizerText({
    required this.displayName,
  });

  final String displayName;

  @override
  Widget build(BuildContext context) {
    final normalizedName = displayName.trim();
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Организатор',
      enText: 'Organizer',
    );
    final name = normalizedName.isEmpty ? label : normalizedName;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.muted,
            size: 13,
            weight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space4),
        Text(
          key: eventListCardOrganizerNameKey,
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ExpatlioDesign.textStyle(
            context,
            size: 18,
            weight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EventOrganizerAvatar extends StatelessWidget {
  const _EventOrganizerAvatar({
    required this.photoUrl,
    required this.displayName,
  });

  final String? photoUrl;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final normalizedPhotoUrl = photoUrl?.trim() ?? '';
    return Container(
      key: eventListCardOrganizerAvatarKey,
      width: 48,
      height: 48,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: normalizedPhotoUrl.isEmpty
          ? _fallback(context)
          : CachedNetworkImage(
              imageUrl: normalizedPhotoUrl,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              memCacheWidth:
                  (48 * MediaQuery.devicePixelRatioOf(context)).round(),
              memCacheHeight:
                  (48 * MediaQuery.devicePixelRatioOf(context)).round(),
              placeholder: (context, _) => _fallback(context),
              errorWidget: (context, _, __) => _fallback(context),
            ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: ExpatlioDesign.primary.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Text(
        _initials(),
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.primary,
          size: 16,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials() {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      return '?';
    }
    final words = normalizedName
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.length >= 2) {
      return '${words[0].characters.first}${words[1].characters.first}'
          .toUpperCase();
    }
    return normalizedName.characters.take(2).toString().toUpperCase();
  }
}

class _EventCardBodyShell extends StatelessWidget {
  const _EventCardBodyShell({
    required this.card,
  });

  final EventListCardViewModel? card;

  @override
  Widget build(BuildContext context) {
    final event = card;
    if (event == null) {
      return const Column(
        key: eventListCardBodyKey,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _EventCardLinePlaceholder(widthFactor: 0.86, height: 24),
          SizedBox(height: ExpatlioDesign.space12),
          _EventCardLinePlaceholder(widthFactor: 1, height: 16),
          SizedBox(height: ExpatlioDesign.space8),
          _EventCardLinePlaceholder(widthFactor: 0.72, height: 16),
        ],
      );
    }

    final title = event.title.trim();
    final description = event.description.trim();

    return Column(
      key: eventListCardBodyKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          key: eventListCardTitleKey,
          title.isEmpty
              ? FFLocalizations.of(context).getVariableText(
                  ruText: 'Без названия',
                  enText: 'Untitled',
                )
              : title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: ExpatlioDesign.textStyle(
            context,
            size: 21,
            weight: FontWeight.w700,
          ),
        ),
        if (description.isNotEmpty) ...[
          const SizedBox(height: ExpatlioDesign.space8),
          Text(
            key: eventListCardDescriptionKey,
            description,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.muted,
              size: 16,
              height: 1.35,
              weight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }
}

class _EventCardMetaShell extends StatelessWidget {
  const _EventCardMetaShell({
    required this.card,
    required this.languageCatalog,
  });

  final EventListCardViewModel? card;
  final EventLanguageCatalog? languageCatalog;

  @override
  Widget build(BuildContext context) {
    final event = card;
    if (event == null) {
      return const Wrap(
        key: eventListCardMetaKey,
        spacing: ExpatlioDesign.space8,
        runSpacing: ExpatlioDesign.space8,
        children: [
          _EventCardPillPlaceholder(width: 104, height: 34),
          _EventCardPillPlaceholder(width: 92, height: 34),
          _EventCardPillPlaceholder(width: 184, height: 34),
        ],
      );
    }

    final locale = FFLocalizations.of(context).languageCode;
    final eventLocalDateTime = _eventLocalDateTime(
      startsAt: event.startsAt,
      timeZoneId: event.timeZoneId,
    );
    final languageLabel = _eventLanguageLabel(
      event: event,
      languageCatalog: languageCatalog,
      localeCode: locale,
    );
    final locationName = event.locationName.trim();

    return Column(
      key: eventListCardMetaKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: ExpatlioDesign.space8,
          runSpacing: ExpatlioDesign.space8,
          children: [
            if (languageLabel.isNotEmpty)
              _EventInfoChip(
                key: eventListCardLanguageBadgeKey,
                icon: Icons.translate,
                label: languageLabel,
              ),
            _EventInfoChip(
              key: eventListCardDateKey,
              icon: Icons.calendar_month_outlined,
              label: _eventDateLabel(
                context,
                eventLocalDateTime: eventLocalDateTime,
                timeZoneId: event.timeZoneId,
              ),
            ),
            _EventInfoChip(
              key: eventListCardTimeKey,
              icon: Icons.schedule,
              label: dateTimeFormat(
                'Hm',
                eventLocalDateTime,
                locale: locale,
              ),
            ),
          ],
        ),
        const SizedBox(height: ExpatlioDesign.space12),
        Row(
          key: eventListCardPlaceKey,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_on_outlined,
              color: ExpatlioDesign.muted,
              size: 20,
            ),
            const SizedBox(width: ExpatlioDesign.space8),
            Expanded(
              child: Text(
                locationName.isEmpty
                    ? FFLocalizations.of(context).getVariableText(
                        ruText: 'Место не указано',
                        enText: 'Place not specified',
                      )
                    : locationName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 16,
                  weight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EventLevelRangeBadge extends StatelessWidget {
  const _EventLevelRangeBadge({
    required this.levelMin,
    required this.levelMax,
  });

  final String levelMin;
  final String levelMax;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: eventListCardLevelRangeKey,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ExpatlioDesign.space12,
        vertical: ExpatlioDesign.space8,
      ),
      decoration: BoxDecoration(
        color: ExpatlioDesign.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
      ),
      child: Text(
        _eventLevelRangeLabel(levelMin: levelMin, levelMax: levelMax),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.primary,
          size: 14,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventInfoChip extends StatelessWidget {
  const _EventInfoChip({
    super.key,
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        (MediaQuery.sizeOf(context).width - 72).clamp(120.0, 280.0).toDouble();

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ExpatlioDesign.space12,
          vertical: ExpatlioDesign.space8,
        ),
        decoration: BoxDecoration(
          color: ExpatlioDesign.secondarySystemBackground,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: ExpatlioDesign.primary,
              size: 18,
            ),
            const SizedBox(width: ExpatlioDesign.space8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 15,
                  weight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _eventLanguageLabel({
  required EventListCardViewModel event,
  required EventLanguageCatalog? languageCatalog,
  required String? localeCode,
}) {
  final languageCatalogLabel = languageCatalog?.localizedDisplayName(
    languageCode: event.languageCode,
    localeCode: localeCode,
    languageNameEn: event.languageNameEn,
    languageNameRu: event.languageNameRu,
  );
  final normalizedCatalogLabel = languageCatalogLabel?.trim();
  if (normalizedCatalogLabel != null && normalizedCatalogLabel.isNotEmpty) {
    return normalizedCatalogLabel;
  }

  final isRussianLocale = _isRussianLocaleCode(localeCode);
  final preferredFallback = (isRussianLocale
          ? event.languageNameRu ?? event.languageNameEn
          : event.languageNameEn ?? event.languageNameRu)
      ?.trim();
  if (preferredFallback != null && preferredFallback.isNotEmpty) {
    return preferredFallback;
  }

  return event.languageCode.trim();
}

bool _isRussianLocaleCode(String? localeCode) {
  final normalized = localeCode?.trim().toLowerCase();
  return normalized == 'ru' ||
      normalized?.startsWith('ru-') == true ||
      normalized?.startsWith('ru_') == true;
}

String _eventLevelRangeLabel({
  required String levelMin,
  required String levelMax,
}) {
  final range = tryEventLevelRange(
    levelMin: levelMin,
    levelMax: levelMax,
  );
  if (range != null) {
    return range.levelMin == range.levelMax
        ? range.levelMin
        : '${range.levelMin}-${range.levelMax}';
  }

  final normalizedMin = levelMin.trim().toUpperCase();
  final normalizedMax = levelMax.trim().toUpperCase();
  if (normalizedMin.isEmpty) {
    return normalizedMax;
  }
  if (normalizedMax.isEmpty || normalizedMin == normalizedMax) {
    return normalizedMin;
  }
  return '$normalizedMin-$normalizedMax';
}

DateTime _eventLocalDateTime({
  required DateTime startsAt,
  required String timeZoneId,
}) {
  final utcStartsAt = startsAt.isUtc ? startsAt : startsAt.toUtc();
  try {
    final local = timezone.TZDateTime.from(
      utcStartsAt,
      eventListTimeZoneLocation(timeZoneId),
    );
    return DateTime(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  } on ArgumentError {
    return startsAt.toLocal();
  }
}

String _eventDateLabel(
  BuildContext context, {
  required DateTime eventLocalDateTime,
  required String timeZoneId,
}) {
  final locale = FFLocalizations.of(context).languageCode;
  final eventLocalDate = DateTime(
    eventLocalDateTime.year,
    eventLocalDateTime.month,
    eventLocalDateTime.day,
  );
  final nowUtc = DateTime.now().toUtc();
  final today = _safeEventCityLocalDate(
    timeZoneId: timeZoneId,
    utcInstant: nowUtc,
  );
  if (today != null && _sameCalendarDate(eventLocalDate, today)) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Сегодня',
      enText: 'Today',
    );
  }

  final tomorrow =
      today == null ? null : DateTime(today.year, today.month, today.day + 1);
  if (tomorrow != null && _sameCalendarDate(eventLocalDate, tomorrow)) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Завтра',
      enText: 'Tomorrow',
    );
  }

  return dateTimeFormat('d MMM', eventLocalDateTime, locale: locale);
}

DateTime? _safeEventCityLocalDate({
  required String timeZoneId,
  required DateTime utcInstant,
}) {
  try {
    return eventListCityLocalDate(
      timeZoneId: timeZoneId,
      utcInstant: utcInstant,
    );
  } on ArgumentError {
    return null;
  }
}

bool _sameCalendarDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

class _EventCardFooterShell extends StatelessWidget {
  const _EventCardFooterShell({
    required this.card,
  });

  final EventListCardViewModel? card;

  @override
  Widget build(BuildContext context) {
    final event = card;
    if (event == null) {
      return Row(
        key: eventListCardFooterKey,
        children: const [
          SizedBox(
            width: 136,
            height: 34,
            child: Stack(
              children: [
                Positioned(
                  left: 0,
                  child: _EventCardCirclePlaceholder(dimension: 34),
                ),
                Positioned(
                  left: 24,
                  child: _EventCardCirclePlaceholder(dimension: 34),
                ),
                Positioned(
                  left: 48,
                  child: _EventCardCirclePlaceholder(dimension: 34),
                ),
                Positioned(
                  left: 72,
                  child: _EventCardCirclePlaceholder(dimension: 34),
                ),
              ],
            ),
          ),
          SizedBox(width: ExpatlioDesign.space12),
          Expanded(
            child: _EventCardLinePlaceholder(widthFactor: 0.36, height: 16),
          ),
        ],
      );
    }

    return Row(
      key: eventListCardFooterKey,
      children: [
        if (event.hasParticipantPreview)
          _EventParticipantAvatarStack(
            participants: event.participants,
            participantsCount: event.participantsCount,
          ),
        if (event.hasParticipantPreview && event.hasOccupancy)
          const SizedBox(width: ExpatlioDesign.space12),
        if (event.hasOccupancy)
          Flexible(
            child: Text(
              key: eventListCardOccupancyKey,
              _eventOccupancyLabel(
                context,
                participantsCount: event.resolvedParticipantsCount,
                capacity: event.capacity!,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 16,
                weight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

String _eventOccupancyLabel(
  BuildContext context, {
  required int participantsCount,
  required int capacity,
}) {
  final normalizedParticipantsCount =
      participantsCount < 0 ? 0 : participantsCount;
  final suffix = FFLocalizations.of(context).getVariableText(
    ruText: 'мест',
    enText: capacity == 1 ? 'spot' : 'spots',
  );
  return '$normalizedParticipantsCount/$capacity $suffix';
}

class _EventParticipantAvatarStack extends StatelessWidget {
  const _EventParticipantAvatarStack({
    required this.participants,
    required this.participantsCount,
  });

  static const double _avatarSize = 34;
  static const double _avatarStep = 24;
  static const int _maxItems = 4;
  static const int _maxAvatarsWithOverflow = 3;

  final List<EventListParticipantViewModel> participants;
  final int? participantsCount;

  @override
  Widget build(BuildContext context) {
    final totalCount = _totalCount;
    final maxPreviewAvatars =
        totalCount > _maxItems ? _maxAvatarsWithOverflow : _maxItems;
    final visibleAvatarCount = participants.length > maxPreviewAvatars
        ? maxPreviewAvatars
        : participants.length;
    final overflowCount =
        totalCount > visibleAvatarCount ? totalCount - visibleAvatarCount : 0;
    final itemCount = visibleAvatarCount + (overflowCount > 0 ? 1 : 0);

    return SizedBox(
      key: eventListParticipantAvatarStackKey,
      width: _avatarSize + (_avatarStep * (itemCount - 1)),
      height: _avatarSize,
      child: Stack(
        children: [
          for (var index = 0; index < visibleAvatarCount; index += 1)
            PositionedDirectional(
              start: _avatarStep * index,
              child: _EventParticipantAvatar(
                key: _eventParticipantAvatarKey(index),
                participant: participants[index],
                dimension: _avatarSize,
              ),
            ),
          if (overflowCount > 0)
            PositionedDirectional(
              start: _avatarStep * visibleAvatarCount,
              child: _EventParticipantOverflowBadge(
                count: overflowCount,
                dimension: _avatarSize,
              ),
            ),
        ],
      ),
    );
  }

  int get _totalCount {
    final count = participantsCount;
    if (count == null) {
      return participants.length;
    }
    return count < participants.length ? participants.length : count;
  }
}

ValueKey<String> _eventParticipantAvatarKey(int index) =>
    ValueKey<String>('event_list_participant_avatar_$index');

class _EventParticipantAvatar extends StatelessWidget {
  const _EventParticipantAvatar({
    super.key,
    required this.participant,
    required this.dimension,
  });

  final EventListParticipantViewModel participant;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    final normalizedPhotoUrl = participant.photoUrl?.trim() ?? '';
    return Container(
      width: dimension,
      height: dimension,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        shape: BoxShape.circle,
        border: Border.all(
          color: ExpatlioDesign.card,
          width: 2,
        ),
      ),
      child: ClipOval(
        child: normalizedPhotoUrl.isEmpty
            ? _fallback(context)
            : CachedNetworkImage(
                imageUrl: normalizedPhotoUrl,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                memCacheWidth:
                    (dimension * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                memCacheHeight:
                    (dimension * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                placeholder: (context, _) => _fallback(context),
                errorWidget: (context, _, __) => _fallback(context),
              ),
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: ExpatlioDesign.primary.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Text(
        _initials(),
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.primary,
          size: 11,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials() {
    final normalizedName = participant.displayName.trim();
    if (normalizedName.isEmpty) {
      return '?';
    }
    final words = normalizedName
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.length >= 2) {
      return '${words[0].characters.first}${words[1].characters.first}'
          .toUpperCase();
    }
    return normalizedName.characters.take(2).toString().toUpperCase();
  }
}

class _EventParticipantOverflowBadge extends StatelessWidget {
  const _EventParticipantOverflowBadge({
    required this.count,
    required this.dimension,
  });

  final int count;
  final double dimension;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: eventListParticipantOverflowKey,
      width: dimension,
      height: dimension,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: ExpatlioDesign.secondarySystemBackground,
        shape: BoxShape.circle,
        border: Border.all(
          color: ExpatlioDesign.card,
          width: 2,
        ),
      ),
      child: Text(
        '+$count',
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.muted,
          size: 12,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventCardActionsShell extends StatelessWidget {
  const _EventCardActionsShell();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: eventListCardActionsKey,
      children: const [
        Expanded(
          child: _EventCardPillPlaceholder(height: 48),
        ),
        SizedBox(width: ExpatlioDesign.space12),
        _EventCardPillPlaceholder(width: 96, height: 48),
      ],
    );
  }
}

class _EventCardCirclePlaceholder extends StatelessWidget {
  const _EventCardCirclePlaceholder({
    required this.dimension,
  });

  final double dimension;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: ExpatlioDesign.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EventCardLinePlaceholder extends StatelessWidget {
  const _EventCardLinePlaceholder({
    required this.widthFactor,
    required this.height,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: _EventCardPillPlaceholder(height: height),
    );
  }
}

class _EventCardPillPlaceholder extends StatelessWidget {
  const _EventCardPillPlaceholder({
    this.width,
    required this.height,
  });

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: ExpatlioDesign.secondarySystemBackground,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
      ),
    );
  }
}

class _EventLevelChips extends StatelessWidget {
  const _EventLevelChips({
    required this.selectedLevel,
    required this.onChanged,
  });

  final String? selectedLevel;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: ExpatlioDesign.space8,
      runSpacing: ExpatlioDesign.space8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              color: ExpatlioDesign.muted,
              size: 18,
            ),
            const SizedBox(width: ExpatlioDesign.space4),
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Уровень:',
                enText: 'Level:',
              ),
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 14,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
        for (final level in eventLevelRanks.keys)
          ChoiceChip(
            key: _eventLevelFilterChipKey(level),
            label: Text(level),
            selected: selectedLevel == level,
            onSelected: (selected) => onChanged(selected ? level : null),
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
    );
  }
}

ValueKey<String> _eventLevelFilterChipKey(String level) =>
    ValueKey<String>('event_level_filter_$level');

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
