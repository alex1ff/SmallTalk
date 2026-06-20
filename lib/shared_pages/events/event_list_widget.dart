import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as timezone;

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/events/event_create_widget.dart';
import '/shared_pages/events/event_group_chat_widget.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_city_catalog.dart';
import '/services/event_city_chip_source.dart';
import '/services/event_city_resolution.dart';
import '/services/event_city_selection_source.dart';
import '/services/event_selected_city_state.dart';
import '/services/event_temporary_city_selection.dart';
import '/services/event_list_date_bounds.dart';
import '/services/event_list_repository.dart';
import '/services/event_level_helper.dart';
import '/services/event_language_catalog.dart';
import '/services/events_analytics_service.dart';

const ValueKey<String> eventListCreateButtonKey =
    ValueKey<String>('event_list_create_button');
const ValueKey<String> eventListCitySelectorKey =
    ValueKey<String>('event_list_city_selector');
const ValueKey<String> eventManualCitySearchFieldKey =
    ValueKey<String>('event_manual_city_search_field');
const ValueKey<String> eventListLoadingStateKey =
    ValueKey<String>('event_list_loading_state');
const ValueKey<String> eventListEmptyStateKey =
    ValueKey<String>('event_list_empty_state');
const ValueKey<String> eventListErrorStateKey =
    ValueKey<String>('event_list_error_state');
const ValueKey<String> eventListErrorRetryButtonKey =
    ValueKey<String>('event_list_error_retry_button');
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
const ValueKey<String> eventListCardPrimaryCtaKey =
    ValueKey<String>('event_list_card_primary_cta');
const ValueKey<String> eventListCardChatCtaKey =
    ValueKey<String>('event_list_card_chat_cta');
const ValueKey<String> eventListChatParticipantRequiredSnackBarKey =
    ValueKey<String>('event_list_chat_participant_required_snack_bar');
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

typedef EventListNowProvider = DateTime Function();

const int _eventListPageSize = 20;

class EventListParticipantViewModel {
  const EventListParticipantViewModel({
    required this.displayName,
    this.photoUrl,
  });

  final String displayName;
  final String? photoUrl;
}

enum EventListJoinCtaState {
  join,
  joined,
  full,
  canceled,
  past,
}

enum EventListChatCtaState {
  enabled,
  participantOnly,
}

class EventListCardViewModel {
  const EventListCardViewModel({
    this.eventId = '',
    this.countryCode = '',
    this.cityKey = '',
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
    this.joinCtaState = EventListJoinCtaState.join,
    this.chatCtaState = EventListChatCtaState.participantOnly,
  });

  final String organizerDisplayName;
  final String eventId;
  final String countryCode;
  final String cityKey;
  final String? organizerPhotoUrl;
  final List<EventListParticipantViewModel> participants;
  final int? participantsCount;
  final int? capacity;
  final EventListJoinCtaState joinCtaState;
  final EventListChatCtaState chatCtaState;
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
    this.isLoadingEvents = false,
    this.eventListErrorMessage,
    this.onRetryEventsPressed,
    this.analyticsTracker,
    this.eventPageLoader,
    this.nowUtcProvider,
  });

  static String routeName = 'events';
  static String routePath = '/events';

  final EventSelectedCity? initialSelectedCity;
  final VoidCallback? onCitySelectorPressed;
  final EventCityCatalog? cityCatalogOverride;
  final EventLanguageCatalog? languageCatalogOverride;
  final List<EventListCardViewModel>? eventCardsOverride;
  final bool isLoadingEvents;
  final String? eventListErrorMessage;
  final VoidCallback? onRetryEventsPressed;
  final EventsAnalyticsTracker? analyticsTracker;
  final EventListPageLoader? eventPageLoader;
  final EventListNowProvider? nowUtcProvider;

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
  String? _lastTrackedEventListOpenKey;
  String? _lastTrackedCitySelectedKey;
  _EventListLoadKey? _eventListLoadKey;
  Future<List<EventListCardViewModel>>? _eventCardsFuture;

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
    if (oldWidget.eventPageLoader != widget.eventPageLoader ||
        oldWidget.nowUtcProvider != widget.nowUtcProvider) {
      _eventListLoadKey = null;
      _eventCardsFuture = null;
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
            final hasEventListError = widget.eventListErrorMessage != null;
            final eventCards =
                widget.eventCardsOverride ?? const <EventListCardViewModel>[];
            final eventCardsFuture =
                widget.eventCardsOverride == null && !hasEventListError
                    ? _eventCardsFutureForSelectedState(selectedState)
                    : null;
            _trackCitySelectedIfNeeded(selectedState);
            _trackEventListOpenedIfNeeded(selectedState);
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
                                onChanged: _selectDateFilter,
                              ),
                              const SizedBox(height: ExpatlioDesign.space12),
                              _EventLevelChips(
                                selectedLevel: _selectedLevel,
                                onChanged: _selectLevelFilter,
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
                                if (widget.isLoadingEvents)
                                  const _EventListLoadingState()
                                else if (hasEventListError)
                                  _EventListErrorState(
                                    message: widget.eventListErrorMessage,
                                    onRetryPressed: widget.onRetryEventsPressed,
                                  )
                                else if (eventCardsFuture != null)
                                  FutureBuilder<List<EventListCardViewModel>>(
                                    future: eventCardsFuture,
                                    builder: (context, eventsSnapshot) {
                                      if (eventsSnapshot.connectionState !=
                                          ConnectionState.done) {
                                        return const _EventListLoadingState();
                                      }
                                      if (eventsSnapshot.hasError) {
                                        return _EventListErrorState(
                                          message: null,
                                          onRetryPressed: () {
                                            setState(() {
                                              _eventListLoadKey = null;
                                              _eventCardsFuture = null;
                                            });
                                          },
                                        );
                                      }

                                      final loadedCards = eventsSnapshot.data ??
                                          const <EventListCardViewModel>[];
                                      if (loadedCards.isEmpty) {
                                        return const _EventListEmptyState();
                                      }

                                      return _EventListCards(
                                        eventCards: loadedCards,
                                        languageCatalogFuture:
                                            _languageCatalogFuture,
                                        selectedCity: selectedState?.selected,
                                        canOpenEventCardChat:
                                            _canOpenEventCardChat,
                                        openEventCardChat: _openEventCardChat,
                                        showParticipantRequiredSnackBar: () =>
                                            _showEventListChatParticipantRequiredSnackBar(
                                          context,
                                        ),
                                      );
                                    },
                                  )
                                else if (eventCards.isEmpty)
                                  const _EventListEmptyState()
                                else
                                  _EventListCards(
                                    eventCards: eventCards,
                                    languageCatalogFuture:
                                        _languageCatalogFuture,
                                    selectedCity: selectedState?.selected,
                                    canOpenEventCardChat: _canOpenEventCardChat,
                                    openEventCardChat: _openEventCardChat,
                                    showParticipantRequiredSnackBar: () =>
                                        _showEventListChatParticipantRequiredSnackBar(
                                      context,
                                    ),
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

  Future<List<EventListCardViewModel>>? _eventCardsFutureForSelectedState(
    EventSelectedCityState? selectedState,
  ) {
    final selected = selectedState?.selected;
    if (selected == null) {
      return null;
    }

    final key = _EventListLoadKey(
      countryCode: selected.city.countryCode,
      cityKey: selected.city.cityKey,
      timeZoneId: selected.city.timeZoneId,
      dateFilter: _selectedDateFilter,
      selectedLevel: _selectedLevel,
    );
    if (_eventListLoadKey != key || _eventCardsFuture == null) {
      _eventListLoadKey = key;
      _eventCardsFuture = _loadEventCards(
        selected: selected,
        dateFilter: _selectedDateFilter,
        selectedLevel: _selectedLevel,
      );
    }
    return _eventCardsFuture;
  }

  Future<List<EventListCardViewModel>> _loadEventCards({
    required EventSelectedCity selected,
    required EventListDateFilter dateFilter,
    required String? selectedLevel,
  }) async {
    final nowUtc = (widget.nowUtcProvider ?? _eventListNowUtc)();
    final normalizedNowUtc = nowUtc.isUtc ? nowUtc : nowUtc.toUtc();
    final page =
        await EventListRepository.loadLevelFilteredActiveEventPageForDateRange(
      countryCode: selected.city.countryCode,
      cityKey: selected.city.cityKey,
      timeZoneId: selected.city.timeZoneId,
      localDateRange: eventListDateFilterLocalDateRange(
        dateFilter: dateFilter,
        timeZoneId: selected.city.timeZoneId,
        nowUtc: normalizedNowUtc,
      ),
      nowUtc: normalizedNowUtc,
      pageSize: _eventListPageSize,
      selectedLevel: selectedLevel,
      pageLoader: widget.eventPageLoader,
    );

    return page.data
        .map(
          (event) => _eventListCardFromRecord(
            event,
            fallbackTimeZoneId: selected.city.timeZoneId,
            nowUtc: normalizedNowUtc,
          ),
        )
        .whereType<EventListCardViewModel>()
        .toList(growable: false);
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

  void _selectDateFilter(EventListDateFilter filter) {
    if (filter == _selectedDateFilter) {
      return;
    }
    setState(() {
      _selectedDateFilter = filter;
    });
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    unawaited(
      tracker.trackDateFilterSelected(filter).catchError(
            (Object error, StackTrace stackTrace) {},
          ),
    );
  }

  void _selectLevelFilter(String? level) {
    if (level == _selectedLevel) {
      return;
    }
    setState(() {
      _selectedLevel = level;
    });
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    unawaited(
      tracker.trackLevelFilterSelected(level).catchError(
            (Object error, StackTrace stackTrace) {},
          ),
    );
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

  void _trackEventListOpenedIfNeeded(
    EventSelectedCityState? selectedState,
  ) {
    final selected = selectedState?.selected;
    if (selected == null) {
      return;
    }
    final trackingKey =
        '${selected.city.identity}|${selected.source.analyticsValue}';
    if (_lastTrackedEventListOpenKey == trackingKey) {
      return;
    }
    _lastTrackedEventListOpenKey = trackingKey;
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    unawaited(
      tracker.trackEventListOpened(selected).catchError(
            (Object error, StackTrace stackTrace) {},
          ),
    );
  }

  void _trackCitySelectedIfNeeded(
    EventSelectedCityState? selectedState,
  ) {
    final selected = selectedState?.selected;
    if (selected == null) {
      return;
    }
    final trackingKey =
        '${selected.city.identity}|${selected.source.analyticsValue}';
    if (_lastTrackedCitySelectedKey == trackingKey) {
      return;
    }
    _lastTrackedCitySelectedKey = trackingKey;
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    unawaited(
      tracker.trackCitySelected(selected).catchError(
            (Object error, StackTrace stackTrace) {},
          ),
    );
  }

  bool _canOpenEventCardChat(EventListCardViewModel event) {
    return event.chatCtaState == EventListChatCtaState.enabled &&
        event.eventId.trim().isNotEmpty;
  }

  void _openEventCardChat({
    required EventListCardViewModel event,
    required EventSelectedCity? selectedCity,
  }) {
    final eventId = event.eventId.trim();
    if (eventId.isEmpty) {
      return;
    }
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    unawaited(
      Future<void>.sync(
        () => tracker.trackEventChatOpened(
          countryCode: event.countryCode,
          cityKey: event.cityKey,
          citySource: selectedCity?.source.analyticsValue,
        ),
      ).catchError(
        (Object error, StackTrace stackTrace) {},
      ),
    );
    context.pushNamed(
      EventGroupChatWidget.routeName,
      pathParameters: <String, String>{'eventId': eventId},
    );
  }
}

class _EventListCards extends StatelessWidget {
  const _EventListCards({
    required this.eventCards,
    required this.languageCatalogFuture,
    required this.selectedCity,
    required this.canOpenEventCardChat,
    required this.openEventCardChat,
    required this.showParticipantRequiredSnackBar,
  });

  final List<EventListCardViewModel> eventCards;
  final Future<EventLanguageCatalog>? languageCatalogFuture;
  final EventSelectedCity? selectedCity;
  final bool Function(EventListCardViewModel event) canOpenEventCardChat;
  final void Function({
    required EventListCardViewModel event,
    required EventSelectedCity? selectedCity,
  }) openEventCardChat;
  final VoidCallback showParticipantRequiredSnackBar;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<EventLanguageCatalog>(
      future: languageCatalogFuture,
      builder: (context, languageSnapshot) {
        final languageCatalog = languageSnapshot.data;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final eventCard in eventCards) ...[
              _EventCardShell(
                card: eventCard,
                languageCatalog: languageCatalog,
                onChatPressed: canOpenEventCardChat(eventCard)
                    ? () => openEventCardChat(
                          event: eventCard,
                          selectedCity: selectedCity,
                        )
                    : null,
                onChatParticipantRequiredPressed: eventCard.chatCtaState ==
                        EventListChatCtaState.participantOnly
                    ? showParticipantRequiredSnackBar
                    : null,
              ),
              if (eventCard != eventCards.last)
                const SizedBox(height: ExpatlioDesign.space12),
            ],
          ],
        );
      },
    );
  }
}

class _EventListLoadKey {
  const _EventListLoadKey({
    required this.countryCode,
    required this.cityKey,
    required this.timeZoneId,
    required this.dateFilter,
    required this.selectedLevel,
  });

  final String countryCode;
  final String cityKey;
  final String timeZoneId;
  final EventListDateFilter dateFilter;
  final String? selectedLevel;

  @override
  bool operator ==(Object other) {
    return other is _EventListLoadKey &&
        other.countryCode == countryCode &&
        other.cityKey == cityKey &&
        other.timeZoneId == timeZoneId &&
        other.dateFilter == dateFilter &&
        other.selectedLevel == selectedLevel;
  }

  @override
  int get hashCode => Object.hash(
        countryCode,
        cityKey,
        timeZoneId,
        dateFilter,
        selectedLevel,
      );
}

DateTime _eventListNowUtc() => DateTime.now().toUtc();

EventListCardViewModel? _eventListCardFromRecord(
  EventsRecord event, {
  required String fallbackTimeZoneId,
  required DateTime nowUtc,
}) {
  final startsAt = event.startsAt;
  if (startsAt == null) {
    return null;
  }
  final timeZoneId = event.timeZoneId.trim().isEmpty
      ? fallbackTimeZoneId
      : event.timeZoneId.trim();
  final participantsCount =
      event.hasParticipantsCount() ? event.participantsCount : null;
  final capacity = event.hasCapacity() ? event.capacity : null;
  final isOrganizer = currentUserUid.trim().isNotEmpty &&
      event.organizerId.trim() == currentUserUid.trim();

  return EventListCardViewModel(
    eventId: event.reference.id,
    countryCode: event.countryCode,
    cityKey: event.cityKey,
    organizerDisplayName: event.organizerDisplayName,
    organizerPhotoUrl:
        event.hasOrganizerPhotoUrl() ? event.organizerPhotoUrl.trim() : null,
    languageCode: event.languageCode,
    languageNameEn:
        event.hasLanguageNameEn() ? event.languageNameEn.trim() : null,
    languageNameRu:
        event.hasLanguageNameRu() ? event.languageNameRu.trim() : null,
    title: event.title,
    description: event.description,
    levelMin: event.levelMin,
    levelMax: event.levelMax,
    startsAt: startsAt,
    timeZoneId: timeZoneId,
    locationName: event.locationName,
    participantsCount: participantsCount,
    capacity: capacity,
    joinCtaState: _eventListJoinStateForRecord(
      event: event,
      nowUtc: nowUtc,
      isOrganizer: isOrganizer,
      participantsCount: participantsCount,
      capacity: capacity,
    ),
    chatCtaState: isOrganizer
        ? EventListChatCtaState.enabled
        : EventListChatCtaState.participantOnly,
  );
}

EventListJoinCtaState _eventListJoinStateForRecord({
  required EventsRecord event,
  required DateTime nowUtc,
  required bool isOrganizer,
  required int? participantsCount,
  required int? capacity,
}) {
  if (event.status == eventStatusCanceled) {
    return EventListJoinCtaState.canceled;
  }
  if (isOrganizer) {
    return EventListJoinCtaState.joined;
  }
  final startsAt = event.startsAt;
  if (startsAt == null || !startsAt.isAfter(nowUtc)) {
    return EventListJoinCtaState.past;
  }
  final resolvedCapacity = capacity;
  final resolvedParticipantsCount = participantsCount;
  if (resolvedCapacity != null &&
      resolvedCapacity > 0 &&
      resolvedParticipantsCount != null &&
      resolvedParticipantsCount >= resolvedCapacity) {
    return EventListJoinCtaState.full;
  }
  return EventListJoinCtaState.join;
}

class _EventListEmptyState extends StatelessWidget {
  const _EventListEmptyState();

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Пока нет событий',
      enText: 'No events yet',
    );
    final description = FFLocalizations.of(context).getVariableText(
      ruText: 'Выберите другой день, уровень или город.',
      enText: 'Choose another day, level, or city.',
    );

    return Semantics(
      key: eventListEmptyStateKey,
      container: true,
      liveRegion: true,
      label: '$title. $description',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space24,
            ExpatlioDesign.space32,
            ExpatlioDesign.space24,
            ExpatlioDesign.space32,
          ),
          decoration: ExpatlioDesign.cardDecoration(
            borderColor: ExpatlioDesign.separator,
          ),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: ExpatlioDesign.softPrimaryDecoration(
                  radius: ExpatlioDesign.radiusCapsule,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.calendar_month_outlined,
                  color: ExpatlioDesign.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: ExpatlioDesign.space16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 20,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ExpatlioDesign.space8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 15,
                  height: 1.36,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventListErrorState extends StatelessWidget {
  const _EventListErrorState({
    required this.message,
    required this.onRetryPressed,
  });

  final String? message;
  final VoidCallback? onRetryPressed;

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось загрузить события',
      enText: 'Could not load events',
    );
    final fallbackMessage = FFLocalizations.of(context).getVariableText(
      ruText: 'Проверьте подключение и попробуйте снова.',
      enText: 'Check your connection and try again.',
    );
    final retryLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Повторить',
      enText: 'Retry',
    );
    final retrySemanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Повторить загрузку событий',
      enText: 'Retry loading events',
    );
    final normalizedMessage = message?.trim() ?? '';
    final description =
        normalizedMessage.isEmpty ? fallbackMessage : normalizedMessage;

    return Semantics(
      key: eventListErrorStateKey,
      container: true,
      explicitChildNodes: true,
      liveRegion: true,
      label: '$title. $description',
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space24,
          ExpatlioDesign.space32,
          ExpatlioDesign.space24,
          ExpatlioDesign.space32,
        ),
        decoration: ExpatlioDesign.cardDecoration(
          borderColor: ExpatlioDesign.separator,
        ),
        child: Column(
          children: [
            ExcludeSemantics(
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(
                        ExpatlioDesign.radiusCapsule,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.refresh,
                      color: ExpatlioDesign.danger,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: ExpatlioDesign.space16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 20,
                      weight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: ExpatlioDesign.space8),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: ExpatlioDesign.textStyle(
                      context,
                      color: ExpatlioDesign.muted,
                      size: 15,
                      height: 1.36,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space20),
            ConstrainedBox(
              constraints: const BoxConstraints(
                minWidth: 160,
                minHeight: 48,
              ),
              child: Semantics(
                key: eventListErrorRetryButtonKey,
                container: true,
                button: true,
                enabled: onRetryPressed != null,
                label: retrySemanticsLabel,
                onTap: onRetryPressed,
                child: ExcludeSemantics(
                  child: TextButton.icon(
                    onPressed: onRetryPressed,
                    style: TextButton.styleFrom(
                      minimumSize: const Size(160, 48),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: ExpatlioDesign.space16,
                        vertical: ExpatlioDesign.space12,
                      ),
                      foregroundColor: Colors.white,
                      disabledForegroundColor: ExpatlioDesign.muted,
                      backgroundColor: ExpatlioDesign.primary,
                      disabledBackgroundColor:
                          ExpatlioDesign.secondarySystemBackground,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ExpatlioDesign.buttonRadius,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.refresh, size: 20),
                    label: Text(
                      retryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: onRetryPressed == null
                            ? ExpatlioDesign.muted
                            : Colors.white,
                        size: 16,
                        weight: FontWeight.w600,
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

class _EventListLoadingState extends StatelessWidget {
  const _EventListLoadingState();

  @override
  Widget build(BuildContext context) {
    final loadingLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Загружаем события',
      enText: 'Loading events',
    );

    return Semantics(
      key: eventListLoadingStateKey,
      container: true,
      liveRegion: true,
      label: loadingLabel,
      child: const ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventCardShell(
              card: null,
              languageCatalog: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCardShell extends StatelessWidget {
  const _EventCardShell({
    required this.card,
    required this.languageCatalog,
    this.onChatPressed,
    this.onChatParticipantRequiredPressed,
  });

  final EventListCardViewModel? card;
  final EventLanguageCatalog? languageCatalog;
  final VoidCallback? onChatPressed;
  final VoidCallback? onChatParticipantRequiredPressed;

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
          _EventCardActionsShell(
            card: card,
            onChatPressed: onChatPressed,
            onChatParticipantRequiredPressed: onChatParticipantRequiredPressed,
          ),
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
  const _EventCardActionsShell({
    required this.card,
    this.onChatPressed,
    this.onChatParticipantRequiredPressed,
  });

  final EventListCardViewModel? card;
  final VoidCallback? onChatPressed;
  final VoidCallback? onChatParticipantRequiredPressed;

  @override
  Widget build(BuildContext context) {
    final event = card;
    if (event == null) {
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

    final canOpenChat = event.chatCtaState == EventListChatCtaState.enabled &&
        onChatPressed != null;
    final canShowParticipantRequiredHint =
        event.chatCtaState == EventListChatCtaState.participantOnly &&
            onChatParticipantRequiredPressed != null;

    return Row(
      key: eventListCardActionsKey,
      children: [
        Expanded(
          child: _EventCardPrimaryCta(state: event.joinCtaState),
        ),
        const SizedBox(width: ExpatlioDesign.space12),
        _EventCardChatCta(
          state: event.chatCtaState,
          onPressed: canOpenChat ? onChatPressed : null,
          onParticipantRequiredPressed: canShowParticipantRequiredHint
              ? onChatParticipantRequiredPressed
              : null,
        ),
      ],
    );
  }
}

class _EventCardPrimaryCta extends StatelessWidget {
  const _EventCardPrimaryCta({
    required this.state,
  });

  final EventListJoinCtaState state;

  @override
  Widget build(BuildContext context) {
    final enabled = state == EventListJoinCtaState.join;
    final backgroundColor = enabled
        ? ExpatlioDesign.primary
        : ExpatlioDesign.secondarySystemBackground;
    final textColor = enabled
        ? Colors.white
        : state == EventListJoinCtaState.joined
            ? ExpatlioDesign.primary
            : ExpatlioDesign.muted;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Container(
        key: eventListCardPrimaryCtaKey,
        height: 48,
        alignment: Alignment.center,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ExpatlioDesign.space16,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
        ),
        child: Text(
          _eventPrimaryCtaLabel(context, state),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: ExpatlioDesign.textStyle(
            context,
            color: textColor,
            size: 16,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EventCardChatCta extends StatelessWidget {
  const _EventCardChatCta({
    required this.state,
    required this.onPressed,
    this.onParticipantRequiredPressed,
  });

  final EventListChatCtaState state;
  final VoidCallback? onPressed;
  final VoidCallback? onParticipantRequiredPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = state == EventListChatCtaState.enabled && onPressed != null;
    final effectiveOnPressed = enabled
        ? onPressed
        : state == EventListChatCtaState.participantOnly
            ? onParticipantRequiredPressed
            : null;
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Чат',
      enText: 'Chat',
    );
    final disabledLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Чат доступен только участникам',
      enText: 'Chat is available to participants only',
    );
    final foregroundColor =
        enabled ? ExpatlioDesign.text : ExpatlioDesign.disabled;

    return Semantics(
      key: eventListCardChatCtaKey,
      container: true,
      button: true,
      enabled: enabled,
      label: enabled ? label : disabledLabel,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: TextButton.icon(
          onPressed: effectiveOnPressed,
          style: ButtonStyle(
            minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
            padding: const WidgetStatePropertyAll(
              EdgeInsetsDirectional.symmetric(
                horizontal: ExpatlioDesign.space12,
              ),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(ExpatlioDesign.buttonRadius),
              ),
            ),
            foregroundColor: WidgetStatePropertyAll(foregroundColor),
            iconColor: WidgetStatePropertyAll(foregroundColor),
            backgroundColor: WidgetStatePropertyAll(
              enabled
                  ? ExpatlioDesign.secondarySystemBackground
                  : ExpatlioDesign.secondarySystemBackground.withValues(
                      alpha: 0.62,
                    ),
            ),
            overlayColor: WidgetStatePropertyAll(
              ExpatlioDesign.primary.withValues(alpha: 0.08),
            ),
          ),
          icon: Icon(
            enabled ? Icons.chat_bubble_outline : Icons.lock_outline,
            size: 20,
          ),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: foregroundColor,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

void _showEventListChatParticipantRequiredSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      key: eventListChatParticipantRequiredSnackBarKey,
      content: Text(
        FFLocalizations.of(context).getVariableText(
          ruText: 'Сначала присоединитесь к событию',
          enText: 'Join the event first',
        ),
      ),
    ),
  );
}

String _eventPrimaryCtaLabel(
  BuildContext context,
  EventListJoinCtaState state,
) {
  return switch (state) {
    EventListJoinCtaState.join => FFLocalizations.of(context).getVariableText(
        ruText: 'Присоединиться',
        enText: 'Join',
      ),
    EventListJoinCtaState.joined => FFLocalizations.of(context).getVariableText(
        ruText: 'Вы участвуете',
        enText: 'Joined',
      ),
    EventListJoinCtaState.full => FFLocalizations.of(context).getVariableText(
        ruText: 'Мест нет',
        enText: 'Full',
      ),
    EventListJoinCtaState.canceled =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Отменено',
        enText: 'Canceled',
      ),
    EventListJoinCtaState.past => FFLocalizations.of(context).getVariableText(
        ruText: 'Уже началось',
        enText: 'Already started',
      ),
  };
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
