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
import '/components/profile_dropdown_menu_item.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/events/event_create_widget.dart';
import '/shared_pages/events/event_detail_widget.dart';
import '/shared_pages/events/event_detail_route_widget.dart';
import '/shared_pages/events/event_group_chat_widget.dart';
import '/shared_pages/events/event_history_widget.dart';
import '/students_pages/pay/pay_widget.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_action_error_mapper.dart';
import '/services/event_actions_repository.dart';
import '/services/event_city_catalog.dart';
import '/services/event_city_chip_source.dart';
import '/services/event_city_resolution.dart';
import '/services/event_city_selection_source.dart';
import '/services/event_detail_repository.dart';
import '/services/event_selected_city_state.dart';
import '/services/event_temporary_city_selection.dart';
import '/services/event_list_date_bounds.dart';
import '/services/event_list_repository.dart';
import '/services/event_level_helper.dart';
import '/services/event_language_catalog.dart';
import '/services/event_list_cache_invalidation.dart';
import '/services/events_analytics_service.dart';
import '/services/supported_location_catalog.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/user_public_profile_preload_repository.dart';
import '/utils/subscription_utils.dart';

const ValueKey<String> eventListCreateButtonKey =
    ValueKey<String>('event_list_create_button');
const ValueKey<String> eventListCitySelectorKey =
    ValueKey<String>('event_list_city_selector');
const ValueKey<String> eventListActiveCitySelectorKey =
    ValueKey<String>('event_list_active_city_selector');
const ValueKey<String> eventListScrollViewKey =
    ValueKey<String>('event_list_scroll_view');
const ValueKey<String> eventListVerticalViewportClipKey =
    ValueKey<String>('event_list_vertical_viewport_clip');
const ValueKey<String> eventListDateFiltersScrollKey =
    ValueKey<String>('event_list_date_filters_scroll');
const ValueKey<String> eventListLevelFiltersScrollKey =
    ValueKey<String>('event_list_level_filters_scroll');
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
const ValueKey<String> eventListEmptyResetFiltersButtonKey =
    ValueKey<String>('event_list_empty_reset_filters_button');
const ValueKey<String> eventListEmptyMyEventsButtonKey =
    ValueKey<String>('event_list_empty_my_events_button');
const ValueKey<String> eventListErrorStateKey =
    ValueKey<String>('event_list_error_state');
const ValueKey<String> eventListErrorRetryButtonKey =
    ValueKey<String>('event_list_error_retry_button');
const ValueKey<String> eventListPaginationLoadingKey =
    ValueKey<String>('event_list_pagination_loading');
const ValueKey<String> eventListNoMoreItemsKey =
    ValueKey<String>('event_list_no_more_items');
const ValueKey<String> eventListPaginationErrorKey =
    ValueKey<String>('event_list_pagination_error');
const ValueKey<String> eventListPaginationRetryButtonKey =
    ValueKey<String>('event_list_pagination_retry_button');
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
const ValueKey<String> eventListParticipantActionErrorSnackBarKey =
    ValueKey<String>('event_list_participant_action_error_snack_bar');
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
typedef EventListPublicProfilesLoader = Future<UserPublicProfilePreloadResult>
    Function(Iterable<String> userIds);

const int _eventListPageSize = 20;
const int _eventListParticipantPreviewLimit = 6;
const int _eventListInitialProfileCardBudget = 2;
const int _eventListProfileCardWindow = 2;
const int _eventListEarlyProfileParticipantLimit =
    _eventListParticipantPreviewLimit - 1;
const int _eventListInitialProfileUserBudget =
    _eventListInitialProfileCardBudget * _eventListParticipantPreviewLimit;
const int _eventListCardsCacheMaxEntries = 24;
const Duration _eventListCardsCacheFreshness = Duration(minutes: 5);
const Duration _eventListCardsCacheRetention = Duration(minutes: 30);
const double _eventListHorizontalPadding = 17.0;
const double _eventListTopPadding = 10.0;
const double _eventListPaginationPrefetchExtent = 240.0;
const double _eventListCardRadius = 15.0;
const double _eventListCardPadding = 16.0;
const double _eventListCardHeaderBodyGap = 14.0;
const double _eventListCardBodyMetaGap = 8.0;
const double _eventListCardMetaPlaceGap = 13.0;
const double _eventListCardMetaFooterGap = 14.0;
const double _eventListCardFooterActionsGap = 14.0;
const double _eventListDateChipHeight = 30.0;
const double _eventListLevelChipHeight = 24.0;
const double _eventListActionHeight = 36.0;
const double _eventListActionGap = 8.0;
const double _eventListActionRadius = 14.0;
const double _eventListInlineActionsMinWidth = 280.0;
const double _eventListActionStackThresholdLineHeight = 13.0;
const double _eventListActionVerticalPadding = 16.0;
const int _eventListActionMaxLines = 1;
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
const Color _eventListChipBackground = Colors.white;
const Color _eventListSoftPrimaryBackground = Color(0xFFF0E6FF);
final RegExp _eventListInvisibleAvatarCharacters = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180B-\u180F\u200B-\u200F\u202A-\u202E\u2060-\u206F\u3164\uFE00-\uFE0F\uFEFF\uFFA0]',
);
final RegExp _eventListAvatarInitialLetterOrNumber = RegExp(
  r'[\p{L}\p{N}]',
  unicode: true,
);

final DateTime _eventListAllEventsUpperBoundUtc = DateTime.utc(9999, 12, 31);

final _eventListCardsCache = _EventListCardsMemoryCache(
  maxEntries: _eventListCardsCacheMaxEntries,
  freshness: _eventListCardsCacheFreshness,
  retention: _eventListCardsCacheRetention,
);
bool _eventListCreatedEventSeederRegistered = false;

void _ensureEventListCreatedEventSeederRegistered() {
  if (_eventListCreatedEventSeederRegistered) {
    return;
  }
  _eventListCreatedEventSeederRegistered = true;
  EventListCacheInvalidation.registerCreatedEventSeeder(
    _eventListCardsCache.seedCreatedEvent,
  );
}

final _eventListViewStateStore = _EventListViewStateStore();
final _eventListPublicProfilePreloadRepository =
    UserPublicProfilePreloadRepository();
final _eventListParticipantActionCoordinator =
    _EventListParticipantActionCoordinator();

void _clearEventListCardsCache() {
  _eventListCardsCache.clear();
}

void _clearEventListSessionCache() {
  _clearEventListCardsCache();
  _eventListViewStateStore.clear();
}

void debugClearEventListCache() {
  _clearEventListSessionCache();
  _eventListPublicProfilePreloadRepository.clear();
  _eventListParticipantActionCoordinator.clear();
}

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
  joining,
  joined,
  leaving,
  joinedLocked,
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
    this.participantActionSourceRevision = 0,
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
  final int participantActionSourceRevision;
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

  EventListCardViewModel copyWithParticipants(
    List<EventListParticipantViewModel> updatedParticipants,
  ) {
    return EventListCardViewModel(
      eventId: eventId,
      countryCode: countryCode,
      cityKey: cityKey,
      organizerDisplayName: organizerDisplayName,
      organizerPhotoUrl: organizerPhotoUrl,
      participants: List.unmodifiable(updatedParticipants),
      participantsCount: participantsCount,
      capacity: capacity,
      joinCtaState: joinCtaState,
      chatCtaState: chatCtaState,
      membershipState: membershipState,
      reserveParticipantPreviewSpace: reserveParticipantPreviewSpace,
      participantActionSourceRevision: participantActionSourceRevision,
      languageCode: languageCode,
      languageNameEn: languageNameEn,
      languageNameRu: languageNameRu,
      title: title,
      description: description,
      levelMin: levelMin,
      levelMax: levelMax,
      startsAt: startsAt,
      timeZoneId: timeZoneId,
      locationName: locationName,
    );
  }

  EventListCardViewModel copyWithParticipantAction({
    required List<EventListParticipantViewModel> updatedParticipants,
    required int updatedParticipantsCount,
    required EventListJoinCtaState updatedJoinCtaState,
    required EventListChatCtaState updatedChatCtaState,
  }) {
    return EventListCardViewModel(
      eventId: eventId,
      countryCode: countryCode,
      cityKey: cityKey,
      organizerDisplayName: organizerDisplayName,
      organizerPhotoUrl: organizerPhotoUrl,
      participants: List.unmodifiable(updatedParticipants),
      participantsCount: updatedParticipantsCount,
      capacity: capacity,
      joinCtaState: updatedJoinCtaState,
      chatCtaState: updatedChatCtaState,
      membershipState: EventListMembershipState.resolved,
      reserveParticipantPreviewSpace: reserveParticipantPreviewSpace,
      participantActionSourceRevision: participantActionSourceRevision,
      languageCode: languageCode,
      languageNameEn: languageNameEn,
      languageNameRu: languageNameRu,
      title: title,
      description: description,
      levelMin: levelMin,
      levelMax: levelMax,
      startsAt: startsAt,
      timeZoneId: timeZoneId,
      locationName: locationName,
    );
  }

  EventListCardViewModel copyWithJoinCtaState(
    EventListJoinCtaState updatedJoinCtaState,
  ) {
    return EventListCardViewModel(
      eventId: eventId,
      countryCode: countryCode,
      cityKey: cityKey,
      organizerDisplayName: organizerDisplayName,
      organizerPhotoUrl: organizerPhotoUrl,
      participants: participants,
      participantsCount: participantsCount,
      capacity: capacity,
      joinCtaState: updatedJoinCtaState,
      chatCtaState: chatCtaState,
      membershipState: membershipState,
      reserveParticipantPreviewSpace: reserveParticipantPreviewSpace,
      participantActionSourceRevision: participantActionSourceRevision,
      languageCode: languageCode,
      languageNameEn: languageNameEn,
      languageNameRu: languageNameRu,
      title: title,
      description: description,
      levelMin: levelMin,
      levelMax: levelMax,
      startsAt: startsAt,
      timeZoneId: timeZoneId,
      locationName: locationName,
    );
  }

  EventListCardViewModel copyWithParticipantActionSourceRevision(
    int updatedParticipantActionSourceRevision,
  ) {
    return EventListCardViewModel(
      eventId: eventId,
      countryCode: countryCode,
      cityKey: cityKey,
      organizerDisplayName: organizerDisplayName,
      organizerPhotoUrl: organizerPhotoUrl,
      participants: participants,
      participantsCount: participantsCount,
      capacity: capacity,
      joinCtaState: joinCtaState,
      chatCtaState: chatCtaState,
      membershipState: membershipState,
      reserveParticipantPreviewSpace: reserveParticipantPreviewSpace,
      participantActionSourceRevision: updatedParticipantActionSourceRevision,
      languageCode: languageCode,
      languageNameEn: languageNameEn,
      languageNameRu: languageNameRu,
      title: title,
      description: description,
      levelMin: levelMin,
      levelMax: levelMax,
      startsAt: startsAt,
      timeZoneId: timeZoneId,
      locationName: locationName,
    );
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
    this.publicProfilesLoader,
    this.nowUtcProvider,
    this.joinEventInvoker,
    this.leaveEventInvoker,
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
  final EventListPublicProfilesLoader? publicProfilesLoader;
  final EventListNowProvider? nowUtcProvider;
  final EventCallableInvoker? joinEventInvoker;
  final EventCallableInvoker? leaveEventInvoker;

  @override
  State<EventListWidget> createState() => _EventListWidgetState();
}

class _EventListWidgetState extends State<EventListWidget> {
  late final ScrollController _scrollController;
  late String _eventListViewStateUserId;
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
  _EventListPublicProfileSession? _publicProfileSession;
  _EventListPaginationSession? _eventListPaginationSession;
  double _eventListProfileScrollOriginPixels = 0;
  bool _eventListScrollResetPending = false;
  int _eventListLoadGeneration = 0;
  late int _eventCardsOverrideSourceRevision;
  _EventListParticipantActionFailure? _participantActionError;
  Timer? _participantActionErrorTimer;
  int _participantActionErrorGeneration = 0;
  bool _participantActionErrorDismissalScheduled = false;

  @override
  void initState() {
    super.initState();
    _ensureEventListCreatedEventSeederRegistered();
    EventListCacheInvalidation.register(_clearEventListCardsCache);
    UxSessionCacheLifecycle.register(_clearEventListSessionCache);
    _eventListViewStateUserId = currentUserUid;
    final restoredViewState =
        _eventListViewStateStore.read(_eventListViewStateUserId);
    _selectedDateFilter = restoredViewState?.dateFilter;
    _selectedLevel = restoredViewState?.selectedLevel;
    _scrollController = ScrollController(
      initialScrollOffset: restoredViewState?.scrollOffset ?? 0,
    );
    _selectedCity = widget.initialSelectedCity;
    _eventCardsOverrideSourceRevision =
        _eventListParticipantActionCoordinator.sourceRevisionForOverride(
      widget.eventCardsOverride,
    );
    _scrollController.addListener(_handleEventListScroll);
    _eventListParticipantActionCoordinator.addListener(
      _handleEventListParticipantActionChange,
    );
  }

  @override
  void dispose() {
    _saveEventListViewState();
    _eventListParticipantActionCoordinator.removeListener(
      _handleEventListParticipantActionChange,
    );
    _dismissEventListParticipantActionFailure(notify: false);
    _scrollController
      ..removeListener(_handleEventListScroll)
      ..dispose();
    super.dispose();
  }

  void _handleEventListParticipantActionChange() {
    if (!mounted) {
      return;
    }
    final viewerUserId = currentUserUid;
    final failure = viewerUserId.isNotEmpty &&
            _canPresentEventListParticipantActionFeedback()
        ? _eventListParticipantActionCoordinator.takeFailureForUser(
            viewerUserId,
          )
        : null;
    setState(() {});
    if (failure != null) {
      _scheduleEventListParticipantActionFailure(failure);
    }
  }

  bool _eventListParticipantActionRouteIsCurrent() {
    final route = ModalRoute.of(context);
    return route == null || route.isCurrent;
  }

  bool _canPresentEventListParticipantActionFeedback() {
    return _eventListParticipantActionRouteIsCurrent() &&
        TickerMode.of(context);
  }

  void _scheduleEventListParticipantActionFailure(
    _EventListParticipantActionFailure failure,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          currentUserUid != failure.userId ||
          !_canPresentEventListParticipantActionFeedback()) {
        return;
      }
      _showEventListParticipantActionFailure(failure);
    });
  }

  void _showEventListParticipantActionFailure(
    _EventListParticipantActionFailure failure,
  ) {
    if (!mounted) {
      return;
    }
    _participantActionErrorTimer?.cancel();
    final generation = ++_participantActionErrorGeneration;
    setState(() {
      _participantActionError = failure;
    });
    _participantActionErrorTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted || generation != _participantActionErrorGeneration) {
        return;
      }
      _participantActionErrorTimer = null;
      setState(() {
        _participantActionError = null;
      });
    });
  }

  void _dismissEventListParticipantActionFailure({bool notify = true}) {
    _participantActionErrorTimer?.cancel();
    _participantActionErrorTimer = null;
    _participantActionErrorGeneration += 1;
    if (_participantActionError == null) {
      return;
    }
    if (notify && mounted) {
      setState(() {
        _participantActionError = null;
      });
    } else {
      _participantActionError = null;
    }
  }

  void _scheduleParticipantActionFailureDismissalIfNeeded() {
    if (_participantActionError == null ||
        _participantActionErrorDismissalScheduled) {
      return;
    }
    _participantActionErrorDismissalScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _participantActionErrorDismissalScheduled = false;
      final failure = _participantActionError;
      if (!mounted || failure == null) {
        return;
      }
      if (failure.userId != currentUserUid ||
          !_canPresentEventListParticipantActionFeedback()) {
        _dismissEventListParticipantActionFailure();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cityCatalogFuture ??= _loadCityCatalog();
    _scheduleParticipantActionFailureDismissalIfNeeded();
  }

  @override
  void didUpdateWidget(covariant EventListWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.eventCardsOverride, widget.eventCardsOverride)) {
      _eventCardsOverrideSourceRevision =
          _eventListParticipantActionCoordinator.sourceRevisionForOverride(
        widget.eventCardsOverride,
      );
    }
    if (oldWidget.initialSelectedCity != widget.initialSelectedCity) {
      _selectedCity = widget.initialSelectedCity;
    }
    if (oldWidget.cityCatalogOverride != widget.cityCatalogOverride) {
      _cityCatalogFuture = _loadCityCatalog();
      _cityChipsFuture = null;
      _cityChipsCatalog = null;
    }
    if (!identical(oldWidget.eventCardsOverride, widget.eventCardsOverride) ||
        oldWidget.eventPageLoader != widget.eventPageLoader ||
        oldWidget.currentUserParticipantLoader !=
            widget.currentUserParticipantLoader ||
        oldWidget.activeParticipantsLoader != widget.activeParticipantsLoader ||
        oldWidget.publicProfilesLoader != widget.publicProfilesLoader ||
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
        _syncEventListViewStateOwner();
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
            final viewerUserId = currentUserUid;
            final participantActionFailure = _participantActionError;
            final showParticipantActionFailure =
                participantActionFailure != null &&
                    participantActionFailure.userId == viewerUserId &&
                    _canPresentEventListParticipantActionFeedback();
            if (participantActionFailure != null &&
                !showParticipantActionFailure) {
              _scheduleParticipantActionFailureDismissalIfNeeded();
            }
            final renderNowUtc = _currentEventListNowUtc();
            List<EventListCardViewModel> visibleCards(
              List<EventListCardViewModel> cards,
            ) =>
                _eventListCardsWithParticipantActionOverlays(
                  cards,
                  currentUserId: viewerUserId,
                  nowUtc: renderNowUtc,
                );
            final eventCardsOverride = widget.eventCardsOverride;
            final eventCards = visibleCards(
              eventCardsOverride == null
                  ? const <EventListCardViewModel>[]
                  : _eventListCardsWithParticipantActionSourceRevision(
                      eventCardsOverride,
                      _eventCardsOverrideSourceRevision,
                    ),
            );
            final ValueChanged<EventListCardViewModel>? onPrimaryPressed =
                viewerUserId.isEmpty
                    ? null
                    : (event) => _handleEventListParticipantAction(
                          event,
                          expectedUserId: viewerUserId,
                        );
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
            void openEventCardDetail(EventListCardViewModel event) =>
                _openEventCardDetail(
                  event,
                  selectedCity: selectedState?.selected,
                );

            Widget boxSliver(Widget child) => SliverToBoxAdapter(child: child);
            Widget cardsSliver(
              List<EventListCardViewModel> cards, {
              _EventListPaginationViewState paginationState =
                  const _EventListPaginationViewState(),
            }) =>
                _EventListCardsSliver(
                  eventCards: cards,
                  selectedCity: selectedState?.selected,
                  canOpenEventCardChat: _canOpenEventCardChat,
                  onPrimaryPressed: onPrimaryPressed,
                  openEventCardDetail: openEventCardDetail,
                  openEventCardChat: _openEventCardChat,
                  paginationState: paginationState,
                  showParticipantRequiredSnackBar: () =>
                      _showEventListChatParticipantRequiredSnackBar(context),
                );
            Widget boxCards(List<EventListCardViewModel> cards) =>
                _EventListCards(
                  eventCards: cards,
                  selectedCity: selectedState?.selected,
                  canOpenEventCardChat: _canOpenEventCardChat,
                  onPrimaryPressed: onPrimaryPressed,
                  openEventCardDetail: openEventCardDetail,
                  openEventCardChat: _openEventCardChat,
                  showParticipantRequiredSnackBar: () =>
                      _showEventListChatParticipantRequiredSnackBar(context),
                );
            Widget emptyState() => _EventListEmptyState(
                  hasActiveFilters:
                      _selectedDateFilter != null || _selectedLevel != null,
                  onResetFilters: _resetEventFilters,
                  onOpenMyEvents: () =>
                      context.pushNamed(EventHistoryWidget.routeName),
                );

            Widget eventCardsSliver(
              AsyncSnapshot<List<EventListCardViewModel>> eventsSnapshot,
            ) {
              if (!canShowEventCards) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              if (widget.isLoadingEvents) {
                return boxSliver(
                  hasVisibleEventCards
                      ? _EventListPreviousCardsState(
                          cards: eventCards,
                          selectedCity: selectedState?.selected,
                          emptyState: emptyState(),
                          canOpenEventCardChat: _canOpenEventCardChat,
                          onPrimaryPressed: onPrimaryPressed,
                          openEventCardDetail: openEventCardDetail,
                          openEventCardChat: _openEventCardChat,
                          showParticipantRequiredSnackBar: () =>
                              _showEventListChatParticipantRequiredSnackBar(
                            context,
                          ),
                        )
                      : const SizedBox.shrink(),
                );
              }
              if (hasEventListError) {
                return SliverMainAxisGroup(
                  slivers: [
                    boxSliver(
                      _EventListErrorState(
                        message: widget.eventListErrorMessage,
                        onRetryPressed: widget.onRetryEventsPressed,
                        compact: hasVisibleEventCards,
                      ),
                    ),
                    if (hasVisibleEventCards) ...[
                      boxSliver(
                        const SizedBox(height: ExpatlioDesign.space12),
                      ),
                      boxSliver(boxCards(eventCards)),
                    ],
                  ],
                );
              }
              if (eventCardsFuture == null) {
                return eventCards.isEmpty
                    ? boxSliver(emptyState())
                    : boxSliver(boxCards(eventCards));
              }

              final activeLoadKey = _eventListLoadKey;
              final paginationState =
                  _eventListPaginationViewState(activeLoadKey);
              final previousCards = _previousCardsForActiveKey(activeLoadKey);
              if (eventsSnapshot.connectionState != ConnectionState.done) {
                final initialCards = _eventCardsFutureInitialCards;
                if (initialCards != null) {
                  return initialCards.isEmpty
                      ? boxSliver(emptyState())
                      : cardsSliver(
                          visibleCards(initialCards),
                          paginationState: paginationState,
                        );
                }
                if (previousCards != null) {
                  return boxSliver(
                    _EventListPreviousCardsState(
                      cards: visibleCards(previousCards.cards),
                      selectedCity: selectedState?.selected,
                      emptyState: emptyState(),
                      showEmptyState: previousCards.key.activeDataKey ==
                          activeLoadKey?.activeDataKey,
                      canOpenEventCardChat: _canOpenEventCardChat,
                      onPrimaryPressed: onPrimaryPressed,
                      openEventCardDetail: openEventCardDetail,
                      openEventCardChat: _openEventCardChat,
                      showParticipantRequiredSnackBar: () =>
                          _showEventListChatParticipantRequiredSnackBar(
                        context,
                      ),
                    ),
                  );
                }
                return boxSliver(const SizedBox.shrink());
              }
              if (eventsSnapshot.hasError) {
                if (previousCards != null) {
                  return boxSliver(
                    _EventListPreviousCardsState(
                      cards: visibleCards(previousCards.cards),
                      selectedCity: selectedState?.selected,
                      emptyState: emptyState(),
                      errorMessage: null,
                      onRetryPressed: _retryEventCardsLoad,
                      canOpenEventCardChat: _canOpenEventCardChat,
                      onPrimaryPressed: onPrimaryPressed,
                      openEventCardDetail: openEventCardDetail,
                      openEventCardChat: _openEventCardChat,
                      showParticipantRequiredSnackBar: () =>
                          _showEventListChatParticipantRequiredSnackBar(
                        context,
                      ),
                    ),
                  );
                }
                return boxSliver(
                  _EventListErrorState(
                    message: null,
                    onRetryPressed: _retryEventCardsLoad,
                  ),
                );
              }

              final loadedCards = visibleCards(
                eventsSnapshot.data ?? const <EventListCardViewModel>[],
              );
              return loadedCards.isEmpty
                  ? boxSliver(emptyState())
                  : cardsSliver(
                      loadedCards,
                      paginationState: paginationState,
                    );
            }

            int eventCardsSemanticCount(
              AsyncSnapshot<List<EventListCardViewModel>> eventsSnapshot,
            ) {
              if (!canShowEventCards ||
                  widget.isLoadingEvents ||
                  hasEventListError ||
                  eventCardsFuture == null ||
                  eventsSnapshot.hasError) {
                return 0;
              }
              if (eventsSnapshot.connectionState != ConnectionState.done) {
                return _eventCardsFutureInitialCards?.length ?? 0;
              }
              return eventsSnapshot.data?.length ?? 0;
            }

            return Scaffold(
              backgroundColor: ExpatlioDesign.background,
              floatingActionButton: showParticipantActionFailure
                  ? _EventListParticipantActionErrorNotice(
                      message: eventActionFailureMessage(
                        context,
                        participantActionFailure.error,
                      ),
                    )
                  : null,
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
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
                        child: FutureBuilder<List<EventListCardViewModel>>(
                          key: ValueKey(_eventListLoadKey),
                          future: eventCardsFuture,
                          initialData: _eventCardsFutureInitialCards,
                          builder: (context, eventsSnapshot) {
                            return ClipRect(
                              key: eventListVerticalViewportClipKey,
                              clipper: const _EventListVerticalViewportClipper(
                                horizontalOverflow: _eventListHorizontalPadding,
                              ),
                              child: CustomScrollView(
                                key: eventListScrollViewKey,
                                controller: _scrollController,
                                clipBehavior: Clip.none,
                                semanticChildCount:
                                    eventCardsSemanticCount(eventsSnapshot),
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        _EventDateChips(
                                          selectedFilter: _selectedDateFilter,
                                          onChanged: _selectDateFilter,
                                        ),
                                        const SizedBox(
                                          height: ExpatlioDesign.space8,
                                        ),
                                        _EventLevelChips(
                                          selectedLevel: _selectedLevel,
                                          onChanged: _selectLevelFilter,
                                        ),
                                        if (selectedState?.selected != null &&
                                            !selectedState!
                                                .needsCitySelection &&
                                            !selectedState
                                                .hasOutdatedProfileCity) ...[
                                          const SizedBox(
                                            height: ExpatlioDesign.space12,
                                          ),
                                          _EventCitySelector(
                                            selectorKey:
                                                eventListActiveCitySelectorKey,
                                            selectedCity:
                                                selectedState.selected,
                                            hasOutdatedProfileCity: false,
                                            showsMissingLocationPrompt: false,
                                            onPressed: onCitySelectorPressed,
                                          ),
                                        ],
                                        if (selectedState != null &&
                                            (selectedState.needsCitySelection ||
                                                selectedState
                                                    .hasOutdatedProfileCity)) ...[
                                          const SizedBox(
                                            height: ExpatlioDesign.space16,
                                          ),
                                          _EventCitySelector(
                                            selectedCity:
                                                selectedState.selected,
                                            hasOutdatedProfileCity:
                                                selectedState
                                                    .hasOutdatedProfileCity,
                                            showsMissingLocationPrompt:
                                                selectedState
                                                        .needsCitySelection &&
                                                    !selectedState
                                                        .hasOutdatedProfileCity,
                                            onPressed: onCitySelectorPressed,
                                          ),
                                        ],
                                        if (canShowEventCards)
                                          const SizedBox(
                                            height: ExpatlioDesign.space16,
                                          ),
                                      ],
                                    ),
                                  ),
                                  eventCardsSliver(eventsSnapshot),
                                  const SliverToBoxAdapter(
                                    child: SizedBox(
                                      height: ExpatlioDesign.pageBottomSpacing,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
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

    final normalizedNowUtc = _currentEventListNowUtc();
    final viewerUserId = currentUserUid;
    final selectedDateFilter = _selectedDateFilter;
    final localDateRange = selectedDateFilter == null
        ? null
        : eventListDateFilterLocalDateRange(
            dateFilter: selectedDateFilter,
            timeZoneId: selected.city.timeZoneId,
            nowUtc: normalizedNowUtc,
          );
    final baseRequestLowerBoundUtc = localDateRange == null
        ? normalizedNowUtc
        : computeEventListDateBounds(
            timeZoneId: selected.city.timeZoneId,
            localDateRange: localDateRange,
            nowUtc: normalizedNowUtc,
          ).lowerBoundUtc;
    final key = _EventListLoadKey(
      countryCode: selected.city.countryCode,
      cityKey: selected.city.cityKey,
      timeZoneId: selected.city.timeZoneId,
      dateFilter: selectedDateFilter,
      localStartDate: localDateRange?.startDate,
      localExclusiveEndDate: localDateRange?.exclusiveEndDate,
      selectedLevel: _selectedLevel,
      pageLoaderIdentity: widget.eventPageLoader,
      currentUserId: viewerUserId,
      participantLoaderIdentity: widget.currentUserParticipantLoader,
      activeParticipantsLoaderIdentity: widget.activeParticipantsLoader,
      publicProfilesLoaderIdentity: widget.publicProfilesLoader,
    );
    if (_eventListLoadKey != key || _eventCardsFuture == null) {
      if (_eventListLoadKey != null && _eventListLoadKey != key) {
        _eventListProfileScrollOriginPixels = 0;
        _scheduleEventListScrollReset();
      }
      _eventListLoadGeneration += 1;
      _eventListLoadKey = key;
      _eventListPaginationSession = null;
      final loadGeneration = _eventListLoadGeneration;
      final participantActionSourceRevision =
          _eventListParticipantActionCoordinator.currentConfirmedRevision;
      final cacheOwnerToken = _eventListCardsCache.claim(key);
      final cachedEntry = _eventListCardsCache.read(
        key,
        nowUtc: normalizedNowUtc,
      );
      final cachedEvents = cachedEntry?.events
          .where((event) => event.startsAt?.isAfter(normalizedNowUtc) ?? false)
          .toList(growable: false);
      final cachedCards = cachedEntry == null
          ? null
          : cachedEvents!.isEmpty
              ? const <EventListCardViewModel>[]
              : _eventListBaseCardsFromEvents(
                  events: cachedEvents,
                  fallbackTimeZoneId: selected.city.timeZoneId,
                  nowUtc: normalizedNowUtc,
                  currentUserId: viewerUserId,
                  participantActionSourceRevision:
                      participantActionSourceRevision,
                );
      final cachedEntryIsFresh = cachedEntry != null &&
          _eventListCardsCache.isFresh(
            cachedEntry,
            nowUtc: normalizedNowUtc,
          );
      if (cachedCards != null) {
        final entry = cachedEntry!;
        final entryEvents = cachedEvents!;
        _eventListCardsCache.registerEventsIfOwner(
          key,
          cacheOwnerToken,
          cachedCards.map((card) => card.eventId),
        );
        _rememberLoadedCards(key, cachedCards);
        if (cachedEntryIsFresh) {
          final paginationSession = _EventListPaginationSession(
            key: key,
            loadGeneration: loadGeneration,
            cacheOwnerToken: cacheOwnerToken,
            selected: selected,
            localDateRange: localDateRange,
            nowUtc: normalizedNowUtc,
            baseFetchedAtUtc: entry.fetchedAtUtc,
            selectedLevel: _selectedLevel,
            currentUserId: viewerUserId,
            participantActionSourceRevision: participantActionSourceRevision,
            events: entryEvents,
            nextPageMarker: entry.nextPageMarker,
            hasRequestedNextPage: entry.hasRequestedNextPage,
            noMoreItems: entry.noMoreItems,
          );
          _eventListPaginationSession = paginationSession;
          _scheduleEventListPaginationCheck(paginationSession);
          if (entryEvents.isNotEmpty) {
            paginationSession.pendingEnrichmentEventIds.addAll(
              cachedCards.map((card) => card.eventId),
            );
            unawaited(
              _enrichEventCards(
                events: entryEvents,
                fallbackTimeZoneId: selected.city.timeZoneId,
                key: key,
                nowUtc: normalizedNowUtc,
                currentUserId: viewerUserId,
                loadGeneration: loadGeneration,
                cacheOwnerToken: cacheOwnerToken,
                participantActionSourceRevision:
                    participantActionSourceRevision,
                paginationSession: paginationSession,
              ),
            );
          }
        }
      }
      _eventCardsFutureInitialCards = cachedCards;
      _eventCardsFuture = cachedEntryIsFresh
          ? Future<List<EventListCardViewModel>>.value(cachedCards!)
          : _eventListCardsCache
              .reuseBaseLoad(
              key,
              () => _loadBaseEventCards(
                selected: selected,
                localDateRange: localDateRange,
                nowUtc: normalizedNowUtc,
                selectedLevel: _selectedLevel,
                currentUserId: viewerUserId,
                participantActionSourceRevision:
                    participantActionSourceRevision,
              ),
              lowerBoundUtc: baseRequestLowerBoundUtc,
            )
              .then((sharedBaseLoad) {
              final baseEvents = sharedBaseLoad.events
                  .where(
                    (event) =>
                        event.startsAt == null ||
                        event.startsAt!.isAfter(normalizedNowUtc),
                  )
                  .toList(growable: false);
              final baseLoad = _EventListBaseCardsLoad(
                events: baseEvents,
                cards: _eventListBaseCardsFromEvents(
                  events: baseEvents,
                  fallbackTimeZoneId: selected.city.timeZoneId,
                  nowUtc: normalizedNowUtc,
                  currentUserId: viewerUserId,
                  participantActionSourceRevision:
                      participantActionSourceRevision,
                ),
                nextPageMarker: sharedBaseLoad.nextPageMarker,
                hasMore: sharedBaseLoad.hasMore,
              );
              if (baseLoad.cards.isNotEmpty || baseLoad.events.isEmpty) {
                _eventListCardsCache.writeIfOwner(
                  key,
                  cacheOwnerToken,
                  baseLoad.cards,
                  fetchedAtUtc: normalizedNowUtc,
                  events: baseLoad.events,
                  nextPageMarker: baseLoad.nextPageMarker,
                  hasRequestedNextPage: false,
                  noMoreItems: !baseLoad.hasMore,
                );
              }
              if (_eventListLoadIsCurrent(key, loadGeneration)) {
                final paginationSession = _EventListPaginationSession(
                  key: key,
                  loadGeneration: loadGeneration,
                  cacheOwnerToken: cacheOwnerToken,
                  selected: selected,
                  localDateRange: localDateRange,
                  nowUtc: normalizedNowUtc,
                  baseFetchedAtUtc: normalizedNowUtc,
                  selectedLevel: _selectedLevel,
                  currentUserId: viewerUserId,
                  participantActionSourceRevision:
                      participantActionSourceRevision,
                  events: baseLoad.events,
                  nextPageMarker: baseLoad.nextPageMarker,
                  noMoreItems: !baseLoad.hasMore,
                );
                _eventListPaginationSession = paginationSession;
                _scheduleEventListPaginationCheck(paginationSession);
                _rememberLoadedCards(key, baseLoad.cards);
                if (baseLoad.cards.isNotEmpty) {
                  paginationSession.pendingEnrichmentEventIds.addAll(
                    baseLoad.cards.map((card) => card.eventId),
                  );
                  unawaited(
                    _enrichEventCards(
                      events: baseLoad.events,
                      fallbackTimeZoneId: selected.city.timeZoneId,
                      key: key,
                      nowUtc: normalizedNowUtc,
                      currentUserId: viewerUserId,
                      loadGeneration: loadGeneration,
                      cacheOwnerToken: cacheOwnerToken,
                      participantActionSourceRevision:
                          participantActionSourceRevision,
                      paginationSession: paginationSession,
                    ),
                  );
                }
              }
              return baseLoad.cards;
            });
    }
    return _eventCardsFuture;
  }

  DateTime _currentEventListNowUtc() {
    final nowUtc = (widget.nowUtcProvider ?? _eventListNowUtc)();
    return nowUtc.isUtc ? nowUtc : nowUtc.toUtc();
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
    if (previous.key != key) {
      return null;
    }
    return previous;
  }

  void _retryEventCardsLoad() {
    setState(() {
      final key = _eventListLoadKey;
      if (key != null) {
        _eventListCardsCache.invalidate(key);
      }
      _resetEventCardsLoadState(clearLastLoadedCards: false);
    });
  }

  void _resetEventCardsLoadState({required bool clearLastLoadedCards}) {
    _eventListLoadGeneration += 1;
    _eventListLoadKey = null;
    _eventCardsFuture = null;
    _eventCardsFutureInitialCards = null;
    _publicProfileSession = null;
    _eventListPaginationSession = null;
    _eventListProfileScrollOriginPixels = 0;
    _scheduleEventListScrollReset();
    if (clearLastLoadedCards) {
      _lastLoadedCards = null;
    }
  }

  void _scheduleEventListScrollReset() {
    _eventListScrollResetPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _eventListScrollResetPending = false;
    });
  }

  Future<_EventListBaseCardsLoad> _loadBaseEventCards({
    required EventSelectedCity selected,
    required EventListLocalDateRange? localDateRange,
    required DateTime nowUtc,
    required String? selectedLevel,
    required String currentUserId,
    required int participantActionSourceRevision,
  }) async {
    final page = await _loadEventRecordsPage(
      selected: selected,
      localDateRange: localDateRange,
      nowUtc: nowUtc,
      selectedLevel: selectedLevel,
    );

    final cards = _eventListBaseCardsFromEvents(
      events: page.data,
      fallbackTimeZoneId: selected.city.timeZoneId,
      nowUtc: nowUtc,
      currentUserId: currentUserId,
      participantActionSourceRevision: participantActionSourceRevision,
    );
    return _EventListBaseCardsLoad(
      events: page.data,
      cards: cards,
      nextPageMarker: page.nextPageMarker,
      hasMore: EventListRepository.pageHasMore(page),
    );
  }

  Future<FFFirestorePage<EventsRecord>> _loadEventRecordsPage({
    required EventSelectedCity selected,
    required EventListLocalDateRange? localDateRange,
    required DateTime nowUtc,
    required String? selectedLevel,
    DocumentSnapshot? nextPageMarker,
  }) {
    return localDateRange == null
        ? EventListRepository.loadLevelFilteredActiveEventPage(
            countryCode: selected.city.countryCode,
            cityKey: selected.city.cityKey,
            lowerBoundUtc: nowUtc,
            upperBoundUtc: _eventListAllEventsUpperBoundUtc,
            pageSize: _eventListPageSize,
            selectedLevel: selectedLevel,
            nextPageMarker: nextPageMarker,
            pageLoader: widget.eventPageLoader,
          )
        : EventListRepository.loadLevelFilteredActiveEventPageForDateRange(
            countryCode: selected.city.countryCode,
            cityKey: selected.city.cityKey,
            timeZoneId: selected.city.timeZoneId,
            localDateRange: localDateRange,
            nowUtc: nowUtc,
            pageSize: _eventListPageSize,
            selectedLevel: selectedLevel,
            nextPageMarker: nextPageMarker,
            pageLoader: widget.eventPageLoader,
          );
  }

  List<EventListCardViewModel> _eventListBaseCardsFromEvents({
    required List<EventsRecord> events,
    required String fallbackTimeZoneId,
    required DateTime nowUtc,
    required String currentUserId,
    required int participantActionSourceRevision,
  }) {
    return events
        .map(
          (event) => _eventListCardFromRecord(
            event,
            fallbackTimeZoneId: fallbackTimeZoneId,
            nowUtc: nowUtc,
            currentUserId: currentUserId,
            participantActionSourceRevision: participantActionSourceRevision,
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
  }

  Future<void> _enrichEventCards({
    required List<EventsRecord> events,
    required String fallbackTimeZoneId,
    required _EventListLoadKey key,
    required DateTime nowUtc,
    required String currentUserId,
    required int loadGeneration,
    required int cacheOwnerToken,
    required int participantActionSourceRevision,
    required _EventListPaginationSession paginationSession,
  }) async {
    final currentParticipantsFuture =
        _loadCurrentUserParticipantRecordsByEventId(
      cacheKey: key,
      events: events,
      currentUserId: currentUserId,
    );
    final initialEvents =
        events.take(_eventListInitialProfileCardBudget).toList(
              growable: false,
            );
    final remainingEvents = events.skip(initialEvents.length).toList(
          growable: false,
        );
    final initialActiveParticipantsFuture =
        _loadActiveParticipantRecordsByEventId(
      cacheKey: key,
      events: initialEvents,
    );
    final remainingActiveParticipantsFuture =
        _loadActiveParticipantRecordsByEventId(
      cacheKey: key,
      events: remainingEvents,
    );
    final initialActiveParticipantsLoad = await initialActiveParticipantsFuture;

    if (!_eventListLoadIsCurrent(key, loadGeneration) ||
        !_eventListPaginationSessionIsCurrent(paginationSession)) {
      return;
    }

    final provisionalCards = _eventListCardsFromParticipantRecords(
      events: events,
      fallbackTimeZoneId: fallbackTimeZoneId,
      nowUtc: nowUtc,
      currentUserId: currentUserId,
      participantActionSourceRevision: participantActionSourceRevision,
      activeParticipantRecordsByEventId:
          initialActiveParticipantsLoad.recordsByEventId,
    );
    final canPreloadProfiles =
        _canPreloadEventListPublicProfiles(currentUserId);
    final earlyProfileIds = canPreloadProfiles
        ? _eventListVisibleParticipantUserIds(
            provisionalCards.take(_eventListInitialProfileCardBudget),
            participantLimit: _eventListEarlyProfileParticipantLimit,
          )
        : const <String>{};
    final earlyProfilesFuture = canPreloadProfiles
        ? _preloadEventListPublicProfiles(
            earlyProfileIds,
            currentUserId: currentUserId,
          )
        : Future<UserPublicProfilePreloadResult>.value(
            UserPublicProfilePreloadResult(),
          );
    final remainingActiveParticipantsLoad =
        await remainingActiveParticipantsFuture;
    final activeParticipantRecordsByEventId =
        <String, List<EventParticipantsRecord>>{
      ...initialActiveParticipantsLoad.recordsByEventId,
      ...remainingActiveParticipantsLoad.recordsByEventId,
    };
    final activeParticipantFailedEventIds = <String>{
      ...initialActiveParticipantsLoad.failedEventIds,
      ...remainingActiveParticipantsLoad.failedEventIds,
    };
    final membershipLoad = await currentParticipantsFuture;

    if (!_eventListLoadIsCurrent(key, loadGeneration) ||
        !_eventListPaginationSessionIsCurrent(paginationSession)) {
      return;
    }

    var participantCards = _eventListCardsFromParticipantRecords(
      events: events,
      fallbackTimeZoneId: fallbackTimeZoneId,
      nowUtc: nowUtc,
      currentUserId: currentUserId,
      participantActionSourceRevision: participantActionSourceRevision,
      activeParticipantRecordsByEventId: activeParticipantRecordsByEventId,
      membershipLoad: membershipLoad,
    );
    participantCards = _replaceEventListCards(
      _displayedEventListCards(paginationSession),
      participantCards,
    );
    final finalProfileIds = canPreloadProfiles
        ? _eventListVisibleParticipantUserIds(
            participantCards.take(_eventListInitialProfileCardBudget),
          )
        : const <String>{};
    final additionalProfileIds = LinkedHashSet<String>();
    final remainingProfileBudget =
        _eventListInitialProfileUserBudget - earlyProfileIds.length;
    for (final userId in finalProfileIds) {
      if (!earlyProfileIds.contains(userId)) {
        additionalProfileIds.add(userId);
      }
      if (additionalProfileIds.length >= remainingProfileBudget) {
        break;
      }
    }
    final additionalProfilesFuture = canPreloadProfiles
        ? _preloadEventListPublicProfiles(
            additionalProfileIds,
            currentUserId: currentUserId,
          )
        : Future<UserPublicProfilePreloadResult>.value(
            UserPublicProfilePreloadResult(),
          );

    if (!canPreloadProfiles) {
      paginationSession.pendingEnrichmentEventIds.removeAll(
        events.map((event) => event.reference.id),
      );
      if (membershipLoad.failedEventIds.isNotEmpty ||
          activeParticipantFailedEventIds.isNotEmpty) {
        _markEventListPaginationCacheUnsafe(paginationSession);
      } else if (participantCards.isNotEmpty) {
        _writeEventListBaseCardsCacheIfOwner(paginationSession);
      }
      setState(() {
        _eventCardsFutureInitialCards = participantCards;
        _eventCardsFuture =
            Future<List<EventListCardViewModel>>.value(participantCards);
        _rememberLoadedCards(key, participantCards);
      });
      return;
    }

    final session = _EventListPublicProfileSession(
      key: key,
      loadGeneration: loadGeneration,
      currentUserId: currentUserId,
      nowUtc: nowUtc,
      cards: participantCards,
      targetCardCount: math.min(
        participantCards.length,
        _eventListInitialProfileCardBudget,
      ),
      completedCardCount: 0,
      scrollStartPixels: _eventListProfileScrollOriginPixels,
      canCacheCards: membershipLoad.failedEventIds.isEmpty &&
          activeParticipantFailedEventIds.isEmpty,
      requestedUserIds: <String>{
        ...earlyProfileIds,
        ...additionalProfileIds,
      },
      requestInFlight: true,
      cacheOwnerToken: cacheOwnerToken,
    );
    if (membershipLoad.failedEventIds.isNotEmpty ||
        activeParticipantFailedEventIds.isNotEmpty) {
      _markEventListPaginationCacheUnsafe(paginationSession);
    }
    if (!_eventListScrollResetPending) {
      session.targetCardCount = math.max(
        session.targetCardCount,
        _eventListProfileCardBudget(session),
      );
    }
    _publicProfileSession = session;
    setState(() {
      _eventCardsFutureInitialCards = participantCards;
      _eventCardsFuture =
          Future<List<EventListCardViewModel>>.value(participantCards);
      _rememberLoadedCards(key, participantCards);
    });

    final profileLoads = await Future.wait([
      earlyProfilesFuture,
      additionalProfilesFuture,
    ]);
    session.requestInFlight = false;
    if (!_eventListPublicProfileSessionIsCurrent(session)) {
      return;
    }

    final profileLoad = _mergeEventListPublicProfileLoads(profileLoads);
    session.completedCardCount = math.min(
      participantCards.length,
      _eventListInitialProfileCardBudget,
    );
    paginationSession.pendingEnrichmentEventIds.removeAll(
      events.map((event) => event.reference.id),
    );
    _applyEventListPublicProfileLoad(session, profileLoad);
    await _pumpEventListPublicProfileSession(session);
  }

  bool _canPreloadEventListPublicProfiles(String currentUserId) {
    return currentUserId.isNotEmpty &&
        (widget.publicProfilesLoader != null || widget.eventPageLoader == null);
  }

  int _eventListProfileCardBudget(_EventListPublicProfileSession session) {
    final totalCardCount = session.cards.length;
    final initialCardCount = math.min(
      totalCardCount,
      _eventListInitialProfileCardBudget,
    );
    if (totalCardCount <= initialCardCount) {
      return totalCardCount;
    }
    var cardBudget = initialCardCount;
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      if (!position.hasViewportDimension) {
        return cardBudget;
      }
      final viewportDimension = position.viewportDimension;
      final scrollDistance = math.max(
        0.0,
        position.pixels - session.scrollStartPixels,
      );
      if (viewportDimension > 0 && scrollDistance >= viewportDimension) {
        final traversedWindows = (scrollDistance / viewportDimension).floor();
        cardBudget += traversedWindows * _eventListProfileCardWindow;
      }
    }
    return math.min(totalCardCount, cardBudget);
  }

  void _saveEventListViewState() {
    final userId = _eventListViewStateUserId;
    if (userId.isEmpty) {
      return;
    }
    final previousState = _eventListViewStateStore.read(userId);
    _eventListViewStateStore.write(
      userId,
      _EventListViewState(
        dateFilter: _selectedDateFilter,
        selectedLevel: _selectedLevel,
        scrollOffset: _scrollController.hasClients
            ? _scrollController.offset
            : previousState?.scrollOffset ?? 0,
      ),
    );
  }

  void _syncEventListViewStateOwner() {
    final userId = currentUserUid;
    if (userId == _eventListViewStateUserId) {
      return;
    }
    _saveEventListViewState();
    _eventListViewStateUserId = userId;
    final restoredState = _eventListViewStateStore.read(userId);
    _selectedDateFilter = restoredState?.dateFilter;
    _selectedLevel = restoredState?.selectedLevel;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          currentUserUid != userId ||
          !_scrollController.hasClients) {
        return;
      }
      _scrollController.jumpTo(0);
    });
  }

  void _handleEventListScroll() {
    _saveEventListViewState();
    final profileSession = _publicProfileSession;
    if (profileSession != null &&
        _eventListPublicProfileSessionIsCurrent(profileSession)) {
      final targetCardCount = _eventListProfileCardBudget(profileSession);
      if (targetCardCount > profileSession.targetCardCount) {
        profileSession.targetCardCount = targetCardCount;
        unawaited(_pumpEventListPublicProfileSession(profileSession));
      }
    }
    _maybeLoadNextEventPage();
  }

  void _maybeLoadNextEventPage() {
    final session = _eventListPaginationSession;
    if (session == null ||
        !_eventListPaginationSessionIsCurrent(session) ||
        session.requestInFlight ||
        session.noMoreItems ||
        session.error != null ||
        session.nextPageMarker == null ||
        !_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (!position.hasContentDimensions ||
        position.extentAfter > _eventListPaginationPrefetchExtent) {
      return;
    }
    unawaited(_loadNextEventPage(session));
  }

  void _scheduleEventListPaginationCheck(
    _EventListPaginationSession session,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_eventListPaginationSessionIsCurrent(session)) {
        return;
      }
      _maybeLoadNextEventPage();
    });
  }

  bool _eventListPaginationSessionIsCurrent(
    _EventListPaginationSession session,
  ) {
    return mounted &&
        identical(_eventListPaginationSession, session) &&
        currentUserUid == session.currentUserId &&
        _eventListLoadIsCurrent(session.key, session.loadGeneration);
  }

  _EventListPaginationViewState _eventListPaginationViewState(
    _EventListLoadKey? key,
  ) {
    final session = _eventListPaginationSession;
    if (session == null ||
        key == null ||
        session.key != key ||
        !_eventListPaginationSessionIsCurrent(session)) {
      return const _EventListPaginationViewState();
    }
    return _EventListPaginationViewState(
      error: session.error,
      onRetry: session.error == null ? null : _retryNextEventPage,
    );
  }

  Future<void> _loadNextEventPage(
    _EventListPaginationSession session,
  ) async {
    final requestMarker = session.nextPageMarker;
    if (!_eventListPaginationSessionIsCurrent(session) ||
        session.requestInFlight ||
        session.noMoreItems ||
        requestMarker == null) {
      return;
    }

    setState(() {
      session
        ..requestInFlight = true
        ..hasRequestedNextPage = true
        ..error = null;
    });

    try {
      final page = await _loadEventRecordsPage(
        selected: session.selected,
        localDateRange: session.localDateRange,
        nowUtc: session.nowUtc,
        selectedLevel: session.selectedLevel,
        nextPageMarker: requestMarker,
      );
      if (!_eventListPaginationSessionIsCurrent(session) ||
          !identical(session.nextPageMarker, requestMarker)) {
        return;
      }

      final knownEventIds =
          session.events.map((event) => event.reference.id).toSet();
      final additionalEvents = page.data
          .where((event) => knownEventIds.add(event.reference.id))
          .toList(growable: false);
      final nextPageMarker = page.nextPageMarker;
      final pageHasMore = EventListRepository.pageHasMore(page);
      final cursorDidNotAdvance = nextPageMarker != null &&
          (identical(nextPageMarker, requestMarker) ||
              nextPageMarker.id == requestMarker.id);
      session
        ..requestInFlight = false
        ..nextPageMarker = nextPageMarker
        ..noMoreItems = !pageHasMore ||
            nextPageMarker == null ||
            (additionalEvents.isEmpty && cursorDidNotAdvance);

      if (additionalEvents.isEmpty) {
        _eventListCardsCache.updatePaginationIfOwner(
          session.key,
          session.cacheOwnerToken,
          events: session.events,
          nextPageMarker: session.nextPageMarker,
          hasRequestedNextPage: session.hasRequestedNextPage,
          noMoreItems: session.noMoreItems,
        );
        setState(() {});
        if (!session.noMoreItems) {
          _scheduleEventListPaginationCheck(session);
        }
        return;
      }

      session.events = List<EventsRecord>.unmodifiable(
        <EventsRecord>[...session.events, ...additionalEvents],
      );
      final additionalCards = _eventListBaseCardsFromEvents(
        events: additionalEvents,
        fallbackTimeZoneId: session.selected.city.timeZoneId,
        nowUtc: session.nowUtc,
        currentUserId: session.currentUserId,
        participantActionSourceRevision:
            session.participantActionSourceRevision,
      );
      session.pendingEnrichmentEventIds.addAll(
        additionalCards.map((card) => card.eventId),
      );
      _writeEventListBaseCardsCacheIfOwner(session);
      final mergedCards = _appendUniqueEventListCards(
        _displayedEventListCards(session),
        additionalCards,
      );
      final profileSession = _publicProfileSession;
      if (profileSession != null &&
          _eventListPublicProfileSessionIsCurrent(profileSession)) {
        profileSession.cards = mergedCards;
      }
      _eventListCardsCache.registerEventsIfOwner(
        session.key,
        session.cacheOwnerToken,
        session.events.map((event) => event.reference.id),
      );
      setState(() {
        _publishEventListCards(session, mergedCards);
      });
      if (!session.noMoreItems) {
        _scheduleEventListPaginationCheck(session);
      }
      unawaited(
        _enrichNextEventPage(
          session: session,
          events: additionalEvents,
        ),
      );
    } catch (error) {
      if (!_eventListPaginationSessionIsCurrent(session) ||
          !identical(session.nextPageMarker, requestMarker)) {
        return;
      }
      setState(() {
        session
          ..requestInFlight = false
          ..error = error;
      });
    }
  }

  void _retryNextEventPage() {
    final session = _eventListPaginationSession;
    if (session == null || !_eventListPaginationSessionIsCurrent(session)) {
      return;
    }
    unawaited(_loadNextEventPage(session));
  }

  List<EventListCardViewModel> _displayedEventListCards(
    _EventListPaginationSession session,
  ) {
    final profileSession = _publicProfileSession;
    if (profileSession != null &&
        _eventListPublicProfileSessionIsCurrent(profileSession)) {
      return profileSession.cards;
    }
    final currentCards = _eventCardsFutureInitialCards;
    if (currentCards != null) {
      return currentCards;
    }
    final previous = _lastLoadedCards;
    if (previous != null && previous.key == session.key) {
      return previous.cards;
    }
    return const <EventListCardViewModel>[];
  }

  List<EventListCardViewModel> _appendUniqueEventListCards(
    List<EventListCardViewModel> existing,
    List<EventListCardViewModel> additions,
  ) {
    final cardsById = LinkedHashMap<String, EventListCardViewModel>();
    for (final card in existing) {
      cardsById[card.eventId] = card;
    }
    for (final card in additions) {
      cardsById.putIfAbsent(card.eventId, () => card);
    }
    return List<EventListCardViewModel>.unmodifiable(cardsById.values);
  }

  List<EventListCardViewModel> _replaceEventListCards(
    List<EventListCardViewModel> existing,
    List<EventListCardViewModel> replacements,
  ) {
    final replacementsById = <String, EventListCardViewModel>{
      for (final card in replacements) card.eventId: card,
    };
    return List<EventListCardViewModel>.unmodifiable(
      existing.map(
        (card) => replacementsById[card.eventId] ?? card,
      ),
    );
  }

  void _publishEventListCards(
    _EventListPaginationSession session,
    List<EventListCardViewModel> cards,
  ) {
    _eventCardsFutureInitialCards = cards;
    _eventCardsFuture = Future<List<EventListCardViewModel>>.value(cards);
    _rememberLoadedCards(session.key, cards);
  }

  Future<void> _enrichNextEventPage({
    required _EventListPaginationSession session,
    required List<EventsRecord> events,
  }) async {
    final currentParticipantsFuture =
        _loadCurrentUserParticipantRecordsByEventId(
      cacheKey: session.key,
      events: events,
      currentUserId: session.currentUserId,
    );
    final activeParticipantsFuture = _loadActiveParticipantRecordsByEventId(
      cacheKey: session.key,
      events: events,
    );
    final activeParticipantsLoad = await activeParticipantsFuture;
    final membershipLoad = await currentParticipantsFuture;
    if (!_eventListPaginationSessionIsCurrent(session)) {
      return;
    }

    var enrichedCards = _eventListCardsFromParticipantRecords(
      events: events,
      fallbackTimeZoneId: session.selected.city.timeZoneId,
      nowUtc: session.nowUtc,
      currentUserId: session.currentUserId,
      participantActionSourceRevision: session.participantActionSourceRevision,
      activeParticipantRecordsByEventId:
          activeParticipantsLoad.recordsByEventId,
      membershipLoad: membershipLoad,
    );
    final profileUserIds = _eventListVisibleParticipantUserIds(enrichedCards);
    final profileLoad = await _preloadEventListPublicProfiles(
      profileUserIds,
      currentUserId: session.currentUserId,
    );
    if (!_eventListPaginationSessionIsCurrent(session)) {
      return;
    }
    enrichedCards = _eventListCardsWithPublicProfiles(
      enrichedCards,
      profileLoad.profilesByUserId,
    );

    final mergedCards = _replaceEventListCards(
      _displayedEventListCards(session),
      enrichedCards,
    );
    final profileSession = _publicProfileSession;
    if (profileSession != null &&
        _eventListPublicProfileSessionIsCurrent(profileSession)) {
      profileSession
        ..cards = mergedCards
        ..requestedUserIds.addAll(profileUserIds);
      if (membershipLoad.failedEventIds.isNotEmpty ||
          activeParticipantsLoad.failedEventIds.isNotEmpty ||
          profileLoad.failedUserIds.isNotEmpty ||
          profileLoad.missingUserIds.isNotEmpty) {
        profileSession.canCacheCards = false;
      }
    }
    setState(() {
      _publishEventListCards(session, mergedCards);
    });
    session.pendingEnrichmentEventIds.removeAll(
      events.map((event) => event.reference.id),
    );
    final enrichmentCanCache = membershipLoad.failedEventIds.isEmpty &&
        activeParticipantsLoad.failedEventIds.isEmpty &&
        profileLoad.failedUserIds.isEmpty &&
        profileLoad.missingUserIds.isEmpty &&
        (profileSession?.canCacheCards ?? true);
    if (!enrichmentCanCache) {
      _markEventListPaginationCacheUnsafe(session);
    }
    if (enrichmentCanCache && session.canCacheCards) {
      _writeEventListBaseCardsCacheIfOwner(session);
    }
  }

  bool _eventListPublicProfileSessionIsCurrent(
    _EventListPublicProfileSession session,
  ) {
    return identical(_publicProfileSession, session) &&
        _eventListLoadIsCurrent(session.key, session.loadGeneration);
  }

  Future<void> _pumpEventListPublicProfileSession(
    _EventListPublicProfileSession session,
  ) async {
    while (_eventListPublicProfileSessionIsCurrent(session) &&
        !session.requestInFlight &&
        session.completedCardCount < session.targetCardCount) {
      final windowStart = session.completedCardCount;
      final windowEnd = math.min(
        session.targetCardCount,
        windowStart + _eventListProfileCardWindow,
      );
      final windowUserIds = _eventListVisibleParticipantUserIds(
        session.cards.skip(windowStart).take(windowEnd - windowStart),
      );
      final pendingUserIds = windowUserIds.difference(
        session.requestedUserIds,
      );
      if (pendingUserIds.isEmpty) {
        session.completedCardCount = windowEnd;
        _writeEventListPublicProfileSessionCache(session);
        continue;
      }

      session
        ..requestInFlight = true
        ..requestedUserIds.addAll(pendingUserIds);
      final profileLoad = await _preloadEventListPublicProfiles(
        pendingUserIds,
        currentUserId: session.currentUserId,
      );
      session.requestInFlight = false;
      if (!_eventListPublicProfileSessionIsCurrent(session)) {
        return;
      }
      session.completedCardCount = windowEnd;
      _applyEventListPublicProfileLoad(session, profileLoad);
    }
  }

  void _applyEventListPublicProfileLoad(
    _EventListPublicProfileSession session,
    UserPublicProfilePreloadResult profileLoad,
  ) {
    if (!_eventListPublicProfileSessionIsCurrent(session)) {
      return;
    }
    if (profileLoad.failedUserIds.isNotEmpty ||
        profileLoad.missingUserIds.isNotEmpty) {
      session.canCacheCards = false;
      final paginationSession = _eventListPaginationSession;
      if (paginationSession != null &&
          paginationSession.key == session.key &&
          paginationSession.cacheOwnerToken == session.cacheOwnerToken) {
        _markEventListPaginationCacheUnsafe(paginationSession);
      }
    }
    session.cards = _eventListCardsWithPublicProfiles(
      session.cards,
      profileLoad.profilesByUserId,
    );
    _writeEventListPublicProfileSessionCache(session);
    setState(() {
      _eventCardsFutureInitialCards = session.cards;
      _eventCardsFuture =
          Future<List<EventListCardViewModel>>.value(session.cards);
      _rememberLoadedCards(session.key, session.cards);
    });
  }

  void _writeEventListPublicProfileSessionCache(
    _EventListPublicProfileSession session,
  ) {
    if (session.cards.isEmpty ||
        !session.canCacheCards ||
        session.requestInFlight ||
        !_eventListPublicProfileSessionIsCurrent(session)) {
      return;
    }
    final paginationSession = _eventListPaginationSession;
    if (paginationSession != null &&
        paginationSession.key == session.key &&
        paginationSession.cacheOwnerToken == session.cacheOwnerToken) {
      _writeEventListBaseCardsCacheIfOwner(paginationSession);
    }
  }

  bool _writeEventListBaseCardsCacheIfOwner(
    _EventListPaginationSession paginationSession,
  ) {
    final cards = _eventListBaseCardsFromEvents(
      events: paginationSession.events,
      fallbackTimeZoneId: paginationSession.selected.city.timeZoneId,
      nowUtc: paginationSession.nowUtc,
      currentUserId: paginationSession.currentUserId,
      participantActionSourceRevision:
          paginationSession.participantActionSourceRevision,
    );
    if (cards.isEmpty && paginationSession.events.isNotEmpty) {
      return false;
    }
    return _eventListCardsCache.writeIfOwner(
      paginationSession.key,
      paginationSession.cacheOwnerToken,
      cards,
      fetchedAtUtc: paginationSession.baseFetchedAtUtc,
      events: paginationSession.events,
      nextPageMarker: paginationSession.nextPageMarker,
      hasRequestedNextPage: paginationSession.hasRequestedNextPage,
      noMoreItems: paginationSession.noMoreItems,
    );
  }

  void _markEventListPaginationCacheUnsafe(
    _EventListPaginationSession session,
  ) {
    if (!_eventListPaginationSessionIsCurrent(session)) {
      return;
    }
    session.canCacheCards = false;
  }

  List<EventListCardViewModel> _eventListCardsFromParticipantRecords({
    required List<EventsRecord> events,
    required String fallbackTimeZoneId,
    required DateTime nowUtc,
    required String currentUserId,
    required int participantActionSourceRevision,
    required Map<String, List<EventParticipantsRecord>>
        activeParticipantRecordsByEventId,
    _EventListMembershipLoad? membershipLoad,
  }) {
    return events
        .map(
          (event) => _eventListCardFromRecord(
            event,
            fallbackTimeZoneId: fallbackTimeZoneId,
            nowUtc: nowUtc,
            currentUserId: currentUserId,
            participantActionSourceRevision: participantActionSourceRevision,
            currentUserParticipant:
                membershipLoad?.recordsByEventId[event.reference.id],
            activeParticipants:
                activeParticipantRecordsByEventId[event.reference.id] ??
                    const <EventParticipantsRecord>[],
            membershipState: membershipLoad == null
                ? _eventListMembershipNeedsLookup(event, currentUserId)
                    ? EventListMembershipState.pending
                    : EventListMembershipState.resolved
                : membershipLoad.failedEventIds.contains(event.reference.id)
                    ? EventListMembershipState.lookupFailed
                    : EventListMembershipState.resolved,
          ),
        )
        .whereType<EventListCardViewModel>()
        .toList(growable: false);
  }

  Future<UserPublicProfilePreloadResult> _preloadEventListPublicProfiles(
    Set<String> userIds, {
    required String currentUserId,
  }) async {
    if (userIds.isEmpty || currentUserId.isEmpty) {
      return UserPublicProfilePreloadResult();
    }
    final injectedLoader = widget.publicProfilesLoader;
    if (injectedLoader == null && widget.eventPageLoader != null) {
      return UserPublicProfilePreloadResult();
    }

    final requestedUserIds = Set<String>.unmodifiable(userIds);
    UserPublicProfilePreloadResult loaded;
    try {
      loaded = await (injectedLoader ??
              _eventListPublicProfilePreloadRepository.preload)
          .call(requestedUserIds);
    } catch (_) {
      return UserPublicProfilePreloadResult(
        failedUserIds: requestedUserIds,
      );
    }

    final profilesByUserId = <String, UserPublicProfilesRecord>{};
    for (final entry in loaded.profilesByUserId.entries) {
      final userId = entry.key;
      if (requestedUserIds.contains(userId) &&
          isValidUserPublicProfileRecordForUserId(entry.value, userId)) {
        profilesByUserId[userId] = entry.value;
      }
    }
    final failedUserIds =
        loaded.failedUserIds.where(requestedUserIds.contains).toSet();
    final missingUserIds =
        loaded.missingUserIds.where(requestedUserIds.contains).toSet();
    for (final userId in requestedUserIds) {
      if (!profilesByUserId.containsKey(userId) &&
          !failedUserIds.contains(userId) &&
          !missingUserIds.contains(userId)) {
        missingUserIds.add(userId);
      }
    }
    return UserPublicProfilePreloadResult(
      profilesByUserId: profilesByUserId,
      missingUserIds: missingUserIds,
      failedUserIds: failedUserIds,
    );
  }

  Future<_EventListMembershipLoad> _loadCurrentUserParticipantRecordsByEventId({
    required _EventListLoadKey cacheKey,
    required List<EventsRecord> events,
    required String currentUserId,
  }) async {
    final userId = currentUserId;
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
        return _eventListCardsCache.reuseMembershipLookup(
          cacheKey,
          event.reference.id,
          () async {
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
          },
        );
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

  Future<_EventListActiveParticipantsLoad>
      _loadActiveParticipantRecordsByEventId({
    required _EventListLoadKey cacheKey,
    required List<EventsRecord> events,
  }) async {
    if (events.isEmpty) {
      return const _EventListActiveParticipantsLoad();
    }
    if (widget.activeParticipantsLoader == null &&
        widget.eventPageLoader != null) {
      return const _EventListActiveParticipantsLoad();
    }
    final loader = widget.activeParticipantsLoader ??
        _loadEventListActiveParticipantPreview;
    final entries = await Future.wait(
      events.map((event) async {
        return _eventListCardsCache.reuseActiveParticipantsLookup(
          cacheKey,
          event.reference.id,
          () async {
            try {
              final participants = await loader(event.reference);
              final activeParticipants = participants
                  .where((participant) =>
                      participant.status.trim() == eventStatusActive &&
                      participant.parentReference.path == event.reference.path)
                  .toList(growable: false);
              return _EventListActiveParticipantsLookupResult(
                eventId: event.reference.id,
                participants: activeParticipants,
              );
            } catch (_) {
              return _EventListActiveParticipantsLookupResult(
                eventId: event.reference.id,
                failed: true,
              );
            }
          },
        );
      }),
    );
    return _EventListActiveParticipantsLoad(
      recordsByEventId: Map<String, List<EventParticipantsRecord>>.fromEntries(
        entries.where((entry) => entry.participants.isNotEmpty).map(
              (entry) => MapEntry(entry.eventId, entry.participants),
            ),
      ),
      failedEventIds: Set<String>.unmodifiable(
        entries.where((entry) => entry.failed).map((entry) => entry.eventId),
      ),
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
    _saveEventListViewState();
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
    _saveEventListViewState();
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    unawaited(
      tracker.trackLevelFilterSelected(level).catchError(
            (Object error, StackTrace stackTrace) {},
          ),
    );
  }

  void _resetEventFilters() {
    if (_selectedDateFilter == null && _selectedLevel == null) {
      return;
    }
    final clearedLevelFilter = _selectedLevel != null;
    setState(() {
      _selectedDateFilter = null;
      _selectedLevel = null;
    });
    _saveEventListViewState();
    if (clearedLevelFilter) {
      final tracker =
          widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
      unawaited(
        tracker.trackLevelFilterSelected(null).catchError(
              (Object error, StackTrace stackTrace) {},
            ),
      );
    }
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

  List<EventListCardViewModel> _eventListCardsWithParticipantActionOverlays(
    List<EventListCardViewModel> cards, {
    required String currentUserId,
    required DateTime nowUtc,
  }) {
    if (cards.isEmpty) {
      return cards;
    }
    var changed = false;
    final resolvedCards = cards.map((card) {
      final timeResolvedCard = _eventListCardWithCurrentActionTime(
        card,
        nowUtc: nowUtc,
      );
      final overlay = currentUserId.isEmpty
          ? null
          : _eventListParticipantActionCoordinator.overlayFor(
              userId: currentUserId,
              eventId: timeResolvedCard.eventId.trim(),
            );
      if (overlay == null) {
        changed = changed || !identical(timeResolvedCard, card);
        return timeResolvedCard;
      }
      final resolved = _eventListCardWithParticipantActionOverlay(
        timeResolvedCard,
        overlay: overlay,
        currentUserId: currentUserId,
        nowUtc: nowUtc,
      );
      changed = changed || !identical(resolved, card);
      return resolved;
    }).toList(growable: false);
    return changed ? List.unmodifiable(resolvedCards) : cards;
  }

  Future<void> _handleEventListParticipantAction(
    EventListCardViewModel event, {
    required String expectedUserId,
  }) async {
    final eventId = event.eventId.trim();
    final userId = currentUserUid;
    if (eventId.isEmpty ||
        userId.isEmpty ||
        userId != expectedUserId ||
        event.membershipState != EventListMembershipState.resolved) {
      return;
    }

    final desiredJoined = switch (event.joinCtaState) {
      EventListJoinCtaState.join => true,
      EventListJoinCtaState.joined => false,
      EventListJoinCtaState.joining ||
      EventListJoinCtaState.leaving ||
      EventListJoinCtaState.joinedLocked ||
      EventListJoinCtaState.full ||
      EventListJoinCtaState.canceled ||
      EventListJoinCtaState.past =>
        null,
    };
    if (desiredJoined == null) {
      return;
    }
    if (desiredJoined &&
        widget.joinEventInvoker == null &&
        !isPaidPremiumSubscription(currentUserDocument)) {
      context.pushNamed(
        PayWidget.routeName,
        queryParameters: {
          'premiumOnly': serializeParam(true, ParamType.bool),
        }.withoutNulls,
      );
      return;
    }
    final nowUtc = _currentEventListNowUtc();
    if (!event.startsAt.isAfter(nowUtc)) {
      if (mounted) {
        setState(() {});
      }
      return;
    }
    final capacity = event.capacity;
    if (desiredJoined &&
        capacity != null &&
        capacity > 0 &&
        event.resolvedParticipantsCount >= capacity) {
      if (mounted) {
        setState(() {});
      }
      return;
    }

    final participant = desiredJoined
        ? _eventListCurrentUserParticipantViewModel(userId)
        : null;
    final optimisticParticipantsCount = desiredJoined
        ? math.max(2, event.resolvedParticipantsCount + 1)
        : math.max(1, event.resolvedParticipantsCount - 1);
    final request = _eventListParticipantActionCoordinator.begin(
      userId: userId,
      eventId: eventId,
      desiredJoined: desiredJoined,
      participantsCount: optimisticParticipantsCount,
      participant: participant,
    );
    if (request == null) {
      return;
    }
    _dismissEventListParticipantActionFailure();

    _invalidateEventListParticipantActionCache(
      userId: userId,
      eventId: eventId,
    );

    try {
      final result = desiredJoined
          ? await EventActionsRepository.joinEvent(
              eventId: eventId,
              invoker: widget.joinEventInvoker,
            )
          : await EventActionsRepository.leaveEvent(
              eventId: eventId,
              invoker: widget.leaveEventInvoker,
            );
      final minimumParticipantsCount = desiredJoined ? 2 : 1;
      final exceedsCapacity = desiredJoined &&
          capacity != null &&
          capacity > 0 &&
          result.participantsCount > capacity;
      if (result.eventId != eventId ||
          result.participantsCount < minimumParticipantsCount ||
          exceedsCapacity) {
        _eventListParticipantActionCoordinator.rollback(
          request,
          failure: const _EventListParticipantActionInvalidResult(),
        );
        return;
      }
      _eventListParticipantActionCoordinator.complete(
        request,
        participantsCount: result.participantsCount,
      );
    } catch (error) {
      _eventListParticipantActionCoordinator.rollback(
        request,
        failure: error,
      );
    } finally {
      _invalidateEventListParticipantActionCache(
        userId: userId,
        eventId: eventId,
      );
    }
  }

  void _invalidateEventListParticipantActionCache({
    required String userId,
    required String eventId,
  }) {
    _eventListCardsCache.invalidateEvent(
      eventId: eventId,
    );
    final activeKey = _eventListLoadKey;
    if (activeKey != null && activeKey.currentUserId == userId) {
      _eventListCardsCache.invalidate(activeKey);
    }
  }

  bool _canOpenEventCardChat(EventListCardViewModel event) {
    return event.chatCtaState == EventListChatCtaState.enabled &&
        event.eventId.trim().isNotEmpty;
  }

  void _openEventCardDetail(
    EventListCardViewModel event, {
    required EventSelectedCity? selectedCity,
  }) {
    final eventId = event.eventId.trim();
    if (eventId.isEmpty) {
      return;
    }
    final detailNavigation = context.pushNamed(
      EventDetailWidget.routeName,
      pathParameters: <String, String>{'eventId': eventId},
      extra: <String, dynamic>{
        eventDetailPublicPreviewExtraKey: EventDetailPublicPreview(
          eventId: eventId,
          title: event.title,
          description: eventDetailPublicPreviewDescription(event.description),
          languageCode: event.languageCode,
          languageNameEn: event.languageNameEn,
          languageNameRu: event.languageNameRu,
          levelMin: event.levelMin,
          levelMax: event.levelMax,
          startsAt: event.startsAt,
          timeZoneId: event.timeZoneId,
          organizerDisplayName: event.organizerDisplayName,
          organizerPhotoUrl: event.organizerPhotoUrl,
          publicLocationLabel:
              _eventListPublicLocationLabel(event, selectedCity),
          participantsCount: event.participantsCount,
          capacity: event.capacity,
          joinCtaState: _eventDetailJoinStateForListCard(event.joinCtaState),
        ),
      },
    );
    unawaited(
      detailNavigation.whenComplete(
        () => _invalidateEventCardsAfterDetailReturn(eventId),
      ),
    );
  }

  String _eventListPublicLocationLabel(
    EventListCardViewModel event,
    EventSelectedCity? selected,
  ) {
    final city = selected?.city;
    if (city == null ||
        city.countryCode != event.countryCode.trim().toUpperCase() ||
        city.cityKey != event.cityKey.trim()) {
      return '';
    }
    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    final cityName = isRu ? city.cityNameRu : city.cityNameEn;
    final displayContext = city.cityDisplayContext.trim();
    return displayContext.isEmpty ? cityName : '$cityName, $displayContext';
  }

  void _invalidateEventCardsAfterDetailReturn(String eventId) {
    if (!mounted) {
      return;
    }
    setState(() {
      _eventListCardsCache.invalidateEvent(eventId: eventId);
      _resetEventCardsLoadState(clearLastLoadedCards: false);
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

class _EventListVerticalViewportClipper extends CustomClipper<Rect> {
  const _EventListVerticalViewportClipper({
    required this.horizontalOverflow,
  });

  final double horizontalOverflow;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
        -horizontalOverflow,
        0,
        size.width + horizontalOverflow,
        size.height,
      );

  @override
  bool shouldReclip(_EventListVerticalViewportClipper oldClipper) =>
      oldClipper.horizontalOverflow != horizontalOverflow;
}

class _EventListParticipantActionErrorNotice extends StatelessWidget {
  const _EventListParticipantActionErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final snackBarTheme = theme.snackBarTheme;
    final contentStyle = snackBarTheme.contentTextStyle ??
        theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onInverseSurface,
        );

    return SizedBox(
      width: math.min(
        600,
        math.max(0, MediaQuery.widthOf(context) - ExpatlioDesign.space32),
      ),
      child: Semantics(
        container: true,
        liveRegion: true,
        child: Material(
          key: eventListParticipantActionErrorSnackBarKey,
          color:
              snackBarTheme.backgroundColor ?? theme.colorScheme.inverseSurface,
          elevation: snackBarTheme.elevation ?? 6,
          shape: snackBarTheme.shape ??
              const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: ExpatlioDesign.space16,
              vertical: ExpatlioDesign.space12,
            ),
            child: Text(
              message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: contentStyle,
            ),
          ),
        ),
      ),
    );
  }
}

class _EventListCards extends StatelessWidget {
  const _EventListCards({
    required this.eventCards,
    required this.selectedCity,
    required this.canOpenEventCardChat,
    required this.onPrimaryPressed,
    required this.openEventCardDetail,
    required this.openEventCardChat,
    required this.showParticipantRequiredSnackBar,
  });

  final List<EventListCardViewModel> eventCards;
  final EventSelectedCity? selectedCity;
  final bool Function(EventListCardViewModel event) canOpenEventCardChat;
  final ValueChanged<EventListCardViewModel>? onPrimaryPressed;
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
            onPrimaryPressed:
                eventCard.membershipState == EventListMembershipState.resolved
                    ? onPrimaryPressed == null
                        ? null
                        : () => onPrimaryPressed?.call(eventCard)
                    : eventCard.eventId.trim().isEmpty
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

class _EventListCardsSliver extends StatelessWidget {
  const _EventListCardsSliver({
    required this.eventCards,
    required this.selectedCity,
    required this.canOpenEventCardChat,
    required this.onPrimaryPressed,
    required this.openEventCardDetail,
    required this.openEventCardChat,
    required this.showParticipantRequiredSnackBar,
    this.paginationState = const _EventListPaginationViewState(),
  });

  final List<EventListCardViewModel> eventCards;
  final EventSelectedCity? selectedCity;
  final bool Function(EventListCardViewModel event) canOpenEventCardChat;
  final ValueChanged<EventListCardViewModel>? onPrimaryPressed;
  final ValueChanged<EventListCardViewModel> openEventCardDetail;
  final void Function({
    required EventListCardViewModel event,
    required EventSelectedCity? selectedCity,
  }) openEventCardChat;
  final VoidCallback showParticipantRequiredSnackBar;
  final _EventListPaginationViewState paginationState;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              if (index.isOdd) {
                return const SizedBox(height: ExpatlioDesign.space12);
              }
              final eventCard = eventCards[index ~/ 2];
              return RepaintBoundary(
                key: ValueKey<String>('event_list_lazy_${eventCard.eventId}'),
                child: _EventCardShell(
                  card: eventCard,
                  onPressed: eventCard.eventId.trim().isEmpty
                      ? null
                      : () => openEventCardDetail(eventCard),
                  onPrimaryPressed: eventCard.membershipState ==
                          EventListMembershipState.resolved
                      ? onPrimaryPressed == null
                          ? null
                          : () => onPrimaryPressed?.call(eventCard)
                      : eventCard.eventId.trim().isEmpty
                          ? null
                          : () => openEventCardDetail(eventCard),
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
              );
            },
            childCount: eventCards.isEmpty ? 0 : eventCards.length * 2 - 1,
            addRepaintBoundaries: false,
            semanticIndexCallback: (_, index) =>
                index.isEven ? index ~/ 2 : null,
            findChildIndexCallback: (key) {
              if (key is! ValueKey<String> ||
                  !key.value.startsWith('event_list_lazy_')) {
                return null;
              }
              final eventId = key.value.substring('event_list_lazy_'.length);
              final cardIndex = eventCards.indexWhere(
                (card) => card.eventId == eventId,
              );
              return cardIndex < 0 ? null : cardIndex * 2;
            },
          ),
        ),
        if (paginationState.isVisible) ...[
          const SliverToBoxAdapter(
            child: SizedBox(height: ExpatlioDesign.space12),
          ),
          SliverToBoxAdapter(
            child: _EventListPaginationFooter(state: paginationState),
          ),
        ],
      ],
    );
  }
}

class _EventListPaginationViewState {
  const _EventListPaginationViewState({
    this.error,
    this.onRetry,
  });

  final Object? error;
  final VoidCallback? onRetry;

  bool get isVisible => error != null;
}

class _EventListPaginationFooter extends StatelessWidget {
  const _EventListPaginationFooter({required this.state});

  final _EventListPaginationViewState state;

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось загрузить ещё события',
      enText: 'Could not load more events',
    );
    final message = FFLocalizations.of(context).getVariableText(
      ruText: 'Проверьте подключение и попробуйте снова.',
      enText: 'Check your connection and try again.',
    );
    final retryLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Повторить',
      enText: 'Retry',
    );
    return UxErrorState(
      stateKey: eventListPaginationErrorKey,
      title: title,
      message: message,
      semanticsLabel: '$title. $message',
      retryLabel: retryLabel,
      retrySemanticsLabel: title,
      retryButtonKey: eventListPaginationRetryButtonKey,
      onRetry: state.onRetry,
      contained: true,
      borderColor: _eventListBorderColor,
      maxWidth: double.infinity,
      showIcon: false,
      padding: const EdgeInsetsDirectional.all(ExpatlioDesign.space12),
      titleSize: 16.0,
      messageSize: 14.0,
      retryMinHeight: 44.0,
    );
  }
}

class _EventListPreviousCardsState extends StatelessWidget {
  const _EventListPreviousCardsState({
    required this.cards,
    required this.selectedCity,
    required this.emptyState,
    required this.canOpenEventCardChat,
    required this.onPrimaryPressed,
    required this.openEventCardDetail,
    required this.openEventCardChat,
    required this.showParticipantRequiredSnackBar,
    this.errorMessage,
    this.onRetryPressed,
    this.showEmptyState = true,
  });

  final List<EventListCardViewModel> cards;
  final EventSelectedCity? selectedCity;
  final Widget emptyState;
  final String? errorMessage;
  final VoidCallback? onRetryPressed;
  final bool showEmptyState;
  final bool Function(EventListCardViewModel event) canOpenEventCardChat;
  final ValueChanged<EventListCardViewModel>? onPrimaryPressed;
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
            emptyState
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
            onPrimaryPressed: onPrimaryPressed,
            openEventCardDetail: openEventCardDetail,
            openEventCardChat: openEventCardChat,
            showParticipantRequiredSnackBar: showParticipantRequiredSnackBar,
          ),
      ],
    );

    return content;
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

class _EventListParticipantActionKey {
  const _EventListParticipantActionKey({
    required this.userId,
    required this.eventId,
  });

  final String userId;
  final String eventId;

  @override
  bool operator ==(Object other) {
    return other is _EventListParticipantActionKey &&
        other.userId == userId &&
        other.eventId == eventId;
  }

  @override
  int get hashCode => Object.hash(userId, eventId);
}

class _EventListParticipantActionOverlay {
  const _EventListParticipantActionOverlay({
    required this.desiredJoined,
    required this.participantsCount,
    required this.participant,
    required this.pending,
    required this.generation,
    required this.confirmedRevision,
  });

  final bool desiredJoined;
  final int participantsCount;
  final EventListParticipantViewModel? participant;
  final bool pending;
  final int generation;
  final int confirmedRevision;
}

class _EventListParticipantActionRequest {
  const _EventListParticipantActionRequest({
    required this.key,
    required this.generation,
    required this.previousOverlay,
  });

  final _EventListParticipantActionKey key;
  final int generation;
  final _EventListParticipantActionOverlay? previousOverlay;
}

class _EventListParticipantActionFailure {
  const _EventListParticipantActionFailure({
    required this.userId,
    required this.eventId,
    required this.error,
  });

  final String userId;
  final String eventId;
  final Object error;
}

class _EventListParticipantActionInvalidResult implements Exception {
  const _EventListParticipantActionInvalidResult();
}

class _EventListParticipantActionCoordinator extends ChangeNotifier {
  static const int _maxRetainedOverlays = 64;

  final LinkedHashMap<_EventListParticipantActionKey,
          _EventListParticipantActionOverlay> _overlays =
      LinkedHashMap<_EventListParticipantActionKey,
          _EventListParticipantActionOverlay>();
  final Expando<int> _overrideSourceRevisions =
      Expando<int>('eventListParticipantActionSourceRevision');
  _EventListParticipantActionFailure? _failure;
  int _generation = 0;
  int _confirmedRevision = 0;

  int get currentConfirmedRevision => _confirmedRevision;

  int sourceRevisionForOverride(List<EventListCardViewModel>? cards) {
    if (cards == null) {
      return currentConfirmedRevision;
    }
    final existingRevision = _overrideSourceRevisions[cards];
    if (existingRevision != null) {
      return existingRevision;
    }
    final revision = currentConfirmedRevision;
    _overrideSourceRevisions[cards] = revision;
    return revision;
  }

  _EventListParticipantActionOverlay? overlayFor({
    required String userId,
    required String eventId,
  }) {
    return _overlays[
        _EventListParticipantActionKey(userId: userId, eventId: eventId)];
  }

  _EventListParticipantActionFailure? takeFailureForUser(String userId) {
    final failure = _failure;
    if (failure == null || failure.userId != userId) {
      return null;
    }
    _failure = null;
    return failure;
  }

  _EventListParticipantActionRequest? begin({
    required String userId,
    required String eventId,
    required bool desiredJoined,
    required int participantsCount,
    required EventListParticipantViewModel? participant,
  }) {
    final key = _EventListParticipantActionKey(
      userId: userId,
      eventId: eventId,
    );
    final previousOverlay = _overlays[key];
    if (previousOverlay?.pending == true) {
      return null;
    }
    if (previousOverlay == null && !_makeRoomForNewOverlay()) {
      return null;
    }
    final generation = ++_generation;
    _overlays.remove(key);
    _overlays[key] = _EventListParticipantActionOverlay(
      desiredJoined: desiredJoined,
      participantsCount: math.max(0, participantsCount),
      participant: participant,
      pending: true,
      generation: generation,
      confirmedRevision: 0,
    );
    _trimRetainedOverlays();
    notifyListeners();
    return _EventListParticipantActionRequest(
      key: key,
      generation: generation,
      previousOverlay: previousOverlay,
    );
  }

  void complete(
    _EventListParticipantActionRequest request, {
    required int participantsCount,
  }) {
    final current = _overlays[request.key];
    if (current == null || current.generation != request.generation) {
      return;
    }
    _overlays.remove(request.key);
    final confirmedRevision = ++_confirmedRevision;
    _overlays[request.key] = _EventListParticipantActionOverlay(
      desiredJoined: current.desiredJoined,
      participantsCount: math.max(0, participantsCount),
      participant: current.participant,
      pending: false,
      generation: current.generation,
      confirmedRevision: confirmedRevision,
    );
    _trimRetainedOverlays();
    notifyListeners();
  }

  bool rollback(
    _EventListParticipantActionRequest request, {
    Object? failure,
  }) {
    final current = _overlays[request.key];
    if (current == null || current.generation != request.generation) {
      return false;
    }
    final previousOverlay = request.previousOverlay;
    if (previousOverlay == null) {
      _overlays.remove(request.key);
    } else {
      _overlays.remove(request.key);
      _overlays[request.key] = previousOverlay;
    }
    _trimRetainedOverlays();
    if (failure == null) {
      notifyListeners();
    } else {
      _failure = _EventListParticipantActionFailure(
        userId: request.key.userId,
        eventId: request.key.eventId,
        error: failure,
      );
      try {
        notifyListeners();
      } finally {
        _failure = null;
      }
    }
    return true;
  }

  void _trimRetainedOverlays() {
    while (_overlays.length > _maxRetainedOverlays) {
      _EventListParticipantActionKey? removableKey;
      for (final entry in _overlays.entries) {
        if (!entry.value.pending) {
          removableKey = entry.key;
          break;
        }
      }
      if (removableKey == null) {
        return;
      }
      _overlays.remove(removableKey);
    }
  }

  bool _makeRoomForNewOverlay() {
    if (_overlays.length < _maxRetainedOverlays) {
      return true;
    }
    _EventListParticipantActionKey? removableKey;
    for (final entry in _overlays.entries) {
      if (!entry.value.pending) {
        removableKey = entry.key;
        break;
      }
    }
    if (removableKey == null) {
      return false;
    }
    _overlays.remove(removableKey);
    return true;
  }

  void clear() {
    final hadState = _overlays.isNotEmpty || _failure != null;
    if (!hadState) {
      return;
    }
    _overlays.clear();
    _failure = null;
    notifyListeners();
  }
}

class _EventListBaseCardsLoad {
  const _EventListBaseCardsLoad({
    required this.events,
    required this.cards,
    required this.nextPageMarker,
    required this.hasMore,
  });

  final List<EventsRecord> events;
  final List<EventListCardViewModel> cards;
  final DocumentSnapshot? nextPageMarker;
  final bool hasMore;
}

class _EventListPendingBaseLoad {
  const _EventListPendingBaseLoad({
    required this.lowerBoundUtc,
    required this.future,
  });

  final DateTime lowerBoundUtc;
  final Future<_EventListBaseCardsLoad> future;
}

class _EventListPaginationSession {
  _EventListPaginationSession({
    required this.key,
    required this.loadGeneration,
    required this.cacheOwnerToken,
    required this.selected,
    required this.localDateRange,
    required this.nowUtc,
    required this.baseFetchedAtUtc,
    required this.selectedLevel,
    required this.currentUserId,
    required this.participantActionSourceRevision,
    required List<EventsRecord> events,
    required this.nextPageMarker,
    this.hasRequestedNextPage = false,
    this.noMoreItems = false,
  }) : events = List<EventsRecord>.unmodifiable(events);

  final _EventListLoadKey key;
  final int loadGeneration;
  final int cacheOwnerToken;
  final EventSelectedCity selected;
  final EventListLocalDateRange? localDateRange;
  final DateTime nowUtc;
  final DateTime baseFetchedAtUtc;
  final String? selectedLevel;
  final String currentUserId;
  final int participantActionSourceRevision;
  List<EventsRecord> events;
  DocumentSnapshot? nextPageMarker;
  bool hasRequestedNextPage;
  bool noMoreItems;
  bool requestInFlight = false;
  Object? error;
  bool canCacheCards = true;
  final Set<String> pendingEnrichmentEventIds = <String>{};
}

class _EventListMembershipLoad {
  const _EventListMembershipLoad({
    this.recordsByEventId = const <String, EventParticipantsRecord>{},
    this.failedEventIds = const <String>{},
  });

  final Map<String, EventParticipantsRecord> recordsByEventId;
  final Set<String> failedEventIds;
}

class _EventListActiveParticipantsLoad {
  const _EventListActiveParticipantsLoad({
    this.recordsByEventId = const <String, List<EventParticipantsRecord>>{},
    this.failedEventIds = const <String>{},
  });

  final Map<String, List<EventParticipantsRecord>> recordsByEventId;
  final Set<String> failedEventIds;
}

class _EventListPublicProfileSession {
  _EventListPublicProfileSession({
    required this.key,
    required this.loadGeneration,
    required this.currentUserId,
    required this.nowUtc,
    required List<EventListCardViewModel> cards,
    required this.targetCardCount,
    required this.completedCardCount,
    required this.scrollStartPixels,
    required this.canCacheCards,
    required Set<String> requestedUserIds,
    required this.cacheOwnerToken,
    this.requestInFlight = false,
  })  : cards = List<EventListCardViewModel>.unmodifiable(cards),
        requestedUserIds = <String>{...requestedUserIds};

  final _EventListLoadKey key;
  final int loadGeneration;
  final String currentUserId;
  final DateTime nowUtc;
  List<EventListCardViewModel> cards;
  final Set<String> requestedUserIds;
  final int cacheOwnerToken;
  int targetCardCount;
  int completedCardCount;
  final double scrollStartPixels;
  bool canCacheCards;
  bool requestInFlight;
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

class _EventListActiveParticipantsLookupResult {
  const _EventListActiveParticipantsLookupResult({
    required this.eventId,
    this.participants = const <EventParticipantsRecord>[],
    this.failed = false,
  });

  final String eventId;
  final List<EventParticipantsRecord> participants;
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
    required this.publicProfilesLoaderIdentity,
  });

  final String countryCode;
  final String cityKey;
  final String timeZoneId;
  final EventListDateFilter? dateFilter;
  final DateTime? localStartDate;
  final DateTime? localExclusiveEndDate;
  final String? selectedLevel;
  final Object? pageLoaderIdentity;
  final String currentUserId;
  final Object? participantLoaderIdentity;
  final Object? activeParticipantsLoaderIdentity;
  final Object? publicProfilesLoaderIdentity;

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
        identical(other.pageLoaderIdentity, pageLoaderIdentity) &&
        other.currentUserId == currentUserId &&
        identical(
          other.participantLoaderIdentity,
          participantLoaderIdentity,
        ) &&
        identical(
          other.activeParticipantsLoaderIdentity,
          activeParticipantsLoaderIdentity,
        ) &&
        identical(
          other.publicProfilesLoaderIdentity,
          publicProfilesLoaderIdentity,
        );
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
        publicProfilesLoaderIdentity,
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

class _EventListEnrichmentEventKey {
  const _EventListEnrichmentEventKey(this.loadKey, this.eventId);

  final _EventListLoadKey loadKey;
  final String eventId;

  @override
  bool operator ==(Object other) =>
      other is _EventListEnrichmentEventKey &&
      other.loadKey == loadKey &&
      other.eventId == eventId;

  @override
  int get hashCode => Object.hash(loadKey, eventId);
}

class _EventListViewState {
  const _EventListViewState({
    required this.dateFilter,
    required this.selectedLevel,
    required this.scrollOffset,
  });

  final EventListDateFilter? dateFilter;
  final String? selectedLevel;
  final double scrollOffset;
}

class _EventListViewStateStore {
  static const int _maxUsers = 4;

  final _states = LinkedHashMap<String, _EventListViewState>();

  _EventListViewState? read(String userId) {
    if (userId.isEmpty) {
      return null;
    }
    final state = _states.remove(userId);
    if (state != null) {
      _states[userId] = state;
    }
    return state;
  }

  void write(String userId, _EventListViewState state) {
    if (userId.isEmpty) {
      return;
    }
    _states.remove(userId);
    _states[userId] = state;
    while (_states.length > _maxUsers) {
      _states.remove(_states.keys.first);
    }
  }

  void clear() => _states.clear();
}

class _EventListCardsMemoryCache {
  _EventListCardsMemoryCache({
    required this.maxEntries,
    required this.freshness,
    required this.retention,
  });

  final int maxEntries;
  final Duration freshness;
  final Duration retention;
  final _entries =
      LinkedHashMap<_EventListLoadKey, _EventListCardsCacheEntry>();
  final _baseLoads = <_EventListLoadKey, _EventListPendingBaseLoad>{};
  final _membershipLoads = <_EventListEnrichmentEventKey,
      Future<_EventListMembershipLookupResult>>{};
  final _activeParticipantLoads = <_EventListEnrichmentEventKey,
      Future<_EventListActiveParticipantsLookupResult>>{};
  final _ownerTokens = LinkedHashMap<_EventListLoadKey, int>();
  final _ownerMutationEpochs = LinkedHashMap<_EventListLoadKey, int>();
  final _eventIdsByOwner = LinkedHashMap<_EventListLoadKey, Set<String>>();
  int _nextOwnerToken = 0;
  int _mutationEpoch = 0;

  int claim(_EventListLoadKey key) {
    final ownerToken = ++_nextOwnerToken;
    _ownerTokens.remove(key);
    _ownerTokens[key] = ownerToken;
    _ownerMutationEpochs.remove(key);
    _ownerMutationEpochs[key] = _mutationEpoch;
    _eventIdsByOwner.remove(key);
    while (_ownerTokens.length > maxEntries * 2) {
      final staleKey = _ownerTokens.keys.first;
      _ownerTokens.remove(staleKey);
      _ownerMutationEpochs.remove(staleKey);
      _eventIdsByOwner.remove(staleKey);
    }
    return ownerToken;
  }

  bool registerEventsIfOwner(
    _EventListLoadKey key,
    int ownerToken,
    Iterable<String> eventIds,
  ) {
    if (!_isCurrentOwner(key, ownerToken)) {
      return false;
    }
    _eventIdsByOwner.remove(key);
    _eventIdsByOwner[key] = Set<String>.unmodifiable(
      eventIds
          .map((eventId) => eventId.trim())
          .where((eventId) => eventId.isNotEmpty),
    );
    return true;
  }

  _EventListCardsCacheEntry? read(
    _EventListLoadKey key, {
    required DateTime nowUtc,
  }) {
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }
    if (!entry.isFresh(nowUtc: nowUtc, ttl: retention)) {
      return null;
    }
    _entries[key] = entry;
    return entry;
  }

  bool isFresh(
    _EventListCardsCacheEntry entry, {
    required DateTime nowUtc,
  }) =>
      entry.isFresh(nowUtc: nowUtc, ttl: freshness);

  Future<_EventListBaseCardsLoad> reuseBaseLoad(
    _EventListLoadKey key,
    Future<_EventListBaseCardsLoad> Function() loader, {
    required DateTime lowerBoundUtc,
  }) {
    final existing = _baseLoads[key];
    if (existing != null && !lowerBoundUtc.isBefore(existing.lowerBoundUtc)) {
      return existing.future;
    }
    final future = loader();
    final pendingLoad = _EventListPendingBaseLoad(
      lowerBoundUtc: lowerBoundUtc,
      future: future,
    );
    _baseLoads[key] = pendingLoad;
    unawaited(
      future.then<void>(
        (_) => _removeBaseLoadIfCurrent(key, pendingLoad),
        onError: (Object _, StackTrace __) =>
            _removeBaseLoadIfCurrent(key, pendingLoad),
      ),
    );
    return future;
  }

  Future<_EventListMembershipLookupResult> reuseMembershipLookup(
    _EventListLoadKey key,
    String eventId,
    Future<_EventListMembershipLookupResult> Function() loader,
  ) =>
      _reuseEnrichmentLoad(
        _membershipLoads,
        _EventListEnrichmentEventKey(key, eventId),
        loader,
      );

  Future<_EventListActiveParticipantsLookupResult>
      reuseActiveParticipantsLookup(
    _EventListLoadKey key,
    String eventId,
    Future<_EventListActiveParticipantsLookupResult> Function() loader,
  ) =>
          _reuseEnrichmentLoad(
            _activeParticipantLoads,
            _EventListEnrichmentEventKey(key, eventId),
            loader,
          );

  Future<T> _reuseEnrichmentLoad<T>(
    Map<_EventListEnrichmentEventKey, Future<T>> loads,
    _EventListEnrichmentEventKey eventKey,
    Future<T> Function() loader,
  ) {
    final existing = loads[eventKey];
    if (existing != null) {
      return existing;
    }
    final future = loader();
    loads[eventKey] = future;
    unawaited(
      future.then<void>(
        (_) => _removeEnrichmentLoadIfCurrent(loads, eventKey, future),
        onError: (Object _, StackTrace __) =>
            _removeEnrichmentLoadIfCurrent(loads, eventKey, future),
      ),
    );
    return future;
  }

  void _removeEnrichmentLoadIfCurrent<T>(
    Map<_EventListEnrichmentEventKey, Future<T>> loads,
    _EventListEnrichmentEventKey eventKey,
    Future<T> future,
  ) {
    if (identical(loads[eventKey], future)) {
      loads.remove(eventKey);
    }
  }

  void _removeBaseLoadIfCurrent(
    _EventListLoadKey key,
    _EventListPendingBaseLoad pendingLoad,
  ) {
    if (identical(_baseLoads[key], pendingLoad)) {
      _baseLoads.remove(key);
    }
  }

  bool writeIfOwner(
    _EventListLoadKey key,
    int ownerToken,
    List<EventListCardViewModel> cards, {
    required DateTime fetchedAtUtc,
    required List<EventsRecord> events,
    required DocumentSnapshot? nextPageMarker,
    required bool hasRequestedNextPage,
    required bool noMoreItems,
  }) {
    if (!_isCurrentOwner(key, ownerToken)) {
      return false;
    }
    if (!registerEventsIfOwner(
      key,
      ownerToken,
      cards.map((card) => card.eventId),
    )) {
      return false;
    }
    _entries.remove(key);
    _entries[key] = _EventListCardsCacheEntry(
      cards: List.unmodifiable(cards),
      fetchedAtUtc: fetchedAtUtc,
      events: List<EventsRecord>.unmodifiable(events),
      nextPageMarker: nextPageMarker,
      hasRequestedNextPage: hasRequestedNextPage,
      noMoreItems: noMoreItems,
    );
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
    return true;
  }

  bool updatePaginationIfOwner(
    _EventListLoadKey key,
    int ownerToken, {
    required List<EventsRecord> events,
    required DocumentSnapshot? nextPageMarker,
    required bool hasRequestedNextPage,
    required bool noMoreItems,
  }) {
    if (!_isCurrentOwner(key, ownerToken)) {
      return false;
    }
    final entry = _entries.remove(key);
    if (entry == null) {
      return false;
    }
    _entries[key] = _EventListCardsCacheEntry(
      cards: entry.cards,
      fetchedAtUtc: entry.fetchedAtUtc,
      events: List<EventsRecord>.unmodifiable(events),
      nextPageMarker: nextPageMarker,
      hasRequestedNextPage: hasRequestedNextPage,
      noMoreItems: noMoreItems,
    );
    return true;
  }

  void seedCreatedEvent(EventListCreatedEventSeed seed) {
    final startsAtUtc =
        seed.startsAt.isUtc ? seed.startsAt : seed.startsAt.toUtc();
    final eventRange = tryEventLevelRange(
      levelMin: seed.levelMin,
      levelMax: seed.levelMax,
    );
    if (eventRange == null) {
      return;
    }
    final seededEvent = EventsRecord.getDocumentFromData(
      createEventsRecordData(
        title: seed.title,
        description: seed.description,
        languageCode: seed.languageCode,
        languageNameEn: seed.languageNameEn,
        languageNameRu: seed.languageNameRu,
        levelMin: seed.levelMin,
        levelMax: seed.levelMax,
        countryCode: seed.countryCode,
        cityKey: seed.cityKey,
        startsAt: startsAtUtc,
        timeZoneId: seed.timeZoneId,
        capacity: seed.capacity,
        participantsCount: 1,
        organizerId: seed.ownerUserId,
        organizerDisplayName: seed.organizerDisplayName,
        organizerPhotoUrl: seed.organizerPhotoUrl,
        status: eventStatusActive,
      ),
      EventsRecord.collection.doc(seed.eventId),
    );

    for (final cacheEntry
        in List<MapEntry<_EventListLoadKey, _EventListCardsCacheEntry>>.of(
            _entries.entries)) {
      final key = cacheEntry.key;
      final entry = cacheEntry.value;
      if (key.currentUserId != seed.ownerUserId ||
          key.countryCode != seed.countryCode.trim().toUpperCase() ||
          key.cityKey != seed.cityKey.trim() ||
          !startsAtUtc.isAfter(entry.fetchedAtUtc)) {
        continue;
      }
      final selectedRange = selectedEventLevelRange(key.selectedLevel);
      if (selectedRange != null && !eventRange.overlaps(selectedRange)) {
        continue;
      }
      final localStartDate = key.localStartDate;
      final localExclusiveEndDate = key.localExclusiveEndDate;
      if (localStartDate != null && localExclusiveEndDate != null) {
        final local = timezone.TZDateTime.from(
          startsAtUtc,
          eventListTimeZoneLocation(key.timeZoneId),
        );
        final eventLocalDate = DateTime(local.year, local.month, local.day);
        if (eventLocalDate.isBefore(localStartDate) ||
            !eventLocalDate.isBefore(localExclusiveEndDate)) {
          continue;
        }
      }

      final seededCard = EventListCardViewModel(
        eventId: seed.eventId,
        countryCode: seed.countryCode,
        cityKey: seed.cityKey,
        organizerDisplayName: seed.organizerDisplayName,
        organizerPhotoUrl: seed.organizerPhotoUrl,
        participants: <EventListParticipantViewModel>[
          EventListParticipantViewModel(
            userId: seed.ownerUserId,
            displayName: seed.organizerDisplayName,
            photoUrl: seed.organizerPhotoUrl,
          ),
        ],
        participantsCount: 1,
        capacity: seed.capacity,
        joinCtaState: EventListJoinCtaState.joined,
        chatCtaState: EventListChatCtaState.enabled,
        membershipState: EventListMembershipState.resolved,
        reserveParticipantPreviewSpace: true,
        languageCode: seed.languageCode,
        languageNameEn: seed.languageNameEn,
        languageNameRu: seed.languageNameRu,
        title: seed.title,
        description: seed.description,
        levelMin: seed.levelMin,
        levelMax: seed.levelMax,
        startsAt: startsAtUtc,
        timeZoneId: seed.timeZoneId,
        locationName: '',
      );
      final cards = <EventListCardViewModel>[
        seededCard,
        ...entry.cards.where((card) => card.eventId != seed.eventId),
      ]..sort((left, right) {
          final byStart = left.startsAt.compareTo(right.startsAt);
          return byStart != 0 ? byStart : left.eventId.compareTo(right.eventId);
        });
      final events = <EventsRecord>[
        seededEvent,
        ...entry.events.where(
          (event) => event.reference.id != seed.eventId,
        ),
      ]..sort((left, right) {
          final leftStartsAt =
              left.startsAt ?? _eventListAllEventsUpperBoundUtc;
          final rightStartsAt =
              right.startsAt ?? _eventListAllEventsUpperBoundUtc;
          final byStart = leftStartsAt.compareTo(rightStartsAt);
          return byStart != 0
              ? byStart
              : left.reference.id.compareTo(right.reference.id);
        });
      final knownEventIds = <String>{
        ...entry.cards.map((card) => card.eventId),
        seed.eventId,
      };
      final seedOwnerToken = claim(key);
      _entries.remove(key);
      _entries[key] = _EventListCardsCacheEntry(
        cards: List<EventListCardViewModel>.unmodifiable(cards),
        fetchedAtUtc: entry.fetchedAtUtc,
        events: List<EventsRecord>.unmodifiable(events),
        nextPageMarker: entry.nextPageMarker,
        hasRequestedNextPage: entry.hasRequestedNextPage,
        noMoreItems: entry.noMoreItems,
      );
      registerEventsIfOwner(key, seedOwnerToken, knownEventIds);
    }
  }

  void invalidate(_EventListLoadKey key) {
    _entries.remove(key);
    _baseLoads.remove(key);
    _membershipLoads.removeWhere((eventKey, _) => eventKey.loadKey == key);
    _activeParticipantLoads.removeWhere(
      (eventKey, _) => eventKey.loadKey == key,
    );
    claim(key);
  }

  void invalidateEvent({
    required String eventId,
  }) {
    _mutationEpoch += 1;
    final matchingKeys = <_EventListLoadKey>{
      ..._entries.entries
          .where(
            (entry) => entry.value.cards.any(
              (card) => card.eventId.trim() == eventId,
            ),
          )
          .map((entry) => entry.key),
      ..._eventIdsByOwner.entries
          .where(
            (entry) => entry.value.contains(eventId),
          )
          .map((entry) => entry.key),
    };
    for (final key in matchingKeys) {
      invalidate(key);
    }
  }

  bool _isCurrentOwner(_EventListLoadKey key, int ownerToken) {
    return _ownerTokens[key] == ownerToken &&
        _ownerMutationEpochs[key] == _mutationEpoch;
  }

  void clear() {
    _entries.clear();
    _baseLoads.clear();
    _membershipLoads.clear();
    _activeParticipantLoads.clear();
    _ownerTokens.clear();
    _ownerMutationEpochs.clear();
    _eventIdsByOwner.clear();
  }
}

class _EventListCardsCacheEntry {
  const _EventListCardsCacheEntry({
    required this.cards,
    required this.fetchedAtUtc,
    required this.events,
    required this.nextPageMarker,
    required this.hasRequestedNextPage,
    required this.noMoreItems,
  });

  final List<EventListCardViewModel> cards;
  final DateTime fetchedAtUtc;
  final List<EventsRecord> events;
  final DocumentSnapshot? nextPageMarker;
  final bool hasRequestedNextPage;
  final bool noMoreItems;

  bool isFresh({
    required DateTime nowUtc,
    required Duration ttl,
  }) {
    final age = nowUtc.difference(fetchedAtUtc);
    return !age.isNegative && age < ttl;
  }
}

DateTime _eventListNowUtc() => DateTime.now().toUtc();

Future<EventParticipantsRecord?> _loadEventListParticipant(
  DocumentReference eventRef,
  String userId,
) async {
  if (userId.isEmpty) {
    return null;
  }
  final snapshot =
      await EventParticipantsRecord.createDoc(eventRef, id: userId).get();
  if (!snapshot.exists) {
    return null;
  }
  return EventParticipantsRecord.fromSnapshot(snapshot);
}

Future<List<EventParticipantsRecord>> _loadEventListActiveParticipantPreview(
  DocumentReference eventRef,
) {
  return EventDetailRepository.loadActiveParticipants(
    eventRef: eventRef,
    limit: _eventListParticipantPreviewLimit,
  );
}

EventListCardViewModel? _eventListCardFromRecord(
  EventsRecord event, {
  required String fallbackTimeZoneId,
  required DateTime nowUtc,
  required String currentUserId,
  required int participantActionSourceRevision,
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
  final viewerUserId = currentUserId;
  final isOrganizer =
      viewerUserId.isNotEmpty && event.organizerId == viewerUserId;
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
      canLeave: isActiveParticipant && !isOrganizer && startsAt.isAfter(nowUtc),
      participantsCount: participantsCount,
      capacity: capacity,
    ),
    chatCtaState: isJoined
        ? EventListChatCtaState.enabled
        : EventListChatCtaState.participantOnly,
    membershipState: membershipState,
    reserveParticipantPreviewSpace: true,
    participantActionSourceRevision: participantActionSourceRevision,
  );
}

bool _eventListMembershipNeedsLookup(
  EventsRecord event,
  String currentUserId,
) {
  return currentUserId.isNotEmpty && event.organizerId != currentUserId;
}

bool _eventListParticipantIsActiveForUser(
  EventParticipantsRecord? participant, {
  required DocumentReference eventReference,
  required String userId,
}) {
  if (participant == null || userId.isEmpty) {
    return false;
  }
  final belongsToUser =
      _eventListParticipantHasCanonicalIdentity(participant) &&
          participant.reference.id == userId;
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
  final viewerUserId = currentUserId;
  EventListParticipantViewModel participantViewModel(
    EventParticipantsRecord participant,
  ) {
    final participantUserId = _eventListParticipantUserId(participant);
    final isOrganizer =
        event.organizerId.isNotEmpty && participantUserId == event.organizerId;
    final isCurrentUser =
        viewerUserId.isNotEmpty && participantUserId == viewerUserId;
    final displayName = _eventListUsableParticipantDisplayName(
      participant.displayName,
    );
    final currentDisplayName = isCurrentUser
        ? _eventListUsableParticipantDisplayName(currentUserDisplayName)
        : '';
    final resolvedDisplayName = displayName.isNotEmpty
        ? displayName
        : currentDisplayName.isNotEmpty
            ? currentDisplayName
            : isOrganizer
                ? _eventListUsableParticipantDisplayName(
                    event.organizerDisplayName,
                  )
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

  final displayName =
      _eventListUsableParticipantDisplayName(event.organizerDisplayName);
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
        userId: event.organizerId,
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
        (participant) => participant.userId == viewerUserId,
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

Set<String> _eventListVisibleParticipantUserIds(
  Iterable<EventListCardViewModel> cards, {
  int participantLimit = _eventListParticipantPreviewLimit,
}) {
  final userIds = LinkedHashSet<String>();
  for (final card in cards) {
    for (final participant in card.participants.take(participantLimit)) {
      final userId = participant.userId;
      if (isValidUserPublicProfileUserId(userId)) {
        userIds.add(userId);
      }
    }
  }
  return Set<String>.unmodifiable(userIds);
}

UserPublicProfilePreloadResult _mergeEventListPublicProfileLoads(
  Iterable<UserPublicProfilePreloadResult> loads,
) {
  final profilesByUserId = <String, UserPublicProfilesRecord>{};
  final missingUserIds = <String>{};
  final failedUserIds = <String>{};
  for (final load in loads) {
    profilesByUserId.addAll(load.profilesByUserId);
    missingUserIds.addAll(load.missingUserIds);
    failedUserIds.addAll(load.failedUserIds);
  }
  missingUserIds.removeAll(profilesByUserId.keys);
  failedUserIds.removeAll(profilesByUserId.keys);
  return UserPublicProfilePreloadResult(
    profilesByUserId: profilesByUserId,
    missingUserIds: missingUserIds,
    failedUserIds: failedUserIds,
  );
}

List<EventListCardViewModel> _eventListCardsWithPublicProfiles(
  Iterable<EventListCardViewModel> cards,
  Map<String, UserPublicProfilesRecord> profilesByUserId,
) {
  return cards.map((card) {
    final participants = card.participants.map((participant) {
      final userId = participant.userId;
      final profile = profilesByUserId[userId];
      if (profile == null ||
          !isValidUserPublicProfileRecordForUserId(profile, userId)) {
        return participant;
      }
      final publicDisplayName =
          _eventListUsableParticipantDisplayName(profile.displayName);
      final displayName = publicDisplayName.isEmpty
          ? participant.displayName
          : publicDisplayName;
      final publicPhotoUrl = profile.photoUrl.trim();
      final photoUrl = publicPhotoUrl.isEmpty ? null : publicPhotoUrl;
      return EventListParticipantViewModel(
        userId: participant.userId,
        displayName: displayName,
        photoUrl: photoUrl,
      );
    }).toList(growable: false);
    return card.copyWithParticipants(participants);
  }).toList(growable: false);
}

void _eventListKeepParticipantVisible(
  List<EventListParticipantViewModel> participants, {
  required String userId,
  required int visibleLimit,
}) {
  if (userId.isEmpty ||
      visibleLimit <= 0 ||
      participants.length <= visibleLimit) {
    return;
  }
  final index = participants.indexWhere(
    (participant) => participant.userId == userId,
  );
  if (index < visibleLimit || index < 0) {
    return;
  }
  final participant = participants.removeAt(index);
  participants.insert(visibleLimit - 1, participant);
}

void _eventListTrimParticipantPreviewToCount(
  List<EventListParticipantViewModel> participants, {
  required int participantsCount,
  required String? preservedUserId,
}) {
  final maxKnownParticipants = math.max(0, participantsCount);
  final canPreserveUser = maxKnownParticipants > 0 &&
      preservedUserId != null &&
      preservedUserId.isNotEmpty;
  while (participants.length > maxKnownParticipants) {
    var removeIndex = participants.length - 1;
    if (canPreserveUser) {
      for (var index = participants.length - 1; index >= 0; index -= 1) {
        if (participants[index].userId != preservedUserId) {
          removeIndex = index;
          break;
        }
      }
    }
    participants.removeAt(removeIndex);
  }
}

String _eventListParticipantUserId(EventParticipantsRecord participant) {
  return participant.reference.id;
}

bool _eventListParticipantHasCanonicalIdentity(
  EventParticipantsRecord participant,
) {
  final referenceUserId = participant.reference.id;
  return referenceUserId.isNotEmpty &&
      (!participant.hasUserId() ||
          participant.userId.isEmpty ||
          participant.userId == referenceUserId);
}

String _eventListVisibleParticipantDisplayName(String displayName) {
  final normalized = displayName.trim();
  final lower = normalized.toLowerCase();
  if (lower == 'участник' || lower == 'participant') {
    return '';
  }
  return normalized;
}

String _eventListUsableParticipantDisplayName(String displayName) {
  final normalized = _eventListVisibleParticipantDisplayName(displayName);
  return _eventListParticipantAvatarInitial(normalized) == null
      ? ''
      : normalized;
}

String? _eventListParticipantAvatarInitial(String displayName) {
  final normalized = _eventListVisibleParticipantDisplayName(displayName);
  if (normalized.isEmpty) {
    return null;
  }
  final initial = ExpatlioDesign.avatarInitial(normalized);
  final visibleInitial =
      initial.replaceAll(_eventListInvisibleAvatarCharacters, '').trim();
  return visibleInitial.isEmpty ||
          !_eventListAvatarInitialLetterOrNumber.hasMatch(visibleInitial)
      ? null
      : initial;
}

EventListParticipantViewModel _eventListCurrentUserParticipantViewModel(
  String userId,
) {
  final user =
      currentUserDocument?.reference.id == userId ? currentUserDocument : null;
  final displayName = _eventListUsableParticipantDisplayName(
    user?.displayName ?? '',
  );
  final photoUrl = user?.photoUrl.trim() ?? '';
  return EventListParticipantViewModel(
    userId: userId,
    displayName: displayName,
    photoUrl: photoUrl.isEmpty ? null : photoUrl,
  );
}

List<EventListCardViewModel> _eventListCardsWithParticipantActionSourceRevision(
  List<EventListCardViewModel> cards,
  int participantActionSourceRevision,
) {
  var changed = false;
  final revisedCards = cards.map((card) {
    if (card.participantActionSourceRevision ==
        participantActionSourceRevision) {
      return card;
    }
    changed = true;
    return card.copyWithParticipantActionSourceRevision(
      participantActionSourceRevision,
    );
  }).toList(growable: false);
  return changed ? List.unmodifiable(revisedCards) : cards;
}

EventListCardViewModel _eventListCardWithCurrentActionTime(
  EventListCardViewModel card, {
  required DateTime nowUtc,
}) {
  if (card.startsAt.isAfter(nowUtc)) {
    final capacity = card.capacity;
    if (card.joinCtaState == EventListJoinCtaState.join &&
        capacity != null &&
        capacity > 0 &&
        card.resolvedParticipantsCount >= capacity) {
      return card.copyWithJoinCtaState(EventListJoinCtaState.full);
    }
    return card;
  }
  return switch (card.joinCtaState) {
    EventListJoinCtaState.join =>
      card.copyWithJoinCtaState(EventListJoinCtaState.past),
    EventListJoinCtaState.joined =>
      card.copyWithJoinCtaState(EventListJoinCtaState.joinedLocked),
    EventListJoinCtaState.joining ||
    EventListJoinCtaState.leaving ||
    EventListJoinCtaState.joinedLocked ||
    EventListJoinCtaState.full ||
    EventListJoinCtaState.canceled ||
    EventListJoinCtaState.past =>
      card,
  };
}

EventListCardViewModel _eventListCardWithParticipantActionOverlay(
  EventListCardViewModel card, {
  required _EventListParticipantActionOverlay overlay,
  required String currentUserId,
  required DateTime nowUtc,
}) {
  final rawSourceCaughtUp = !overlay.pending &&
      overlay.confirmedRevision > 0 &&
      card.membershipState == EventListMembershipState.resolved &&
      card.participantActionSourceRevision >= overlay.confirmedRevision;
  if (rawSourceCaughtUp) {
    final rawParticipantsCount = card.participantsCount;
    if (rawParticipantsCount == null ||
        card.participants.length <= rawParticipantsCount) {
      return card;
    }
    final reconciledParticipants =
        List<EventListParticipantViewModel>.from(card.participants);
    _eventListTrimParticipantPreviewToCount(
      reconciledParticipants,
      participantsCount: rawParticipantsCount,
      preservedUserId: overlay.desiredJoined ? currentUserId : null,
    );
    return card.copyWithParticipantAction(
      updatedParticipants: reconciledParticipants,
      updatedParticipantsCount: rawParticipantsCount,
      updatedJoinCtaState: card.joinCtaState,
      updatedChatCtaState: card.chatCtaState,
    );
  }

  final participants = List<EventListParticipantViewModel>.from(
    card.participants,
  );
  if (overlay.desiredJoined) {
    final participant = overlay.participant;
    if (participant != null &&
        !participants.any((item) => item.userId == currentUserId)) {
      participants.add(participant);
    }
    _eventListKeepParticipantVisible(
      participants,
      userId: currentUserId,
      visibleLimit: _eventListParticipantPreviewLimit,
    );
  } else {
    participants.removeWhere(
      (participant) => participant.userId == currentUserId,
    );
  }
  _eventListTrimParticipantPreviewToCount(
    participants,
    participantsCount: overlay.participantsCount,
    preservedUserId: overlay.desiredJoined ? currentUserId : null,
  );

  final joinCtaState = overlay.pending
      ? overlay.desiredJoined
          ? EventListJoinCtaState.joining
          : EventListJoinCtaState.leaving
      : _eventListResolvedJoinStateForParticipantAction(
          card,
          desiredJoined: overlay.desiredJoined,
          participantsCount: overlay.participantsCount,
          nowUtc: nowUtc,
        );
  return card.copyWithParticipantAction(
    updatedParticipants: participants,
    updatedParticipantsCount: overlay.participantsCount,
    updatedJoinCtaState: joinCtaState,
    updatedChatCtaState: overlay.desiredJoined && !overlay.pending
        ? EventListChatCtaState.enabled
        : EventListChatCtaState.participantOnly,
  );
}

EventListJoinCtaState _eventListResolvedJoinStateForParticipantAction(
  EventListCardViewModel card, {
  required bool desiredJoined,
  required int participantsCount,
  required DateTime nowUtc,
}) {
  if (card.joinCtaState == EventListJoinCtaState.canceled) {
    return EventListJoinCtaState.canceled;
  }
  if (desiredJoined) {
    return card.startsAt.isAfter(nowUtc)
        ? EventListJoinCtaState.joined
        : EventListJoinCtaState.joinedLocked;
  }
  if (!card.startsAt.isAfter(nowUtc)) {
    return EventListJoinCtaState.past;
  }
  final capacity = card.capacity;
  if (capacity != null && capacity > 0 && participantsCount >= capacity) {
    return EventListJoinCtaState.full;
  }
  return EventListJoinCtaState.join;
}

EventListJoinCtaState _eventListJoinStateForRecord({
  required EventsRecord event,
  required DateTime nowUtc,
  required bool isJoined,
  required bool canLeave,
  required int? participantsCount,
  required int? capacity,
}) {
  if (event.status == eventStatusCanceled) {
    return EventListJoinCtaState.canceled;
  }
  if (isJoined) {
    return canLeave
        ? EventListJoinCtaState.joined
        : EventListJoinCtaState.joinedLocked;
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

EventDetailJoinCtaState _eventDetailJoinStateForListCard(
  EventListJoinCtaState state,
) =>
    switch (state) {
      EventListJoinCtaState.join => EventDetailJoinCtaState.join,
      EventListJoinCtaState.joining => EventDetailJoinCtaState.joining,
      EventListJoinCtaState.joined => EventDetailJoinCtaState.joined,
      EventListJoinCtaState.leaving => EventDetailJoinCtaState.optimisticLeft,
      EventListJoinCtaState.joinedLocked =>
        EventDetailJoinCtaState.joinedLocked,
      EventListJoinCtaState.full => EventDetailJoinCtaState.full,
      EventListJoinCtaState.canceled => EventDetailJoinCtaState.canceled,
      EventListJoinCtaState.past => EventDetailJoinCtaState.past,
    };

class _EventListEmptyState extends StatelessWidget {
  const _EventListEmptyState({
    this.hasActiveFilters = false,
    this.onResetFilters,
    this.onOpenMyEvents,
  });

  final bool hasActiveFilters;
  final VoidCallback? onResetFilters;
  final VoidCallback? onOpenMyEvents;

  @override
  Widget build(BuildContext context) {
    final description = FFLocalizations.of(context).getVariableText(
      ruText: 'Выберите другой день, уровень или локацию.',
      enText: 'Choose another day, level, or location.',
    );
    final emptyStateHeight = _eventListEmptyStateHeight(context);

    return Semantics(
      key: eventListEmptyStateKey,
      container: true,
      liveRegion: true,
      label: description,
      child: SizedBox(
        width: double.infinity,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: emptyStateHeight),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: EmptyWidget(
                      shrinkWrap: true,
                      topPadding: ExpatlioDesign.space0,
                      txt: description,
                    ),
                  ),
                  const SizedBox(height: ExpatlioDesign.space16),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: ExpatlioDesign.space8,
                    runSpacing: ExpatlioDesign.space8,
                    children: [
                      if (hasActiveFilters && onResetFilters != null)
                        OutlinedButton(
                          key: eventListEmptyResetFiltersButtonKey,
                          onPressed: onResetFilters,
                          child: Text(
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'Сбросить фильтры',
                              enText: 'Reset filters',
                            ),
                          ),
                        ),
                      if (onOpenMyEvents != null)
                        TextButton(
                          key: eventListEmptyMyEventsButtonKey,
                          onPressed: onOpenMyEvents,
                          child: Text(
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'Мои события',
                              enText: 'My events',
                            ),
                          ),
                        ),
                    ],
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

class _EventCardLayoutMetrics {
  const _EventCardLayoutMetrics({
    required this.metaChipHeight,
    required this.levelBadgeHeight,
    required this.actionHeight,
    required this.stackActions,
  });

  factory _EventCardLayoutMetrics.from(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
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
      metaChipHeight: math.max(
        24.0,
        _eventCardScaledLineHeight(
              textScaler,
              fontSize: _eventListMetaFontSize,
              height: _eventListDefaultTextHeight,
            ) +
            ExpatlioDesign.space8,
      ),
      levelBadgeHeight: levelBadgeHeight,
      actionHeight: actionHeight,
      stackActions: stackActions,
    );
  }

  final double metaChipHeight;
  final double levelBadgeHeight;
  final double actionHeight;
  final bool stackActions;

  double get actionsHeight =>
      stackActions ? (actionHeight * 2) + _eventListActionGap : actionHeight;

  int get actionMaxLines =>
      stackActions ? _eventListStackedActionMaxLines : _eventListActionMaxLines;
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
    this.onPrimaryPressed,
    this.onChatPressed,
    this.onChatParticipantRequiredPressed,
  });

  final EventListCardViewModel? card;
  final VoidCallback? onPressed;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onChatPressed;
  final VoidCallback? onChatParticipantRequiredPressed;

  @override
  Widget build(BuildContext context) {
    final metrics = _EventCardLayoutMetrics.from(context);
    final borderRadius = BorderRadius.circular(_eventListCardRadius);
    return Material(
      key: eventListCardShellKey,
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
                    _EventCardBodyShell(card: card),
                    const SizedBox(height: _eventListCardBodyMetaGap),
                    _EventCardMetaShell(card: card, metrics: metrics),
                    if (card == null || card!.hasFooterContent) ...[
                      const SizedBox(height: _eventListCardMetaFooterGap),
                      _EventCardFooterShell(card: card),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: _eventListCardFooterActionsGap),
              _EventCardActionsShell(
                card: card,
                metrics: metrics,
                onPrimaryPressed: onPrimaryPressed,
                onChatPressed: onChatPressed,
                onChatParticipantRequiredPressed:
                    onChatParticipantRequiredPressed,
              ),
            ],
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
    return Row(
      key: eventListCardHeaderKey,
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
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
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
          _EventCardPillPlaceholder(
            width: 72,
            height: metrics.levelBadgeHeight,
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 72),
            child: _EventLevelRangeBadge(
              levelMin: organizer.levelMin,
              levelMax: organizer.levelMax,
              height: metrics.levelBadgeHeight,
            ),
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
            size: _eventListTitleFontSize,
            weight: FontWeight.w700,
            height: _eventListTitleTextHeight,
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
              color: ExpatlioDesign.inactive,
              size: _eventListDescriptionFontSize,
              height: _eventListDescriptionTextHeight,
              weight: FontWeight.w400,
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
    required this.metrics,
  });

  final EventListCardViewModel? card;
  final _EventCardLayoutMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final event = card;
    if (event == null) {
      return Wrap(
        key: eventListCardMetaKey,
        spacing: ExpatlioDesign.space8,
        runSpacing: ExpatlioDesign.space8,
        children: [
          _EventCardPillPlaceholder(
            width: 104,
            height: metrics.metaChipHeight,
          ),
          _EventCardPillPlaceholder(
            width: 92,
            height: metrics.metaChipHeight,
          ),
          _EventCardPillPlaceholder(
            width: 184,
            height: metrics.metaChipHeight,
          ),
        ],
      );
    }

    final locale = FFLocalizations.of(context).languageCode;
    final eventLocalDateTime = _eventLocalDateTime(
      startsAt: event.startsAt,
      timeZoneId: event.timeZoneId,
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
            _EventInfoChip(
              key: eventListCardDateKey,
              icon: Icons.calendar_month_outlined,
              label: _eventDateLabel(
                context,
                eventLocalDateTime: eventLocalDateTime,
                timeZoneId: event.timeZoneId,
              ),
              minHeight: metrics.metaChipHeight,
            ),
            _EventInfoChip(
              key: eventListCardTimeKey,
              icon: Icons.schedule,
              label: dateTimeFormat(
                'Hm',
                eventLocalDateTime,
                locale: locale,
              ),
              minHeight: metrics.metaChipHeight,
            ),
          ],
        ),
        const SizedBox(height: _eventListCardMetaPlaceGap),
        Row(
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
      ],
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
    required this.minHeight,
  });

  final IconData icon;
  final String label;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        (MediaQuery.sizeOf(context).width - 72).clamp(96.0, 220.0).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: minHeight,
        maxWidth: maxWidth,
      ),
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
      );
    }

    return Row(
      key: eventListCardFooterKey,
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
    final displayName =
        _eventListUsableParticipantDisplayName(participant.displayName);
    final semanticsLabel = displayName.isEmpty
        ? FFLocalizations.of(context).getVariableText(
            ruText: 'Участник события',
            enText: 'Event participant',
          )
        : FFLocalizations.of(context).getVariableText(
            ruText: 'Участник: $displayName',
            enText: 'Participant: $displayName',
          );
    return Semantics(
      container: true,
      image: true,
      excludeSemantics: true,
      label: semanticsLabel,
      child: Container(
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
      ),
    );
  }

  Widget _fallback(BuildContext context) {
    final initial = _eventListParticipantAvatarInitial(
      participant.displayName,
    );
    if (initial == null) {
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
        initial,
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
    this.onPrimaryPressed,
    this.onChatPressed,
    this.onChatParticipantRequiredPressed,
  });

  final EventListCardViewModel? card;
  final _EventCardLayoutMetrics metrics;
  final VoidCallback? onPrimaryPressed;
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
      final chatAccessPending =
          event.joinCtaState == EventListJoinCtaState.joining ||
              event.joinCtaState == EventListJoinCtaState.leaving;
      final canOpenChat = !chatAccessPending &&
          event.chatCtaState == EventListChatCtaState.enabled &&
          onChatPressed != null;
      final canShowParticipantRequiredHint = !chatAccessPending &&
          event.chatCtaState == EventListChatCtaState.participantOnly &&
          onChatParticipantRequiredPressed != null;
      primaryAction = _EventCardPrimaryCta(
        state: event.joinCtaState,
        membershipState: event.membershipState,
        height: metrics.actionHeight,
        maxLines: metrics.actionMaxLines,
        onPressed: onPrimaryPressed,
      );
      secondaryAction = _EventCardChatCta(
        state: event.chatCtaState,
        membershipState: event.membershipState,
        accessPending: chatAccessPending,
        height: metrics.actionHeight,
        maxLines: metrics.actionMaxLines,
        onPressed: canOpenChat ? onChatPressed : null,
        onParticipantRequiredPressed: canShowParticipantRequiredHint
            ? onChatParticipantRequiredPressed
            : null,
      );
    }

    Widget buildStackedActions() {
      return SizedBox(
        key: eventListCardActionsKey,
        height: (metrics.actionHeight * 2) + _eventListActionGap,
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

    Widget buildInlineActions() {
      return SizedBox(
        key: eventListCardActionsKey,
        height: metrics.actionHeight,
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

    if (metrics.stackActions) {
      return buildStackedActions();
    }
    return LayoutBuilder(
      builder: (context, constraints) =>
          constraints.maxWidth < _eventListInlineActionsMinWidth
              ? buildStackedActions()
              : buildInlineActions(),
    );
  }
}

class _EventCardPrimaryCta extends StatelessWidget {
  const _EventCardPrimaryCta({
    required this.state,
    required this.membershipState,
    required this.height,
    required this.maxLines,
    required this.onPressed,
  });

  final EventListJoinCtaState state;
  final EventListMembershipState membershipState;
  final double height;
  final int maxLines;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final membershipResolved =
        membershipState == EventListMembershipState.resolved;
    final showsDetails =
        membershipState == EventListMembershipState.lookupFailed;
    final membershipPending =
        membershipState == EventListMembershipState.pending;
    final enabled = !membershipPending &&
        onPressed != null &&
        (showsDetails ||
            state == EventListJoinCtaState.join ||
            state == EventListJoinCtaState.joined);
    final isJoinedAction = state == EventListJoinCtaState.joined;
    final showActionStyle = enabled ||
        (membershipPending &&
            (state == EventListJoinCtaState.join || isJoinedAction));
    final backgroundColor = showsDetails
        ? ExpatlioDesign.secondarySystemBackground
        : showActionStyle
            ? isJoinedAction
                ? _eventListSoftPrimaryBackground
                : ExpatlioDesign.primary
            : ExpatlioDesign.secondarySystemBackground;
    final textColor = showsDetails
        ? ExpatlioDesign.primary
        : showActionStyle
            ? isJoinedAction
                ? ExpatlioDesign.primary
                : Colors.white
            : state == EventListJoinCtaState.joinedLocked
                ? ExpatlioDesign.primary
                : ExpatlioDesign.muted;
    final actionPending = state == EventListJoinCtaState.joining ||
        state == EventListJoinCtaState.leaving;
    final visibleLabel = switch (membershipState) {
      EventListMembershipState.lookupFailed =>
        FFLocalizations.of(context).getVariableText(
          ruText: 'Подробнее',
          enText: 'Details',
        ),
      EventListMembershipState.pending ||
      EventListMembershipState.resolved =>
        _eventPrimaryCtaLabel(context, state),
    };
    final semanticsLabel = membershipPending
        ? FFLocalizations.of(context).getVariableText(
            ruText: 'Проверяем участие', enText: 'Checking participation')
        : membershipResolved
            ? _eventPrimaryCtaSemanticsLabel(context, state)
            : visibleLabel;

    return Semantics(
      key: eventListCardPrimaryCtaKey,
      container: true,
      button: true,
      enabled: enabled,
      liveRegion: actionPending,
      label: semanticsLabel,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: Material(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(_eventListActionRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            overlayColor: WidgetStatePropertyAll(
              (isJoinedAction ? ExpatlioDesign.primary : Colors.white)
                  .withValues(alpha: 0.10),
            ),
            child: SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: ExpatlioDesign.space8,
                ),
                child: Center(
                  child: Text(
                    visibleLabel,
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
              ),
            ),
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
    required this.accessPending,
    required this.height,
    required this.maxLines,
    required this.onPressed,
    this.onParticipantRequiredPressed,
  });

  final EventListChatCtaState state;
  final EventListMembershipState membershipState;
  final bool accessPending;
  final double height;
  final int maxLines;
  final VoidCallback? onPressed;
  final VoidCallback? onParticipantRequiredPressed;

  @override
  Widget build(BuildContext context) {
    final membershipResolved =
        membershipState == EventListMembershipState.resolved;
    final enabled = membershipResolved &&
        !accessPending &&
        state == EventListChatCtaState.enabled &&
        onPressed != null;
    final effectiveOnPressed = !membershipResolved || accessPending
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
        canHandleTap || membershipState == EventListMembershipState.pending
            ? ExpatlioDesign.text
            : ExpatlioDesign.disabled;
    const backgroundColor = ExpatlioDesign.secondarySystemBackground;

    return Semantics(
      key: eventListCardChatCtaKey,
      container: true,
      button: true,
      enabled: enabled,
      label: accessPending
          ? pendingLabel
          : switch (membershipState) {
              EventListMembershipState.pending => pendingLabel,
              EventListMembershipState.lookupFailed => failedLabel,
              EventListMembershipState.resolved =>
                enabled ? label : disabledLabel,
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
    EventListJoinCtaState.joining =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Присоединяемся...',
        enText: 'Joining...',
      ),
    EventListJoinCtaState.joined => FFLocalizations.of(context).getVariableText(
        ruText: 'Покинуть',
        enText: 'Leave',
      ),
    EventListJoinCtaState.leaving =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Покидаем...',
        enText: 'Leaving...',
      ),
    EventListJoinCtaState.joinedLocked =>
      FFLocalizations.of(context).getVariableText(
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

String _eventPrimaryCtaSemanticsLabel(
  BuildContext context,
  EventListJoinCtaState state,
) {
  return switch (state) {
    EventListJoinCtaState.join => _eventPrimaryCtaLabel(context, state),
    EventListJoinCtaState.joining =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Присоединяемся к событию',
        enText: 'Joining event',
      ),
    EventListJoinCtaState.joined => FFLocalizations.of(context).getVariableText(
        ruText: 'Вы участвуете. Покинуть событие',
        enText: 'Joined. Leave event',
      ),
    EventListJoinCtaState.leaving =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Покидаем событие',
        enText: 'Leaving event',
      ),
    EventListJoinCtaState.joinedLocked =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Вы участвуете',
        enText: 'Joined',
      ),
    EventListJoinCtaState.full => FFLocalizations.of(context).getVariableText(
        ruText: 'Мест нет',
        enText: 'Event is full',
      ),
    EventListJoinCtaState.canceled =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Событие отменено',
        enText: 'Event canceled',
      ),
    EventListJoinCtaState.past => FFLocalizations.of(context).getVariableText(
        ruText: 'Событие уже началось',
        enText: 'Event already started',
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
    return _eventListHorizontalFilterScroller(
      scrollViewKey: eventListLevelFiltersScrollKey,
      height: _eventListLevelChipHeight,
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
          for (final level in eventLevelFilterMinimums) ...[
            _EventListFilterChip(
              chipKey: _eventLevelFilterChipKey(level),
              label: FFLocalizations.of(context).getVariableText(
                ruText: 'От $level',
                enText: 'From $level',
              ),
              selected: selectedLevel == level,
              height: _eventListLevelChipHeight,
              horizontalPadding: 8,
              fontSize: 13,
              fontWeight: FontWeight.w400,
              selectedBackgroundColor: ExpatlioDesign.primary,
              selectedTextColor: Colors.white,
              selectedBorderColor: _eventListBorderColor,
              selectedBorderWidth: 1,
              onSelected: (selected) => onChanged(selected ? level : null),
            ),
            if (level != eventLevelFilterMinimums.last)
              const SizedBox(width: ExpatlioDesign.space4),
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
    return _eventListHorizontalFilterScroller(
      scrollViewKey: eventListDateFiltersScrollKey,
      height: _eventListDateChipHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final filter in _filters) ...[
            _EventListFilterChip(
              chipKey: _eventDateFilterChipKey(filter),
              label: _eventDateFilterLabel(context, filter),
              selected: selectedFilter == filter,
              height: _eventListDateChipHeight,
              horizontalPadding: 8,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              selectedBackgroundColor: ExpatlioDesign.primary,
              selectedTextColor: Colors.white,
              onSelected: (selected) => onChanged(selected ? filter : null),
            ),
            if (filter != _filters.last)
              const SizedBox(width: ExpatlioDesign.space4),
          ],
        ],
      ),
    );
  }
}

Widget _eventListHorizontalFilterScroller({
  required Key scrollViewKey,
  required double height,
  required Widget child,
}) {
  return SizedBox(
    height: height,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth =
            constraints.maxWidth + (_eventListHorizontalPadding * 2);
        return OverflowBox(
          alignment: Alignment.center,
          minWidth: viewportWidth,
          maxWidth: viewportWidth,
          child: SingleChildScrollView(
            key: scrollViewKey,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: _eventListHorizontalPadding,
            ),
            clipBehavior: Clip.none,
            child: child,
          ),
        );
      },
    ),
  );
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
    final borderColor = selected ? selectedBorderColor : _eventListBorderColor;
    final borderWidth = selected ? selectedBorderWidth : 1.0;

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
            ),
            foregroundDecoration: borderColor == null
                ? null
                : BoxDecoration(
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.radiusCapsule),
                    border: Border.all(
                      color: borderColor,
                      width: borderWidth,
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
  final supportedLabel = supportedLocationLabel(city.countryCode, city.cityKey);
  if (supportedLabel != null) return supportedLabel;
  final isRu = FFLocalizations.of(context).languageCode == 'ru';
  final cityName = isRu ? city.cityNameRu : city.cityNameEn;
  return '$cityName · ${city.cityDisplayContext}';
}

class _EventCitySelector extends StatelessWidget {
  const _EventCitySelector({
    this.selectorKey = eventListCitySelectorKey,
    required this.selectedCity,
    required this.hasOutdatedProfileCity,
    required this.showsMissingLocationPrompt,
    required this.onPressed,
  });

  final Key selectorKey;
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
        ruText: 'Выбор локации',
        enText: 'Location selector',
      ),
      child: Material(
        color: Colors.transparent,
        child: Builder(
          builder: (fieldContext) => InkWell(
            key: selectorKey,
            onTap: onPressed == null
                ? null
                : () async {
                    await onPressed?.call(fieldContext);
                  },
            borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
            child: Container(
              constraints: const BoxConstraints(minHeight: 44),
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
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
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
          ruText: 'Выберите локацию заново',
          enText: 'Choose location again',
        );
      }
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Выберите локацию',
        enText: 'Choose location',
      );
    }
    final supportedLabel =
        supportedLocationLabel(city.countryCode, city.cityKey);
    if (supportedLabel != null) return supportedLabel;
    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    final cityName = isRu ? city.cityNameRu : city.cityNameEn;
    return '$cityName · ${city.cityDisplayContext}';
  }

  String _helperText(BuildContext context) {
    if (hasOutdatedProfileCity) {
      return FFLocalizations.of(context).getVariableText(
        ruText:
            'Сохранённая локация больше недоступна. Выберите актуальную локацию, чтобы увидеть события.',
        enText:
            'Your saved location is no longer available. Choose a current location to see events.',
      );
    }
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Выберите локацию, чтобы увидеть события.',
      enText: 'Choose a location to see events.',
    );
  }
}
