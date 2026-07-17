import 'dart:async';

import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/chat_thread/open_chat_thread.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/events/event_detail_widget.dart';
import '/shared_pages/events/event_edit_widget.dart';
import '/shared_pages/events/event_group_chat_widget.dart';
import '/services/event_action_error_mapper.dart';
import '/services/event_actions_repository.dart';
import '/services/event_detail_repository.dart';
import '/services/events_analytics_service.dart';

const ValueKey<String> eventDetailRouteLoadingKey =
    ValueKey<String>('event_detail_route_loading');
const ValueKey<String> eventDetailRouteMissingKey =
    ValueKey<String>('event_detail_route_missing');
const ValueKey<String> eventDetailRouteErrorKey =
    ValueKey<String>('event_detail_route_error');
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

ValueKey<String> eventDetailReportReasonKey(String reasonCode) =>
    ValueKey<String>('event_detail_report_reason_$reasonCode');

typedef EventChatThreadOpener = Future<void> Function(
  BuildContext context, {
  required DocumentReference? conversationRef,
  ConversationsRecord? initialConversation,
});

class EventDetailRouteWidget extends StatefulWidget {
  const EventDetailRouteWidget({
    super.key,
    required this.eventId,
    this.snapshotStream,
    this.cancelEventInvoker,
    this.joinEventInvoker,
    this.leaveEventInvoker,
    this.reportEventInvoker,
    this.participantSnapshotStream,
    this.participantsStream,
    this.participantPublicProfilesStream,
    this.openOrganizerChatInvoker,
    this.chatThreadOpener,
    this.analyticsTracker,
  });

  final String eventId;
  final EventDetailSnapshotStream? snapshotStream;
  final EventCallableInvoker? cancelEventInvoker;
  final EventCallableInvoker? joinEventInvoker;
  final EventCallableInvoker? leaveEventInvoker;
  final EventCallableInvoker? reportEventInvoker;
  final EventParticipantSnapshotStream? participantSnapshotStream;
  final EventActiveParticipantsStream? participantsStream;
  final EventParticipantPublicProfilesStream? participantPublicProfilesStream;
  final EventCallableInvoker? openOrganizerChatInvoker;
  final EventChatThreadOpener? chatThreadOpener;
  final EventsAnalyticsTracker? analyticsTracker;

  @override
  State<EventDetailRouteWidget> createState() => _EventDetailRouteWidgetState();
}

class _EventDetailRouteWidgetState extends State<EventDetailRouteWidget> {
  late Stream<EventsRecord?> _eventStream;
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
  int? _locallyJoinedParticipantsCount;
  String? _locallyLeftEventId;
  int? _locallyLeftParticipantsCount;
  String? _currentDetailEventId;
  int _participantActionGeneration = 0;
  String? _lastTrackedEventDetailOpenKey;
  String? _lastTrackedCanceledEventId;
  String? _lastTrackedJoinedEventId;
  String? _lastTrackedLeftEventId;

  @override
  void initState() {
    super.initState();
    _eventStream = _watchEvent();
  }

  @override
  void didUpdateWidget(covariant EventDetailRouteWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.snapshotStream != widget.snapshotStream) {
      _eventStream = _watchEvent();
      _clearStartsAtRefreshTimer();
      _locallyStartedEventId = null;
      _locallyStartedAt = null;
      _locallyCanceledEventId = null;
      _locallyJoinedEventId = null;
      _locallyJoinedParticipantsCount = null;
      _locallyLeftEventId = null;
      _locallyLeftParticipantsCount = null;
      _currentDetailEventId = null;
      _lastTrackedEventDetailOpenKey = null;
      _lastTrackedCanceledEventId = null;
      _lastTrackedJoinedEventId = null;
      _lastTrackedLeftEventId = null;
      _participantActionGeneration += 1;
      _isLeaving = false;
      _isJoining = false;
      _isOpeningOrganizerChat = false;
      _isReportingEvent = false;
    }
  }

  @override
  void dispose() {
    _clearStartsAtRefreshTimer();
    super.dispose();
  }

  Stream<EventsRecord?> _watchEvent() => EventDetailRepository.watchEventDetail(
        eventId: widget.eventId,
        snapshotStream: widget.snapshotStream,
      );

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

  Future<void> _handleJoin(EventsRecord event) async {
    if (_isJoining || _isLeaving) {
      return;
    }

    final eventId = event.reference.id;
    final tracker =
        widget.analyticsTracker ?? EventsAnalyticsService.defaultTracker;
    final requestGeneration = _participantActionGeneration + 1;
    _participantActionGeneration = requestGeneration;

    setState(() {
      _isJoining = true;
    });
    try {
      final result = await EventActionsRepository.joinEvent(
        eventId: eventId,
        invoker: widget.joinEventInvoker,
      );
      if (!mounted || requestGeneration != _participantActionGeneration) {
        return;
      }
      if (result.eventId == eventId) {
        _trackEventJoinedIfNeeded(
          eventId: result.eventId,
          event: event,
          tracker: tracker,
        );
      }
      setState(() {
        _locallyJoinedEventId = result.eventId;
        _locallyJoinedParticipantsCount = result.participantsCount;
        _locallyLeftEventId = null;
        _locallyLeftParticipantsCount = null;
        _lastTrackedLeftEventId = null;
      });
    } catch (error) {
      if (!mounted || requestGeneration != _participantActionGeneration) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventDetailJoinErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
    } finally {
      if (mounted && requestGeneration == _participantActionGeneration) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _handleLeave(
    EventsRecord event, {
    required bool isActiveParticipant,
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

    setState(() {
      _isLeaving = true;
    });
    try {
      final result = await EventActionsRepository.leaveEvent(
        eventId: eventId,
        invoker: widget.leaveEventInvoker,
      );
      if (!mounted || requestGeneration != _participantActionGeneration) {
        return;
      }
      if (result.eventId == eventId) {
        _trackEventLeftIfNeeded(
          eventId: result.eventId,
          event: event,
          tracker: tracker,
        );
      }
      setState(() {
        if (result.eventId == eventId) {
          _locallyJoinedEventId = null;
          _locallyJoinedParticipantsCount = null;
          _locallyLeftEventId = result.eventId;
          _locallyLeftParticipantsCount = result.participantsCount;
          _lastTrackedJoinedEventId = null;
        }
      });
    } catch (error) {
      if (!mounted || requestGeneration != _participantActionGeneration) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventDetailLeaveErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
    } finally {
      if (mounted && requestGeneration == _participantActionGeneration) {
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

    final optimisticConversationRef =
        _eventDetailOrganizerConversationRef(event);
    setState(() {
      _isOpeningOrganizerChat = true;
    });
    if (optimisticConversationRef != null) {
      _openChatThreadInBackground(optimisticConversationRef);
    }
    try {
      final result = await EventActionsRepository.openEventOrganizerChat(
        eventId: event.reference.id,
        invoker: widget.openOrganizerChatInvoker,
      );
      if (!mounted) {
        return;
      }
      final conversationRef = FirebaseFirestore.instance.doc(
        result.conversationPath,
      );
      if (optimisticConversationRef == null ||
          optimisticConversationRef.path != conversationRef.path) {
        await (widget.chatThreadOpener ?? openChatThread)(
          context,
          conversationRef: conversationRef,
        );
      }
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

  void _openChatThreadInBackground(DocumentReference conversationRef) {
    try {
      unawaited(
        (widget.chatThreadOpener ?? openChatThread)(
          context,
          conversationRef: conversationRef,
        ).catchError((Object error, StackTrace stackTrace) {}),
      );
    } catch (_) {}
  }

  Future<void> _showReportEventDialog(EventsRecord event) async {
    if (_isReportingEvent) {
      return;
    }

    final eventId = event.reference.id;
    final reportRequest = await showDialog<_EventReportDialogResult>(
      context: context,
      builder: (context) => const _EventReportDialog(),
    );
    if (reportRequest == null ||
        !mounted ||
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
    return StreamBuilder<EventsRecord?>(
      stream: _eventStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          _currentDetailEventId = null;
          return const _EventDetailRouteStateScaffold(
            stateKey: eventDetailRouteErrorKey,
            titleRu: 'Не удалось загрузить событие',
            titleEn: 'Could not load event',
            messageRu: 'Проверьте подключение и попробуйте снова.',
            messageEn: 'Check your connection and try again.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
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

        final event = snapshot.data;
        if (event == null) {
          _currentDetailEventId = null;
          return const _EventDetailRouteStateScaffold(
            stateKey: eventDetailRouteMissingKey,
            titleRu: 'Событие не найдено',
            titleEn: 'Event not found',
            messageRu: 'Возможно, событие удалено или ссылка устарела.',
            messageEn: 'The event may have been deleted or the link expired.',
          );
        }

        final eventId = event.reference.id;
        _currentDetailEventId = eventId;
        _trackEventDetailOpenedIfNeeded(event);
        final isLocallyCanceled = _locallyCanceledEventId == eventId;
        final isLocallyJoined = _locallyJoinedEventId == eventId;
        final isLocallyLeft = _locallyLeftEventId == eventId;
        final snapshotParticipantsCount =
            event.hasParticipantsCount() ? event.participantsCount : null;
        final participantsCount = _eventDetailParticipantsCountForEvent(
          snapshotParticipantsCount: snapshotParticipantsCount,
          localJoinedParticipantsCount:
              isLocallyJoined ? _locallyJoinedParticipantsCount : null,
          localLeftParticipantsCount:
              isLocallyLeft ? _locallyLeftParticipantsCount : null,
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

        final participantStream = currentUserUid.trim().isEmpty
            ? null
            : EventDetailRepository.watchCurrentUserParticipant(
                eventId: eventId,
                userId: currentUserUid,
                snapshotStream: widget.participantSnapshotStream,
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
            final resolvedJoinCtaState = _eventDetailJoinStateForEvent(
              event,
              isCanceled: isCanceled,
              isJoined: isJoinedForActions,
              isJoining: _isJoining,
              hasStarted: hasStarted,
              resolvedParticipantsCount: participantsCount,
            );
            final joinCtaState = isOrganizerActiveParticipant &&
                    resolvedJoinCtaState == EventDetailJoinCtaState.joined
                ? EventDetailJoinCtaState.joinedLocked
                : resolvedJoinCtaState;
            final canJoin = joinCtaState == EventDetailJoinCtaState.join;
            final canLeave = !isOrganizerActiveParticipant &&
                joinCtaState == EventDetailJoinCtaState.joined;
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

            return StreamBuilder<List<EventParticipantsRecord>>(
              stream: EventDetailRepository.watchActiveParticipants(
                eventId: eventId,
                participantsStream: widget.participantsStream,
              ),
              builder: (context, participantsSnapshot) {
                final activeParticipants = participantsSnapshot.data ??
                    const <EventParticipantsRecord>[];
                final publicProfileUserIds =
                    _eventDetailPublicProfileUserIdsForRoute(
                  event: event,
                  participants: activeParticipants,
                );

                return StreamBuilder<Map<String, UserPublicProfilesRecord?>>(
                  stream: EventDetailRepository.watchParticipantPublicProfiles(
                    userIds: publicProfileUserIds,
                    profilesStream: widget.participantPublicProfilesStream,
                  ),
                  builder: (context, publicProfilesSnapshot) {
                    final participantViewModels =
                        _eventDetailParticipantViewModelsWithLocalJoin(
                      participants: _eventDetailParticipantViewModelsForRoute(
                        event: event,
                        participants: activeParticipants,
                        publicProfilesByUserId: publicProfilesSnapshot.data ??
                            const <String, UserPublicProfilesRecord?>{},
                      ),
                      isLocallyJoined: isLocallyJoined,
                    );

                    return EventDetailWidget(
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
                      showOrganizerControls:
                          canManage && isActive && !isCanceled,
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
                      participants: participantViewModels,
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
                      onPrimaryCtaPressed:
                          isActive && !_isJoining && !_isLeaving
                              ? canJoin
                                  ? () => _handleJoin(event)
                                  : canLeave
                                      ? () => _handleLeave(
                                            event,
                                            isActiveParticipant:
                                                isActiveParticipant,
                                          )
                                      : null
                              : null,
                    );
                  },
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
    final localParticipantsCount = _locallyJoinedParticipantsCount;
    final localLeftParticipantsCount = _locallyLeftParticipantsCount;
    final shouldClearJoined = _locallyJoinedEventId == eventId &&
        localParticipantsCount != null &&
        snapshotParticipantsCount != null &&
        snapshotParticipantsCount >= localParticipantsCount;
    final shouldClearLeft = _locallyLeftEventId == eventId &&
        localLeftParticipantsCount != null &&
        snapshotParticipantsCount != null &&
        snapshotParticipantsCount <= localLeftParticipantsCount;
    if (!shouldClearJoined && !shouldClearLeft) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          (shouldClearJoined &&
              (_locallyJoinedEventId != eventId ||
                  _locallyJoinedParticipantsCount != localParticipantsCount)) ||
          (shouldClearLeft &&
              (_locallyLeftEventId != eventId ||
                  _locallyLeftParticipantsCount !=
                      localLeftParticipantsCount))) {
        return;
      }
      setState(() {
        if (shouldClearJoined) {
          _locallyJoinedParticipantsCount = null;
        }
        if (shouldClearLeft) {
          _locallyLeftParticipantsCount = null;
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
  Map<String, UserPublicProfilesRecord?> publicProfilesByUserId =
      const <String, UserPublicProfilesRecord?>{},
}) {
  final organizerId = event.organizerId.trim();
  final organizerDisplayName = event.organizerDisplayName.trim();
  final organizerPhotoUrl = event.organizerPhotoUrl.trim();
  final hasOrganizerParticipant = organizerId.isNotEmpty &&
      participants.any(
        (participant) => participant.userId.trim() == organizerId,
      );

  final participantViewModels = participants.map((participant) {
    final isOrganizer =
        organizerId.isNotEmpty && participant.userId.trim() == organizerId;
    final participantUserId = participant.userId.trim();
    final publicProfile = publicProfilesByUserId[participantUserId];
    final participantDisplayName =
        _eventDetailVisibleParticipantDisplayName(participant.displayName);
    final publicProfileDisplayName = _eventDetailVisibleParticipantDisplayName(
      publicProfile?.displayName ?? '',
    );
    final displayName = participantDisplayName.isNotEmpty
        ? participantDisplayName
        : isOrganizer
            ? organizerDisplayName
            : publicProfileDisplayName;
    final publicProfilePhotoUrl = publicProfile?.photoUrl.trim() ?? '';
    final photoUrl = participant.photoUrl.trim().isNotEmpty
        ? participant.photoUrl.trim()
        : isOrganizer
            ? organizerPhotoUrl
            : publicProfilePhotoUrl;

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

List<String> _eventDetailPublicProfileUserIdsForRoute({
  required EventsRecord event,
  required List<EventParticipantsRecord> participants,
}) {
  final organizerId = event.organizerId.trim();
  final userIds = <String>[];
  final seenUserIds = <String>{};
  for (final participant in participants) {
    final userId = participant.userId.trim();
    if (userId.isEmpty ||
        userId == organizerId ||
        seenUserIds.contains(userId)) {
      continue;
    }

    final hasVisibleDisplayName =
        _eventDetailVisibleParticipantDisplayName(participant.displayName)
            .isNotEmpty;
    final hasPhotoUrl = participant.photoUrl.trim().isNotEmpty;
    if (hasVisibleDisplayName && hasPhotoUrl) {
      continue;
    }

    seenUserIds.add(userId);
    userIds.add(userId);
  }
  return List.unmodifiable(userIds);
}

List<EventDetailParticipantViewModel>
    _eventDetailParticipantViewModelsWithLocalJoin({
  required List<EventDetailParticipantViewModel> participants,
  required bool isLocallyJoined,
}) {
  if (!isLocallyJoined) {
    return participants;
  }
  final userId = currentUserUid.trim();
  if (userId.isEmpty ||
      participants.any((participant) => participant.userId.trim() == userId)) {
    return participants;
  }
  final displayName =
      _eventDetailVisibleParticipantDisplayName(currentUserDisplayName);
  final photoUrl = currentUserPhoto.trim();
  return [
    ...participants,
    EventDetailParticipantViewModel(
      userId: userId,
      displayName: displayName,
      photoUrl: photoUrl.isEmpty ? null : photoUrl,
    ),
  ];
}

String _eventDetailVisibleParticipantDisplayName(String displayName) {
  final normalized = displayName.trim();
  final lower = normalized.toLowerCase();
  if (lower == 'участник' || lower == 'participant') {
    return '';
  }
  return normalized;
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
        child: Center(
          child: Padding(
            padding: const EdgeInsetsDirectional.all(ExpatlioDesign.space24),
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
  if (participant.parentReference.id != eventId) {
    return false;
  }
  return participant.userId.trim() == currentUserUid.trim() &&
      participant.status.trim() == 'active';
}
