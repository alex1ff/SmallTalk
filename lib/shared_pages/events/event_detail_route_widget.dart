import 'dart:async';

import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/events/event_detail_widget.dart';
import '/shared_pages/events/event_edit_widget.dart';
import '/services/event_action_error_mapper.dart';
import '/services/event_actions_repository.dart';
import '/services/event_detail_repository.dart';

const ValueKey<String> eventDetailRouteLoadingKey =
    ValueKey<String>('event_detail_route_loading');
const ValueKey<String> eventDetailRouteMissingKey =
    ValueKey<String>('event_detail_route_missing');
const ValueKey<String> eventDetailRouteErrorKey =
    ValueKey<String>('event_detail_route_error');
const ValueKey<String> eventDetailCancelErrorSnackBarKey =
    ValueKey<String>('event_detail_cancel_error_snack_bar');

class EventDetailRouteWidget extends StatefulWidget {
  const EventDetailRouteWidget({
    super.key,
    required this.eventId,
    this.snapshotStream,
    this.cancelEventInvoker,
    this.joinEventInvoker,
    this.leaveEventInvoker,
  });

  final String eventId;
  final EventDetailSnapshotStream? snapshotStream;
  final EventCallableInvoker? cancelEventInvoker;
  final EventCallableInvoker? joinEventInvoker;
  final EventCallableInvoker? leaveEventInvoker;

  @override
  State<EventDetailRouteWidget> createState() => _EventDetailRouteWidgetState();
}

class _EventDetailRouteWidgetState extends State<EventDetailRouteWidget> {
  late Stream<EventsRecord?> _eventStream;
  bool _isCanceling = false;
  bool _isJoining = false;
  bool _isLeaving = false;
  String? _locallyCanceledEventId;
  String? _locallyJoinedEventId;
  int? _locallyJoinedParticipantsCount;
  int _participantActionGeneration = 0;

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
      _locallyCanceledEventId = null;
      _locallyJoinedEventId = null;
      _locallyJoinedParticipantsCount = null;
      _participantActionGeneration += 1;
      _isLeaving = false;
      _isJoining = false;
    }
  }

  Stream<EventsRecord?> _watchEvent() => EventDetailRepository.watchEventDetail(
        eventId: widget.eventId,
        snapshotStream: widget.snapshotStream,
      );

  Future<void> _handleOrganizerCancel() async {
    if (_isCanceling) {
      return;
    }

    setState(() {
      _isCanceling = true;
    });
    try {
      final result = await EventActionsRepository.cancelEvent(
        eventId: widget.eventId,
        invoker: widget.cancelEventInvoker,
      );
      if (!mounted) {
        return;
      }
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

  Future<void> _handleJoin() async {
    if (_isJoining || _isLeaving) {
      return;
    }

    final requestGeneration = _participantActionGeneration + 1;
    _participantActionGeneration = requestGeneration;

    setState(() {
      _isJoining = true;
    });
    try {
      final result = await EventActionsRepository.joinEvent(
        eventId: widget.eventId,
        invoker: widget.joinEventInvoker,
      );
      if (!mounted || requestGeneration != _participantActionGeneration) {
        return;
      }
      setState(() {
        _locallyJoinedEventId = result.eventId;
        _locallyJoinedParticipantsCount = result.participantsCount;
      });
    } catch (_) {
      // Clear loading only. User-facing join errors are handled in a later task.
    } finally {
      if (mounted && requestGeneration == _participantActionGeneration) {
        setState(() {
          _isJoining = false;
        });
      }
    }
  }

  Future<void> _handleLeave(String eventId) async {
    if (_isJoining || _isLeaving) {
      return;
    }
    if (_locallyJoinedEventId != eventId) {
      return;
    }

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
      setState(() {
        if (_locallyJoinedEventId == result.eventId) {
          _locallyJoinedEventId = null;
          _locallyJoinedParticipantsCount = null;
        }
      });
    } catch (_) {
      // Clear loading only. User-facing leave errors are handled in a later task.
    } finally {
      if (mounted && requestGeneration == _participantActionGeneration) {
        setState(() {
          _isLeaving = false;
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
          return const _EventDetailRouteStateScaffold(
            stateKey: eventDetailRouteErrorKey,
            titleRu: 'Не удалось загрузить событие',
            titleEn: 'Could not load event',
            messageRu: 'Проверьте подключение и попробуйте снова.',
            messageEn: 'Check your connection and try again.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
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
          return const _EventDetailRouteStateScaffold(
            stateKey: eventDetailRouteMissingKey,
            titleRu: 'Событие не найдено',
            titleEn: 'Event not found',
            messageRu: 'Возможно, событие удалено или ссылка устарела.',
            messageEn: 'The event may have been deleted or the link expired.',
          );
        }

        final eventId = event.reference.id;
        final isLocallyCanceled = _locallyCanceledEventId == eventId;
        final isLocallyJoined = _locallyJoinedEventId == eventId;
        final snapshotParticipantsCount =
            event.hasParticipantsCount() ? event.participantsCount : null;
        final participantsCount = _eventDetailParticipantsCountForEvent(
          snapshotParticipantsCount: snapshotParticipantsCount,
          localJoinedParticipantsCount:
              isLocallyJoined ? _locallyJoinedParticipantsCount : null,
        );
        final status = event.status.trim();
        final isActive = status == 'active';
        final isCanceled = isLocallyCanceled || status == 'canceled';
        final canManage = _eventDetailCanCurrentUserManage(event);
        final joinCtaState = _eventDetailJoinStateForEvent(
          event,
          isCanceled: isCanceled,
          isJoined: isLocallyJoined,
          isJoining: _isJoining,
        );
        final canJoin = joinCtaState == EventDetailJoinCtaState.join;
        final canLeave = joinCtaState == EventDetailJoinCtaState.joined;
        _clearLocalParticipantsCountIfSnapshotCaughtUp(
          eventId: eventId,
          snapshotParticipantsCount: snapshotParticipantsCount,
        );

        return EventDetailWidget(
          eventId: eventId,
          levelMin: event.levelMin,
          levelMax: event.levelMax,
          languageCode: event.languageCode,
          languageNameEn: event.languageNameEn,
          languageNameRu: event.languageNameRu,
          title: event.title,
          description: event.description,
          organizerDisplayName: event.organizerDisplayName,
          organizerPhotoUrl: event.organizerPhotoUrl,
          showOrganizerControls: canManage && isActive && !isCanceled,
          onOrganizerEditPressed: _isCanceling
              ? null
              : () {
                  context.pushNamed(
                    EventEditWidget.routeName,
                    pathParameters: <String, String>{'eventId': eventId},
                  );
                },
          onOrganizerCancelPressed:
              _isCanceling || isCanceled ? null : _handleOrganizerCancel,
          startsAt: event.startsAt,
          timeZoneId: event.timeZoneId,
          locationName: event.locationName,
          participantsCount: participantsCount,
          capacity: event.hasCapacity() ? event.capacity : null,
          joinCtaState: joinCtaState,
          onPrimaryCtaPressed: isActive && !_isJoining && !_isLeaving
              ? canJoin
                  ? _handleJoin
                  : canLeave
                      ? () => _handleLeave(eventId)
                      : null
              : null,
        );
      },
    );
  }

  void _clearLocalParticipantsCountIfSnapshotCaughtUp({
    required String eventId,
    required int? snapshotParticipantsCount,
  }) {
    final localParticipantsCount = _locallyJoinedParticipantsCount;
    if (_locallyJoinedEventId != eventId ||
        localParticipantsCount == null ||
        snapshotParticipantsCount == null ||
        snapshotParticipantsCount < localParticipantsCount) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _locallyJoinedEventId != eventId ||
          _locallyJoinedParticipantsCount != localParticipantsCount) {
        return;
      }
      setState(() {
        _locallyJoinedParticipantsCount = null;
      });
    });
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
}) {
  if (isCanceled) {
    return EventDetailJoinCtaState.canceled;
  }
  if (isJoining) {
    return EventDetailJoinCtaState.joining;
  }
  if (isJoined) {
    return EventDetailJoinCtaState.joined;
  }

  final startsAt = event.startsAt;
  if (startsAt != null && !startsAt.isAfter(DateTime.now().toUtc())) {
    return EventDetailJoinCtaState.past;
  }

  if (event.hasCapacity()) {
    final capacity = event.capacity;
    final participantsCount =
        event.hasParticipantsCount() ? event.participantsCount : 0;
    if (capacity > 0 && participantsCount >= capacity) {
      return EventDetailJoinCtaState.full;
    }
  }

  return EventDetailJoinCtaState.join;
}

int? _eventDetailParticipantsCountForEvent({
  required int? snapshotParticipantsCount,
  required int? localJoinedParticipantsCount,
}) {
  final localCount = localJoinedParticipantsCount;
  if (localCount == null) {
    return snapshotParticipantsCount;
  }

  final snapshotCount = snapshotParticipantsCount;
  if (snapshotCount == null || snapshotCount < localCount) {
    return localCount;
  }
  return snapshotCount;
}

bool _eventDetailCanCurrentUserManage(EventsRecord event) {
  final organizerId = event.organizerId.trim();
  final userId = currentUserUid.trim();
  return organizerId.isNotEmpty && userId.isNotEmpty && organizerId == userId;
}
