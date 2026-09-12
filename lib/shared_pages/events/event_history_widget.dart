import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as timezone;

import '/components/app_loading_indicator.dart';
import '/components/basic_page_header.dart';
import '/components/empty/empty_widget.dart';
import '/components/ux_error_state.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/event_history_repository.dart';
import '/services/event_level_helper.dart';
import '/services/event_list_date_bounds.dart';
import '/services/ux_loading_state.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/events/event_detail_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';

const ValueKey<String> eventHistoryLoadingKey =
    ValueKey<String>('event_history_loading');
const ValueKey<String> eventHistoryEmptyKey =
    ValueKey<String>('event_history_empty');
const ValueKey<String> eventHistoryErrorKey =
    ValueKey<String>('event_history_error');
const ValueKey<String> eventHistoryListKey =
    ValueKey<String>('event_history_list');
const ValueKey<String> eventHistoryErrorRetryButtonKey =
    ValueKey<String>('event_history_error_retry_button');

ValueKey<String> eventHistoryItemKey(String eventId) =>
    ValueKey<String>('event_history_item_$eventId');

typedef EventHistoryLoader = Future<EventHistoryResult> Function(String userId);
typedef EventHistoryEventOpener = void Function(
  BuildContext context,
  EventHistoryItem item,
);

final class _StaleEventHistoryRequest implements Exception {
  const _StaleEventHistoryRequest();
}

final class _EventHistoryAuthEmission {
  const _EventHistoryAuthEmission({
    required this.userId,
    required this.epoch,
  });

  final String userId;
  final int epoch;
}

class EventHistoryWidget extends StatefulWidget {
  const EventHistoryWidget({
    super.key,
    this.historyLoader,
    this.eventOpener,
    this.authUidStream,
    this.userIdProvider,
  });

  static String routeName = 'eventHistory';
  static String routePath = '/profile/events';
  static final UxSessionLoadedResultCache<EventHistoryResult> _historyCache =
      UxSessionLoadedResultCache<EventHistoryResult>();
  static int _sessionCacheGeneration = 0;

  static Object _cacheKey(String ownerUid) => ['eventHistory', ownerUid];

  static void _ensureSessionCacheLifecycleRegistered() {
    UxSessionCacheLifecycle.register(debugClearSessionCache);
  }

  static EventHistoryResult? _cachedHistory(String ownerUid) =>
      _historyCache.read(_cacheKey(ownerUid))?.data;

  static void _cacheHistory(
    String ownerUid,
    EventHistoryResult result, {
    required int expectedGeneration,
  }) {
    if (expectedGeneration != _sessionCacheGeneration) {
      return;
    }
    _historyCache.write(
      UxLoadedResult<EventHistoryResult>.data(
        dataKey: _cacheKey(ownerUid),
        data: result,
      ),
    );
  }

  static void seedCreatedEvent({
    required String ownerUid,
    required EventHistoryItem item,
    required DateTime generatedAt,
  }) {
    final normalizedOwnerUid = ownerUid.trim();
    if (normalizedOwnerUid.isEmpty || !item.isOrganizer) {
      return;
    }
    final cached = _cachedHistory(normalizedOwnerUid);
    if (cached == null) {
      return;
    }
    final items = <EventHistoryItem>[
      item,
      ...cached.items.where((existing) => existing.eventId != item.eventId),
    ]..sort(_compareEventHistoryItems);
    _cacheHistory(
      normalizedOwnerUid,
      EventHistoryResult(
        items: List<EventHistoryItem>.unmodifiable(
          items.take(cached.limit),
        ),
        limit: cached.limit,
        generatedAt: generatedAt,
      ),
      expectedGeneration: _sessionCacheGeneration,
    );
  }

  @visibleForTesting
  static void debugClearSessionCache() {
    _sessionCacheGeneration += 1;
    _historyCache.clear();
  }

  final EventHistoryLoader? historyLoader;
  final EventHistoryEventOpener? eventOpener;
  @visibleForTesting
  final Stream<String>? authUidStream;
  @visibleForTesting
  final String Function()? userIdProvider;

  @override
  State<EventHistoryWidget> createState() => _EventHistoryWidgetState();
}

int _compareEventHistoryItems(EventHistoryItem left, EventHistoryItem right) {
  final leftUpcoming =
      left.timelineStatus == EventHistoryTimelineStatus.upcoming;
  final rightUpcoming =
      right.timelineStatus == EventHistoryTimelineStatus.upcoming;
  if (leftUpcoming != rightUpcoming) {
    return leftUpcoming ? -1 : 1;
  }
  final startsAtComparison = leftUpcoming
      ? left.startsAt.compareTo(right.startsAt)
      : right.startsAt.compareTo(left.startsAt);
  return startsAtComparison != 0
      ? startsAtComparison
      : left.eventId.compareTo(right.eventId);
}

class _EventHistoryWidgetState extends State<EventHistoryWidget> {
  Future<EventHistoryResult>? _historyFuture;
  EventHistoryResult? _lastLoadedResult;
  bool _hasAuthoritativeResult = false;
  late Stream<_EventHistoryAuthEmission> _authSessionStream;
  String _latestAuthStreamUserId = '';
  String? _lastObservedSessionCacheOwnerUid;
  int _latestAuthSessionEpoch = 0;
  String _historyOwnerUserId = '';
  int _historyOwnerEpoch = 0;
  int _historyRequestSerial = 0;

  @override
  void initState() {
    super.initState();
    EventHistoryWidget._ensureSessionCacheLifecycleRegistered();
    final initialOwnerUserId = _initialHistoryOwnerUserId();
    _latestAuthStreamUserId = initialOwnerUserId;
    _lastObservedSessionCacheOwnerUid =
        initialOwnerUserId.isEmpty ? null : initialOwnerUserId;
    _authSessionStream = _trackAuthSessions(
      widget.authUidStream ?? _watchEventHistoryOwnerIds(),
    );
  }

  @override
  void didUpdateWidget(covariant EventHistoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final authUidStreamChanged =
        oldWidget.authUidStream != widget.authUidStream;
    if (authUidStreamChanged) {
      _authSessionStream = _trackAuthSessions(
        widget.authUidStream ?? _watchEventHistoryOwnerIds(),
      );
      _latestAuthStreamUserId = '';
    }
    if (authUidStreamChanged ||
        oldWidget.historyLoader != widget.historyLoader) {
      _resetHistoryStateForOwner('', _latestAuthSessionEpoch);
    }
  }

  @override
  void dispose() {
    _historyRequestSerial += 1;
    super.dispose();
  }

  bool get _hasIndependentDirectAuthUid =>
      widget.userIdProvider != null || widget.authUidStream == null;

  String _directAuthUid() => (widget.userIdProvider?.call() ??
          FirebaseAuth.instance.currentUser?.uid ??
          '')
      .trim();

  String _initialHistoryOwnerUserId() =>
      widget.authUidStream == null && _hasIndependentDirectAuthUid
          ? _directAuthUid()
          : '';

  Stream<_EventHistoryAuthEmission> _trackAuthSessions(
    Stream<String> authUidStream,
  ) {
    return authUidStream.map((rawUserId) {
      final userId = rawUserId.trim();
      _observeSessionCacheOwner(userId);
      _latestAuthStreamUserId = userId;
      final epoch = ++_latestAuthSessionEpoch;
      return _EventHistoryAuthEmission(userId: userId, epoch: epoch);
    });
  }

  void _observeSessionCacheOwner(String ownerUserId) {
    final previousOwnerUserId = _lastObservedSessionCacheOwnerUid;
    if (previousOwnerUserId != null && previousOwnerUserId != ownerUserId) {
      EventHistoryWidget.debugClearSessionCache();
    }
    _lastObservedSessionCacheOwnerUid = ownerUserId;
  }

  _EventHistoryAuthEmission _initialAuthEmission() => _EventHistoryAuthEmission(
        userId: _initialHistoryOwnerUserId(),
        epoch: _latestAuthSessionEpoch,
      );

  String _historyOwnerUserIdForEmission(
    _EventHistoryAuthEmission emission,
  ) {
    final streamOwnerUserId = emission.userId;
    if (!_hasIndependentDirectAuthUid) {
      return streamOwnerUserId;
    }
    final directOwnerUserId = _directAuthUid();
    _observeSessionCacheOwner(directOwnerUserId);
    return streamOwnerUserId == directOwnerUserId ? directOwnerUserId : '';
  }

  bool _authBoundaryMatches(String ownerUserId, int ownerEpoch) {
    if (ownerUserId.isEmpty ||
        _latestAuthStreamUserId != ownerUserId ||
        _latestAuthSessionEpoch != ownerEpoch) {
      return false;
    }
    if (!_hasIndependentDirectAuthUid) {
      return true;
    }
    final directOwnerUserId = _directAuthUid();
    _observeSessionCacheOwner(directOwnerUserId);
    return directOwnerUserId == ownerUserId;
  }

  bool _requestIsCurrent(
    int requestId,
    String ownerUserId,
    int ownerEpoch,
    int cacheGeneration,
  ) =>
      mounted &&
      requestId == _historyRequestSerial &&
      ownerUserId == _historyOwnerUserId &&
      ownerEpoch == _historyOwnerEpoch &&
      ownerEpoch == _latestAuthSessionEpoch &&
      cacheGeneration == EventHistoryWidget._sessionCacheGeneration;

  void _invalidateForAuthBoundaryMismatch() {
    if (!mounted) {
      return;
    }
    if (_historyOwnerUserId.isEmpty &&
        _historyFuture == null &&
        !_hasAuthoritativeResult) {
      return;
    }
    setState(
      () => _resetHistoryStateForOwner('', _latestAuthSessionEpoch),
    );
  }

  void _syncHistoryOwner(String ownerUserId, int ownerEpoch) {
    if (ownerUserId == _historyOwnerUserId &&
        ownerEpoch == _historyOwnerEpoch) {
      return;
    }
    _resetHistoryStateForOwner(ownerUserId, ownerEpoch);
  }

  void _resetHistoryStateForOwner(String ownerUserId, int ownerEpoch) {
    final cachedResult = ownerUserId.isEmpty
        ? null
        : EventHistoryWidget._cachedHistory(ownerUserId);
    _historyOwnerUserId = ownerUserId;
    _historyOwnerEpoch = ownerEpoch;
    _lastLoadedResult = cachedResult;
    _hasAuthoritativeResult = cachedResult != null;
    _historyRequestSerial += 1;
    _historyFuture = ownerUserId.isEmpty
        ? null
        : _startHistoryLoad(
            ownerUserId: ownerUserId,
            ownerEpoch: ownerEpoch,
          );
  }

  Future<EventHistoryResult> _startHistoryLoad({
    String? ownerUserId,
    int? ownerEpoch,
    bool deferred = false,
  }) {
    final effectiveOwnerUserId = ownerUserId ?? _historyOwnerUserId;
    final effectiveOwnerEpoch = ownerEpoch ?? _historyOwnerEpoch;
    final cacheGeneration = EventHistoryWidget._sessionCacheGeneration;
    final requestId = ++_historyRequestSerial;
    if (deferred) {
      return Future<EventHistoryResult>.delayed(
        Duration.zero,
        () => _loadHistory(
          requestId,
          effectiveOwnerUserId,
          effectiveOwnerEpoch,
          cacheGeneration,
        ),
      );
    }
    return _loadHistory(
      requestId,
      effectiveOwnerUserId,
      effectiveOwnerEpoch,
      cacheGeneration,
    );
  }

  Future<EventHistoryResult> _loadHistory(
    int requestId,
    String ownerUserId,
    int ownerEpoch,
    int cacheGeneration,
  ) async {
    final loader = widget.historyLoader;
    try {
      final result = loader != null
          ? await loader(ownerUserId)
          : await EventHistoryRepository.loadEventHistory(
              limit: eventHistoryMaxLimit,
            );
      if (!_requestIsCurrent(
        requestId,
        ownerUserId,
        ownerEpoch,
        cacheGeneration,
      )) {
        throw const _StaleEventHistoryRequest();
      }
      if (!_authBoundaryMatches(ownerUserId, ownerEpoch)) {
        _invalidateForAuthBoundaryMismatch();
        throw const _StaleEventHistoryRequest();
      }
      final normalizedResult = EventHistoryResult(
        items: List<EventHistoryItem>.unmodifiable(result.items),
        limit: result.limit,
        generatedAt: result.generatedAt,
      );
      _lastLoadedResult = normalizedResult;
      _hasAuthoritativeResult = true;
      EventHistoryWidget._cacheHistory(
        ownerUserId,
        normalizedResult,
        expectedGeneration: cacheGeneration,
      );
      return normalizedResult;
    } catch (error) {
      if (error is _StaleEventHistoryRequest) {
        rethrow;
      }
      if (!_requestIsCurrent(
        requestId,
        ownerUserId,
        ownerEpoch,
        cacheGeneration,
      )) {
        throw const _StaleEventHistoryRequest();
      }
      if (!_authBoundaryMatches(ownerUserId, ownerEpoch)) {
        _invalidateForAuthBoundaryMismatch();
        throw const _StaleEventHistoryRequest();
      }
      if (_hasAuthoritativeResult) {
        return _lastLoadedResult!;
      }
      rethrow;
    }
  }

  void _reloadHistory() {
    if (!_authBoundaryMatches(_historyOwnerUserId, _historyOwnerEpoch)) {
      _invalidateForAuthBoundaryMismatch();
      return;
    }
    setState(() {
      _historyFuture = _startHistoryLoad(deferred: true);
    });
  }

  void _openEvent(
    EventHistoryItem item, {
    required String ownerUserId,
    required int ownerEpoch,
  }) {
    if (_historyOwnerUserId != ownerUserId ||
        _historyOwnerEpoch != ownerEpoch ||
        !_authBoundaryMatches(ownerUserId, ownerEpoch)) {
      _invalidateForAuthBoundaryMismatch();
      return;
    }
    final opener = widget.eventOpener;
    if (opener != null) {
      opener(context, item);
      return;
    }
    context.pushNamed(
      EventDetailWidget.routeName,
      pathParameters: <String, String>{'eventId': item.eventId},
    );
  }

  Widget _buildHeader(BuildContext context) {
    return BasicPageHeader(
      title: FFLocalizations.of(context).getVariableText(
        ruText: 'Мои события',
        enText: 'My events',
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Загрузка истории событий',
      enText: 'Loading event history',
    );
    return Center(
      child: Semantics(
        key: eventHistoryLoadingKey,
        container: true,
        liveRegion: true,
        label: label,
        child: const ExcludeSemantics(
          child: AppLoadingIndicator(),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final historyFuture = _historyFuture;
    final historyOwnerUserId = _historyOwnerUserId;
    final historyOwnerEpoch = _historyOwnerEpoch;
    if (historyFuture == null) {
      return _buildLoadingState(context);
    }

    return FutureBuilder<EventHistoryResult>(
      key: ValueKey<(String, int)>(
        (historyOwnerUserId, historyOwnerEpoch),
      ),
      future: historyFuture,
      builder: (context, snapshot) {
        if (snapshot.error is _StaleEventHistoryRequest) {
          return _buildLoadingState(context);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          if (_hasAuthoritativeResult) {
            final items = _lastLoadedResult!.items;
            return items.isEmpty
                ? _buildHistoryEmpty(context)
                : _buildHistoryList(
                    context,
                    items,
                    ownerUserId: historyOwnerUserId,
                    ownerEpoch: historyOwnerEpoch,
                  );
          }
          return _buildLoadingState(context);
        }

        if (snapshot.hasError) {
          if (_hasAuthoritativeResult) {
            final items = _lastLoadedResult!.items;
            return items.isEmpty
                ? _buildHistoryEmpty(context)
                : _buildHistoryList(
                    context,
                    items,
                    ownerUserId: historyOwnerUserId,
                    ownerEpoch: historyOwnerEpoch,
                  );
          }
          return _EventHistoryErrorState(onRetry: _reloadHistory);
        }

        final items = snapshot.data?.items ?? const <EventHistoryItem>[];
        if (items.isEmpty) {
          return _buildHistoryEmpty(context);
        }

        return _buildHistoryList(
          context,
          items,
          ownerUserId: historyOwnerUserId,
          ownerEpoch: historyOwnerEpoch,
        );
      },
    );
  }

  Widget _buildHistoryEmpty(BuildContext context) {
    return Center(
      key: eventHistoryEmptyKey,
      child: SizedBox(
        height: 500.0,
        child: EmptyWidget(
          txt: FFLocalizations.of(context).getVariableText(
            ruText:
                'Здесь появятся события, к которым вы присоединились или которые организовали.',
            enText: 'Events you joined or organized will appear here.',
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<EventHistoryItem> items, {
    required String ownerUserId,
    required int ownerEpoch,
  }) {
    final contentTopPadding = MediaQuery.paddingOf(context).top +
        BasicPageHeader.height +
        ExpatlioDesign.sectionSpacing;
    final list = ListView.separated(
      key: eventHistoryListKey,
      padding: EdgeInsets.fromLTRB(
        ExpatlioDesign.pagePadding,
        contentTopPadding,
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.pageBottomSpacing,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const SizedBox(height: ExpatlioDesign.space12),
      itemBuilder: (context, index) {
        final item = items[index];
        return _EventHistoryCard(
          item: item,
          onTap: () => _openEvent(
            item,
            ownerUserId: ownerUserId,
            ownerEpoch: ownerEpoch,
          ),
        );
      },
    );

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<_EventHistoryAuthEmission>(
      key: ObjectKey(_authSessionStream),
      stream: _authSessionStream,
      initialData: _initialAuthEmission(),
      builder: (context, authSessionSnapshot) {
        final authEmission = authSessionSnapshot.data!;
        _syncHistoryOwner(
          _historyOwnerUserIdForEmission(authEmission),
          authEmission.epoch,
        );
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            backgroundColor: ExpatlioDesign.background,
            body: Stack(
              children: [
                _buildBody(context),
                _buildHeader(context),
              ],
            ),
          ),
        );
      },
    );
  }
}

Stream<String> _watchEventHistoryOwnerIds() => FirebaseAuth.instance
    .authStateChanges()
    .map((user) => user?.uid.trim() ?? '');

class _EventHistoryErrorState extends StatelessWidget {
  const _EventHistoryErrorState({
    required this.onRetry,
  });

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось загрузить события',
      enText: 'Could not load events',
    );
    final message = FFLocalizations.of(context).getVariableText(
      ruText: 'Проверьте подключение и попробуйте еще раз.',
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

    final state = UxErrorState(
      stateKey: eventHistoryErrorKey,
      title: title,
      message: message,
      retryLabel: retryLabel,
      retrySemanticsLabel: retrySemanticsLabel,
      retryButtonKey: eventHistoryErrorRetryButtonKey,
      onRetry: onRetry,
      showIcon: false,
      contained: false,
      maxWidth: double.infinity,
      padding: const EdgeInsetsDirectional.all(ExpatlioDesign.space0),
      titleSize: 17.0,
      retryMinHeight: 44.0,
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ExpatlioDesign.pagePadding),
        child: state,
      ),
    );
  }
}

const double _eventHistoryCardRadius = 15.0;
const double _eventHistoryCardPadding = 16.0;
const double _eventHistoryTitleFontSize = 15.0;
const double _eventHistoryTitleTextHeight = 1.22;
const double _eventHistoryMetaFontSize = 12.0;
const double _eventHistoryPlaceFontSize = 13.0;
const double _eventHistoryActionHeight = 36.0;
const double _eventHistoryActionRadius = 14.0;
const Color _eventHistoryBorderColor = Color(0xFFEBEBEB);

class _EventHistoryCard extends StatelessWidget {
  const _EventHistoryCard({
    required this.item,
    required this.onTap,
  });

  final EventHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final localDateTime = _eventHistoryLocalDateTime(item);
    final locale = FFLocalizations.of(context).languageCode;
    final locationLabel = _eventHistoryLocationLabel(context, item);
    final levelLabel = _eventHistoryLevelLabel(item);
    final languageLabel = _eventHistoryLanguageLabel(context, item);
    final title = item.title.trim();
    final borderRadius = BorderRadius.circular(_eventHistoryCardRadius);

    return Material(
      color: Colors.transparent,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: eventHistoryItemKey(item.eventId),
        borderRadius: borderRadius,
        onTap: onTap,
        child: Ink(
          decoration: ExpatlioDesign.cardDecoration(
            color: Colors.white,
            radius: _eventHistoryCardRadius,
            borderColor: _eventHistoryBorderColor,
          ),
          child: Padding(
            padding: const EdgeInsets.all(_eventHistoryCardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: ExpatlioDesign.space8,
                  runSpacing: ExpatlioDesign.space8,
                  children: [
                    _EventHistoryStatusChip(item: item),
                    _EventHistoryRoleChip(item: item),
                    if (levelLabel.isNotEmpty)
                      _EventHistoryLevelBadge(label: levelLabel),
                  ],
                ),
                const SizedBox(height: 14.0),
                Text(
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
                    size: _eventHistoryTitleFontSize,
                    weight: FontWeight.w700,
                    height: _eventHistoryTitleTextHeight,
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space8),
                Wrap(
                  spacing: ExpatlioDesign.space8,
                  runSpacing: ExpatlioDesign.space8,
                  children: [
                    _EventHistoryInfoChip(
                      icon: Icons.calendar_month_outlined,
                      label: dateTimeFormat(
                        'd MMM y',
                        localDateTime,
                        locale: locale,
                      ),
                    ),
                    _EventHistoryInfoChip(
                      icon: Icons.schedule_rounded,
                      label: dateTimeFormat(
                        'Hm',
                        localDateTime,
                        locale: locale,
                      ),
                    ),
                  ],
                ),
                if (locationLabel.isNotEmpty) ...[
                  const SizedBox(height: 13.0),
                  _EventHistoryLocationRow(label: locationLabel),
                ],
                if (languageLabel.isNotEmpty) ...[
                  const SizedBox(height: 14.0),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: _EventHistoryLanguageBadge(label: languageLabel),
                  ),
                ],
                const SizedBox(height: 14.0),
                const _EventHistoryOpenAction(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EventHistoryStatusChip extends StatelessWidget {
  const _EventHistoryStatusChip({required this.item});

  final EventHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final color = _eventHistoryStatusColor(item.timelineStatus);
    return _EventHistoryPill(
      label: _eventHistoryStatusLabel(context, item.timelineStatus),
      color: color,
      icon: switch (item.timelineStatus) {
        EventHistoryTimelineStatus.upcoming => Icons.event_available_outlined,
        EventHistoryTimelineStatus.past => Icons.history_rounded,
        EventHistoryTimelineStatus.canceled => Icons.event_busy_outlined,
        EventHistoryTimelineStatus.left => Icons.logout_rounded,
      },
    );
  }
}

class _EventHistoryRoleChip extends StatelessWidget {
  const _EventHistoryRoleChip({required this.item});

  final EventHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return _EventHistoryPill(
      label: item.isOrganizer
          ? FFLocalizations.of(context).getVariableText(
              ruText: 'Организатор',
              enText: 'Organizer',
            )
          : FFLocalizations.of(context).getVariableText(
              ruText: 'Участник',
              enText: 'Participant',
            ),
      color: item.isOrganizer ? ExpatlioDesign.orange : ExpatlioDesign.info,
      icon: item.isOrganizer
          ? Icons.workspace_premium_outlined
          : Icons.person_outline_rounded,
    );
  }
}

class _EventHistoryPill extends StatelessWidget {
  const _EventHistoryPill({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30.0),
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.0, color: color),
          const SizedBox(width: ExpatlioDesign.space4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: color,
              size: _eventHistoryMetaFontSize,
              weight: FontWeight.w700,
              height: 1.28,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHistoryInfoChip extends StatelessWidget {
  const _EventHistoryInfoChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final maxWidth =
        (MediaQuery.sizeOf(context).width - 72).clamp(96.0, 220.0).toDouble();
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: 30.0, maxWidth: maxWidth),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 10.0,
              vertical: 4.0,
            ),
            decoration: BoxDecoration(
              color: ExpatlioDesign.secondarySystemBackground,
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14.0, color: ExpatlioDesign.primary),
                const SizedBox(width: 6.0),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: _eventHistoryMetaFontSize,
                      weight: FontWeight.w600,
                      height: 1.28,
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

class _EventHistoryLocationRow extends StatelessWidget {
  const _EventHistoryLocationRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.location_on_outlined,
          color: ExpatlioDesign.inactive,
          size: 14.0,
        ),
        const SizedBox(width: 6.0),
        Expanded(
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.inactive,
              size: _eventHistoryPlaceFontSize,
              weight: FontWeight.w400,
              height: 1.28,
            ),
          ),
        ),
      ],
    );
  }
}

class _EventHistoryLevelBadge extends StatelessWidget {
  const _EventHistoryLevelBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30.0),
      alignment: Alignment.center,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: ExpatlioDesign.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.primary,
          size: _eventHistoryMetaFontSize,
          weight: FontWeight.w700,
          height: 1.18,
        ),
      ),
    );
  }
}

class _EventHistoryLanguageBadge extends StatelessWidget {
  const _EventHistoryLanguageBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 30.0),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10.0,
        vertical: 4.0,
      ),
      decoration: BoxDecoration(
        color: ExpatlioDesign.secondarySystemBackground,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.translate_rounded,
            size: 14.0,
            color: ExpatlioDesign.primary,
          ),
          const SizedBox(width: 6.0),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.textStyle(
                context,
                size: _eventHistoryMetaFontSize,
                weight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHistoryOpenAction extends StatelessWidget {
  const _EventHistoryOpenAction();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: _eventHistoryActionHeight,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: ExpatlioDesign.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(_eventHistoryActionRadius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Открыть событие',
                enText: 'Open event',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.primary,
                size: 13.0,
                weight: FontWeight.w700,
                height: 1.0,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: ExpatlioDesign.primary,
            size: 18.0,
          ),
        ],
      ),
    );
  }
}

String _eventHistoryStatusLabel(
  BuildContext context,
  EventHistoryTimelineStatus status,
) {
  return switch (status) {
    EventHistoryTimelineStatus.upcoming =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Запланировано',
        enText: 'Upcoming',
      ),
    EventHistoryTimelineStatus.past =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Прошло',
        enText: 'Past',
      ),
    EventHistoryTimelineStatus.canceled =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Отменено',
        enText: 'Canceled',
      ),
    EventHistoryTimelineStatus.left =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Вы вышли',
        enText: 'Left',
      ),
  };
}

Color _eventHistoryStatusColor(EventHistoryTimelineStatus status) {
  return switch (status) {
    EventHistoryTimelineStatus.upcoming => ExpatlioDesign.primary,
    EventHistoryTimelineStatus.past => ExpatlioDesign.inactive,
    EventHistoryTimelineStatus.canceled => ExpatlioDesign.danger,
    EventHistoryTimelineStatus.left => ExpatlioDesign.orange,
  };
}

DateTime _eventHistoryLocalDateTime(EventHistoryItem item) {
  final startsAt = item.startsAt.isUtc ? item.startsAt : item.startsAt.toUtc();
  try {
    final local = timezone.TZDateTime.from(
      startsAt,
      eventListTimeZoneLocation(item.timeZoneId),
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
  } on Object {
    return startsAt.toLocal();
  }
}

String _eventHistoryLocationLabel(
  BuildContext context,
  EventHistoryItem item,
) {
  final location = item.locationName?.trim() ?? '';
  if (location.isNotEmpty) {
    return location;
  }
  final isRussian = FFLocalizations.of(context).languageCode == 'ru';
  return (isRussian ? item.cityNameRu : item.cityNameEn)?.trim() ??
      (isRussian ? item.cityNameEn : item.cityNameRu)?.trim() ??
      '';
}

String _eventHistoryLanguageLabel(
  BuildContext context,
  EventHistoryItem item,
) {
  final isRussian = FFLocalizations.of(context).languageCode == 'ru';
  return (isRussian ? item.languageNameRu : item.languageNameEn)?.trim() ??
      (isRussian ? item.languageNameEn : item.languageNameRu)?.trim() ??
      item.languageCode?.trim() ??
      '';
}

String _eventHistoryLevelLabel(EventHistoryItem item) {
  final levelMin = item.levelMin?.trim() ?? '';
  final levelMax = item.levelMax?.trim() ?? '';
  if (levelMin.isEmpty && levelMax.isEmpty) {
    return '';
  }
  final range = tryEventLevelRange(levelMin: levelMin, levelMax: levelMax);
  if (range != null) {
    return range.levelMin == range.levelMax
        ? range.levelMin
        : '${range.levelMin}-${range.levelMax}';
  }
  if (levelMin.isEmpty) {
    return levelMax.toUpperCase();
  }
  if (levelMax.isEmpty || levelMin.toUpperCase() == levelMax.toUpperCase()) {
    return levelMin.toUpperCase();
  }
  return '${levelMin.toUpperCase()}-${levelMax.toUpperCase()}';
}
