import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as timezone;

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/components/ux_error_state.dart';
import '/components/ux_refreshing_indicator_overlay.dart';
import '/components/profile_dropdown_menu_item.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/events/event_create_widget.dart';
import '/shared_pages/events/event_detail_widget.dart';
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
const ValueKey<String> eventListRefreshingIndicatorKey =
    ValueKey<String>('event_list_refreshing_indicator');
const ValueKey<String> eventListRefreshingEmptyShellKey =
    ValueKey<String>('event_list_refreshing_empty_shell');
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
typedef EventListCurrentUserParticipantLoader = Future<EventParticipantsRecord?>
    Function(
  DocumentReference eventRef,
  String userId,
);
typedef EventListActiveParticipantsLoader
    = Future<List<EventParticipantsRecord>> Function(
  DocumentReference eventRef,
);

const int _eventListPageSize = 20;
const int _eventListParticipantPreviewLimit = 6;
const int _eventListCardsCacheMaxEntries = 24;
const Duration _eventListCardsCacheTtl = Duration(minutes: 5);
const double _eventListHorizontalPadding = 17.0;
const double _eventListTopPadding = 10.0;
const double _eventListCardRadius = 15.0;
const double _eventListCardBorderWidth = 1.0;
const double _eventListCardPadding = 16.0;
const double _eventListCardHeaderBodyGap = 14.0;
const double _eventListCardBodyMetaGap = 8.0;
const double _eventListCardMetaPlaceGap = 13.0;
const double _eventListCardMetaFooterGap = 14.0;
const double _eventListCardFooterActionsGap = 14.0;
const double _eventListDateChipHeight = 30.0;
const double _eventListLevelChipHeight = 24.0;
const double _eventListActionHeight = 48.0;
const double _eventListActionGap = 8.0;
const double _eventListActionRadius = 14.0;
const double _eventListActionStackThresholdLineHeight = 17.0;
const double _eventListActionVerticalPadding = 16.0;
const int _eventListActionMaxLines = 2;
const int _eventListStackedActionMaxLines = 3;
const int _eventListPrimaryActionFlex = 5;
const int _eventListSecondaryActionFlex = 2;
const double _eventListOrganizerAvatarSize = 36.0;
const double _eventListOrganizerLabelFontSize = 12.0;
const double _eventListOrganizerNameFontSize = 13.0;
const double _eventListLevelFontSize = 12.0;
const double _eventListTitleFontSize = 15.0;
const double _eventListDescriptionFontSize = 13.0;
const double _eventListMetaFontSize = 12.0;
const double _eventListPlaceFontSize = 13.0;
const double _eventListFooterFontSize = 13.0;
const double _eventListActionFontSize = 13.0;
const double _eventListDefaultTextHeight = 1.28;
const double _eventListLevelTextHeight = 1.18;
const double _eventListTitleTextHeight = 1.22;
const double _eventListDescriptionTextHeight = 1.38;
const double _eventListActionTextHeight = 1.0;
const Color _eventListBorderColor = Color(0xFFEBEBEB);
const Color _eventListChipBackground = ExpatlioDesign.card;
const Color _eventListSoftPrimaryBackground = Color(0xFFF0E6FF);

final DateTime _eventListAllEventsUpperBoundUtc = DateTime.utc(9999, 12, 31);

final _eventListCardsCache = _EventListCardsMemoryCache(
  maxEntries: _eventListCardsCacheMaxEntries,
  ttl: _eventListCardsCacheTtl,
);

void debugClearEventListCache() => _eventListCardsCache.clear();

class EventListParticipantViewModel {
  const EventListParticipantViewModel({
    this.userId = '',
    required this.displayName,
    this.photoUrl,
  });

  final String userId;
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

enum EventListMembershipState {
  resolved,
  pending,
  lookupFailed,
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
    this.membershipState = EventListMembershipState.resolved,
    this.reserveParticipantPreviewSpace = false,
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
  final EventListMembershipState membershipState;
  final bool reserveParticipantPreviewSpace;
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

  bool get hasParticipantPreviewRegion =>
      hasParticipantPreview || reserveParticipantPreviewSpace;

  bool get hasOccupancy => capacity != null && capacity! > 0;

  bool get hasFooterContent => hasParticipantPreviewRegion || hasOccupancy;

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
    this.currentUserParticipantLoader,
    this.activeParticipantsLoader,
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
  final EventListCurrentUserParticipantLoader? currentUserParticipantLoader;
  final EventListActiveParticipantsLoader? activeParticipantsLoader;
  final EventListNowProvider? nowUtcProvider;

  @override
  State<EventListWidget> createState() => _EventListWidgetState();
}

class _EventListWidgetState extends State<EventListWidget> {
  late EventSelectedCity? _selectedCity;
  EventListDateFilter? _selectedDateFilter;
  String? _selectedLevel;
  Future<EventCityCatalog>? _cityCatalogFuture;
  Future<List<EventCityChip>>? _cityChipsFuture;
  EventCityCatalog? _cityChipsCatalog;
  String? _cityChipsCountryCodeHint;
  String? _cityChipsSelectedIdentity;
  String? _lastTrackedEventListOpenKey;
  String? _lastTrackedCitySelectedKey;
  _EventListLoadKey? _eventListLoadKey;
  Future<List<EventListCardViewModel>>? _eventCardsFuture;
  List<EventListCardViewModel>? _eventCardsFutureInitialCards;
  _EventListLoadedCards? _lastLoadedCards;
  int _eventListLoadGeneration = 0;

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
    if (oldWidget.eventCardsOverride != widget.eventCardsOverride ||
        oldWidget.eventPageLoader != widget.eventPageLoader ||
        oldWidget.currentUserParticipantLoader !=
            widget.currentUserParticipantLoader ||
        oldWidget.activeParticipantsLoader != widget.activeParticipantsLoader ||
        oldWidget.nowUtcProvider != widget.nowUtcProvider) {
      _resetEventCardsLoadState(clearLastLoadedCards: true);
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
          initialData: widget.cityCatalogOverride,
          builder: (context, snapshot) {
            final catalog = snapshot.data;
            final selectedState = _resolveVisibleSelectedCityState(
              catalog,
            );
            final canShowEventCards = selectedState?.canLoadEvents ?? false;
            final hasEventListError = widget.eventListErrorMessage != null;
            final eventCards =
                widget.eventCardsOverride ?? const <EventListCardViewModel>[];
            final hasVisibleEventCards = eventCards.isNotEmpty;
            final eventCardsFuture =
                widget.eventCardsOverride == null && !hasEventListError
                    ? _eventCardsFutureForSelectedState(selectedState)
                    : null;
            _trackCitySelectedIfNeeded(selectedState);
            _trackEventListOpenedIfNeeded(selectedState);
            final onCitySelectorPressed = widget.onCitySelectorPressed != null
                ? (_) async => widget.onCitySelectorPressed?.call()
                : (catalog == null
                    ? null
                    : (BuildContext anchorContext) => _openCityDropdown(
                          anchorContext: anchorContext,
                          catalog: catalog,
                          selectedCity: selectedState?.selected,
                          countryCodeHint: selectedState?.countryCodeHint,
                        ));

            return Scaffold(
              backgroundColor: ExpatlioDesign.background,
              body: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    _eventListHorizontalPadding,
                    _eventListTopPadding,
                    _eventListHorizontalPadding,
                    0,
                  ),
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
                                size: 18,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: ExpatlioDesign.space12),
                          Tooltip(
                            message:
                                FFLocalizations.of(context).getVariableText(
                              ruText: 'Создать событие',
                              enText: 'Create event',
                            ),
                            child: Material(
                              color: _eventListSoftPrimaryBackground,
                              shape: const CircleBorder(),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                key: eventListCreateButtonKey,
                                customBorder: const CircleBorder(),
                                onTap: () => context.pushNamed(
                                  EventCreateWidget.routeName,
                                ),
                                child: const SizedBox.square(
                                  dimension: 36,
                                  child: Center(
                                    child: Icon(
                                      Icons.add_sharp,
                                      color: ExpatlioDesign.primary,
                                      size: 22,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsetsDirectional.only(
                            bottom: ExpatlioDesign.pageBottomSpacing,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _EventDateChips(
                                selectedFilter: _selectedDateFilter,
                                onChanged: _selectDateFilter,
                              ),
                              const SizedBox(height: ExpatlioDesign.space8),
                              _EventLevelChips(
                                selectedLevel: _selectedLevel,
                                onChanged: _selectLevelFilter,
                              ),
                              if (selectedState == null ||
                                  selectedState.needsCitySelection ||
                                  selectedState.hasOutdatedProfileCity) ...[
                                const SizedBox(
                                  height: ExpatlioDesign.space16,
                                ),
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
                              ],
                              if (canShowEventCards) ...[
                                const SizedBox(height: ExpatlioDesign.space16),
                                if (widget.isLoadingEvents) ...[
                                  if (hasVisibleEventCards)
                                    _EventListPreviousCardsState(
                                      cards: eventCards,
                                      selectedCity: selectedState?.selected,
                                      isRefreshing: true,
                                      canOpenEventCardChat:
                                          _canOpenEventCardChat,
                                      openEventCardDetail: _openEventCardDetail,
                                      openEventCardChat: _openEventCardChat,
                                      showParticipantRequiredSnackBar: () =>
                                          _showEventListChatParticipantRequiredSnackBar(
                                        context,
                                      ),
                                    )
                                  else
                                    const _EventListLoadingState(),
                                ] else if (hasEventListError) ...[
                                  _EventListErrorState(
                                    message: widget.eventListErrorMessage,
                                    onRetryPressed: widget.onRetryEventsPressed,
                                    compact: hasVisibleEventCards,
                                  ),
                                  if (hasVisibleEventCards) ...[
                                    const SizedBox(
                                      height: ExpatlioDesign.space12,
                                    ),
                                    _EventListCards(
                                      eventCards: eventCards,
                                      selectedCity: selectedState?.selected,
                                      canOpenEventCardChat:
                                          _canOpenEventCardChat,
                                      openEventCardDetail: _openEventCardDetail,
                                      openEventCardChat: _openEventCardChat,
                                      showParticipantRequiredSnackBar: () =>
                                          _showEventListChatParticipantRequiredSnackBar(
                                        context,
                                      ),
                                    ),
                                  ],
                                ] else if (eventCardsFuture != null)
                                  FutureBuilder<List<EventListCardViewModel>>(
                                    key: ValueKey(_eventListLoadKey),
                                    future: eventCardsFuture,
                                    initialData: _eventCardsFutureInitialCards,
                                    builder: (context, eventsSnapshot) {
                                      final activeLoadKey = _eventListLoadKey;
                                      final previousCards =
                                          _previousCardsForActiveKey(
                                        activeLoadKey,
                                      );
                                      if (eventsSnapshot.connectionState !=
                                          ConnectionState.done) {
                                        final initialCards =
                                            _eventCardsFutureInitialCards;
                                        if (initialCards != null) {
                                          if (initialCards.isEmpty) {
                                            return const _EventListEmptyState();
                                          }
                                          return _EventListCards(
                                            eventCards: initialCards,
                                            selectedCity:
                                                selectedState?.selected,
                                            canOpenEventCardChat:
                                                _canOpenEventCardChat,
                                            openEventCardDetail:
                                                _openEventCardDetail,
                                            openEventCardChat:
                                                _openEventCardChat,
                                            showParticipantRequiredSnackBar: () =>
                                                _showEventListChatParticipantRequiredSnackBar(
                                              context,
                                            ),
                                          );
                                        }
                                        if (previousCards != null) {
                                          return _EventListPreviousCardsState(
                                            cards: previousCards.cards,
                                            selectedCity:
                                                selectedState?.selected,
                                            isRefreshing: true,
                                            showEmptyState: previousCards
                                                    .key.activeDataKey ==
                                                activeLoadKey?.activeDataKey,
                                            canOpenEventCardChat:
                                                _canOpenEventCardChat,
                                            openEventCardDetail:
                                                _openEventCardDetail,
                                            openEventCardChat:
                                                _openEventCardChat,
                                            showParticipantRequiredSnackBar: () =>
                                                _showEventListChatParticipantRequiredSnackBar(
                                              context,
                                            ),
                                          );
                                        }
                                        return const _EventListLoadingState();
                                      }
                                      if (eventsSnapshot.hasError) {
                                        if (previousCards != null) {
                                          return _EventListPreviousCardsState(
                                            cards: previousCards.cards,
                                            selectedCity:
                                                selectedState?.selected,
                                            errorMessage: null,
                                            onRetryPressed:
                                                _retryEventCardsLoad,
                                            canOpenEventCardChat:
                                                _canOpenEventCardChat,
                                            openEventCardDetail:
                                                _openEventCardDetail,
                                            openEventCardChat:
                                                _openEventCardChat,
                                            showParticipantRequiredSnackBar: () =>
                                                _showEventListChatParticipantRequiredSnackBar(
                                              context,
                                            ),
                                          );
                                        }
                                        return _EventListErrorState(
                                          message: null,
                                          onRetryPressed: _retryEventCardsLoad,
                                        );
                                      }

                                      final loadedCards = eventsSnapshot.data ??
                                          const <EventListCardViewModel>[];
                                      if (loadedCards.isEmpty) {
                                        return const _EventListEmptyState();
                                      }

                                      return _EventListCards(
                                        eventCards: loadedCards,
                                        selectedCity: selectedState?.selected,
                                        canOpenEventCardChat:
                                            _canOpenEventCardChat,
                                        openEventCardDetail:
                                            _openEventCardDetail,
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
                                    selectedCity: selectedState?.selected,
                                    canOpenEventCardChat: _canOpenEventCardChat,
                                    openEventCardDetail: _openEventCardDetail,
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

    final nowUtc = (widget.nowUtcProvider ?? _eventListNowUtc)();
    final normalizedNowUtc = nowUtc.isUtc ? nowUtc : nowUtc.toUtc();
    final viewerUserId = currentUserUid.trim();
    final selectedDateFilter = _selectedDateFilter;
    final localDateRange = selectedDateFilter == null
        ? null
        : eventListDateFilterLocalDateRange(
            dateFilter: selectedDateFilter,
            timeZoneId: selected.city.timeZoneId,
            nowUtc: normalizedNowUtc,
          );
    final key = _EventListLoadKey(
      countryCode: selected.city.countryCode,
      cityKey: selected.city.cityKey,
      timeZoneId: selected.city.timeZoneId,
      dateFilter: selectedDateFilter,
      localStartDate: localDateRange?.startDate,
      localExclusiveEndDate: localDateRange?.exclusiveEndDate,
      selectedLevel: _selectedLevel,
      pageLoaderIdentity: widget.eventPageLoader == null
          ? 0
          : identityHashCode(widget.eventPageLoader),
      currentUserId: viewerUserId,
      participantLoaderIdentity: widget.currentUserParticipantLoader == null
          ? 0
          : identityHashCode(widget.currentUserParticipantLoader),
      activeParticipantsLoaderIdentity: widget.activeParticipantsLoader == null
          ? 0
          : identityHashCode(widget.activeParticipantsLoader),
    );
    if (_eventListLoadKey != key || _eventCardsFuture == null) {
      _eventListLoadGeneration += 1;
      _eventListLoadKey = key;
      final loadGeneration = _eventListLoadGeneration;
      final cachedCards = _eventListCardsCache.read(
        key,
        nowUtc: normalizedNowUtc,
      );
      if (cachedCards != null) {
        _rememberLoadedCards(key, cachedCards);
      }
      _eventCardsFutureInitialCards = cachedCards;
      _eventCardsFuture = cachedCards == null
          ? _loadBaseEventCards(
              selected: selected,
              localDateRange: localDateRange,
              nowUtc: normalizedNowUtc,
              selectedLevel: _selectedLevel,
              currentUserId: viewerUserId,
            ).then((baseLoad) {
              if (_eventListLoadIsCurrent(key, loadGeneration)) {
                _rememberLoadedCards(key, baseLoad.cards);
                if (baseLoad.cards.isNotEmpty) {
                  unawaited(
                    _enrichEventCards(
                      events: baseLoad.events,
                      fallbackTimeZoneId: selected.city.timeZoneId,
                      key: key,
                      nowUtc: normalizedNowUtc,
                      currentUserId: viewerUserId,
                      loadGeneration: loadGeneration,
                    ),
                  );
                }
              }
              return baseLoad.cards;
            })
          : Future<List<EventListCardViewModel>>.value(cachedCards);
    }
    return _eventCardsFuture;
  }

  bool _eventListLoadIsCurrent(_EventListLoadKey key, int loadGeneration) {
    return mounted &&
        _eventListLoadKey == key &&
        _eventListLoadGeneration == loadGeneration;
  }

  void _rememberLoadedCards(
    _EventListLoadKey? key,
    List<EventListCardViewModel> cards,
  ) {
    if (key == null) {
      return;
    }
    _lastLoadedCards = _EventListLoadedCards(
      key: key,
      cards: List<EventListCardViewModel>.unmodifiable(cards),
    );
  }

  _EventListLoadedCards? _previousCardsForActiveKey(_EventListLoadKey? key) {
    final previous = _lastLoadedCards;
    if (key == null || previous == null) {
      return null;
    }
    // List filters and city changes are compatible stale content; account
    // changes are not.
    if (previous.key.currentUserId != key.currentUserId) {
      return null;
    }
    return previous;
  }

  void _retryEventCardsLoad() {
    setState(() {
      final key = _eventListLoadKey;
      if (key != null) {
        _eventListCardsCache.remove(key);
      }
      _resetEventCardsLoadState(clearLastLoadedCards: false);
    });
  }

  void _resetEventCardsLoadState({required bool clearLastLoadedCards}) {
    _eventListLoadGeneration += 1;
    _eventListLoadKey = null;
    _eventCardsFuture = null;
    _eventCardsFutureInitialCards = null;
    if (clearLastLoadedCards) {
      _lastLoadedCards = null;
    }
  }

  Future<_EventListBaseCardsLoad> _loadBaseEventCards({
    required EventSelectedCity selected,
    required EventListLocalDateRange? localDateRange,
    required DateTime nowUtc,
    required String? selectedLevel,
    required String currentUserId,
  }) async {
    final page = localDateRange == null
        ? await EventListRepository.loadLevelFilteredActiveEventPage(
            countryCode: selected.city.countryCode,
            cityKey: selected.city.cityKey,
            lowerBoundUtc: nowUtc,
            upperBoundUtc: _eventListAllEventsUpperBoundUtc,
            pageSize: _eventListPageSize,
            selectedLevel: selectedLevel,
            pageLoader: widget.eventPageLoader,
          )
        : await EventListRepository
            .loadLevelFilteredActiveEventPageForDateRange(
            countryCode: selected.city.countryCode,
            cityKey: selected.city.cityKey,
            timeZoneId: selected.city.timeZoneId,
            localDateRange: localDateRange,
            nowUtc: nowUtc,
            pageSize: _eventListPageSize,
            selectedLevel: selectedLevel,
            pageLoader: widget.eventPageLoader,
          );

    final cards = page.data
        .map(
          (event) => _eventListCardFromRecord(
            event,
            fallbackTimeZoneId: selected.city.timeZoneId,
            nowUtc: nowUtc,
            currentUserId: currentUserId,
            membershipState: _eventListMembershipNeedsLookup(
              event,
              currentUserId,
            )
                ? EventListMembershipState.pending
                : EventListMembershipState.resolved,
          ),
        )
        .whereType<EventListCardViewModel>()
        .toList(growable: false);
    return _EventListBaseCardsLoad(events: page.data, cards: cards);
  }

  Future<void> _enrichEventCards({
    required List<EventsRecord> events,
    required String fallbackTimeZoneId,
    required _EventListLoadKey key,
    required DateTime nowUtc,
    required String currentUserId,
    required int loadGeneration,
  }) async {
    final currentParticipantsFuture =
        _loadCurrentUserParticipantRecordsByEventId(
      events: events,
      currentUserId: currentUserId,
    );
    final activeParticipantsFuture =
        _loadActiveParticipantRecordsByEventId(events: events);
    final membershipLoad = await currentParticipantsFuture;
    final activeParticipantRecordsByEventId = await activeParticipantsFuture;

    if (!_eventListLoadIsCurrent(key, loadGeneration)) {
      return;
    }

    final enrichedCards = events
        .map(
          (event) => _eventListCardFromRecord(
            event,
            fallbackTimeZoneId: fallbackTimeZoneId,
            nowUtc: nowUtc,
            currentUserId: currentUserId,
            currentUserParticipant:
                membershipLoad.recordsByEventId[event.reference.id],
            activeParticipants:
                activeParticipantRecordsByEventId[event.reference.id] ??
                    const <EventParticipantsRecord>[],
            membershipState:
                membershipLoad.failedEventIds.contains(event.reference.id)
                    ? EventListMembershipState.lookupFailed
                    : EventListMembershipState.resolved,
          ),
        )
        .whereType<EventListCardViewModel>()
        .toList(growable: false);
    if (!_eventListLoadIsCurrent(key, loadGeneration)) {
      return;
    }

    if (enrichedCards.isNotEmpty && membershipLoad.failedEventIds.isEmpty) {
      _eventListCardsCache.write(
        key,
        enrichedCards,
        fetchedAtUtc: nowUtc,
      );
    }
    setState(() {
      _eventCardsFutureInitialCards = enrichedCards;
      _eventCardsFuture =
          Future<List<EventListCardViewModel>>.value(enrichedCards);
      _rememberLoadedCards(key, enrichedCards);
    });
  }

  Future<_EventListMembershipLoad> _loadCurrentUserParticipantRecordsByEventId({
    required List<EventsRecord> events,
    required String currentUserId,
  }) async {
    final userId = currentUserId.trim();
    if (events.isEmpty || userId.isEmpty) {
      return const _EventListMembershipLoad();
    }
    final loader =
        widget.currentUserParticipantLoader ?? _loadEventListParticipant;
    final entries = await Future.wait(
      events.map((event) async {
        if (!_eventListMembershipNeedsLookup(event, userId)) {
          return _EventListMembershipLookupResult(
            eventId: event.reference.id,
          );
        }
        try {
          final participant = await loader(event.reference, userId);
          if (!_eventListParticipantIsActiveForUser(
            participant,
            eventReference: event.reference,
            userId: userId,
          )) {
            return _EventListMembershipLookupResult(
              eventId: event.reference.id,
            );
          }
          return _EventListMembershipLookupResult(
            eventId: event.reference.id,
            participant: participant,
          );
        } catch (_) {
          return _EventListMembershipLookupResult(
            eventId: event.reference.id,
            failed: true,
          );
        }
      }),
    );
    return _EventListMembershipLoad(
      recordsByEventId: Map<String, EventParticipantsRecord>.fromEntries(
        entries.where((entry) => entry.participant != null).map(
              (entry) => MapEntry(entry.eventId, entry.participant!),
            ),
      ),
      failedEventIds: Set<String>.unmodifiable(
        entries.where((entry) => entry.failed).map((entry) => entry.eventId),
      ),
    );
  }

  Future<Map<String, List<EventParticipantsRecord>>>
      _loadActiveParticipantRecordsByEventId({
    required List<EventsRecord> events,
  }) async {
    if (events.isEmpty) {
      return const <String, List<EventParticipantsRecord>>{};
    }
    if (widget.activeParticipantsLoader == null &&
        widget.eventPageLoader != null) {
      return const <String, List<EventParticipantsRecord>>{};
    }
    final loader = widget.activeParticipantsLoader ??
        _loadEventListActiveParticipantPreview;
    final entries = await Future.wait(
      events.map((event) async {
        try {
          final participants = await loader(event.reference);
          final activeParticipants = participants
              .where((participant) =>
                  participant.status.trim() == eventStatusActive &&
                  participant.parentReference.path == event.reference.path)
              .toList(growable: false);
          if (activeParticipants.isEmpty) {
            return null;
          }
          return MapEntry(event.reference.id, activeParticipants);
        } catch (_) {
          return null;
        }
      }),
    );
    return Map<String, List<EventParticipantsRecord>>.fromEntries(
      entries.whereType<MapEntry<String, List<EventParticipantsRecord>>>(),
    );
  }

  Future<void> _openCityDropdown({
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
    final selectedOption = await _showEventListDropdownMenu<EventCityChip>(
      anchorContext,
      options: [
        for (final option in options)
          _EventListDropdownMenuOption<EventCityChip>(
            key: _eventManualCityOptionKey(option.city),
            value: option,
            label: _cityChipLabel(context, option.city),
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
    await _selectTemporaryCity(
      catalog: catalog,
      city: selectedOption.city,
      source: selectedOption.source,
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

  void _selectDateFilter(EventListDateFilter? filter) {
    if (filter == _selectedDateFilter) {
      return;
    }
    setState(() {
      _selectedDateFilter = filter;
    });
    if (filter == null) {
      return;
    }
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

  void _openEventCardDetail(EventListCardViewModel event) {
    final eventId = event.eventId.trim();
    if (eventId.isEmpty) {
      return;
    }
    final detailNavigation = context.pushNamed(
      EventDetailWidget.routeName,
      pathParameters: <String, String>{'eventId': eventId},
    );
    unawaited(
      detailNavigation.whenComplete(_invalidateEventCardsAfterDetailReturn),
    );
  }

  void _invalidateEventCardsAfterDetailReturn() {
    if (!mounted) {
      return;
    }
    setState(() {
      _eventListCardsCache.clear();
      _resetEventCardsLoadState(clearLastLoadedCards: true);
    });
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
    required this.selectedCity,
    required this.canOpenEventCardChat,
    required this.openEventCardDetail,
    required this.openEventCardChat,
    required this.showParticipantRequiredSnackBar,
  });

  final List<EventListCardViewModel> eventCards;
  final EventSelectedCity? selectedCity;
  final bool Function(EventListCardViewModel event) canOpenEventCardChat;
  final ValueChanged<EventListCardViewModel> openEventCardDetail;
  final void Function({
    required EventListCardViewModel event,
    required EventSelectedCity? selectedCity,
  }) openEventCardChat;
  final VoidCallback showParticipantRequiredSnackBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final eventCard in eventCards) ...[
          _EventCardShell(
            card: eventCard,
            onPressed: eventCard.eventId.trim().isEmpty
                ? null
                : () => openEventCardDetail(eventCard),
            onChatPressed: canOpenEventCardChat(eventCard)
                ? () => openEventCardChat(
                      event: eventCard,
                      selectedCity: selectedCity,
                    )
                : null,
            onChatParticipantRequiredPressed:
                eventCard.chatCtaState == EventListChatCtaState.participantOnly
                    ? showParticipantRequiredSnackBar
                    : null,
          ),
          if (eventCard != eventCards.last)
            const SizedBox(height: ExpatlioDesign.space12),
        ],
      ],
    );
  }
}

class _EventListPreviousCardsState extends StatelessWidget {
  const _EventListPreviousCardsState({
    required this.cards,
    required this.selectedCity,
    required this.canOpenEventCardChat,
    required this.openEventCardDetail,
    required this.openEventCardChat,
    required this.showParticipantRequiredSnackBar,
    this.errorMessage,
    this.onRetryPressed,
    this.isRefreshing = false,
    this.showEmptyState = true,
  });

  final List<EventListCardViewModel> cards;
  final EventSelectedCity? selectedCity;
  final String? errorMessage;
  final VoidCallback? onRetryPressed;
  final bool isRefreshing;
  final bool showEmptyState;
  final bool Function(EventListCardViewModel event) canOpenEventCardChat;
  final ValueChanged<EventListCardViewModel> openEventCardDetail;
  final void Function({
    required EventListCardViewModel event,
    required EventSelectedCity? selectedCity,
  }) openEventCardChat;
  final VoidCallback showParticipantRequiredSnackBar;

  @override
  Widget build(BuildContext context) {
    final errorState = errorMessage == null && onRetryPressed == null
        ? null
        : _EventListErrorState(
            message: errorMessage,
            onRetryPressed: onRetryPressed,
            compact: true,
          );
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (errorState != null) ...[
          errorState,
          const SizedBox(height: ExpatlioDesign.space12),
        ],
        if (cards.isEmpty)
          if (showEmptyState)
            const _EventListEmptyState()
          else
            SizedBox(
              key: eventListRefreshingEmptyShellKey,
              width: double.infinity,
              height: _eventListEmptyStateHeight(context),
            )
        else
          _EventListCards(
            eventCards: cards,
            selectedCity: selectedCity,
            canOpenEventCardChat: canOpenEventCardChat,
            openEventCardDetail: openEventCardDetail,
            openEventCardChat: openEventCardChat,
            showParticipantRequiredSnackBar: showParticipantRequiredSnackBar,
          ),
      ],
    );

    if (!isRefreshing) {
      return content;
    }

    final refreshingLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Обновляем события',
      enText: 'Refreshing events',
    );

    return UxRefreshingIndicatorOverlay(
      key: eventListRefreshingIndicatorKey,
      isRefreshing: true,
      semanticsLabel: refreshingLabel,
      child: content,
    );
  }
}

class _EventListLoadedCards {
  const _EventListLoadedCards({
    required this.key,
    required this.cards,
  });

  final _EventListLoadKey key;
  final List<EventListCardViewModel> cards;
}

class _EventListBaseCardsLoad {
  const _EventListBaseCardsLoad({
    required this.events,
    required this.cards,
  });

  final List<EventsRecord> events;
  final List<EventListCardViewModel> cards;
}

class _EventListMembershipLoad {
  const _EventListMembershipLoad({
    this.recordsByEventId = const <String, EventParticipantsRecord>{},
    this.failedEventIds = const <String>{},
  });

  final Map<String, EventParticipantsRecord> recordsByEventId;
  final Set<String> failedEventIds;
}

class _EventListMembershipLookupResult {
  const _EventListMembershipLookupResult({
    required this.eventId,
    this.participant,
    this.failed = false,
  });

  final String eventId;
  final EventParticipantsRecord? participant;
  final bool failed;
}

class _EventListLoadKey {
  const _EventListLoadKey({
    required this.countryCode,
    required this.cityKey,
    required this.timeZoneId,
    required this.dateFilter,
    required this.localStartDate,
    required this.localExclusiveEndDate,
    required this.selectedLevel,
    required this.pageLoaderIdentity,
    required this.currentUserId,
    required this.participantLoaderIdentity,
    required this.activeParticipantsLoaderIdentity,
  });

  final String countryCode;
  final String cityKey;
  final String timeZoneId;
  final EventListDateFilter? dateFilter;
  final DateTime? localStartDate;
  final DateTime? localExclusiveEndDate;
  final String? selectedLevel;
  final int pageLoaderIdentity;
  final String currentUserId;
  final int participantLoaderIdentity;
  final int activeParticipantsLoaderIdentity;

  _EventListActiveDataKey get activeDataKey => _EventListActiveDataKey(
        countryCode: countryCode,
        cityKey: cityKey,
        dateFilter: dateFilter,
        selectedLevel: selectedLevel,
        currentUserId: currentUserId,
      );

  @override
  bool operator ==(Object other) {
    return other is _EventListLoadKey &&
        other.countryCode == countryCode &&
        other.cityKey == cityKey &&
        other.timeZoneId == timeZoneId &&
        other.dateFilter == dateFilter &&
        other.localStartDate == localStartDate &&
        other.localExclusiveEndDate == localExclusiveEndDate &&
        other.selectedLevel == selectedLevel &&
        other.pageLoaderIdentity == pageLoaderIdentity &&
        other.currentUserId == currentUserId &&
        other.participantLoaderIdentity == participantLoaderIdentity &&
        other.activeParticipantsLoaderIdentity ==
            activeParticipantsLoaderIdentity;
  }

  @override
  int get hashCode => Object.hash(
        countryCode,
        cityKey,
        timeZoneId,
        dateFilter,
        localStartDate,
        localExclusiveEndDate,
        selectedLevel,
        pageLoaderIdentity,
        currentUserId,
        participantLoaderIdentity,
        activeParticipantsLoaderIdentity,
      );
}

/// Visual query identity. Request windows, time zones, and loader identities
/// stay in [_EventListLoadKey] because they must not turn the same visible
/// filters into a different empty-state identity.
class _EventListActiveDataKey {
  const _EventListActiveDataKey({
    required this.countryCode,
    required this.cityKey,
    required this.dateFilter,
    required this.selectedLevel,
    required this.currentUserId,
  });

  final String countryCode;
  final String cityKey;
  final EventListDateFilter? dateFilter;
  final String? selectedLevel;
  final String currentUserId;

  @override
  bool operator ==(Object other) {
    return other is _EventListActiveDataKey &&
        other.countryCode == countryCode &&
        other.cityKey == cityKey &&
        other.dateFilter == dateFilter &&
        other.selectedLevel == selectedLevel &&
        other.currentUserId == currentUserId;
  }

  @override
  int get hashCode => Object.hash(
        countryCode,
        cityKey,
        dateFilter,
        selectedLevel,
        currentUserId,
      );
}

class _EventListCardsMemoryCache {
  _EventListCardsMemoryCache({
    required this.maxEntries,
    required this.ttl,
  });

  final int maxEntries;
  final Duration ttl;
  final _entries =
      LinkedHashMap<_EventListLoadKey, _EventListCardsCacheEntry>();

  List<EventListCardViewModel>? read(
    _EventListLoadKey key, {
    required DateTime nowUtc,
  }) {
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }
    if (!entry.isFresh(nowUtc: nowUtc, ttl: ttl)) {
      return null;
    }
    _entries[key] = entry;
    return entry.cards;
  }

  void write(
    _EventListLoadKey key,
    List<EventListCardViewModel> cards, {
    required DateTime fetchedAtUtc,
  }) {
    _entries.remove(key);
    _entries[key] = _EventListCardsCacheEntry(
      cards: List.unmodifiable(cards),
      fetchedAtUtc: fetchedAtUtc,
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }

  void remove(_EventListLoadKey key) {
    _entries.remove(key);
  }

  void clear() {
    _entries.clear();
  }
}

class _EventListCardsCacheEntry {
  const _EventListCardsCacheEntry({
    required this.cards,
    required this.fetchedAtUtc,
  });

  final List<EventListCardViewModel> cards;
  final DateTime fetchedAtUtc;

  bool isFresh({
    required DateTime nowUtc,
    required Duration ttl,
  }) {
    return nowUtc.difference(fetchedAtUtc) < ttl;
  }
}

DateTime _eventListNowUtc() => DateTime.now().toUtc();

Future<EventParticipantsRecord?> _loadEventListParticipant(
  DocumentReference eventRef,
  String userId,
) async {
  final trimmedUserId = userId.trim();
  if (trimmedUserId.isEmpty) {
    return null;
  }
  final snapshot =
      await EventParticipantsRecord.createDoc(eventRef, id: trimmedUserId)
          .get();
  if (!snapshot.exists) {
    return null;
  }
  return EventParticipantsRecord.fromSnapshot(snapshot);
}

Future<List<EventParticipantsRecord>> _loadEventListActiveParticipantPreview(
  DocumentReference eventRef,
) {
  return queryEventParticipantsRecordOnce(
    parent: eventRef,
    queryBuilder: (participantsQuery) => participantsQuery
        .where('status', isEqualTo: eventStatusActive)
        .orderBy('joinedAt'),
    limit: _eventListParticipantPreviewLimit,
  );
}

EventListCardViewModel? _eventListCardFromRecord(
  EventsRecord event, {
  required String fallbackTimeZoneId,
  required DateTime nowUtc,
  required String currentUserId,
  EventParticipantsRecord? currentUserParticipant,
  List<EventParticipantsRecord> activeParticipants =
      const <EventParticipantsRecord>[],
  EventListMembershipState membershipState = EventListMembershipState.resolved,
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
  final viewerUserId = currentUserId.trim();
  final isOrganizer =
      viewerUserId.isNotEmpty && event.organizerId.trim() == viewerUserId;
  final isActiveParticipant = _eventListParticipantIsActiveForUser(
    currentUserParticipant,
    eventReference: event.reference,
    userId: viewerUserId,
  );
  final isJoined = isOrganizer || isActiveParticipant;

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
    participants: _eventListParticipantsForRecord(
      event,
      currentUserId: currentUserId,
      currentUserParticipant: currentUserParticipant,
      activeParticipants: activeParticipants,
    ),
    participantsCount: participantsCount,
    capacity: capacity,
    joinCtaState: _eventListJoinStateForRecord(
      event: event,
      nowUtc: nowUtc,
      isJoined: isJoined,
      participantsCount: participantsCount,
      capacity: capacity,
    ),
    chatCtaState: isJoined
        ? EventListChatCtaState.enabled
        : EventListChatCtaState.participantOnly,
    membershipState: membershipState,
    reserveParticipantPreviewSpace: true,
  );
}

bool _eventListMembershipNeedsLookup(
  EventsRecord event,
  String currentUserId,
) {
  final userId = currentUserId.trim();
  return userId.isNotEmpty && event.organizerId.trim() != userId;
}

bool _eventListParticipantIsActiveForUser(
  EventParticipantsRecord? participant, {
  required DocumentReference eventReference,
  required String userId,
}) {
  final trimmedUserId = userId.trim();
  if (participant == null || trimmedUserId.isEmpty) {
    return false;
  }
  final participantUserId = participant.userId.trim();
  final belongsToUser = participantUserId.isEmpty
      ? participant.reference.id == trimmedUserId
      : participantUserId == trimmedUserId;
  if (!belongsToUser ||
      participant.parentReference.path != eventReference.path) {
    return false;
  }
  return participant.status.trim() == eventStatusActive;
}

List<EventListParticipantViewModel> _eventListParticipantsForRecord(
  EventsRecord event, {
  required String currentUserId,
  EventParticipantsRecord? currentUserParticipant,
  List<EventParticipantsRecord> activeParticipants =
      const <EventParticipantsRecord>[],
}) {
  final viewerUserId = currentUserId.trim();
  EventListParticipantViewModel participantViewModel(
    EventParticipantsRecord participant,
  ) {
    final participantUserId = _eventListParticipantUserId(participant);
    final isOrganizer = event.organizerId.trim().isNotEmpty &&
        participantUserId == event.organizerId.trim();
    final isCurrentUser =
        viewerUserId.isNotEmpty && participantUserId == viewerUserId;
    final displayName = _eventListVisibleParticipantDisplayName(
      participant.displayName,
    );
    final currentDisplayName = isCurrentUser
        ? _eventListVisibleParticipantDisplayName(currentUserDisplayName)
        : '';
    final resolvedDisplayName = displayName.isNotEmpty
        ? displayName
        : currentDisplayName.isNotEmpty
            ? currentDisplayName
            : isOrganizer
                ? event.organizerDisplayName.trim()
                : '';
    final participantPhotoUrl = participant.photoUrl.trim();
    final currentPhotoUrl = isCurrentUser ? currentUserPhoto.trim() : '';
    final photoUrl = participantPhotoUrl.isNotEmpty
        ? participantPhotoUrl
        : currentPhotoUrl.isNotEmpty
            ? currentPhotoUrl
            : isOrganizer && event.hasOrganizerPhotoUrl()
                ? event.organizerPhotoUrl.trim()
                : '';
    return EventListParticipantViewModel(
      userId: participantUserId,
      displayName: resolvedDisplayName,
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
    );
  }

  final participantViewModels = activeParticipants
      .where((participant) => participant.status.trim() == eventStatusActive)
      .map(participantViewModel)
      .toList();

  final displayName = event.organizerDisplayName.trim();
  final photoUrl =
      event.hasOrganizerPhotoUrl() ? event.organizerPhotoUrl.trim() : null;
  final participantsCount =
      event.hasParticipantsCount() ? event.participantsCount : 0;
  if (participantViewModels.isEmpty &&
      (participantsCount > 0 ||
          displayName.isNotEmpty ||
          (photoUrl != null && photoUrl.isNotEmpty))) {
    participantViewModels.add(
      EventListParticipantViewModel(
        userId: event.organizerId.trim(),
        displayName: displayName,
        photoUrl: photoUrl,
      ),
    );
  }

  if (_eventListParticipantIsActiveForUser(
        currentUserParticipant,
        eventReference: event.reference,
        userId: viewerUserId,
      ) &&
      !participantViewModels.any(
        (participant) => participant.userId.trim() == viewerUserId,
      )) {
    participantViewModels.add(participantViewModel(currentUserParticipant!));
    _eventListKeepParticipantVisible(
      participantViewModels,
      userId: viewerUserId,
      visibleLimit: _eventListParticipantPreviewLimit,
    );
  }

  if (participantViewModels.isEmpty) {
    return const <EventListParticipantViewModel>[];
  }
  return List.unmodifiable(participantViewModels);
}

void _eventListKeepParticipantVisible(
  List<EventListParticipantViewModel> participants, {
  required String userId,
  required int visibleLimit,
}) {
  final normalizedUserId = userId.trim();
  if (normalizedUserId.isEmpty ||
      visibleLimit <= 0 ||
      participants.length <= visibleLimit) {
    return;
  }
  final index = participants.indexWhere(
    (participant) => participant.userId.trim() == normalizedUserId,
  );
  if (index < visibleLimit || index < 0) {
    return;
  }
  final participant = participants.removeAt(index);
  participants.insert(visibleLimit - 1, participant);
}

String _eventListParticipantUserId(EventParticipantsRecord participant) {
  final userId = participant.userId.trim();
  return userId.isNotEmpty ? userId : participant.reference.id.trim();
}

String _eventListVisibleParticipantDisplayName(String displayName) {
  final normalized = displayName.trim();
  final lower = normalized.toLowerCase();
  if (lower == 'участник' || lower == 'participant') {
    return '';
  }
  return normalized;
}

EventListJoinCtaState _eventListJoinStateForRecord({
  required EventsRecord event,
  required DateTime nowUtc,
  required bool isJoined,
  required int? participantsCount,
  required int? capacity,
}) {
  if (event.status == eventStatusCanceled) {
    return EventListJoinCtaState.canceled;
  }
  if (isJoined) {
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
    final description = FFLocalizations.of(context).getVariableText(
      ruText: 'Выберите другой день, уровень или город.',
      enText: 'Choose another day, level, or city.',
    );
    final emptyStateHeight = _eventListEmptyStateHeight(context);

    return Semantics(
      key: eventListEmptyStateKey,
      container: true,
      liveRegion: true,
      label: description,
      child: ExcludeSemantics(
        child: SizedBox(
          width: double.infinity,
          height: emptyStateHeight,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: EmptyWidget(
                shrinkWrap: true,
                topPadding: ExpatlioDesign.space0,
                txt: description,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

double _eventListEmptyStateHeight(BuildContext context) {
  return (MediaQuery.sizeOf(context).height - 280)
      .clamp(420.0, 640.0)
      .toDouble();
}

class _EventListErrorState extends StatelessWidget {
  const _EventListErrorState({
    required this.message,
    required this.onRetryPressed,
    this.compact = false,
  });

  final String? message;
  final VoidCallback? onRetryPressed;
  final bool compact;

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

    return UxErrorState(
      stateKey: eventListErrorStateKey,
      title: title,
      message: description,
      semanticsLabel: '$title. $description',
      retryLabel: retryLabel,
      retrySemanticsLabel: retrySemanticsLabel,
      retryButtonKey: eventListErrorRetryButtonKey,
      onRetry: onRetryPressed,
      contained: true,
      borderColor: _eventListBorderColor,
      maxWidth: double.infinity,
      showIcon: !compact,
      padding: compact
          ? const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space16,
              ExpatlioDesign.space16,
              ExpatlioDesign.space16,
              ExpatlioDesign.space16,
            )
          : const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space24,
              ExpatlioDesign.space32,
              ExpatlioDesign.space24,
              ExpatlioDesign.space32,
            ),
      titleSize: compact ? 17.0 : 20.0,
      retryMinHeight: compact ? 44.0 : 48.0,
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
            ),
          ],
        ),
      ),
    );
  }
}

class _EventCardLayoutMetrics {
  const _EventCardLayoutMetrics({
    required this.headerHeight,
    required this.titleHeight,
    required this.descriptionHeight,
    required this.metaChipHeight,
    required this.placeHeight,
    required this.footerHeight,
    required this.levelBadgeHeight,
    required this.actionHeight,
    required this.stackActions,
  });

  factory _EventCardLayoutMetrics.from(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final organizerLabelHeight = _eventCardScaledLineHeight(
      textScaler,
      fontSize: _eventListOrganizerLabelFontSize,
      height: _eventListDefaultTextHeight,
    );
    final organizerNameHeight = _eventCardScaledLineHeight(
      textScaler,
      fontSize: _eventListOrganizerNameFontSize,
      height: _eventListDefaultTextHeight,
    );
    final levelBadgeHeight = math.max(
      _eventListLevelChipHeight,
      _eventCardScaledLineHeight(
            textScaler,
            fontSize: _eventListLevelFontSize,
            height: _eventListLevelTextHeight,
          ) +
          ExpatlioDesign.space8,
    );
    final actionLineHeight = _eventCardScaledLineHeight(
      textScaler,
      fontSize: _eventListActionFontSize,
      height: _eventListActionTextHeight,
    );
    final stackActions =
        actionLineHeight > _eventListActionStackThresholdLineHeight;
    final actionMaxLines = stackActions
        ? _eventListStackedActionMaxLines
        : _eventListActionMaxLines;
    final actionHeight = math.max(
      _eventListActionHeight,
      (actionLineHeight * actionMaxLines) + _eventListActionVerticalPadding,
    );

    return _EventCardLayoutMetrics(
      headerHeight: math.max(
        38.0,
        math.max(
          _eventListOrganizerAvatarSize,
          math.max(
            organizerLabelHeight + ExpatlioDesign.space4 + organizerNameHeight,
            levelBadgeHeight,
          ),
        ),
      ),
      titleHeight: math.max(
        38.0,
        _eventCardScaledLineHeight(
          textScaler,
          fontSize: _eventListTitleFontSize,
          height: _eventListTitleTextHeight,
          maxLines: 2,
        ),
      ),
      descriptionHeight: math.max(
        54.0,
        _eventCardScaledLineHeight(
          textScaler,
          fontSize: _eventListDescriptionFontSize,
          height: _eventListDescriptionTextHeight,
          maxLines: 3,
        ),
      ),
      metaChipHeight: math.max(
        24.0,
        _eventCardScaledLineHeight(
              textScaler,
              fontSize: _eventListMetaFontSize,
              height: _eventListDefaultTextHeight,
            ) +
            ExpatlioDesign.space8,
      ),
      placeHeight: math.max(
        35.0,
        _eventCardScaledLineHeight(
          textScaler,
          fontSize: _eventListPlaceFontSize,
          height: _eventListDefaultTextHeight,
          maxLines: 2,
        ),
      ),
      footerHeight: math.max(
        24.0,
        _eventCardScaledLineHeight(
          textScaler,
          fontSize: _eventListFooterFontSize,
          height: _eventListDefaultTextHeight,
        ),
      ),
      levelBadgeHeight: levelBadgeHeight,
      actionHeight: actionHeight,
      stackActions: stackActions,
    );
  }

  final double headerHeight;
  final double titleHeight;
  final double descriptionHeight;
  final double metaChipHeight;
  final double placeHeight;
  final double footerHeight;
  final double levelBadgeHeight;
  final double actionHeight;
  final bool stackActions;

  double get bodyHeight =>
      titleHeight + ExpatlioDesign.space8 + descriptionHeight;

  double get metaHeight =>
      metaChipHeight + _eventListCardMetaPlaceGap + placeHeight;

  double get actionsHeight =>
      stackActions ? (actionHeight * 2) + _eventListActionGap : actionHeight;

  int get actionMaxLines =>
      stackActions ? _eventListStackedActionMaxLines : _eventListActionMaxLines;

  double get totalHeight =>
      (_eventListCardBorderWidth * 2) +
      (_eventListCardPadding * 2) +
      headerHeight +
      _eventListCardHeaderBodyGap +
      bodyHeight +
      _eventListCardBodyMetaGap +
      metaHeight +
      _eventListCardMetaFooterGap +
      footerHeight +
      _eventListCardFooterActionsGap +
      actionsHeight;
}

double _eventCardScaledLineHeight(
  TextScaler textScaler, {
  required double fontSize,
  required double height,
  int maxLines = 1,
}) {
  return (textScaler.scale(fontSize) * height * maxLines).ceilToDouble();
}

class _EventCardShell extends StatelessWidget {
  const _EventCardShell({
    required this.card,
    this.onPressed,
    this.onChatPressed,
    this.onChatParticipantRequiredPressed,
  });

  final EventListCardViewModel? card;
  final VoidCallback? onPressed;
  final VoidCallback? onChatPressed;
  final VoidCallback? onChatParticipantRequiredPressed;

  @override
  Widget build(BuildContext context) {
    final metrics = _EventCardLayoutMetrics.from(context);
    final borderRadius = BorderRadius.circular(_eventListCardRadius);
    return SizedBox(
      key: eventListCardShellKey,
      height: metrics.totalHeight,
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: ExpatlioDesign.cardDecoration(
            color: Colors.white,
            radius: _eventListCardRadius,
            borderColor: _eventListBorderColor,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(_eventListCardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  onTap: onPressed,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _EventCardHeaderShell(card: card, metrics: metrics),
                      const SizedBox(height: _eventListCardHeaderBodyGap),
                      _EventCardBodyShell(card: card, metrics: metrics),
                      const SizedBox(height: _eventListCardBodyMetaGap),
                      _EventCardMetaShell(card: card, metrics: metrics),
                      const SizedBox(height: _eventListCardMetaFooterGap),
                      _EventCardFooterShell(card: card, metrics: metrics),
                    ],
                  ),
                ),
                const SizedBox(height: _eventListCardFooterActionsGap),
                InkWell(
                  onTap:
                      card?.membershipState == EventListMembershipState.resolved
                          ? onPressed
                          : null,
                  child: _EventCardActionsShell(
                    card: card,
                    metrics: metrics,
                    onChatPressed: onChatPressed,
                    onChatParticipantRequiredPressed:
                        onChatParticipantRequiredPressed,
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

class _EventCardHeaderShell extends StatelessWidget {
  const _EventCardHeaderShell({
    required this.card,
    required this.metrics,
  });

  final EventListCardViewModel? card;
  final _EventCardLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final organizer = card;
    return SizedBox(
      key: eventListCardHeaderKey,
      height: metrics.headerHeight,
      child: Row(
        children: [
          if (organizer == null)
            const _EventCardCirclePlaceholder(
              dimension: _eventListOrganizerAvatarSize,
            )
          else
            _EventOrganizerAvatar(
              photoUrl: organizer.organizerPhotoUrl,
              displayName: organizer.organizerDisplayName,
            ),
          const SizedBox(width: ExpatlioDesign.space12),
          Expanded(
            child: organizer == null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _EventCardLinePlaceholder(
                        widthFactor: 0.38,
                        height: math.min(16.0, metrics.headerHeight),
                      ),
                      const SizedBox(height: ExpatlioDesign.space4),
                      _EventCardLinePlaceholder(
                        widthFactor: 0.58,
                        height: math.min(18.0, metrics.headerHeight),
                      ),
                    ],
                  )
                : _EventOrganizerText(
                    displayName: organizer.organizerDisplayName,
                  ),
          ),
          const SizedBox(width: ExpatlioDesign.space12),
          SizedBox(
            width: 72.0,
            child: organizer == null
                ? _EventCardPillPlaceholder(
                    height: metrics.levelBadgeHeight,
                  )
                : _EventLevelRangeBadge(
                    levelMin: organizer.levelMin,
                    levelMax: organizer.levelMax,
                    height: metrics.levelBadgeHeight,
                  ),
          ),
        ],
      ),
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
            color: ExpatlioDesign.inactive,
            size: _eventListOrganizerLabelFontSize,
            weight: FontWeight.w400,
            height: _eventListDefaultTextHeight,
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
            size: _eventListOrganizerNameFontSize,
            weight: FontWeight.w700,
            height: _eventListDefaultTextHeight,
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
      width: _eventListOrganizerAvatarSize,
      height: _eventListOrganizerAvatarSize,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      foregroundDecoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: ExpatlioDesign.border),
        ),
      ),
      child: normalizedPhotoUrl.isEmpty
          ? _fallback(context)
          : CachedNetworkImage(
              imageUrl: normalizedPhotoUrl,
              width: _eventListOrganizerAvatarSize,
              height: _eventListOrganizerAvatarSize,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              memCacheWidth: (_eventListOrganizerAvatarSize *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
              memCacheHeight: (_eventListOrganizerAvatarSize *
                      MediaQuery.devicePixelRatioOf(context))
                  .round(),
              placeholder: (context, _) => _fallback(context),
              errorWidget: (context, _, __) => _fallback(context),
            ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: ExpatlioDesign.avatarFallbackBackground,
      alignment: Alignment.center,
      child: Text(
        ExpatlioDesign.avatarInitial(displayName),
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.avatarFallbackText,
          size: 12,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventCardBodyShell extends StatelessWidget {
  const _EventCardBodyShell({
    required this.card,
    required this.metrics,
  });

  final EventListCardViewModel? card;
  final _EventCardLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final event = card;
    if (event == null) {
      return SizedBox(
        key: eventListCardBodyKey,
        height: metrics.bodyHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: metrics.titleHeight,
              child: const Align(
                alignment: AlignmentDirectional.topStart,
                child: _EventCardLinePlaceholder(
                  widthFactor: 0.86,
                  height: 24,
                ),
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space8),
            SizedBox(
              height: metrics.descriptionHeight,
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EventCardLinePlaceholder(widthFactor: 1, height: 16),
                  SizedBox(height: ExpatlioDesign.space8),
                  _EventCardLinePlaceholder(widthFactor: 0.72, height: 16),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final title = event.title.trim();
    final description = event.description.trim();

    return SizedBox(
      key: eventListCardBodyKey,
      height: metrics.bodyHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: metrics.titleHeight,
            child: Align(
              alignment: AlignmentDirectional.topStart,
              child: Text(
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
                  size: _eventListTitleFontSize,
                  weight: FontWeight.w700,
                  height: _eventListTitleTextHeight,
                ),
              ),
            ),
          ),
          const SizedBox(height: ExpatlioDesign.space8),
          SizedBox(
            height: metrics.descriptionHeight,
            child: description.isEmpty
                ? const SizedBox.shrink()
                : Align(
                    alignment: AlignmentDirectional.topStart,
                    child: Text(
                      key: eventListCardDescriptionKey,
                      description,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.inactive,
                        size: _eventListDescriptionFontSize,
                        height: _eventListDescriptionTextHeight,
                        weight: FontWeight.w400,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventCardMetaShell extends StatelessWidget {
  const _EventCardMetaShell({
    required this.card,
    required this.metrics,
  });

  final EventListCardViewModel? card;
  final _EventCardLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final event = card;
    if (event == null) {
      return SizedBox(
        key: eventListCardMetaKey,
        height: metrics.metaHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: metrics.metaChipHeight,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: _EventCardPillPlaceholder(
                      height: metrics.metaChipHeight,
                    ),
                  ),
                  const SizedBox(width: ExpatlioDesign.space8),
                  Expanded(
                    flex: 2,
                    child: _EventCardPillPlaceholder(
                      height: metrics.metaChipHeight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: _eventListCardMetaPlaceGap),
            SizedBox(
              height: metrics.placeHeight,
              child: const Align(
                alignment: AlignmentDirectional.topStart,
                child: _EventCardLinePlaceholder(
                  widthFactor: 0.72,
                  height: 16,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final locale = FFLocalizations.of(context).languageCode;
    final eventLocalDateTime = _eventLocalDateTime(
      startsAt: event.startsAt,
      timeZoneId: event.timeZoneId,
    );
    final locationName = event.locationName.trim();

    return SizedBox(
      key: eventListCardMetaKey,
      height: metrics.metaHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: metrics.metaChipHeight,
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: _EventInfoChip(
                    key: eventListCardDateKey,
                    icon: Icons.calendar_month_outlined,
                    label: _eventDateLabel(
                      context,
                      eventLocalDateTime: eventLocalDateTime,
                      timeZoneId: event.timeZoneId,
                    ),
                    height: metrics.metaChipHeight,
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space8),
                Expanded(
                  flex: 2,
                  child: _EventInfoChip(
                    key: eventListCardTimeKey,
                    icon: Icons.schedule,
                    label: dateTimeFormat(
                      'Hm',
                      eventLocalDateTime,
                      locale: locale,
                    ),
                    height: metrics.metaChipHeight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: _eventListCardMetaPlaceGap),
          SizedBox(
            height: metrics.placeHeight,
            child: Row(
              key: eventListCardPlaceKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  color: ExpatlioDesign.inactive,
                  size: 14,
                ),
                const SizedBox(width: 6),
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
                      color: ExpatlioDesign.inactive,
                      size: _eventListPlaceFontSize,
                      weight: FontWeight.w400,
                      height: _eventListDefaultTextHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EventLevelRangeBadge extends StatelessWidget {
  const _EventLevelRangeBadge({
    required this.levelMin,
    required this.levelMax,
    required this.height,
  });

  final String levelMin;
  final String levelMax;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: eventListCardLevelRangeKey,
      height: height,
      alignment: Alignment.center,
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
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
          size: _eventListLevelFontSize,
          weight: FontWeight.w700,
          height: _eventListLevelTextHeight,
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
    required this.height,
  });

  final IconData icon;
  final String label;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Container(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 4,
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
              size: 14,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: _eventListMetaFontSize,
                  weight: FontWeight.w600,
                  height: _eventListDefaultTextHeight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    required this.metrics,
  });

  final EventListCardViewModel? card;
  final _EventCardLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final event = card;
    if (event == null) {
      return SizedBox(
        key: eventListCardFooterKey,
        height: metrics.footerHeight,
        child: Row(
          children: const [
            SizedBox(
              width: 90,
              height: 24,
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    child: _EventCardCirclePlaceholder(dimension: 24),
                  ),
                  Positioned(
                    left: 22,
                    child: _EventCardCirclePlaceholder(dimension: 24),
                  ),
                  Positioned(
                    left: 44,
                    child: _EventCardCirclePlaceholder(dimension: 24),
                  ),
                  Positioned(
                    left: 66,
                    child: _EventCardCirclePlaceholder(dimension: 24),
                  ),
                ],
              ),
            ),
            SizedBox(width: ExpatlioDesign.space12),
            Expanded(
              child: _EventCardLinePlaceholder(
                widthFactor: 0.36,
                height: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      key: eventListCardFooterKey,
      height: metrics.footerHeight,
      child: event.hasFooterContent
          ? Row(
              children: [
                if (event.hasParticipantPreviewRegion)
                  _EventParticipantAvatarStack(
                    participants: event.participants,
                    participantsCount: event.participantsCount,
                    capacity: event.capacity,
                    reservePreviewSpace: event.reserveParticipantPreviewSpace,
                  ),
                if (event.hasParticipantPreviewRegion && event.hasOccupancy)
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
                        color: ExpatlioDesign.inactive,
                        size: _eventListFooterFontSize,
                        weight: FontWeight.w400,
                        height: _eventListDefaultTextHeight,
                      ),
                    ),
                  ),
              ],
            )
          : const SizedBox.shrink(),
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
    required this.capacity,
    required this.reservePreviewSpace,
  });

  static const double _avatarSize = 24;
  static const double _avatarStep = 22;
  static const int _maxVisibleSlots = 6;

  final List<EventListParticipantViewModel> participants;
  final int? participantsCount;
  final int? capacity;
  final bool reservePreviewSpace;

  @override
  Widget build(BuildContext context) {
    final totalCount = _totalCount;
    final previewTotal = _previewTotal(totalCount);
    final visibleSlotCount = math.min(previewTotal, _maxVisibleSlots);
    if (visibleSlotCount <= 0 && !reservePreviewSpace) {
      return const SizedBox.shrink();
    }
    final visibleFilledSlotCount = math.min(totalCount, visibleSlotCount);
    final overflowCount = previewTotal - visibleSlotCount;
    final itemCount = reservePreviewSpace
        ? _maxVisibleSlots + 1
        : visibleSlotCount + (overflowCount > 0 ? 1 : 0);

    return SizedBox(
      key: eventListParticipantAvatarStackKey,
      width: _avatarSize + (_avatarStep * (itemCount - 1)),
      height: _avatarSize,
      child: Stack(
        children: [
          for (var index = 0; index < visibleSlotCount; index += 1)
            PositionedDirectional(
              start: _avatarStep * index,
              child: index < participants.length
                  ? _EventParticipantAvatar(
                      key: _eventParticipantAvatarKey(index),
                      participant: participants[index],
                      dimension: _avatarSize,
                    )
                  : _EventParticipantAvatarPlaceholder(
                      key: _eventParticipantAvatarKey(index),
                      dimension: _avatarSize,
                      filled: index < visibleFilledSlotCount,
                    ),
            ),
          if (overflowCount > 0)
            PositionedDirectional(
              start: _avatarStep * visibleSlotCount,
              child: _EventParticipantOverflowBadge(
                count: overflowCount,
                dimension: _avatarSize,
              ),
            ),
        ],
      ),
    );
  }

  int _previewTotal(int totalCount) {
    final resolvedCapacity = capacity;
    if (resolvedCapacity == null || resolvedCapacity <= 0) {
      return totalCount;
    }
    return math.max(totalCount, resolvedCapacity);
  }

  int get _totalCount {
    final count = participantsCount;
    if (count == null) {
      return math.max(0, participants.length);
    }
    return math.max(0, math.max(count, participants.length));
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
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        shape: BoxShape.circle,
        border: Border.all(color: ExpatlioDesign.border, width: 1),
      ),
      child: ClipOval(
        child: normalizedPhotoUrl.isEmpty
            ? _fallback(context)
            : CachedNetworkImage(
                imageUrl: normalizedPhotoUrl,
                width: dimension,
                height: dimension,
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
    if (participant.displayName.trim().isEmpty) {
      return Container(
        color: ExpatlioDesign.avatarFallbackBackground,
        alignment: Alignment.center,
        child: Icon(
          Icons.person_outline,
          color: ExpatlioDesign.avatarFallbackText,
          size: dimension * 0.62,
        ),
      );
    }
    return Container(
      color: ExpatlioDesign.avatarFallbackBackground,
      alignment: Alignment.center,
      child: Text(
        ExpatlioDesign.avatarInitial(participant.displayName),
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.avatarFallbackText,
          size: 9,
          weight: FontWeight.w700,
          height: 1,
        ),
      ),
    );
  }
}

class _EventParticipantAvatarPlaceholder extends StatelessWidget {
  const _EventParticipantAvatarPlaceholder({
    super.key,
    required this.dimension,
    required this.filled,
  });

  final double dimension;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: dimension,
      height: dimension,
      padding: const EdgeInsets.all(1),
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        shape: BoxShape.circle,
        border: Border.all(color: ExpatlioDesign.border, width: 1),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: filled
              ? ExpatlioDesign.avatarFallbackBackground
              : ExpatlioDesign.card,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_outline,
          color: filled
              ? ExpatlioDesign.avatarFallbackText
              : ExpatlioDesign.systemGray4,
          size: 15,
        ),
      ),
    );
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
        color: ExpatlioDesign.avatarFallbackBackground,
        shape: BoxShape.circle,
        border: Border.all(color: ExpatlioDesign.border, width: 1),
      ),
      child: Text(
        '+$count',
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.avatarFallbackText,
          size: 10,
          weight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EventCardActionsShell extends StatelessWidget {
  const _EventCardActionsShell({
    required this.card,
    required this.metrics,
    this.onChatPressed,
    this.onChatParticipantRequiredPressed,
  });

  final EventListCardViewModel? card;
  final _EventCardLayoutMetrics metrics;
  final VoidCallback? onChatPressed;
  final VoidCallback? onChatParticipantRequiredPressed;

  @override
  Widget build(BuildContext context) {
    final event = card;
    final Widget primaryAction;
    final Widget secondaryAction;
    if (event == null) {
      primaryAction = _EventCardPillPlaceholder(height: metrics.actionHeight);
      secondaryAction = _EventCardPillPlaceholder(height: metrics.actionHeight);
    } else {
      final canOpenChat = event.chatCtaState == EventListChatCtaState.enabled &&
          onChatPressed != null;
      final canShowParticipantRequiredHint =
          event.chatCtaState == EventListChatCtaState.participantOnly &&
              onChatParticipantRequiredPressed != null;
      primaryAction = _EventCardPrimaryCta(
        state: event.joinCtaState,
        membershipState: event.membershipState,
        height: metrics.actionHeight,
        maxLines: metrics.actionMaxLines,
      );
      secondaryAction = _EventCardChatCta(
        state: event.chatCtaState,
        membershipState: event.membershipState,
        height: metrics.actionHeight,
        maxLines: metrics.actionMaxLines,
        onPressed: canOpenChat ? onChatPressed : null,
        onParticipantRequiredPressed: canShowParticipantRequiredHint
            ? onChatParticipantRequiredPressed
            : null,
      );
    }

    if (metrics.stackActions) {
      return SizedBox(
        key: eventListCardActionsKey,
        height: metrics.actionsHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: metrics.actionHeight, child: primaryAction),
            const SizedBox(height: _eventListActionGap),
            SizedBox(height: metrics.actionHeight, child: secondaryAction),
          ],
        ),
      );
    }

    return SizedBox(
      key: eventListCardActionsKey,
      height: metrics.actionsHeight,
      child: Row(
        children: [
          Expanded(
            flex: _eventListPrimaryActionFlex,
            child: primaryAction,
          ),
          const SizedBox(width: _eventListActionGap),
          Expanded(
            flex: _eventListSecondaryActionFlex,
            child: secondaryAction,
          ),
        ],
      ),
    );
  }
}

class _EventCardPrimaryCta extends StatelessWidget {
  const _EventCardPrimaryCta({
    required this.state,
    required this.membershipState,
    required this.height,
    required this.maxLines,
  });

  final EventListJoinCtaState state;
  final EventListMembershipState membershipState;
  final double height;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final membershipResolved =
        membershipState == EventListMembershipState.resolved;
    final enabled = membershipResolved && state == EventListJoinCtaState.join;
    final backgroundColor = enabled
        ? ExpatlioDesign.primary
        : ExpatlioDesign.secondarySystemBackground;
    final textColor = !membershipResolved
        ? ExpatlioDesign.muted
        : enabled
            ? Colors.white
            : state == EventListJoinCtaState.joined
                ? ExpatlioDesign.primary
                : ExpatlioDesign.muted;

    return Semantics(
      button: true,
      enabled: enabled,
      child: Container(
        key: eventListCardPrimaryCtaKey,
        height: height,
        alignment: Alignment.center,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ExpatlioDesign.space8,
        ),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(_eventListActionRadius),
        ),
        child: Text(
          switch (membershipState) {
            EventListMembershipState.pending =>
              FFLocalizations.of(context).getVariableText(
                ruText: 'Проверяем участие',
                enText: 'Checking status',
              ),
            EventListMembershipState.lookupFailed =>
              FFLocalizations.of(context).getVariableText(
                ruText: 'Статус недоступен',
                enText: 'Status unavailable',
              ),
            EventListMembershipState.resolved =>
              _eventPrimaryCtaLabel(context, state),
          },
          maxLines: maxLines,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: ExpatlioDesign.textStyle(
            context,
            color: textColor,
            size: _eventListActionFontSize,
            weight: FontWeight.w700,
            height: _eventListActionTextHeight,
          ),
        ),
      ),
    );
  }
}

class _EventCardChatCta extends StatelessWidget {
  const _EventCardChatCta({
    required this.state,
    required this.membershipState,
    required this.height,
    required this.maxLines,
    required this.onPressed,
    this.onParticipantRequiredPressed,
  });

  final EventListChatCtaState state;
  final EventListMembershipState membershipState;
  final double height;
  final int maxLines;
  final VoidCallback? onPressed;
  final VoidCallback? onParticipantRequiredPressed;

  @override
  Widget build(BuildContext context) {
    final membershipResolved =
        membershipState == EventListMembershipState.resolved;
    final enabled = membershipResolved &&
        state == EventListChatCtaState.enabled &&
        onPressed != null;
    final effectiveOnPressed = !membershipResolved
        ? null
        : enabled
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
    final pendingLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Проверяем доступ к чату',
      enText: 'Checking chat access',
    );
    final failedLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось проверить доступ к чату',
      enText: 'Could not check chat access',
    );
    final canHandleTap = effectiveOnPressed != null;
    final foregroundColor =
        canHandleTap ? ExpatlioDesign.text : ExpatlioDesign.disabled;
    final backgroundColor = enabled
        ? ExpatlioDesign.secondarySystemBackground
        : ExpatlioDesign.secondarySystemBackground.withValues(alpha: 0.62);

    return Semantics(
      key: eventListCardChatCtaKey,
      container: true,
      button: true,
      enabled: enabled,
      label: switch (membershipState) {
        EventListMembershipState.pending => pendingLabel,
        EventListMembershipState.lookupFailed => failedLabel,
        EventListMembershipState.resolved => enabled ? label : disabledLabel,
      },
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(_eventListActionRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: effectiveOnPressed,
            overlayColor: WidgetStatePropertyAll(
              ExpatlioDesign.primary.withValues(alpha: 0.08),
            ),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: ExpatlioDesign.space8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      ExpatlioDesign.chatIconAsset,
                      width: 16,
                      height: 16,
                      colorFilter: ColorFilter.mode(
                        foregroundColor,
                        BlendMode.srcIn,
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: foregroundColor,
                          size: _eventListActionFontSize,
                          weight: FontWeight.w700,
                          height: _eventListActionTextHeight,
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
        enText: 'Past',
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
        color: ExpatlioDesign.avatarFallbackBackground,
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
    required this.height,
  });

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: _eventListLevelChipHeight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  color: ExpatlioDesign.inactive,
                  size: 14,
                ),
                const SizedBox(width: ExpatlioDesign.space4),
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Уровень:',
                    enText: 'Level:',
                  ),
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.inactive,
                    size: 12,
                    weight: FontWeight.w400,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ExpatlioDesign.space8),
          for (final level in eventLevelRanks.keys) ...[
            _EventListFilterChip(
              chipKey: _eventLevelFilterChipKey(level),
              label: level,
              selected: selectedLevel == level,
              height: _eventListLevelChipHeight,
              horizontalPadding: 13,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              selectedBackgroundColor: ExpatlioDesign.primary,
              selectedTextColor: Colors.white,
              selectedBorderColor: _eventListBorderColor,
              selectedBorderWidth: 1,
              onSelected: (selected) => onChanged(selected ? level : null),
            ),
            if (level != eventLevelRanks.keys.last)
              const SizedBox(width: ExpatlioDesign.space8),
          ],
        ],
      ),
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

  final EventListDateFilter? selectedFilter;
  final ValueChanged<EventListDateFilter?> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final filter in _filters) ...[
            _EventListFilterChip(
              chipKey: _eventDateFilterChipKey(filter),
              label: _eventDateFilterLabel(context, filter),
              selected: selectedFilter == filter,
              height: _eventListDateChipHeight,
              horizontalPadding: 14,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              selectedBackgroundColor: ExpatlioDesign.primary,
              selectedTextColor: Colors.white,
              onSelected: (selected) => onChanged(selected ? filter : null),
            ),
            if (filter != _filters.last)
              const SizedBox(width: ExpatlioDesign.space8),
          ],
        ],
      ),
    );
  }
}

class _EventListFilterChip extends StatelessWidget {
  const _EventListFilterChip({
    required this.chipKey,
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.height,
    required this.horizontalPadding,
    required this.fontSize,
    required this.fontWeight,
    this.selectedBackgroundColor,
    this.selectedTextColor,
    this.selectedBorderColor,
    this.selectedBorderWidth = 0,
  });

  final Key chipKey;
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final double height;
  final double horizontalPadding;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? selectedBackgroundColor;
  final Color? selectedTextColor;
  final Color? selectedBorderColor;
  final double selectedBorderWidth;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected
        ? selectedTextColor ?? ExpatlioDesign.text
        : ExpatlioDesign.text;
    final backgroundColor = selected
        ? selectedBackgroundColor ?? _eventListChipBackground
        : _eventListChipBackground;
    final borderColor = selected ? selectedBorderColor : null;

    return Semantics(
      key: chipKey,
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
          onTap: () => onSelected(!selected),
          child: Container(
            height: height,
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: horizontalPadding,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
              border: borderColor == null
                  ? null
                  : Border.all(
                      color: borderColor,
                      width: selectedBorderWidth,
                    ),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ExpatlioDesign.textStyle(
                context,
                color: labelColor,
                size: fontSize,
                weight: fontWeight,
                height: 1,
              ),
            ),
          ),
        ),
      ),
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

ValueKey<String> _eventManualCityOptionKey(EventCity city) => ValueKey<String>(
    'event_manual_city_option_${city.countryCode}_${city.cityKey}');

class _EventListDropdownMenuOption<T> {
  const _EventListDropdownMenuOption({
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

Future<T?> _showEventListDropdownMenu<T>(
  BuildContext anchorContext, {
  required List<_EventListDropdownMenuOption<T>> options,
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
    color: Colors.white,
    elevation: 8.0,
    shadowColor: const Color(0x12000000),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
      side: const BorderSide(color: _eventListBorderColor),
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
  final Future<void> Function(BuildContext context)? onPressed;

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
        child: Builder(
          builder: (fieldContext) => InkWell(
            key: eventListCitySelectorKey,
            onTap: onPressed == null
                ? null
                : () async {
                    await onPressed?.call(fieldContext);
                  },
            borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
            child: Container(
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space16,
                10,
                ExpatlioDesign.space12,
                10,
              ),
              decoration: ExpatlioDesign.cardDecoration(
                color: Colors.white,
                borderColor: _eventListBorderColor,
                radius: ExpatlioDesign.radiusLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: ExpatlioDesign.primary,
                        size: 16,
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
                            size: 13,
                            weight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: ExpatlioDesign.space8),
                      Icon(
                        FFIcons.kchevronDown,
                        color: ExpatlioDesign.muted,
                        size: 16,
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
                        size: 11,
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
