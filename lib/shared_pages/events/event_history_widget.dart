import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as timezone;

import '/components/app_loading_indicator.dart';
import '/components/basic_page_header.dart';
import '/components/empty/empty_widget.dart';
import '/components/ux_error_state.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/event_history_repository.dart';
import '/services/event_level_helper.dart';
import '/services/event_list_date_bounds.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/events/event_detail_widget.dart';

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

ValueKey<String> eventHistoryItemKey(String eventId) =>
    ValueKey<String>('event_history_item_$eventId');

typedef EventHistoryLoader = Future<EventHistoryResult> Function();
typedef EventHistoryEventOpener = void Function(
  BuildContext context,
  EventHistoryItem item,
);

class EventHistoryWidget extends StatefulWidget {
  const EventHistoryWidget({
    super.key,
    this.historyLoader,
    this.eventOpener,
  });

  static String routeName = 'eventHistory';
  static String routePath = '/profile/events';

  final EventHistoryLoader? historyLoader;
  final EventHistoryEventOpener? eventOpener;

  @override
  State<EventHistoryWidget> createState() => _EventHistoryWidgetState();
}

class _EventHistoryWidgetState extends State<EventHistoryWidget> {
  Future<EventHistoryResult>? _historyFuture;
  EventHistoryResult? _lastLoadedResult;
  Object? _historyError;
  late String _historyOwnerUserId;
  int _historyRequestSerial = 0;

  @override
  void initState() {
    super.initState();
    _historyOwnerUserId = _currentHistoryOwnerUserId();
    _historyFuture = _startHistoryLoad();
  }

  @override
  void didUpdateWidget(covariant EventHistoryWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.historyLoader != widget.historyLoader) {
      _resetHistoryStateForOwner(_currentHistoryOwnerUserId());
    }
  }

  String _currentHistoryOwnerUserId() => currentUserUid.trim();

  void _syncHistoryOwner() {
    final ownerUserId = _currentHistoryOwnerUserId();
    if (ownerUserId == _historyOwnerUserId) {
      return;
    }
    _resetHistoryStateForOwner(ownerUserId);
  }

  void _resetHistoryStateForOwner(String ownerUserId) {
    _historyOwnerUserId = ownerUserId;
    _lastLoadedResult = null;
    _historyError = null;
    _historyFuture = _startHistoryLoad(ownerUserId: ownerUserId);
  }

  Future<EventHistoryResult> _startHistoryLoad({
    String? ownerUserId,
    bool deferred = false,
  }) {
    final effectiveOwnerUserId = ownerUserId ?? _historyOwnerUserId;
    final requestId = ++_historyRequestSerial;
    if (deferred) {
      return Future<EventHistoryResult>.delayed(
        Duration.zero,
        () => _loadHistory(requestId, effectiveOwnerUserId),
      );
    }
    return _loadHistory(requestId, effectiveOwnerUserId);
  }

  Future<EventHistoryResult> _loadHistory(
    int requestId,
    String ownerUserId,
  ) async {
    final loader = widget.historyLoader;
    try {
      final result = loader != null
          ? await loader()
          : await EventHistoryRepository.loadEventHistory(
              limit: eventHistoryMaxLimit,
            );
      if (requestId == _historyRequestSerial &&
          ownerUserId == _historyOwnerUserId) {
        _historyError = null;
        _lastLoadedResult = result;
      }
      return result;
    } catch (error) {
      final isActiveRequest = requestId == _historyRequestSerial &&
          ownerUserId == _historyOwnerUserId;
      if (isActiveRequest) {
        _historyError = error;
      }
      final lastLoadedResult = _lastLoadedResult;
      if (isActiveRequest && lastLoadedResult != null) {
        return lastLoadedResult;
      }
      rethrow;
    }
  }

  void _reloadHistory() {
    setState(() {
      _historyFuture = _startHistoryLoad(deferred: true);
    });
  }

  void _openEvent(EventHistoryItem item) {
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

  Widget _buildBody(BuildContext context) {
    return FutureBuilder<EventHistoryResult>(
      future: _historyFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            _historyFuture == null) {
          final lastLoadedResult = _lastLoadedResult;
          if (lastLoadedResult != null) {
            final items = lastLoadedResult.items;
            if (items.isEmpty) {
              return _buildHistoryEmpty(context);
            }
            return _buildHistoryList(context, items);
          }
          return const Center(
            key: eventHistoryLoadingKey,
            child: AppLoadingIndicator(),
          );
        }

        if (snapshot.hasError) {
          final lastLoadedResult = _lastLoadedResult;
          if (lastLoadedResult != null) {
            return _buildPreviousHistoryWithError(
              context,
              items: lastLoadedResult.items,
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
      leading: errorState,
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

    final contentTopPadding = MediaQuery.paddingOf(context).top +
        BasicPageHeader.height +
        ExpatlioDesign.sectionSpacing;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        ExpatlioDesign.pagePadding,
        contentTopPadding,
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.pageBottomSpacing,
      ),
      children: [
        leading,
        const SizedBox(height: ExpatlioDesign.space12),
        emptyState,
      ],
    );
  }

  Widget _buildHistoryList(
    BuildContext context,
    List<EventHistoryItem> items, {
    Widget? leading,
  }) {
    final contentTopPadding = MediaQuery.paddingOf(context).top +
        BasicPageHeader.height +
        ExpatlioDesign.sectionSpacing;
    final itemCount = items.length + (leading == null ? 0 : 1);

    return ListView.separated(
      key: eventHistoryListKey,
      padding: EdgeInsets.fromLTRB(
        ExpatlioDesign.pagePadding,
        contentTopPadding,
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.pageBottomSpacing,
      ),
      itemCount: itemCount,
      separatorBuilder: (_, __) =>
          const SizedBox(height: ExpatlioDesign.space12),
      itemBuilder: (context, index) {
        if (leading != null && index == 0) {
          return leading;
        }
        final itemIndex = leading == null ? index : index - 1;
        final item = items[itemIndex];
        return _EventHistoryCard(
          item: item,
          onTap: () => _openEvent(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        _syncHistoryOwner();
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

    final state = UxErrorState(
      stateKey: eventHistoryErrorKey,
      title: title,
      message: message,
      retryLabel: retryLabel,
      retrySemanticsLabel: retrySemanticsLabel,
      retryButtonKey: eventHistoryErrorRetryButtonKey,
      onRetry: onRetry,
      showIcon: false,
      contained: compact,
      maxWidth: double.infinity,
      padding: compact
          ? const EdgeInsetsDirectional.all(ExpatlioDesign.space16)
          : const EdgeInsetsDirectional.all(ExpatlioDesign.space0),
      titleSize: 17.0,
      retryMinHeight: 44.0,
    );

    if (compact) {
      return state;
    }

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
