import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/ux_refreshing_indicator_overlay.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/chat_thread/open_chat_thread.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/events/event_detail_widget.dart';
import '/shared_pages/events/event_edit_widget.dart';
import '/shared_pages/events/event_group_chat_widget.dart';
import '/students_pages/pay/pay_widget.dart';
import '/services/event_action_error_mapper.dart';
import '/services/event_actions_repository.dart';
import '/services/event_detail_repository.dart';
import '/services/events_analytics_service.dart';
import '/services/user_public_profile_preload_repository.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/utils/subscription_utils.dart';

const ValueKey<String> eventDetailRouteLoadingKey =
    ValueKey<String>('event_detail_route_loading');
const ValueKey<String> eventDetailRouteMissingKey =
    ValueKey<String>('event_detail_route_missing');
const ValueKey<String> eventDetailRouteErrorKey =
    ValueKey<String>('event_detail_route_error');
const ValueKey<String> eventDetailRouteRefreshingIndicatorKey =
    ValueKey<String>('event_detail_route_refreshing_indicator');
const ValueKey<String> eventDetailRouteRefreshErrorIndicatorKey =
    ValueKey<String>('event_detail_route_refresh_error_indicator');
const ValueKey<String> eventDetailCancelErrorSnackBarKey =
    ValueKey<String>('event_detail_cancel_error_snack_bar');
const ValueKey<String> eventDetailJoinErrorSnackBarKey =
    ValueKey<String>('event_detail_join_error_snack_bar');
const ValueKey<String> eventDetailLeaveErrorSnackBarKey =
    ValueKey<String>('event_detail_leave_error_snack_bar');
const ValueKey<String> eventDetailOrganizerChatErrorSnackBarKey =
    ValueKey<String>('event_detail_organizer_chat_error_snack_bar');
const ValueKey<String> eventDetailReportSuccessSnackBarKey =
    ValueKey<String>('event_detail_report_success_snack_bar');
const ValueKey<String> eventDetailReportErrorSnackBarKey =
    ValueKey<String>('event_detail_report_error_snack_bar');
const ValueKey<String> eventDetailReportDialogKey =
    ValueKey<String>('event_detail_report_dialog');
const ValueKey<String> eventDetailReportDetailsFieldKey =
    ValueKey<String>('event_detail_report_details_field');
const ValueKey<String> eventDetailReportDismissButtonKey =
    ValueKey<String>('event_detail_report_dismiss_button');
const ValueKey<String> eventDetailReportSubmitButtonKey =
    ValueKey<String>('event_detail_report_submit_button');
const String eventDetailPublicPreviewExtraKey = 'eventDetailPublicPreview';
const int eventDetailPublicPreviewDescriptionMaxLength = 160;

EventDetailPublicPreview? eventDetailPublicPreviewFromParam(Object? value) =>
    value is EventDetailPublicPreview ? value : null;

String eventDetailPublicPreviewDescription(String value) {
  final text = value.trim();
  final characters = text.characters;
  if (characters.length <= eventDetailPublicPreviewDescriptionMaxLength) {
    return text;
  }
  return '${characters.take(eventDetailPublicPreviewDescriptionMaxLength).toString().trim()}…';
}

ValueKey<String> eventDetailReportReasonKey(String reasonCode) =>
    ValueKey<String>('event_detail_report_reason_$reasonCode');

/// Public event fields already visible in the list.
///
/// This is display-only seed data. It must never be treated as confirmed
/// membership, subscription access, or permission to reveal private fields.
class EventDetailPublicPreview {
  const EventDetailPublicPreview({
    required this.eventId,
    required this.title,
    required this.description,
    required this.languageCode,
    required this.levelMin,
    required this.levelMax,
    required this.startsAt,
    required this.timeZoneId,
    required this.organizerDisplayName,
    this.publicLocationLabel = '',
    this.languageNameEn,
    this.languageNameRu,
    this.organizerPhotoUrl,
    this.participantsCount,
    this.capacity,
    this.joinCtaState = EventDetailJoinCtaState.join,
    this.restrictedToUserId,
  });

  final String eventId;
  final String title;
  final String description;
  final String languageCode;
  final String? languageNameEn;
  final String? languageNameRu;
  final String levelMin;
  final String levelMax;
  final DateTime startsAt;
  final String timeZoneId;
  final String organizerDisplayName;
  final String publicLocationLabel;
  final String? organizerPhotoUrl;
  final int? participantsCount;
  final int? capacity;
  final EventDetailJoinCtaState joinCtaState;
  final String? restrictedToUserId;
}

typedef EventChatThreadOpener = Future<void> Function(
  BuildContext context, {
  required DocumentReference? conversationRef,
  ConversationsRecord? initialConversation,
  ChatConversationPreparation? preparation,
});
typedef EventDetailPublicProfilesLoader = Future<UserPublicProfilePreloadResult>
    Function(
  Iterable<String> userIds,
);
typedef _EventDetailRouteDataKey = ({String eventId, String userId});
typedef _EventDetailPendingMembershipIntent = ({
  _EventDetailRouteDataKey dataKey,
  bool desiredJoined,
  int generation,
  int optimisticParticipantsCount,
});

_EventDetailRouteDataKey _eventDetailRouteDataKey({
  required String eventId,
  required String userId,
}) =>
    (eventId: normalizeEventDetailId(eventId), userId: userId);

final _eventDetailPublicProfilePreloadRepository =
    UserPublicProfilePreloadRepository();
final RegExp _eventDetailInvisibleParticipantNameCharacters = RegExp(
  r'[\u0000-\u001F\u007F-\u009F\u00AD\u034F\u061C\u115F\u1160\u17B4\u17B5\u180B-\u180F\u200B-\u200F\u202A-\u202E\u2060-\u206F\u3164\uFE00-\uFE0F\uFEFF\uFFA0]',
);
final RegExp _eventDetailParticipantNameLetterOrNumber = RegExp(
  r'[\p{L}\p{N}]',
  unicode: true,
);

class _EventDetailSnapshotSummary {
  const _EventDetailSnapshotSummary({
    required this.connectionState,
    required this.hasResolvedResult,
    required this.event,
    required this.error,
  });

  factory _EventDetailSnapshotSummary.initial(EventsRecord? initialEvent) {
    return _EventDetailSnapshotSummary(
      connectionState: ConnectionState.none,
      hasResolvedResult: initialEvent != null,
      event: initialEvent,
      error: null,
    );
  }

  final ConnectionState connectionState;
  final bool hasResolvedResult;
  final EventsRecord? event;
  final Object? error;

  bool get hasError => error != null;
  bool get isConfirmedMissing => hasResolvedResult && event == null;

  _EventDetailSnapshotSummary copyWith({
    ConnectionState? connectionState,
    bool? hasResolvedResult,
    EventsRecord? event,
    bool replaceEvent = false,
    Object? error,
    bool clearError = false,
  }) {
    return _EventDetailSnapshotSummary(
      connectionState: connectionState ?? this.connectionState,
      hasResolvedResult: hasResolvedResult ?? this.hasResolvedResult,
      event: replaceEvent ? event : this.event,
      error: clearError ? null : error ?? this.error,
    );
  }
}

typedef _EventDetailSnapshotSummaryBuilder = Widget Function(
  BuildContext context,
  _EventDetailSnapshotSummary summary,
);

class _EventDetailSnapshotBuilder
    extends StreamBuilderBase<EventsRecord?, _EventDetailSnapshotSummary> {
  const _EventDetailSnapshotBuilder({
    super.key,
    required super.stream,
    required this.initialEvent,
    required this.builder,
  });

  final EventsRecord? initialEvent;
  final _EventDetailSnapshotSummaryBuilder builder;

  @override
  _EventDetailSnapshotSummary initial() =>
      _EventDetailSnapshotSummary.initial(initialEvent);

  @override
  _EventDetailSnapshotSummary afterConnected(
    _EventDetailSnapshotSummary current,
  ) {
    final retainedEvent =
        current.hasResolvedResult ? current.event : initialEvent;
    return current.copyWith(
      connectionState: ConnectionState.waiting,
      hasResolvedResult: current.hasResolvedResult || initialEvent != null,
      event: retainedEvent,
      replaceEvent: true,
      clearError: true,
    );
  }

  @override
  _EventDetailSnapshotSummary afterData(
    _EventDetailSnapshotSummary current,
    EventsRecord? data,
  ) {
    return current.copyWith(
      connectionState: ConnectionState.active,
      hasResolvedResult: true,
      event: data,
      replaceEvent: true,
      clearError: true,
    );
  }

  @override
  _EventDetailSnapshotSummary afterError(
    _EventDetailSnapshotSummary current,
    Object error,
    StackTrace stackTrace,
  ) {
    return current.copyWith(
      connectionState: ConnectionState.active,
      error: error,
    );
  }

  @override
  _EventDetailSnapshotSummary afterDone(
    _EventDetailSnapshotSummary current,
  ) {
    return current.copyWith(connectionState: ConnectionState.done);
  }

  @override
  _EventDetailSnapshotSummary afterDisconnected(
    _EventDetailSnapshotSummary current,
  ) {
    return current.copyWith(
      connectionState: ConnectionState.none,
      clearError: true,
    );
  }

  @override
  Widget build(
      BuildContext context, _EventDetailSnapshotSummary currentSummary) {
    return builder(context, currentSummary);
  }
}

class EventDetailRouteWidget extends StatefulWidget {
  const EventDetailRouteWidget({
    super.key,
    required this.eventId,
    this.initialPreview,
    this.snapshotStream,
    this.snapshotIsFromCache,
    this.snapshotHasPendingWrites,
    this.cancelEventInvoker,
    this.joinEventInvoker,
    this.leaveEventInvoker,
    this.reportEventInvoker,
    this.participantSnapshotStream,
    this.participantsStream,
    this.publicProfilesLoader,
    this.openOrganizerChatInvoker,
    this.chatThreadOpener,
    this.analyticsTracker,
  });

  final String eventId;
  final EventDetailPublicPreview? initialPreview;
  final EventDetailSnapshotStream? snapshotStream;
  final EventDetailSnapshotFlagReader? snapshotIsFromCache;
  final EventDetailSnapshotFlagReader? snapshotHasPendingWrites;
  final EventCallableInvoker? cancelEventInvoker;
  final EventCallableInvoker? joinEventInvoker;
  final EventCallableInvoker? leaveEventInvoker;
  final EventCallableInvoker? reportEventInvoker;
  final EventParticipantSnapshotStream? participantSnapshotStream;
  final EventActiveParticipantsStream? participantsStream;
  final EventDetailPublicProfilesLoader? publicProfilesLoader;
  final EventCallableInvoker? openOrganizerChatInvoker;
  final EventChatThreadOpener? chatThreadOpener;
  final EventsAnalyticsTracker? analyticsTracker;

  @override
  State<EventDetailRouteWidget> createState() => _EventDetailRouteWidgetState();
}

class _EventDetailRouteWidgetState extends State<EventDetailRouteWidget> {
  late Stream<EventsRecord?> _eventStream;
  late _EventDetailRouteDataKey _eventStreamDataKey;
  EventsRecord? _eventInitialData;
  Stream<EventParticipantsRecord?>? _currentUserParticipantStream;
  String? _currentUserParticipantStreamEventId;
  String? _currentUserParticipantStreamUserId;
  Object? _currentUserParticipantStreamLoaderIdentity;
  Stream<List<EventParticipantsRecord>>? _activeParticipantsStream;
  String? _activeParticipantsStreamEventId;
  Object? _activeParticipantsStreamLoaderIdentity;
  Timer? _startsAtRefreshTimer;
  String? _startsAtRefreshEventId;
  DateTime? _startsAtRefreshAt;
  String? _locallyStartedEventId;
  DateTime? _locallyStartedAt;
  bool _isCanceling = false;
  bool _isJoining = false;
  bool _isLeaving = false;
  bool _isOpeningOrganizerChat = false;
  bool _isReportingEvent = false;
  String? _locallyCanceledEventId;
  String? _locallyJoinedEventId;
  String? _locallyJoinedParticipantsCountEventId;
  int? _locallyJoinedParticipantsCount;
  String? _locallyLeftEventId;
  String? _locallyLeftParticipantsCountEventId;
  int? _locallyLeftParticipantsCount;
  _EventDetailPendingMembershipIntent? _pendingMembershipIntent;
  String? _currentDetailEventId;
  int _participantActionGeneration = 0;
  String? _lastTrackedEventDetailOpenKey;
  String? _lastTrackedCanceledEventId;
  String? _lastTrackedJoinedEventId;
  String? _lastTrackedLeftEventId;

  @override
  void initState() {
    super.initState();
    _configureEventStream(sessionCacheUserId: _sessionCacheUserId);
  }

  @override
  void didUpdateWidget(covariant EventDetailRouteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final sessionCacheUserId = _sessionCacheUserId;
    final nextDataKey = _eventDetailRouteDataKey(
      eventId: widget.eventId,
      userId: sessionCacheUserId,
    );
    final dataKeyChanged = _eventStreamDataKey != nextDataKey;
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.snapshotStream != widget.snapshotStream ||
        oldWidget.snapshotIsFromCache != widget.snapshotIsFromCache ||
        oldWidget.snapshotHasPendingWrites != widget.snapshotHasPendingWrites ||
        dataKeyChanged) {
      _configureEventStream(sessionCacheUserId: sessionCacheUserId);
      if (dataKeyChanged) {
        _clearNestedEventStreams();
        _clearStartsAtRefreshTimer();
        _locallyStartedEventId = null;
        _locallyStartedAt = null;
        _locallyCanceledEventId = null;
        _locallyJoinedEventId = null;
        _locallyJoinedParticipantsCountEventId = null;
        _locallyJoinedParticipantsCount = null;
        _locallyLeftEventId = null;
        _locallyLeftParticipantsCountEventId = null;
        _locallyLeftParticipantsCount = null;
        _currentDetailEventId = null;
        _lastTrackedEventDetailOpenKey = null;
        _pendingMembershipIntent = null;
        _participantActionGeneration += 1;
        _isLeaving = false;
        _isJoining = false;
        _lastTrackedCanceledEventId = null;
        _lastTrackedJoinedEventId = null;
        _lastTrackedLeftEventId = null;
        _isOpeningOrganizerChat = false;
        _isReportingEvent = false;
      }
    }
  }

  @override
  void dispose() {
    _clearStartsAtRefreshTimer();
    super.dispose();
  }

  String get _sessionCacheUserId =>
      UxSessionCacheLifecycle.sessionUserIdOrFallback(
        currentUser?.uid ?? currentUserUid,
      );

  EventDetailPublicPreview? get _matchingInitialPreview {
    final preview = widget.initialPreview;
    if (preview == null) {
      return null;
    }
    final restrictedToUserId = preview.restrictedToUserId;
    if (restrictedToUserId != null &&
        restrictedToUserId != _eventStreamDataKey.userId) {
      return null;
    }
    try {
      return normalizeEventDetailId(preview.eventId) ==
              _eventStreamDataKey.eventId
          ? preview
          : null;
    } on ArgumentError {
      return null;
    }
  }

  Widget _buildInitialPublicPreview(
    EventDetailPublicPreview preview, {
    required bool hasRefreshError,
  }) {
    final content = EventDetailWidget(
      eventId: _eventStreamDataKey.eventId,
      levelMin: preview.levelMin,
      levelMax: preview.levelMax,
      languageCode: preview.languageCode,
      languageNameEn: preview.languageNameEn,
      languageNameRu: preview.languageNameRu,
      title: preview.title,
      description: preview.description,
      organizerDisplayName: preview.organizerDisplayName,
      organizerPhotoUrl: preview.organizerPhotoUrl,
      startsAt: preview.startsAt,
      timeZoneId: preview.timeZoneId,
      locationName: preview.publicLocationLabel,
      participants: const <EventDetailParticipantViewModel>[],
      participantsCount: preview.participantsCount,
      capacity: preview.capacity,
      joinCtaState: preview.joinCtaState,
    );
    return _EventDetailRefreshErrorOverlay(
      isVisible: hasRefreshError,
      child: content,
    );
  }

  void _configureEventStream({required String sessionCacheUserId}) {
    _eventStreamDataKey = _eventDetailRouteDataKey(
      eventId: widget.eventId,
      userId: sessionCacheUserId,
    );
    _eventInitialData = EventDetailRepository.cachedEventDetail(
      eventId: _eventStreamDataKey.eventId,
      userId: _eventStreamDataKey.userId,
    );
    _eventStream = _watchEvent(sessionCacheUserId: sessionCacheUserId);
  }

  Stream<EventsRecord?> _watchEvent({required String sessionCacheUserId}) =>
      EventDetailRepository.watchEventDetail(
        eventId: widget.eventId,
        snapshotStream: widget.snapshotStream,
        sessionCacheUserId: sessionCacheUserId,
        snapshotIsFromCache: widget.snapshotIsFromCache,
        snapshotHasPendingWrites: widget.snapshotHasPendingWrites,
      );

  Stream<EventParticipantsRecord?>? _currentParticipantStreamFor({
    required String eventId,
    required String userId,
  }) {
    if (userId.isEmpty) {
      _currentUserParticipantStream = null;
      _currentUserParticipantStreamEventId = null;
      _currentUserParticipantStreamUserId = null;
      _currentUserParticipantStreamLoaderIdentity = null;
      return null;
    }
    final loaderIdentity = widget.participantSnapshotStream;
    if (_currentUserParticipantStream == null ||
        _currentUserParticipantStreamEventId != eventId ||
        _currentUserParticipantStreamUserId != userId ||
        !identical(
          _currentUserParticipantStreamLoaderIdentity,
          loaderIdentity,
        )) {
      _currentUserParticipantStreamEventId = eventId;
      _currentUserParticipantStreamUserId = userId;
      _currentUserParticipantStreamLoaderIdentity = loaderIdentity;
      _currentUserParticipantStream =
          EventDetailRepository.watchCurrentUserParticipant(
        eventId: eventId,
        userId: userId,
        snapshotStream: widget.participantSnapshotStream,
      );
    }
    return _currentUserParticipantStream;
  }

  Stream<List<EventParticipantsRecord>> _activeParticipantsStreamFor(
    String eventId,
  ) {
    final loaderIdentity = widget.participantsStream;
    if (_activeParticipantsStream == null ||
        _activeParticipantsStreamEventId != eventId ||
        !identical(
          _activeParticipantsStreamLoaderIdentity,
          loaderIdentity,
        )) {
      _activeParticipantsStreamEventId = eventId;
      _activeParticipantsStreamLoaderIdentity = loaderIdentity;
      _activeParticipantsStream = EventDetailRepository.watchActiveParticipants(
        eventId: eventId,
        participantsStream: widget.participantsStream,
      );
    }
    return _activeParticipantsStream!;
  }

  void _clearNestedEventStreams() {
    _currentUserParticipantStream = null;
    _currentUserParticipantStreamEventId = null;
    _currentUserParticipantStreamUserId = null;
    _currentUserParticipantStreamLoaderIdentity = null;
    _activeParticipantsStream = null;
    _activeParticipantsStreamEventId = null;
    _activeParticipantsStreamLoaderIdentity = null;
  }

  bool _isCurrentParticipantAction({
    required int generation,
    required _EventDetailRouteDataKey dataKey,
  }) =>
      mounted &&
      generation == _participantActionGeneration &&
      dataKey == _eventStreamDataKey;

  void _validateParticipantActionEventId({
    required String expectedEventId,
    required String actualEventId,
  }) {
    if (actualEventId != expectedEventId) {
      throw StateError(
        'Participant action returned event "$actualEventId" for '
        '"$expectedEventId".',
      );
    }
  }

  Future<void> _handleOrganizerCancel(EventsRecord event) async {
    if (_isCanceling) {
      return;
    }

    final eventId = event.reference.id;
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    setState(() {
      _isCanceling = true;
    });
    try {
      final result = await EventActionsRepository.cancelEvent(
        eventId: eventId,
        invoker: widget.cancelEventInvoker,
      );
      if (!mounted) {
        return;
      }
      _trackEventCanceledIfNeeded(
        eventId: result.eventId,
        event: event,
        tracker: tracker,
      );
      setState(() {
        _locallyCanceledEventId = result.eventId;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventDetailCancelErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCanceling = false;
        });
      }
    }
  }

  Future<void> _handleJoin(
    EventsRecord event, {
    required int displayedParticipantsCount,
  }) async {
    if (_isJoining || _isLeaving) {
      return;
    }
    if (widget.joinEventInvoker == null &&
        !isPaidPremiumSubscription(currentUserDocument)) {
      context.pushNamed(
        PayWidget.routeName,
        queryParameters: {
          'premiumOnly': serializeParam(true, ParamType.bool),
        }.withoutNulls,
      );
      return;
    }

    final eventId = event.reference.id;
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    final requestGeneration = _participantActionGeneration + 1;
    _participantActionGeneration = requestGeneration;
    final requestDataKey = _eventStreamDataKey;

    setState(() {
      _isJoining = true;
      _pendingMembershipIntent = (
        dataKey: requestDataKey,
        desiredJoined: true,
        generation: requestGeneration,
        optimisticParticipantsCount: _eventDetailOptimisticParticipantsCount(
          displayedParticipantsCount: displayedParticipantsCount,
          desiredJoined: true,
        ),
      );
    });
    try {
      final result = await EventActionsRepository.joinEvent(
        eventId: eventId,
        invoker: widget.joinEventInvoker,
      );
      if (!_isCurrentParticipantAction(
        generation: requestGeneration,
        dataKey: requestDataKey,
      )) {
        return;
      }
      _validateParticipantActionEventId(
        expectedEventId: eventId,
        actualEventId: result.eventId,
      );
      _trackEventJoinedIfNeeded(
        eventId: result.eventId,
        event: event,
        tracker: tracker,
      );
      setState(() {
        _pendingMembershipIntent = null;
        _locallyJoinedEventId = result.eventId;
        _locallyJoinedParticipantsCountEventId = result.eventId;
        _locallyJoinedParticipantsCount = result.participantsCount;
        _locallyLeftEventId = null;
        _locallyLeftParticipantsCountEventId = null;
        _locallyLeftParticipantsCount = null;
        _lastTrackedLeftEventId = null;
      });
    } catch (error) {
      if (!_isCurrentParticipantAction(
        generation: requestGeneration,
        dataKey: requestDataKey,
      )) {
        return;
      }
      setState(() {
        _pendingMembershipIntent = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventDetailJoinErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
    } finally {
      if (_isCurrentParticipantAction(
        generation: requestGeneration,
        dataKey: requestDataKey,
      )) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _handleLeave(
    EventsRecord event, {
    required bool isActiveParticipant,
    required int displayedParticipantsCount,
  }) async {
    if (_isJoining || _isLeaving) {
      return;
    }

    final eventId = event.reference.id;
    final wasJoined = _locallyJoinedEventId == eventId ||
        (_locallyLeftEventId != eventId && isActiveParticipant);
    if (!wasJoined) {
      return;
    }
    if (_eventDetailHasStartedForRoute(
      eventId: eventId,
      startsAt: event.startsAt,
    )) {
      return;
    }

    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    final requestGeneration = _participantActionGeneration + 1;
    _participantActionGeneration = requestGeneration;
    final requestDataKey = _eventStreamDataKey;

    setState(() {
      _isLeaving = true;
      _pendingMembershipIntent = (
        dataKey: requestDataKey,
        desiredJoined: false,
        generation: requestGeneration,
        optimisticParticipantsCount: _eventDetailOptimisticParticipantsCount(
          displayedParticipantsCount: displayedParticipantsCount,
          desiredJoined: false,
        ),
      );
    });
    try {
      final result = await EventActionsRepository.leaveEvent(
        eventId: eventId,
        invoker: widget.leaveEventInvoker,
      );
      if (!_isCurrentParticipantAction(
        generation: requestGeneration,
        dataKey: requestDataKey,
      )) {
        return;
      }
      _validateParticipantActionEventId(
        expectedEventId: eventId,
        actualEventId: result.eventId,
      );
      _trackEventLeftIfNeeded(
        eventId: result.eventId,
        event: event,
        tracker: tracker,
      );
      setState(() {
        _pendingMembershipIntent = null;
        _locallyJoinedEventId = null;
        _locallyJoinedParticipantsCountEventId = null;
        _locallyJoinedParticipantsCount = null;
        _locallyLeftEventId = result.eventId;
        _locallyLeftParticipantsCountEventId = result.eventId;
        _locallyLeftParticipantsCount = result.participantsCount;
        _lastTrackedJoinedEventId = null;
      });
    } catch (error) {
      if (!_isCurrentParticipantAction(
        generation: requestGeneration,
        dataKey: requestDataKey,
      )) {
        return;
      }
      setState(() {
        _pendingMembershipIntent = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventDetailLeaveErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
    } finally {
      if (_isCurrentParticipantAction(
        generation: requestGeneration,
        dataKey: requestDataKey,
      )) {
        setState(() {
          _isLeaving = false;
        });
      }
    }
  }

  Future<void> _handleOrganizerMessage(EventsRecord event) async {
    if (_isOpeningOrganizerChat) {
      return;
    }

    final conversationRef = _eventDetailOrganizerConversationRef(event);
    if (conversationRef == null) {
      return;
    }
    final eventId = event.reference.id;
    final organizerChatInvoker = widget.openOrganizerChatInvoker;
    Future<void> prepareConversation() async {
      final result = await EventActionsRepository.openEventOrganizerChat(
        eventId: eventId,
        invoker: organizerChatInvoker,
      );
      if (result.conversationId != conversationRef.id ||
          result.conversationPath != conversationRef.path) {
        throw StateError('Organizer conversation identity mismatch.');
      }
    }

    setState(() {
      _isOpeningOrganizerChat = true;
    });
    try {
      await (widget.chatThreadOpener ?? openChatThread)(
        context,
        conversationRef: conversationRef,
        preparation: prepareConversation,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventDetailOrganizerChatErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningOrganizerChat = false;
        });
      }
    }
  }

  DocumentReference? _eventDetailOrganizerConversationRef(EventsRecord event) {
    final requesterId = currentUserUid.trim();
    final organizerId = event.organizerId.trim();
    if (requesterId.isEmpty ||
        organizerId.isEmpty ||
        requesterId == organizerId) {
      return null;
    }

    try {
      return conversationReferenceForPairId(
        canonicalConversationPairId(requesterId, organizerId),
      );
    } on ArgumentError {
      return null;
    }
  }

  Future<void> _showReportEventDialog(EventsRecord event) async {
    if (_isReportingEvent) {
      return;
    }

    final eventId = event.reference.id;
    final dataKey = _eventStreamDataKey;
    final reportRequest = await showDialog<_EventReportDialogResult>(
      context: context,
      builder: (context) => const _EventReportDialog(),
    );
    if (reportRequest == null ||
        !mounted ||
        dataKey != _eventStreamDataKey ||
        _currentDetailEventId != eventId ||
        widget.eventId.trim() != eventId) {
      return;
    }
    await _handleReportEvent(eventId, reportRequest);
  }

  Future<void> _handleReportEvent(
    String eventId,
    _EventReportDialogResult reportRequest,
  ) async {
    if (_isReportingEvent) {
      return;
    }

    setState(() {
      _isReportingEvent = true;
    });
    try {
      final result = await EventActionsRepository.reportEvent(
        eventId: eventId,
        reasonCode: reportRequest.reasonCode,
        details: reportRequest.details,
        invoker: widget.reportEventInvoker,
      );
      if (!mounted) {
        return;
      }
      final message = result.alreadySubmitted
          ? FFLocalizations.of(context).getVariableText(
              ruText: 'Жалоба уже отправлена.',
              enText: 'Report already submitted.',
            )
          : FFLocalizations.of(context).getVariableText(
              ruText: 'Жалоба отправлена.',
              enText: 'Report submitted.',
            );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventDetailReportSuccessSnackBarKey,
          content: Text(message),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventDetailReportErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isReportingEvent = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _EventDetailSnapshotBuilder(
      key: ValueKey<_EventDetailRouteDataKey>(_eventStreamDataKey),
      stream: _eventStream,
      initialEvent: _eventInitialData,
      builder: (context, summary) {
        final initialPreview = _matchingInitialPreview;
        if (!summary.hasResolvedResult && initialPreview != null) {
          _currentDetailEventId = null;
          _clearNestedEventStreams();
          return _buildInitialPublicPreview(
            initialPreview,
            hasRefreshError: summary.hasError,
          );
        }
        if (summary.hasError && !summary.hasResolvedResult) {
          _currentDetailEventId = null;
          return const _EventDetailRouteStateScaffold(
            stateKey: eventDetailRouteErrorKey,
            titleRu: 'Не удалось загрузить событие',
            titleEn: 'Could not load event',
            messageRu: 'Проверьте подключение и попробуйте снова.',
            messageEn: 'Check your connection and try again.',
          );
        }

        if (!summary.hasResolvedResult) {
          _currentDetailEventId = null;
          return const _EventDetailRouteStateScaffold(
            stateKey: eventDetailRouteLoadingKey,
            titleRu: 'Загрузка события...',
            titleEn: 'Loading event...',
            messageRu: 'Получаем детали события.',
            messageEn: 'Loading event details.',
            showProgress: true,
          );
        }

        final event = summary.event;
        if (event == null) {
          _currentDetailEventId = null;
          _clearNestedEventStreams();
          const missingState = _EventDetailRouteStateScaffold(
            stateKey: eventDetailRouteMissingKey,
            titleRu: 'Событие не найдено',
            titleEn: 'Event not found',
            messageRu: 'Возможно, событие удалено или ссылка устарела.',
            messageEn: 'The event may have been deleted or the link expired.',
          );
          return _EventDetailRefreshErrorOverlay(
            isVisible: summary.hasError && summary.isConfirmedMissing,
            child: missingState,
          );
        }

        final eventId = event.reference.id;
        _currentDetailEventId = eventId;
        _trackEventDetailOpenedIfNeeded(event);
        final isLocallyCanceled = _locallyCanceledEventId == eventId;
        final isLocallyJoined = _locallyJoinedEventId == eventId;
        final isLocallyLeft = _locallyLeftEventId == eventId;
        final hasLocalJoinedParticipantsCount =
            _locallyJoinedParticipantsCountEventId == eventId;
        final hasLocalLeftParticipantsCount =
            _locallyLeftParticipantsCountEventId == eventId;
        final snapshotParticipantsCount =
            event.hasParticipantsCount() ? event.participantsCount : null;
        final confirmedParticipantsCount =
            _eventDetailParticipantsCountForEvent(
          snapshotParticipantsCount: snapshotParticipantsCount,
          localJoinedParticipantsCount: hasLocalJoinedParticipantsCount
              ? _locallyJoinedParticipantsCount
              : null,
          localLeftParticipantsCount: hasLocalLeftParticipantsCount
              ? _locallyLeftParticipantsCount
              : null,
        );
        final status = event.status.trim();
        final isActive = status == 'active';
        final isCanceled = isLocallyCanceled || status == 'canceled';
        final hasStarted = _eventDetailHasStartedForRoute(
          eventId: eventId,
          startsAt: event.startsAt,
        );
        final canManage = _eventDetailCanCurrentUserManage(event);
        _clearLocalParticipantsCountIfSnapshotCaughtUp(
          eventId: eventId,
          snapshotParticipantsCount: snapshotParticipantsCount,
        );

        final participantUserId = currentUserUid.trim();
        final participantStream = _currentParticipantStreamFor(
          eventId: eventId,
          userId: participantUserId,
        );

        return StreamBuilder<EventParticipantsRecord?>(
          stream: participantStream,
          builder: (context, participantSnapshot) {
            final isActiveParticipant = _eventDetailIsActiveParticipant(
              participantSnapshot.data,
              eventId: eventId,
            );
            final isJoinedForActions =
                !isLocallyLeft && (isLocallyJoined || isActiveParticipant);
            final isOrganizerActiveParticipant =
                canManage && isActiveParticipant;
            final pendingMembershipIntent = _pendingMembershipIntent;
            final activePendingMembershipIntent = pendingMembershipIntent !=
                        null &&
                    pendingMembershipIntent.dataKey == _eventStreamDataKey &&
                    pendingMembershipIntent.dataKey.eventId == eventId &&
                    pendingMembershipIntent.generation ==
                        _participantActionGeneration
                ? pendingMembershipIntent
                : null;
            final hasResolvedParticipantSnapshot = !participantSnapshot
                    .hasError &&
                participantSnapshot.connectionState != ConnectionState.waiting;
            final pendingPreviewJoinCtaState = hasResolvedParticipantSnapshot
                ? null
                : _matchingInitialPreview?.joinCtaState;
            _clearLocalMembershipIfParticipantSnapshotCaughtUp(
              eventId: eventId,
              isActiveParticipant: isActiveParticipant,
              hasResolvedParticipantSnapshot: hasResolvedParticipantSnapshot,
            );
            _scheduleStartsAtRefreshIfNeeded(
              eventId: eventId,
              startsAt: event.startsAt,
              hasStarted: hasStarted,
              isActive: isActive,
              isCanceled: isCanceled,
              isJoined: isJoinedForActions,
            );
            final canOpenChat = eventId.trim().isNotEmpty &&
                !isLocallyLeft &&
                (isLocallyJoined || isActiveParticipant || canManage);
            final canMessageOrganizer = currentUserUid.trim().isNotEmpty &&
                event.organizerId.trim().isNotEmpty &&
                event.organizerId.trim() != currentUserUid.trim() &&
                isActive &&
                !isCanceled;
            final canAttemptReport = currentUserUid.trim().isNotEmpty &&
                isActive &&
                !isCanceled &&
                event.organizerId.trim() != currentUserUid.trim();
            final hasFullEventAccess = widget.snapshotStream != null ||
                isPaidPremiumSubscription(currentUserDocument) ||
                canManage ||
                isActiveParticipant;

            if (!hasFullEventAccess) {
              final previewDescription = event.description.length > 160
                  ? '${event.description.substring(0, 160).trim()}…'
                  : event.description;
              return EventDetailWidget(
                eventId: eventId,
                levelMin: event.levelMin,
                levelMax: event.levelMax,
                languageCode: event.languageCode,
                languageNameEn: event.languageNameEn,
                languageNameRu: event.languageNameRu,
                title: event.title,
                description: previewDescription,
                organizerDisplayName: event.organizerDisplayName,
                organizerPhotoUrl: event.organizerPhotoUrl,
                startsAt: event.startsAt,
                timeZoneId: event.timeZoneId,
                locationName: '',
                participants: const <EventDetailParticipantViewModel>[],
                participantsCount: null,
                capacity: null,
                joinCtaState:
                    pendingPreviewJoinCtaState ?? EventDetailJoinCtaState.join,
                onPrimaryCtaPressed:
                    isActive && pendingPreviewJoinCtaState == null
                        ? () => _handleJoin(
                              event,
                              displayedParticipantsCount:
                                  confirmedParticipantsCount ?? 0,
                            )
                        : null,
              );
            }

            return StreamBuilder<List<EventParticipantsRecord>>(
              stream: _activeParticipantsStreamFor(eventId),
              builder: (context, participantsSnapshot) {
                final participantRecords = participantsSnapshot.data ??
                    const <EventParticipantsRecord>[];
                final confirmedDesiredJoined = isLocallyLeft
                    ? false
                    : isLocallyJoined || isActiveParticipant
                        ? true
                        : hasResolvedParticipantSnapshot
                            ? false
                            : null;
                final desiredJoined =
                    activePendingMembershipIntent?.desiredJoined ??
                        confirmedDesiredJoined;
                final currentUserDocumentForPreview = currentUserDocument;
                final hasCurrentUserPreview =
                    currentUserDocumentForPreview != null &&
                        currentUserDocumentForPreview.reference.id ==
                            participantUserId;
                final baseParticipantViewModels =
                    _eventDetailParticipantViewModelsWithMembershipOverride(
                  participants: _eventDetailParticipantViewModelsForRoute(
                    event: event,
                    participants: participantRecords,
                  ),
                  currentUserId: participantUserId,
                  desiredJoined: desiredJoined,
                  currentUserDisplayName: hasCurrentUserPreview
                      ? currentUserDocumentForPreview.displayName
                      : '',
                  currentUserPhotoUrl: hasCurrentUserPreview
                      ? currentUserDocumentForPreview.photoUrl
                      : '',
                );
                final participantsCount =
                    _eventDetailParticipantsCountWithPendingIntent(
                  confirmedParticipantsCount: confirmedParticipantsCount,
                  pendingMembershipIntent: activePendingMembershipIntent,
                );
                final displayedParticipantsCount =
                    _eventDetailDisplayedParticipantsCount(
                  participantsCount: participantsCount,
                  participantTileCount: baseParticipantViewModels.length,
                );
                final pendingDesiredJoined =
                    activePendingMembershipIntent?.desiredJoined;
                final resolvedJoinCtaState = isCanceled
                    ? EventDetailJoinCtaState.canceled
                    : pendingDesiredJoined == true
                        ? EventDetailJoinCtaState.optimisticJoined
                        : pendingDesiredJoined == false
                            ? EventDetailJoinCtaState.optimisticLeft
                            : pendingPreviewJoinCtaState != null
                                ? pendingPreviewJoinCtaState
                                : _eventDetailJoinStateForEvent(
                                    event,
                                    isCanceled: false,
                                    isJoined: isJoinedForActions,
                                    isJoining: _isJoining,
                                    hasStarted: hasStarted,
                                    resolvedParticipantsCount:
                                        displayedParticipantsCount,
                                  );
                final joinCtaState = isOrganizerActiveParticipant &&
                        resolvedJoinCtaState == EventDetailJoinCtaState.joined
                    ? EventDetailJoinCtaState.joinedLocked
                    : resolvedJoinCtaState;
                final canJoin = (pendingPreviewJoinCtaState == null ||
                        hasResolvedParticipantSnapshot) &&
                    joinCtaState == EventDetailJoinCtaState.join;
                final canLeave = !isOrganizerActiveParticipant &&
                    (pendingPreviewJoinCtaState == null ||
                        hasResolvedParticipantSnapshot) &&
                    joinCtaState == EventDetailJoinCtaState.joined;

                Widget buildContent(
                  List<EventDetailParticipantViewModel>
                      resolvedParticipantViewModels,
                ) {
                  final content = EventDetailWidget(
                    eventId: eventId,
                    showReportAction: canAttemptReport,
                    onReportPressed: canAttemptReport && !_isReportingEvent
                        ? () => _showReportEventDialog(event)
                        : null,
                    levelMin: event.levelMin,
                    levelMax: event.levelMax,
                    languageCode: event.languageCode,
                    languageNameEn: event.languageNameEn,
                    languageNameRu: event.languageNameRu,
                    title: event.title,
                    description: event.description,
                    organizerDisplayName: event.organizerDisplayName,
                    organizerPhotoUrl: event.organizerPhotoUrl,
                    onOrganizerMessagePressed: canMessageOrganizer
                        ? () => _handleOrganizerMessage(event)
                        : null,
                    showOrganizerControls: canManage && isActive && !isCanceled,
                    onOrganizerEditPressed: _isCanceling
                        ? null
                        : () {
                            context.pushNamed(
                              EventEditWidget.routeName,
                              pathParameters: <String, String>{
                                'eventId': eventId,
                              },
                            );
                          },
                    onOrganizerCancelPressed: _isCanceling || isCanceled
                        ? null
                        : () => _handleOrganizerCancel(event),
                    startsAt: event.startsAt,
                    timeZoneId: event.timeZoneId,
                    locationName: event.locationName,
                    participants: resolvedParticipantViewModels,
                    participantsCount: participantsCount,
                    capacity: event.hasCapacity() ? event.capacity : null,
                    joinCtaState: joinCtaState,
                    onChatPressed: canOpenChat
                        ? () {
                            _trackEventChatOpened(event);
                            context.pushNamed(
                              EventGroupChatWidget.routeName,
                              pathParameters: <String, String>{
                                'eventId': eventId,
                              },
                            );
                          }
                        : null,
                    onPrimaryCtaPressed: isActive && !_isJoining && !_isLeaving
                        ? canJoin
                            ? () => _handleJoin(
                                  event,
                                  displayedParticipantsCount:
                                      displayedParticipantsCount,
                                )
                            : canLeave
                                ? () => _handleLeave(
                                      event,
                                      isActiveParticipant: isActiveParticipant,
                                      displayedParticipantsCount:
                                          displayedParticipantsCount,
                                    )
                                : null
                        : null,
                  );
                  final refreshingLabel =
                      FFLocalizations.of(context).getVariableText(
                    ruText: 'Обновляем событие',
                    enText: 'Refreshing event',
                  );
                  final refreshingContent = UxRefreshingIndicatorOverlay(
                    key: eventDetailRouteRefreshingIndicatorKey,
                    isRefreshing:
                        summary.connectionState == ConnectionState.waiting,
                    semanticsLabel: refreshingLabel,
                    padding: EdgeInsets.fromLTRB(
                      ExpatlioDesign.space8,
                      MediaQuery.paddingOf(context).top + ExpatlioDesign.space8,
                      ExpatlioDesign.space8,
                      ExpatlioDesign.space8,
                    ),
                    child: content,
                  );
                  return _EventDetailRefreshErrorOverlay(
                    isVisible: summary.hasError,
                    child: refreshingContent,
                  );
                }

                final injectedPublicProfilesLoader =
                    widget.publicProfilesLoader;
                final hasResolvedParticipantsSnapshot =
                    participantsSnapshot.data != null ||
                        (!participantsSnapshot.hasError &&
                            participantsSnapshot.connectionState !=
                                ConnectionState.waiting);
                final publicProfileUserIds =
                    _eventDetailPublicProfileUserIdsForRoute(
                  eventId: eventId,
                  organizerId: event.organizerId,
                  currentUserId: participantUserId,
                  includeCurrentUser: desiredJoined == true,
                  participantRecords: participantRecords,
                  visibleParticipants: baseParticipantViewModels,
                );
                return _EventDetailPublicProfileEnricher(
                  dataKey: _eventStreamDataKey,
                  participants: baseParticipantViewModels,
                  userIds: publicProfileUserIds,
                  enabled: hasResolvedParticipantsSnapshot &&
                      participantUserId.isNotEmpty &&
                      (injectedPublicProfilesLoader != null ||
                          widget.participantsStream == null),
                  loader: injectedPublicProfilesLoader ??
                      _eventDetailPublicProfilePreloadRepository.preload,
                  loaderIdentity: injectedPublicProfilesLoader ??
                      _eventDetailPublicProfilePreloadRepository,
                  builder: buildContent,
                );
              },
            );
          },
        );
      },
    );
  }

  void _scheduleStartsAtRefreshIfNeeded({
    required String eventId,
    required DateTime? startsAt,
    required bool hasStarted,
    required bool isActive,
    required bool isCanceled,
    required bool isJoined,
  }) {
    if (!isActive ||
        isCanceled ||
        !isJoined ||
        startsAt == null ||
        hasStarted) {
      _clearStartsAtRefreshTimer();
      return;
    }

    if (_startsAtRefreshTimer?.isActive == true &&
        _startsAtRefreshEventId == eventId &&
        _startsAtRefreshAt == startsAt) {
      return;
    }

    _clearStartsAtRefreshTimer();
    _startsAtRefreshEventId = eventId;
    _startsAtRefreshAt = startsAt;
    _startsAtRefreshTimer =
        Timer(startsAt.difference(DateTime.now().toUtc()), () {
      if (mounted) {
        setState(() {
          _locallyStartedEventId = eventId;
          _locallyStartedAt = startsAt;
        });
      }
    });
  }

  void _clearStartsAtRefreshTimer() {
    _startsAtRefreshTimer?.cancel();
    _startsAtRefreshTimer = null;
    _startsAtRefreshEventId = null;
    _startsAtRefreshAt = null;
  }

  bool _eventDetailHasStartedForRoute({
    required String eventId,
    required DateTime? startsAt,
  }) {
    return _eventDetailHasStarted(startsAt) ||
        (_locallyStartedEventId == eventId && _locallyStartedAt == startsAt);
  }

  void _clearLocalParticipantsCountIfSnapshotCaughtUp({
    required String eventId,
    required int? snapshotParticipantsCount,
  }) {
    final dataKey = _eventStreamDataKey;
    final localParticipantsCount = _locallyJoinedParticipantsCount;
    final localLeftParticipantsCount = _locallyLeftParticipantsCount;
    final shouldClearJoined =
        _locallyJoinedParticipantsCountEventId == eventId &&
            localParticipantsCount != null &&
            snapshotParticipantsCount != null &&
            snapshotParticipantsCount >= localParticipantsCount;
    final shouldClearLeft = _locallyLeftParticipantsCountEventId == eventId &&
        localLeftParticipantsCount != null &&
        snapshotParticipantsCount != null &&
        snapshotParticipantsCount <= localLeftParticipantsCount;
    if (!shouldClearJoined && !shouldClearLeft) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _eventStreamDataKey != dataKey ||
          (shouldClearJoined &&
              (_locallyJoinedParticipantsCountEventId != eventId ||
                  _locallyJoinedParticipantsCount != localParticipantsCount)) ||
          (shouldClearLeft &&
              (_locallyLeftParticipantsCountEventId != eventId ||
                  _locallyLeftParticipantsCount !=
                      localLeftParticipantsCount))) {
        return;
      }
      setState(() {
        if (shouldClearJoined) {
          _locallyJoinedParticipantsCountEventId = null;
          _locallyJoinedParticipantsCount = null;
        }
        if (shouldClearLeft) {
          _locallyLeftParticipantsCountEventId = null;
          _locallyLeftParticipantsCount = null;
        }
      });
    });
  }

  void _clearLocalMembershipIfParticipantSnapshotCaughtUp({
    required String eventId,
    required bool isActiveParticipant,
    required bool hasResolvedParticipantSnapshot,
  }) {
    final dataKey = _eventStreamDataKey;
    final actionGeneration = _participantActionGeneration;
    final shouldClearJoined =
        _locallyJoinedEventId == eventId && isActiveParticipant;
    final shouldClearLeft = _locallyLeftEventId == eventId &&
        hasResolvedParticipantSnapshot &&
        !isActiveParticipant;
    if (!shouldClearJoined && !shouldClearLeft) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _eventStreamDataKey != dataKey ||
          _participantActionGeneration != actionGeneration ||
          (shouldClearJoined && _locallyJoinedEventId != eventId) ||
          (shouldClearLeft && _locallyLeftEventId != eventId)) {
        return;
      }
      setState(() {
        if (shouldClearJoined) {
          _locallyJoinedEventId = null;
        }
        if (shouldClearLeft) {
          _locallyLeftEventId = null;
        }
      });
    });
  }

  void _trackEventDetailOpenedIfNeeded(EventsRecord event) {
    final payload = eventCityAnalyticsPayload(
      countryCode: event.countryCode,
      cityKey: event.cityKey,
    );
    if (payload == null) {
      return;
    }
    final trackingKey =
        '${event.reference.id}|${payload['countryCode']}|${payload['cityKey']}';
    if (_lastTrackedEventDetailOpenKey == trackingKey) {
      return;
    }
    _lastTrackedEventDetailOpenKey = trackingKey;
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    unawaited(
      tracker.trackEventDetailOpened(event).catchError(
            (Object error, StackTrace stackTrace) {},
          ),
    );
  }

  void _trackEventCanceledIfNeeded({
    required String eventId,
    required EventsRecord event,
    required EventsAnalyticsTracker tracker,
  }) {
    if (_lastTrackedCanceledEventId == eventId) {
      return;
    }
    _lastTrackedCanceledEventId = eventId;
    unawaited(
      Future<void>.sync(
        () => tracker.trackEventCanceled(event),
      ).catchError(
        (Object error, StackTrace stackTrace) {},
      ),
    );
  }

  void _trackEventJoinedIfNeeded({
    required String eventId,
    required EventsRecord event,
    required EventsAnalyticsTracker tracker,
  }) {
    if (_lastTrackedJoinedEventId == eventId) {
      return;
    }
    _lastTrackedJoinedEventId = eventId;
    unawaited(
      Future<void>.sync(
        () => tracker.trackEventJoined(event),
      ).catchError(
        (Object error, StackTrace stackTrace) {},
      ),
    );
  }

  void _trackEventLeftIfNeeded({
    required String eventId,
    required EventsRecord event,
    required EventsAnalyticsTracker tracker,
  }) {
    if (_lastTrackedLeftEventId == eventId) {
      return;
    }
    _lastTrackedLeftEventId = eventId;
    unawaited(
      Future<void>.sync(
        () => tracker.trackEventLeft(event),
      ).catchError(
        (Object error, StackTrace stackTrace) {},
      ),
    );
  }

  void _trackEventChatOpened(EventsRecord event) {
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    unawaited(
      Future<void>.sync(
        () => tracker.trackEventChatOpened(
          countryCode: event.countryCode,
          cityKey: event.cityKey,
        ),
      ).catchError(
        (Object error, StackTrace stackTrace) {},
      ),
    );
  }
}

typedef _EventDetailPublicProfileBuilder = Widget Function(
  List<EventDetailParticipantViewModel> participants,
);

class _EventDetailPublicProfileEnricher extends StatefulWidget {
  const _EventDetailPublicProfileEnricher({
    required this.dataKey,
    required this.participants,
    required this.userIds,
    required this.enabled,
    required this.loader,
    required this.loaderIdentity,
    required this.builder,
  });

  final _EventDetailRouteDataKey dataKey;
  final List<EventDetailParticipantViewModel> participants;
  final List<String> userIds;
  final bool enabled;
  final EventDetailPublicProfilesLoader loader;
  final Object loaderIdentity;
  final _EventDetailPublicProfileBuilder builder;

  @override
  State<_EventDetailPublicProfileEnricher> createState() =>
      _EventDetailPublicProfileEnricherState();
}

class _EventDetailPublicProfileEnricherState
    extends State<_EventDetailPublicProfileEnricher> {
  static const int _maxKnownProfiles = 64;

  _EventDetailRouteDataKey? _scopeDataKey;
  Object? _scopeLoaderIdentity;
  _EventDetailPublicProfileRequestKey? _requestKey;
  final LinkedHashMap<String, UserPublicProfilesRecord> _knownProfilesByUserId =
      LinkedHashMap<String, UserPublicProfilesRecord>();
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _configureRequest();
  }

  @override
  void didUpdateWidget(covariant _EventDetailPublicProfileEnricher oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configureRequest();
  }

  void _configureRequest() {
    final scopeChanged = _scopeDataKey != widget.dataKey ||
        !identical(_scopeLoaderIdentity, widget.loaderIdentity);
    if (scopeChanged) {
      _scopeDataKey = widget.dataKey;
      _scopeLoaderIdentity = widget.loaderIdentity;
      _requestKey = null;
      _requestGeneration += 1;
      _knownProfilesByUserId.clear();
    }
    if (!widget.enabled) {
      return;
    }

    final nextRequestKey = _EventDetailPublicProfileRequestKey(
      dataKey: widget.dataKey,
      userIds: widget.userIds,
      loaderIdentity: widget.loaderIdentity,
    );
    if (nextRequestKey == _requestKey) {
      return;
    }
    _requestKey = nextRequestKey;
    final requestGeneration = ++_requestGeneration;
    for (final userId in nextRequestKey.userIds) {
      final knownProfile = _knownProfilesByUserId.remove(userId);
      if (knownProfile != null) {
        _knownProfilesByUserId[userId] = knownProfile;
      }
    }
    final unknownUserIds = nextRequestKey.userIds
        .where((userId) => !_knownProfilesByUserId.containsKey(userId))
        .toList(growable: false);
    if (unknownUserIds.isEmpty) {
      return;
    }
    unawaited(
      _loadEventDetailPublicProfiles(
        userIds: unknownUserIds,
        loader: widget.loader,
      ).then((profilesByUserId) {
        if (!mounted ||
            requestGeneration != _requestGeneration ||
            nextRequestKey != _requestKey ||
            profilesByUserId.isEmpty) {
          return;
        }
        setState(() {
          for (final entry in profilesByUserId.entries) {
            _knownProfilesByUserId.remove(entry.key);
            _knownProfilesByUserId[entry.key] = entry.value;
          }
          while (_knownProfilesByUserId.length > _maxKnownProfiles) {
            _knownProfilesByUserId.remove(_knownProfilesByUserId.keys.first);
          }
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final participants = _knownProfilesByUserId.isEmpty
        ? widget.participants
        : _eventDetailParticipantViewModelsWithPublicProfiles(
            participants: widget.participants,
            profilesByUserId: _knownProfilesByUserId,
          );
    return widget.builder(participants);
  }
}

class _EventDetailPublicProfileRequestKey {
  _EventDetailPublicProfileRequestKey({
    required this.dataKey,
    required List<String> userIds,
    required this.loaderIdentity,
  }) : userIds = List<String>.unmodifiable(userIds);

  final _EventDetailRouteDataKey dataKey;
  final List<String> userIds;
  final Object loaderIdentity;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! _EventDetailPublicProfileRequestKey ||
        other.dataKey != dataKey ||
        !identical(other.loaderIdentity, loaderIdentity) ||
        other.userIds.length != userIds.length) {
      return false;
    }
    for (var index = 0; index < userIds.length; index += 1) {
      if (other.userIds[index] != userIds[index]) {
        return false;
      }
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        dataKey,
        identityHashCode(loaderIdentity),
        Object.hashAll(userIds),
      );
}

List<String> _eventDetailPublicProfileUserIdsForRoute({
  required String eventId,
  required String organizerId,
  required String currentUserId,
  required bool includeCurrentUser,
  required List<EventParticipantsRecord> participantRecords,
  required List<EventDetailParticipantViewModel> visibleParticipants,
}) {
  final eligibleUserIds = <String>{};
  for (final participant in participantRecords) {
    final userId = _eventDetailCanonicalParticipantUserId(
      participant,
      eventId: eventId,
    );
    if (userId.isNotEmpty) {
      eligibleUserIds.add(userId);
    }
  }

  final normalizedOrganizerId = organizerId.trim();
  if (isValidUserPublicProfileUserId(normalizedOrganizerId)) {
    eligibleUserIds.add(normalizedOrganizerId);
  }
  final normalizedCurrentUserId = currentUserId.trim();
  if (includeCurrentUser &&
      isValidUserPublicProfileUserId(normalizedCurrentUserId)) {
    eligibleUserIds.add(normalizedCurrentUserId);
  }

  final visibleUserIds = visibleParticipants
      .map((participant) => participant.userId.trim())
      .toSet();
  return eligibleUserIds.where(visibleUserIds.contains).toList(growable: false)
    ..sort();
}

Future<Map<String, UserPublicProfilesRecord>> _loadEventDetailPublicProfiles({
  required List<String> userIds,
  required EventDetailPublicProfilesLoader loader,
}) async {
  final requestedUserIds = Set<String>.unmodifiable(userIds);
  try {
    final result = await Future<UserPublicProfilePreloadResult>.sync(
      () => loader(requestedUserIds),
    );
    final profilesByUserId = <String, UserPublicProfilesRecord>{};
    for (final entry in result.profilesByUserId.entries) {
      final userId = entry.key;
      if (requestedUserIds.contains(userId) &&
          isValidUserPublicProfileRecordForUserId(entry.value, userId)) {
        profilesByUserId[userId] = entry.value;
      }
    }
    return Map<String, UserPublicProfilesRecord>.unmodifiable(
      profilesByUserId,
    );
  } catch (_) {
    return const <String, UserPublicProfilesRecord>{};
  }
}

List<EventDetailParticipantViewModel>
    _eventDetailParticipantViewModelsWithPublicProfiles({
  required List<EventDetailParticipantViewModel> participants,
  required Map<String, UserPublicProfilesRecord> profilesByUserId,
}) {
  return participants.map((participant) {
    final userId = participant.userId.trim();
    final profile = profilesByUserId[userId];
    if (profile == null ||
        !isValidUserPublicProfileRecordForUserId(profile, userId)) {
      return participant;
    }

    final publicDisplayName =
        _eventDetailVisibleParticipantDisplayName(profile.displayName);
    final publicPhotoUrl = profile.photoUrl.trim();
    return EventDetailParticipantViewModel(
      userId: participant.userId,
      displayName: publicDisplayName.isEmpty
          ? participant.displayName
          : publicDisplayName,
      photoUrl: publicPhotoUrl.isEmpty ? participant.photoUrl : publicPhotoUrl,
    );
  }).toList(growable: false);
}

class _EventReportDialogResult {
  const _EventReportDialogResult({
    required this.reasonCode,
    this.details,
  });

  final String reasonCode;
  final String? details;
}

class _EventReportReasonOption {
  const _EventReportReasonOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

class _EventReportDialog extends StatefulWidget {
  const _EventReportDialog();

  @override
  State<_EventReportDialog> createState() => _EventReportDialogState();
}

class _EventReportDialogState extends State<_EventReportDialog> {
  final TextEditingController _detailsController = TextEditingController();
  String? _selectedReasonCode;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = FFLocalizations.of(context);
    final options = _eventReportReasonOptions(context);

    return AlertDialog(
      key: eventDetailReportDialogKey,
      title: Text(
        localizations.getVariableText(
          ruText: 'Пожаловаться на событие',
          enText: 'Report event',
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  ChoiceChip(
                    key: eventDetailReportReasonKey(option.code),
                    label: Text(option.label),
                    selected: _selectedReasonCode == option.code,
                    onSelected: (_) {
                      setState(() {
                        _selectedReasonCode = option.code;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: eventDetailReportDetailsFieldKey,
              controller: _detailsController,
              maxLines: 3,
              maxLength: eventReportDetailsMaxLength,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: localizations.getVariableText(
                  ruText: 'Комментарий',
                  enText: 'Comment',
                ),
                hintText: localizations.getVariableText(
                  ruText: 'Можно оставить пустым',
                  enText: 'Optional',
                ),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: ExpatlioDesign.border),
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.controlRadius),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: eventDetailReportDismissButtonKey,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            localizations.getVariableText(
              ruText: 'Отмена',
              enText: 'Cancel',
            ),
          ),
        ),
        FilledButton(
          key: eventDetailReportSubmitButtonKey,
          onPressed: _selectedReasonCode == null
              ? null
              : () {
                  Navigator.of(context).pop(
                    _EventReportDialogResult(
                      reasonCode: _selectedReasonCode!,
                      details: _detailsController.text,
                    ),
                  );
                },
          child: Text(
            localizations.getVariableText(
              ruText: 'Отправить',
              enText: 'Submit',
            ),
          ),
        ),
      ],
    );
  }
}

List<_EventReportReasonOption> _eventReportReasonOptions(
  BuildContext context,
) {
  final localizations = FFLocalizations.of(context);
  return [
    _EventReportReasonOption(
      code: 'spam',
      label: localizations.getVariableText(
        ruText: 'Спам',
        enText: 'Spam',
      ),
    ),
    _EventReportReasonOption(
      code: 'offensive',
      label: localizations.getVariableText(
        ruText: 'Оскорбления',
        enText: 'Offensive',
      ),
    ),
    _EventReportReasonOption(
      code: 'unsafe',
      label: localizations.getVariableText(
        ruText: 'Небезопасно',
        enText: 'Unsafe',
      ),
    ),
    _EventReportReasonOption(
      code: 'other',
      label: localizations.getVariableText(
        ruText: 'Другое',
        enText: 'Other',
      ),
    ),
  ];
}

List<EventDetailParticipantViewModel>
    _eventDetailParticipantViewModelsForRoute({
  required EventsRecord event,
  required List<EventParticipantsRecord> participants,
}) {
  final organizerId = event.organizerId.trim();
  final organizerDisplayName = event.organizerDisplayName.trim();
  final organizerPhotoUrl = event.organizerPhotoUrl.trim();
  final hasOrganizerParticipant = organizerId.isNotEmpty &&
      participants.any(
        (participant) =>
            _eventDetailCanonicalParticipantUserId(
              participant,
              eventId: event.reference.id,
            ) ==
            organizerId,
      );

  final participantViewModels = participants.map((participant) {
    final participantUserId = _eventDetailCanonicalParticipantUserId(
      participant,
      eventId: event.reference.id,
    );
    final isOrganizer =
        organizerId.isNotEmpty && participantUserId == organizerId;
    final participantDisplayName =
        _eventDetailVisibleParticipantDisplayName(participant.displayName);
    final displayName = participantDisplayName.isNotEmpty
        ? participantDisplayName
        : isOrganizer
            ? organizerDisplayName
            : '';
    final photoUrl = participant.photoUrl.trim().isNotEmpty
        ? participant.photoUrl.trim()
        : isOrganizer
            ? organizerPhotoUrl
            : '';

    return EventDetailParticipantViewModel(
      userId: participantUserId,
      displayName: displayName,
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
    );
  }).toList(growable: false);

  if (organizerId.isEmpty || hasOrganizerParticipant) {
    return participantViewModels;
  }

  return [
    EventDetailParticipantViewModel(
      userId: organizerId,
      displayName: organizerDisplayName,
      photoUrl: organizerPhotoUrl.isEmpty ? null : organizerPhotoUrl,
    ),
    ...participantViewModels,
  ];
}

String _eventDetailCanonicalParticipantUserId(
  EventParticipantsRecord participant, {
  required String eventId,
}) {
  final referenceUserId = participant.reference.id;
  if (!isValidUserPublicProfileUserId(referenceUserId) ||
      participant.reference.parent.parent?.path !=
          EventsRecord.collection.doc(eventId).path) {
    return '';
  }
  final storedUserId = participant.userId;
  if (!participant.hasUserId() || storedUserId.isEmpty) {
    return referenceUserId;
  }
  return storedUserId == referenceUserId ? referenceUserId : '';
}

List<EventDetailParticipantViewModel>
    _eventDetailParticipantViewModelsWithMembershipOverride({
  required List<EventDetailParticipantViewModel> participants,
  required String currentUserId,
  required bool? desiredJoined,
  required String currentUserDisplayName,
  required String currentUserPhotoUrl,
}) {
  final userId = currentUserId.trim();
  if (userId.isEmpty || desiredJoined == null) {
    return participants;
  }

  if (!desiredJoined) {
    return participants
        .where((participant) => participant.userId.trim() != userId)
        .toList(growable: false);
  }

  var foundCurrentUser = false;
  final deduplicatedParticipants = <EventDetailParticipantViewModel>[];
  for (final participant in participants) {
    if (participant.userId.trim() != userId) {
      deduplicatedParticipants.add(participant);
      continue;
    }
    if (!foundCurrentUser) {
      deduplicatedParticipants.add(participant);
      foundCurrentUser = true;
    }
  }
  if (foundCurrentUser) {
    return deduplicatedParticipants;
  }
  final displayName =
      _eventDetailVisibleParticipantDisplayName(currentUserDisplayName);
  final photoUrl = currentUserPhotoUrl.trim();
  return [
    ...deduplicatedParticipants,
    EventDetailParticipantViewModel(
      userId: userId,
      displayName: displayName,
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
    ),
  ];
}

int _eventDetailOptimisticParticipantsCount({
  required int displayedParticipantsCount,
  required bool desiredJoined,
}) {
  final normalizedCount =
      displayedParticipantsCount < 0 ? 0 : displayedParticipantsCount;
  if (desiredJoined) {
    return normalizedCount + 1;
  }
  return normalizedCount > 0 ? normalizedCount - 1 : 0;
}

int? _eventDetailParticipantsCountWithPendingIntent({
  required int? confirmedParticipantsCount,
  required _EventDetailPendingMembershipIntent? pendingMembershipIntent,
}) {
  final pendingIntent = pendingMembershipIntent;
  if (pendingIntent == null) {
    return confirmedParticipantsCount;
  }

  final optimisticCount = pendingIntent.optimisticParticipantsCount;
  final confirmedCount = confirmedParticipantsCount;
  if (confirmedCount == null) {
    return optimisticCount;
  }
  if (pendingIntent.desiredJoined) {
    return confirmedCount > optimisticCount ? confirmedCount : optimisticCount;
  }
  return confirmedCount < optimisticCount ? confirmedCount : optimisticCount;
}

int _eventDetailDisplayedParticipantsCount({
  required int? participantsCount,
  required int participantTileCount,
}) {
  final normalizedCount = participantsCount == null || participantsCount < 0
      ? 0
      : participantsCount;
  return normalizedCount < participantTileCount
      ? participantTileCount
      : normalizedCount;
}

String _eventDetailVisibleParticipantDisplayName(String displayName) {
  final normalized = displayName.trim();
  final lower = normalized.toLowerCase();
  if (lower == 'участник' || lower == 'participant') {
    return '';
  }
  final visibleName = normalized
      .replaceAll(_eventDetailInvisibleParticipantNameCharacters, '')
      .trim();
  if (visibleName.isEmpty ||
      !_eventDetailParticipantNameLetterOrNumber.hasMatch(visibleName)) {
    return '';
  }
  return visibleName;
}

class _EventDetailRefreshErrorOverlay extends StatelessWidget {
  const _EventDetailRefreshErrorOverlay({
    required this.isVisible,
    required this.child,
  });

  final bool isVisible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось обновить событие',
      enText: 'Could not refresh event',
    );
    return UxRefreshingIndicatorOverlay(
      isRefreshing: isVisible,
      semanticsLabel: label,
      padding: EdgeInsets.fromLTRB(
        ExpatlioDesign.space8,
        MediaQuery.paddingOf(context).top + ExpatlioDesign.space8,
        ExpatlioDesign.space8,
        ExpatlioDesign.space8,
      ),
      indicator: ExcludeSemantics(
        child: Material(
          key: eventDetailRouteRefreshErrorIndicatorKey,
          color: ExpatlioDesign.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
            side: const BorderSide(color: ExpatlioDesign.border),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ExpatlioDesign.space12,
              vertical: ExpatlioDesign.space8,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.cloud_off_outlined,
                  size: 16,
                  color: ExpatlioDesign.systemRed,
                ),
                const SizedBox(width: ExpatlioDesign.space8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 13,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}

class _EventDetailRouteStateScaffold extends StatelessWidget {
  const _EventDetailRouteStateScaffold({
    required this.stateKey,
    required this.titleRu,
    required this.titleEn,
    required this.messageRu,
    required this.messageEn,
    this.showProgress = false,
  });

  final Key stateKey;
  final String titleRu;
  final String titleEn;
  final String messageRu;
  final String messageEn;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: Column(
          children: [
            const EventDetailTopBar(
              onSharePressed: null,
              showReportAction: false,
              onReportPressed: null,
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(
                    ExpatlioDesign.space24,
                  ),
                  child: Column(
                    key: stateKey,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showProgress) ...[
                        const SizedBox.square(
                          dimension: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.8),
                        ),
                        const SizedBox(height: ExpatlioDesign.space20),
                      ],
                      Text(
                        FFLocalizations.of(context).getVariableText(
                          ruText: titleRu,
                          enText: titleEn,
                        ),
                        textAlign: TextAlign.center,
                        style: ExpatlioDesign.pageHeaderTitleStyle(context),
                      ),
                      const SizedBox(height: ExpatlioDesign.space8),
                      Text(
                        FFLocalizations.of(context).getVariableText(
                          ruText: messageRu,
                          enText: messageEn,
                        ),
                        textAlign: TextAlign.center,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: ExpatlioDesign.muted,
                          size: 15,
                          weight: FontWeight.w500,
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
    );
  }
}

EventDetailJoinCtaState _eventDetailJoinStateForEvent(
  EventsRecord event, {
  required bool isCanceled,
  required bool isJoined,
  required bool isJoining,
  required bool hasStarted,
  required int? resolvedParticipantsCount,
}) {
  if (isCanceled) {
    return EventDetailJoinCtaState.canceled;
  }
  if (isJoining) {
    return EventDetailJoinCtaState.joining;
  }

  if (isJoined) {
    return hasStarted
        ? EventDetailJoinCtaState.joinedLocked
        : EventDetailJoinCtaState.joined;
  }
  if (hasStarted) {
    return EventDetailJoinCtaState.past;
  }

  if (event.hasCapacity()) {
    final capacity = event.capacity;
    final participantsCount = resolvedParticipantsCount ?? 0;
    if (capacity > 0 && participantsCount >= capacity) {
      return EventDetailJoinCtaState.full;
    }
  }

  return EventDetailJoinCtaState.join;
}

bool _eventDetailHasStarted(DateTime? startsAt) {
  return startsAt != null && !startsAt.isAfter(DateTime.now().toUtc());
}

int? _eventDetailParticipantsCountForEvent({
  required int? snapshotParticipantsCount,
  required int? localJoinedParticipantsCount,
  required int? localLeftParticipantsCount,
}) {
  final localJoinedCount = localJoinedParticipantsCount;
  if (localJoinedCount != null) {
    final snapshotCount = snapshotParticipantsCount;
    if (snapshotCount == null || snapshotCount < localJoinedCount) {
      return localJoinedCount;
    }
    return snapshotCount;
  }

  final localLeftCount = localLeftParticipantsCount;
  if (localLeftCount != null) {
    final snapshotCount = snapshotParticipantsCount;
    if (snapshotCount == null || snapshotCount > localLeftCount) {
      return localLeftCount;
    }
    return snapshotCount;
  }

  return snapshotParticipantsCount;
}

bool _eventDetailCanCurrentUserManage(EventsRecord event) {
  final organizerId = event.organizerId.trim();
  final userId = currentUserUid.trim();
  return organizerId.isNotEmpty && userId.isNotEmpty && organizerId == userId;
}

bool _eventDetailIsActiveParticipant(
  EventParticipantsRecord? participant, {
  required String eventId,
}) {
  if (participant == null) {
    return false;
  }
  return _eventDetailCanonicalParticipantUserId(
            participant,
            eventId: eventId,
          ) ==
          currentUserUid.trim() &&
      participant.status.trim() == 'active';
}
