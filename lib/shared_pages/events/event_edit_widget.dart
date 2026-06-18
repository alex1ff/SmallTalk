import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as timezone;

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/events/event_create_widget.dart';
import '/services/event_actions_repository.dart';
import '/services/event_city_catalog.dart';
import '/services/event_city_selection_source.dart';
import '/services/event_detail_repository.dart';
import '/services/event_language_catalog.dart';
import '/services/event_list_date_bounds.dart';
import '/services/event_selected_city_state.dart';

const ValueKey<String> eventEditLoadingKey =
    ValueKey<String>('event_edit_loading');
const ValueKey<String> eventEditMissingKey =
    ValueKey<String>('event_edit_missing');
const ValueKey<String> eventEditErrorKey = ValueKey<String>('event_edit_error');
const ValueKey<String> eventEditForbiddenKey =
    ValueKey<String>('event_edit_forbidden');

class EventEditWidget extends StatefulWidget {
  const EventEditWidget({
    super.key,
    required this.eventId,
    this.snapshotStream,
    this.cityCatalogOverride,
    this.languageCatalogOverride,
    this.editEventInvoker,
  });

  final String eventId;
  final EventDetailSnapshotStream? snapshotStream;
  final EventCityCatalog? cityCatalogOverride;
  final EventLanguageCatalog? languageCatalogOverride;
  final EventCallableInvoker? editEventInvoker;

  static String routeName = 'eventEdit';
  static String routePath = '/events/:eventId/edit';

  @override
  State<EventEditWidget> createState() => _EventEditWidgetState();
}

class _EventEditWidgetState extends State<EventEditWidget> {
  late Future<_EventEditLoadResult> _initialDataFuture;

  @override
  void initState() {
    super.initState();
    _initialDataFuture = _loadInitialData();
  }

  @override
  void didUpdateWidget(covariant EventEditWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.snapshotStream != widget.snapshotStream ||
        oldWidget.cityCatalogOverride != widget.cityCatalogOverride) {
      _initialDataFuture = _loadInitialData();
    }
  }

  Future<_EventEditLoadResult> _loadInitialData() async {
    final event = await EventDetailRepository.watchEventDetail(
      eventId: widget.eventId,
      snapshotStream: widget.snapshotStream,
    ).first;
    if (event == null) {
      return _EventEditLoadResult.missing();
    }
    if (!_eventEditCanCurrentUserEdit(event)) {
      return _EventEditLoadResult.forbidden();
    }

    final cityCatalog = await _loadCityCatalog();
    return _EventEditLoadResult.found(
      _EventEditInitialData.fromEvent(
        event: event,
        cityCatalog: cityCatalog,
      ),
    );
  }

  Future<EventCityCatalog> _loadCityCatalog() {
    final override = widget.cityCatalogOverride;
    if (override != null) {
      return Future.value(override);
    }
    return EventCityCatalog.loadFromAsset();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_EventEditLoadResult>(
      future: _initialDataFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _EventEditStateScaffold(
            stateKey: eventEditErrorKey,
            titleRu: 'Не удалось загрузить событие',
            titleEn: 'Could not load event',
            messageRu: 'Проверьте подключение и попробуйте снова.',
            messageEn: 'Check your connection and try again.',
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return _EventEditStateScaffold(
            stateKey: eventEditLoadingKey,
            titleRu: 'Загрузка события...',
            titleEn: 'Loading event...',
            messageRu: 'Подготавливаем форму редактирования.',
            messageEn: 'Preparing the edit form.',
            showProgress: true,
          );
        }

        final result = snapshot.data;
        if (result == null) {
          return _EventEditStateScaffold(
            stateKey: eventEditLoadingKey,
            titleRu: 'Загрузка события...',
            titleEn: 'Loading event...',
            messageRu: 'Подготавливаем форму редактирования.',
            messageEn: 'Preparing the edit form.',
            showProgress: true,
          );
        }

        final initialData = result.initialData;
        if (result.isForbidden) {
          return _EventEditStateScaffold(
            stateKey: eventEditForbiddenKey,
            titleRu: 'Редактирование недоступно',
            titleEn: 'Editing unavailable',
            messageRu: 'Редактировать событие может только организатор.',
            messageEn: 'Only the organizer can edit this event.',
          );
        }
        if (initialData == null) {
          return _EventEditStateScaffold(
            stateKey: eventEditMissingKey,
            titleRu: 'Событие не найдено',
            titleEn: 'Event not found',
            messageRu: 'Возможно, событие удалено или ссылка устарела.',
            messageEn: 'The event may have been deleted or the link expired.',
          );
        }

        return EventCreateWidget(
          formMode: EventFormMode.edit,
          eventId: widget.eventId,
          languageCatalogOverride: widget.languageCatalogOverride,
          cityCatalogOverride: initialData.cityCatalog,
          initialTitle: initialData.title,
          initialDescription: initialData.description,
          initialLanguageCode: initialData.languageCode,
          initialLevelMin: initialData.levelMin,
          initialLevelMax: initialData.levelMax,
          initialSelectedCity: initialData.selectedCity,
          initialLocationName: initialData.locationName,
          initialLocationGeoPoint: initialData.locationGeoPoint,
          initialDate: initialData.localDate,
          initialTime: initialData.localTime,
          initialCapacity: initialData.capacity,
          minimumCapacity: initialData.participantsCount,
          editEventInvoker: widget.editEventInvoker,
        );
      },
    );
  }
}

class _EventEditLoadResult {
  const _EventEditLoadResult._({
    this.initialData,
    this.isForbidden = false,
  });

  factory _EventEditLoadResult.found(_EventEditInitialData initialData) =>
      _EventEditLoadResult._(initialData: initialData);

  factory _EventEditLoadResult.missing() => const _EventEditLoadResult._();

  factory _EventEditLoadResult.forbidden() =>
      const _EventEditLoadResult._(isForbidden: true);

  final _EventEditInitialData? initialData;
  final bool isForbidden;
}

class _EventEditInitialData {
  const _EventEditInitialData({
    required this.cityCatalog,
    required this.title,
    required this.description,
    required this.languageCode,
    required this.levelMin,
    required this.levelMax,
    required this.selectedCity,
    required this.locationName,
    required this.locationGeoPoint,
    required this.localDate,
    required this.localTime,
    required this.capacity,
    required this.participantsCount,
  });

  factory _EventEditInitialData.fromEvent({
    required EventsRecord event,
    required EventCityCatalog cityCatalog,
  }) {
    final city = cityCatalog.resolve(event.countryCode, event.cityKey);
    final localStart = _eventEditLocalStartForEvent(
      event: event,
      city: city,
    );

    return _EventEditInitialData(
      cityCatalog: cityCatalog,
      title: event.title,
      description: event.description,
      languageCode: event.languageCode,
      levelMin: event.levelMin,
      levelMax: event.levelMax,
      selectedCity: city == null
          ? null
          : EventSelectedCity(
              city: city,
              source: EventCitySelectionSource.static,
            ),
      locationName: event.locationName,
      locationGeoPoint: event.locationGeoPoint,
      localDate: localStart?.date,
      localTime: localStart?.time,
      capacity: event.hasCapacity() ? event.capacity : null,
      participantsCount:
          event.hasParticipantsCount() ? event.participantsCount : 0,
    );
  }

  final EventCityCatalog cityCatalog;
  final String title;
  final String description;
  final String languageCode;
  final String levelMin;
  final String levelMax;
  final EventSelectedCity? selectedCity;
  final String locationName;
  final LatLng? locationGeoPoint;
  final DateTime? localDate;
  final TimeOfDay? localTime;
  final int? capacity;
  final int participantsCount;
}

class _EventEditLocalStart {
  const _EventEditLocalStart({
    required this.date,
    required this.time,
  });

  final DateTime date;
  final TimeOfDay time;
}

class _EventEditStateScaffold extends StatelessWidget {
  const _EventEditStateScaffold({
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventEditStateTopBar(
              onBackPressed: () => context.safePop(),
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

class _EventEditStateTopBar extends StatelessWidget {
  const _EventEditStateTopBar({
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
                ruText: 'Редактировать событие',
                enText: 'Edit event',
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

_EventEditLocalStart? _eventEditLocalStartForEvent({
  required EventsRecord event,
  required EventCity? city,
}) {
  final startsAt = event.startsAt;
  if (startsAt == null) {
    return null;
  }
  final timeZoneId = _eventEditTimeZoneId(event: event, city: city);
  if (timeZoneId == null) {
    return null;
  }

  try {
    final location = eventListTimeZoneLocation(timeZoneId);
    final utcInstant = startsAt.isUtc ? startsAt : startsAt.toUtc();
    final localInstant = timezone.TZDateTime.from(utcInstant, location);
    return _EventEditLocalStart(
      date: DateTime(
        localInstant.year,
        localInstant.month,
        localInstant.day,
      ),
      time: TimeOfDay(
        hour: localInstant.hour,
        minute: localInstant.minute,
      ),
    );
  } on ArgumentError {
    return null;
  }
}

String? _eventEditTimeZoneId({
  required EventsRecord event,
  required EventCity? city,
}) {
  final eventTimeZoneId = event.timeZoneId.trim();
  if (eventTimeZoneId.isNotEmpty) {
    return eventTimeZoneId;
  }
  final cityTimeZoneId = city?.timeZoneId.trim();
  if (cityTimeZoneId != null && cityTimeZoneId.isNotEmpty) {
    return cityTimeZoneId;
  }
  return null;
}

bool _eventEditCanCurrentUserEdit(EventsRecord event) {
  final organizerId = event.organizerId.trim();
  final userId = currentUserUid.trim();
  return organizerId.isNotEmpty && userId.isNotEmpty && organizerId == userId;
}
