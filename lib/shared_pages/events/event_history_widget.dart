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
const ValueKey<String> eventHistoryRefreshButtonKey =
    ValueKey<String>('event_history_refresh_button');
const ValueKey<String> eventHistoryErrorRetryButtonKey =
    ValueKey<String>('event_history_error_retry_button');
const ValueKey<String> eventHistoryRefreshingKey =
    ValueKey<String>('event_history_refreshing');

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

  final EventHistoryLoader? historyLoader;
  final EventHistoryEventOpener? eventOpener;
  @visibleForTesting
  final Stream<String>? authUidStream;
  @visibleForTesting
  final String Function()? userIdProvider;

  @override
  State<EventHistoryWidget> createState() => _EventHistoryWidgetState();
}

class _EventHistoryWidgetState extends State<EventHistoryWidget> {
  Future<EventHistoryResult>? _historyFuture;
  EventHistoryResult? _lastLoadedResult;
  bool _hasAuthoritativeResult = false;
  Object? _historyError;
  late Stream<_EventHistoryAuthEmission> _authSessionStream;
  String _latestAuthStreamUserId = '';
  int _latestAuthSessionEpoch = 0;
  String _historyOwnerUserId = '';
  int _historyOwnerEpoch = 0;
  int _historyRequestSerial = 0;

  @override
  void initState() {
    super.initState();
    _latestAuthStreamUserId = _initialHistoryOwnerUserId();
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
      _latestAuthStreamUserId = userId;
      final epoch = ++_latestAuthSessionEpoch;
      return _EventHistoryAuthEmission(userId: userId, epoch: epoch);
    });
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
    return streamOwnerUserId == directOwnerUserId ? directOwnerUserId : '';
  }

  bool _authBoundaryMatches(String ownerUserId, int ownerEpoch) {
    if (ownerUserId.isEmpty ||
        _latestAuthStreamUserId != ownerUserId ||
        _latestAuthSessionEpoch != ownerEpoch) {
      return false;
    }
    return !_hasIndependentDirectAuthUid || _directAuthUid() == ownerUserId;
  }

  bool _requestIsCurrent(
    int requestId,
    String ownerUserId,
    int ownerEpoch,
  ) =>
      mounted &&
      requestId == _historyRequestSerial &&
      ownerUserId == _historyOwnerUserId &&
      ownerEpoch == _historyOwnerEpoch &&
      ownerEpoch == _latestAuthSessionEpoch;

  void _invalidateForAuthBoundaryMismatch() {
    if (!mounted) {
      return;
    }
    if (_historyOwnerUserId.isEmpty &&
        _historyFuture == null &&
        !_hasAuthoritativeResult &&
        _historyError == null) {
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
    _historyOwnerUserId = ownerUserId;
    _historyOwnerEpoch = ownerEpoch;
    _lastLoadedResult = null;
    _hasAuthoritativeResult = false;
    _historyError = null;
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
    final requestId = ++_historyRequestSerial;
    if (deferred) {
      return Future<EventHistoryResult>.delayed(
        Duration.zero,
        () => _loadHistory(
          requestId,
          effectiveOwnerUserId,
          effectiveOwnerEpoch,
        ),
      );
    }
    return _loadHistory(
      requestId,
      effectiveOwnerUserId,
      effectiveOwnerEpoch,
    );
  }

  Future<EventHistoryResult> _loadHistory(
    int requestId,
    String ownerUserId,
    int ownerEpoch,
  ) async {
    final loader = widget.historyLoader;
    try {
      final result = loader != null
          ? await loader(ownerUserId)
          : await EventHistoryRepository.loadEventHistory(
              limit: eventHistoryMaxLimit,
            );
      if (!_requestIsCurrent(requestId, ownerUserId, ownerEpoch)) {
        throw const _StaleEventHistoryRequest();
      }
      if (!_authBoundaryMatches(ownerUserId, ownerEpoch)) {
        _invalidateForAuthBoundaryMismatch();
        throw const _StaleEventHistoryRequest();
      }
      _historyError = null;
      _lastLoadedResult = result;
      _hasAuthoritativeResult = true;
      return result;
    } catch (error) {
      if (error is _StaleEventHistoryRequest) {
        rethrow;
      }
      if (!_requestIsCurrent(requestId, ownerUserId, ownerEpoch)) {
        throw const _StaleEventHistoryRequest();
      }
      if (!_authBoundaryMatches(ownerUserId, ownerEpoch)) {
        _invalidateForAuthBoundaryMismatch();
        throw const _StaleEventHistoryRequest();
      }
      _historyError = error;
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
      trailing: SizedBox(
        width: 44.0,
        height: 44.0,
        child: IconButton(
          key: eventHistoryRefreshButtonKey,
          tooltip: FFLocalizations.of(context).getVariableText(
            ruText: 'Обновить',
            enText: 'Refresh',
          ),
          onPressed: _reloadHistory,
          icon: const Icon(
            Icons.refresh_rounded,
            color: ExpatlioDesign.text,
            size: 22.0,
          ),
        ),
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
      key: ObjectKey(historyFuture),
      future: historyFuture,
      builder: (context, snapshot) {
        if (snapshot.error is _StaleEventHistoryRequest) {
          return _buildLoadingState(context);
        }
        if (snapshot.connectionState != ConnectionState.done) {
          if (_hasAuthoritativeResult) {
            final items = _lastLoadedResult!.items;
            final content = items.isEmpty
                ? _buildHistoryEmpty(context)
                : _buildHistoryList(
                    context,
                    items,
                    ownerUserId: historyOwnerUserId,
                    ownerEpoch: historyOwnerEpoch,
                  );
            return _buildRefreshingHistory(context, content);
          }
          return _buildLoadingState(context);
        }

        if (snapshot.hasError) {
          if (_hasAuthoritativeResult) {
            return _buildPreviousHistoryWithError(
              context,
              items: _lastLoadedResult!.items,
              ownerUserId: historyOwnerUserId,
              ownerEpoch: historyOwnerEpoch,
            );
          }
          return _EventHistoryErrorState(onRetry: _reloadHistory);
        }

        final items = snapshot.data?.items ?? const <EventHistoryItem>[];
        final shouldShowInlineError = _historyError != null && items.isNotEmpty;
        if (items.isEmpty) {
          return _buildHistoryEmpty(
            context,
            leading: _historyError == null
                ? null
                : _EventHistoryErrorState(
                    onRetry: _reloadHistory,
                    compact: true,
                  ),
          );
        }

        return _buildHistoryList(
          context,
          items,
          ownerUserId: historyOwnerUserId,
          ownerEpoch: historyOwnerEpoch,
          leading: shouldShowInlineError
              ? _EventHistoryErrorState(
                  onRetry: _reloadHistory,
                  compact: true,
                )
              : null,
        );
      },
    );
  }

  Widget _buildPreviousHistoryWithError(
    BuildContext context, {
    required List<EventHistoryItem> items,
    required String ownerUserId,
    required int ownerEpoch,
  }) {
    final errorState = _EventHistoryErrorState(
      onRetry: _reloadHistory,
      compact: true,
    );
    if (items.isEmpty) {
      return _buildHistoryEmpty(context, leading: errorState);
    }
    return _buildHistoryList(
      context,
      items,
      ownerUserId: ownerUserId,
      ownerEpoch: ownerEpoch,
      leading: errorState,
    );
  }

  Widget _buildRefreshingHistory(BuildContext context, Widget content) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Обновление истории событий',
      enText: 'Refreshing event history',
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        content,
        PositionedDirectional(
          start: ExpatlioDesign.pagePadding,
          end: ExpatlioDesign.pagePadding,
          top: MediaQuery.paddingOf(context).top + BasicPageHeader.height,
          child: Semantics(
            key: eventHistoryRefreshingKey,
            container: true,
            liveRegion: true,
            label: label,
            child: const ExcludeSemantics(
              child: LinearProgressIndicator(
                minHeight: 2.0,
                color: ExpatlioDesign.primary,
                backgroundColor: Colors.transparent,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryEmpty(
    BuildContext context, {
    Widget? leading,
  }) {
    final emptyState = Center(
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

    if (leading == null) {
      return emptyState;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        emptyState,
        _buildHistoryErrorOverlay(context, leading),
      ],
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<EventHistoryItem> items, {
    required String ownerUserId,
    required int ownerEpoch,
    Widget? leading,
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

    if (leading == null) {
      return list;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        list,
        _buildHistoryErrorOverlay(context, leading),
      ],
    );
  }

  Widget _buildHistoryErrorOverlay(BuildContext context, Widget errorState) {
    return PositionedDirectional(
      start: ExpatlioDesign.pagePadding,
      end: ExpatlioDesign.pagePadding,
      bottom: MediaQuery.viewPaddingOf(context).bottom + ExpatlioDesign.space16,
      child: Material(
        color: Colors.transparent,
        elevation: 4.0,
        borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
        child: errorState,
      ),
    );
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
    this.compact = false,
  });

  final VoidCallback onRetry;
  final bool compact;

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

    if (compact) {
      return Semantics(
        key: eventHistoryErrorKey,
        container: true,
        explicitChildNodes: true,
        liveRegion: true,
        label: '$title. $message',
        child: Container(
          constraints: const BoxConstraints(minHeight: 56.0),
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space12,
            ExpatlioDesign.space8,
            ExpatlioDesign.space8,
            ExpatlioDesign.space8,
          ),
          decoration: BoxDecoration(
            color: ExpatlioDesign.card,
            borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
            border: Border.all(color: ExpatlioDesign.danger),
          ),
          child: Row(
            children: [
              Expanded(
                child: ExcludeSemantics(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 14.0,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: ExpatlioDesign.space8),
              Semantics(
                button: true,
                label: retrySemanticsLabel,
                onTap: onRetry,
                excludeSemantics: true,
                child: TextButton(
                  key: eventHistoryErrorRetryButtonKey,
                  onPressed: onRetry,
                  child: Text(retryLabel),
                ),
              ),
            ],
          ),
        ),
      );
    }

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

class _EventHistoryCard extends StatelessWidget {
  const _EventHistoryCard({
    required this.item,
    required this.onTap,
  });

  final EventHistoryItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final metaRows = <Widget>[
      _EventHistoryMetaRow(
        icon: Icons.calendar_today_rounded,
        text: _eventHistoryDateTimeLabel(context, item),
      ),
    ];
    final locationLabel = _eventHistoryLocationLabel(context, item);
    if (locationLabel.isNotEmpty) {
      metaRows.add(
        _EventHistoryMetaRow(
          icon: Icons.place_outlined,
          text: locationLabel,
        ),
      );
    }

    final detailChips = <Widget>[
      if (_eventHistoryLevelLabel(item).isNotEmpty)
        _EventHistorySmallChip(
          icon: Icons.school_outlined,
          label: _eventHistoryLevelLabel(item),
        ),
      if (_eventHistoryLanguageLabel(context, item).isNotEmpty)
        _EventHistorySmallChip(
          icon: Icons.translate_rounded,
          label: _eventHistoryLanguageLabel(context, item),
        ),
    ];

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: eventHistoryItemKey(item.eventId),
        borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
        onTap: onTap,
        child: Ink(
          decoration: ExpatlioDesign.cardDecoration(
            borderColor: ExpatlioDesign.border,
          ),
          child: Padding(
            padding: const EdgeInsets.all(ExpatlioDesign.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: ExpatlioDesign.space8,
                  runSpacing: ExpatlioDesign.space8,
                  children: [
                    _EventHistoryStatusChip(item: item),
                    _EventHistoryRoleChip(item: item),
                  ],
                ),
                const SizedBox(height: ExpatlioDesign.space12),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    size: 18.0,
                    weight: FontWeight.w700,
                    height: 1.18,
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space12),
                ...metaRows,
                if (detailChips.isNotEmpty) ...[
                  const SizedBox(height: ExpatlioDesign.space12),
                  Wrap(
                    spacing: ExpatlioDesign.space8,
                    runSpacing: ExpatlioDesign.space8,
                    children: detailChips,
                  ),
                ],
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
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.0, color: color),
          const SizedBox(width: ExpatlioDesign.space4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: color,
              size: 13.0,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHistoryMetaRow extends StatelessWidget {
  const _EventHistoryMetaRow({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 18.0, color: ExpatlioDesign.muted),
          const SizedBox(width: ExpatlioDesign.space8),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 15.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EventHistorySmallChip extends StatelessWidget {
  const _EventHistorySmallChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10.0,
        vertical: 6.0,
      ),
      decoration: BoxDecoration(
        color: ExpatlioDesign.secondarySystemFill,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15.0, color: ExpatlioDesign.text),
          const SizedBox(width: ExpatlioDesign.space4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.text,
              size: 13.0,
              weight: FontWeight.w600,
            ),
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

String _eventHistoryDateTimeLabel(
  BuildContext context,
  EventHistoryItem item,
) {
  final localDateTime = _eventHistoryLocalDateTime(item);
  final locale = FFLocalizations.of(context).languageCode;
  return '${dateTimeFormat('d MMM y', localDateTime, locale: locale)} · '
      '${dateTimeFormat('Hm', localDateTime, locale: locale)}';
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
