import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/app_loading_indicator.dart';
import '/components/dictionary_word_row.dart';
import '/components/empty/empty_widget.dart';
import '/components/review_words_bar.dart';
import '/components/ux_error_state.dart';
import '/components/ux_refreshing_indicator_overlay.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/ux_loading_state.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import '/students_pages/words/word_detail_widget.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'words_model.dart';
export 'words_model.dart';

const ValueKey<String> wordsHeaderKey = ValueKey<String>('words_header');
const ValueKey<String> wordsContentViewportKey =
    ValueKey<String>('words_content_viewport');
const ValueKey<String> wordsInitialLoadingKey =
    ValueKey<String>('words_initial_loading');
const ValueKey<String> wordsListKey = ValueKey<String>('words_list');
const ValueKey<String> wordsEmptyStateKey =
    ValueKey<String>('words_empty_state');
const ValueKey<String> wordsFullErrorStateKey =
    ValueKey<String>('words_full_error_state');
const ValueKey<String> wordsRetryButtonKey =
    ValueKey<String>('words_retry_button');
const ValueKey<String> wordsRefreshingIndicatorKey =
    ValueKey<String>('words_refreshing_indicator');
const ValueKey<String> wordsRefreshErrorIndicatorKey =
    ValueKey<String>('words_refresh_error_indicator');

ValueKey<String> wordsRowKey(String wordPath) =>
    ValueKey<String>('words_row_$wordPath');

final class WordsQueryResult<T extends Object> {
  WordsQueryResult({
    required List<T> items,
    required this.isServerConfirmed,
  }) : items = List<T>.unmodifiable(items);

  final List<T> items;
  final bool isServerConfirmed;
}

typedef WordsQueryStreamFactory<T extends Object> = Stream<WordsQueryResult<T>>
    Function(DocumentReference? userReference);

bool wordsSnapshotIsServerConfirmed({
  required bool isFromCache,
  required bool hasPendingWrites,
}) {
  return !isFromCache && !hasPendingWrites;
}

Stream<WordsQueryResult<UserWordsRecord>> _watchUserWords(
  DocumentReference? userReference,
) {
  if (userReference == null) {
    return const Stream<WordsQueryResult<UserWordsRecord>>.empty();
  }
  return UserWordsRecord.collection(userReference)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => WordsQueryResult<UserWordsRecord>(
          items: snapshot.docs.map(UserWordsRecord.fromSnapshot).toList(),
          isServerConfirmed: wordsSnapshotIsServerConfirmed(
            isFromCache: snapshot.metadata.isFromCache,
            hasPendingWrites: snapshot.metadata.hasPendingWrites,
          ),
        ),
      );
}

Stream<WordsQueryResult<WordReviewsRecord>> _watchWordReviews(
  DocumentReference? userReference,
) {
  if (userReference == null) {
    return const Stream<WordsQueryResult<WordReviewsRecord>>.empty();
  }
  return WordReviewsRecord.collection(userReference)
      .snapshots(includeMetadataChanges: true)
      .map(
        (snapshot) => WordsQueryResult<WordReviewsRecord>(
          items: snapshot.docs.map(WordReviewsRecord.fromSnapshot).toList(),
          isServerConfirmed: wordsSnapshotIsServerConfirmed(
            isFromCache: snapshot.metadata.isFromCache,
            hasPendingWrites: snapshot.metadata.hasPendingWrites,
          ),
        ),
      );
}

final class _RetainedWordsQuerySummary<T extends Object> {
  const _RetainedWordsQuerySummary({
    required this.connectionState,
    required this.lastSuccessfulResult,
    required this.hasNewResult,
    required this.awaitingServerConfirmation,
    required this.error,
  });

  factory _RetainedWordsQuerySummary.initial({
    required Object dataKey,
    required List<T>? initialItems,
  }) {
    return _RetainedWordsQuerySummary<T>(
      connectionState: ConnectionState.none,
      lastSuccessfulResult: initialItems == null
          ? null
          : uxLoadedListResult<T>(
              dataKey: dataKey,
              items: initialItems,
            ),
      hasNewResult: false,
      awaitingServerConfirmation: false,
      error: null,
    );
  }

  final ConnectionState connectionState;
  final UxLoadedResult<List<T>>? lastSuccessfulResult;
  final bool hasNewResult;
  final bool awaitingServerConfirmation;
  final Object? error;

  UxLoadingState<List<T>> resolve(Object dataKey) {
    return UxLoadingState<List<T>>.resolve(
      activeDataKey: dataKey,
      isLoading: connectionState == ConnectionState.waiting ||
          awaitingServerConfirmation,
      newResult: hasNewResult ? lastSuccessfulResult : null,
      lastSuccessfulResult: lastSuccessfulResult,
      error: error,
      errorDataKey: error == null ? null : dataKey,
    );
  }
}

typedef _RetainedWordsStateBuilder<T extends Object> = Widget Function(
  BuildContext context,
  UxLoadingState<List<T>> state,
);

class _RetainedWordsQueryBuilder<T extends Object> extends StreamBuilderBase<
    WordsQueryResult<T>, _RetainedWordsQuerySummary<T>> {
  const _RetainedWordsQueryBuilder({
    super.key,
    required super.stream,
    required this.dataKey,
    required this.initialItems,
    required this.onAcceptedItems,
    required this.builder,
  });

  final Object dataKey;
  final List<T>? initialItems;
  final ValueChanged<List<T>> onAcceptedItems;
  final _RetainedWordsStateBuilder<T> builder;

  @override
  _RetainedWordsQuerySummary<T> initial() =>
      _RetainedWordsQuerySummary<T>.initial(
        dataKey: dataKey,
        initialItems: initialItems,
      );

  @override
  _RetainedWordsQuerySummary<T> afterConnected(
    _RetainedWordsQuerySummary<T> current,
  ) {
    return _RetainedWordsQuerySummary<T>(
      connectionState: ConnectionState.waiting,
      lastSuccessfulResult: current.lastSuccessfulResult,
      hasNewResult: false,
      awaitingServerConfirmation: false,
      error: null,
    );
  }

  @override
  _RetainedWordsQuerySummary<T> afterData(
    _RetainedWordsQuerySummary<T> current,
    WordsQueryResult<T> data,
  ) {
    final canAcceptItems = data.isServerConfirmed || data.items.isNotEmpty;
    final result = canAcceptItems
        ? uxLoadedListResult<T>(dataKey: dataKey, items: data.items)
        : current.lastSuccessfulResult;
    if (canAcceptItems) {
      onAcceptedItems(data.items);
    }
    return _RetainedWordsQuerySummary<T>(
      connectionState: ConnectionState.active,
      lastSuccessfulResult: result,
      hasNewResult: data.isServerConfirmed,
      awaitingServerConfirmation: !data.isServerConfirmed,
      error: null,
    );
  }

  @override
  _RetainedWordsQuerySummary<T> afterError(
    _RetainedWordsQuerySummary<T> current,
    Object error,
    StackTrace stackTrace,
  ) {
    return _RetainedWordsQuerySummary<T>(
      connectionState: ConnectionState.active,
      lastSuccessfulResult: current.lastSuccessfulResult,
      hasNewResult: false,
      awaitingServerConfirmation: false,
      error: error,
    );
  }

  @override
  _RetainedWordsQuerySummary<T> afterDone(
    _RetainedWordsQuerySummary<T> current,
  ) {
    return _RetainedWordsQuerySummary<T>(
      connectionState: ConnectionState.done,
      lastSuccessfulResult: current.lastSuccessfulResult,
      hasNewResult: current.hasNewResult,
      awaitingServerConfirmation: current.awaitingServerConfirmation,
      error: current.error,
    );
  }

  @override
  _RetainedWordsQuerySummary<T> afterDisconnected(
    _RetainedWordsQuerySummary<T> current,
  ) {
    return _RetainedWordsQuerySummary<T>(
      connectionState: ConnectionState.none,
      lastSuccessfulResult: current.lastSuccessfulResult,
      hasNewResult: false,
      awaitingServerConfirmation: false,
      error: null,
    );
  }

  @override
  Widget build(
    BuildContext context,
    _RetainedWordsQuerySummary<T> currentSummary,
  ) {
    return builder(context, currentSummary.resolve(dataKey));
  }
}

class WordsWidget extends StatefulWidget {
  const WordsWidget({
    super.key,
    this.wordsStreamFactory,
    this.wordReviewsStreamFactory,
    this.userReferenceProvider,
    this.sessionCacheKeyOverride,
  });

  final WordsQueryStreamFactory<UserWordsRecord>? wordsStreamFactory;
  final WordsQueryStreamFactory<WordReviewsRecord>? wordReviewsStreamFactory;
  final DocumentReference? Function()? userReferenceProvider;
  final String? sessionCacheKeyOverride;

  static String routeName = 'Words';
  static String routePath = '/words';

  @override
  State<WordsWidget> createState() => _WordsWidgetState();
}

class _WordsWidgetState extends State<WordsWidget> {
  static const double _reviewBarFadeExtraHeight = 36.0;

  late WordsModel _model;
  DocumentReference? _activeUserReference;
  late Object _wordsDataKey;
  late Object _wordReviewsDataKey;
  Stream<WordsQueryResult<UserWordsRecord>>? _wordsStream;
  Stream<WordsQueryResult<WordReviewsRecord>>? _wordReviewsStream;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WordsModel());
    WordsModel.ensureSessionCacheLifecycleRegistered();
    _configureDataSources(_resolveUserReference());

    final userRef = _activeUserReference;
    if (userRef != null) {
      unawaited(
        FlashcardReviewRepository.ensureWordReviewsBackfilled(
          userRef: userRef,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(covariant WordsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextUserReference = _resolveUserReference();
    final userChanged = _activeUserReference?.path != nextUserReference?.path;
    if (userChanged ||
        oldWidget.wordsStreamFactory != widget.wordsStreamFactory ||
        oldWidget.wordReviewsStreamFactory != widget.wordReviewsStreamFactory ||
        oldWidget.sessionCacheKeyOverride != widget.sessionCacheKeyOverride) {
      _configureDataSources(nextUserReference);
      if (userChanged && nextUserReference != null) {
        unawaited(
          FlashcardReviewRepository.ensureWordReviewsBackfilled(
            userRef: nextUserReference,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  DocumentReference? _resolveUserReference() =>
      widget.userReferenceProvider?.call() ?? currentUserReference;

  void _configureDataSources(DocumentReference? userReference) {
    _activeUserReference = userReference;
    final cacheKey = widget.sessionCacheKeyOverride ?? userReference?.path;
    _model.userCacheKey = cacheKey;
    final dataKeyScope = cacheKey ?? 'anonymous:${identityHashCode(this)}';
    _wordsDataKey = 'words:$dataKeyScope';
    _wordReviewsDataKey = 'word-reviews:$dataKeyScope';
    _wordsStream = (widget.wordsStreamFactory ?? _watchUserWords)(
      userReference,
    );
    _wordReviewsStream = (widget.wordReviewsStreamFactory ?? _watchWordReviews)(
      userReference,
    );
  }

  void _retryData() {
    setState(() {
      _wordsStream = (widget.wordsStreamFactory ?? _watchUserWords)(
        _activeUserReference,
      );
      _wordReviewsStream =
          (widget.wordReviewsStreamFactory ?? _watchWordReviews)(
        _activeUserReference,
      );
    });
  }

  int _dueWordsCount(List<WordReviewsRecord> reviews) {
    final now = DateTime.now();
    return reviews
        .where(
          (review) => review.dueAt != null && !review.dueAt!.isAfter(now),
        )
        .length;
  }

  double _reviewBarBottomOffset(BuildContext context) {
    final navClearance =
        Theme.of(context).platform == TargetPlatform.android ? 12.0 : 10.0;
    return MediaQuery.paddingOf(context).bottom + navClearance;
  }

  double _contentBottomPadding(
    BuildContext context, {
    required bool showReviewBar,
  }) {
    if (!showReviewBar) {
      return MediaQuery.paddingOf(context).bottom + ExpatlioDesign.space16;
    }
    return _reviewBarBottomOffset(context) +
        reviewWordsBarHeight +
        ExpatlioDesign.space16;
  }

  Future<void> _openWordPage(UserWordsRecord wordDoc) async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute(
        builder: (_) => WordDetailWidget(
          initialWord: wordDoc,
          wordRef: wordDoc.reference,
        ),
      ),
    );
  }

  int? _reviewCountForState(
    UxLoadingState<List<WordReviewsRecord>> state,
  ) {
    final result = state.displayedResult;
    if (result == null) {
      return null;
    }
    return _dueWordsCount(result.data ?? const <WordReviewsRecord>[]);
  }

  Widget _buildWordsViewport({
    required UxLoadingState<List<UserWordsRecord>> wordsState,
    required UxLoadingState<List<WordReviewsRecord>> reviewsState,
    required bool showReviewBar,
  }) {
    final localizations = FFLocalizations.of(context);
    final displayedResult = wordsState.displayedResult;
    final hasDisplayResult = displayedResult != null;
    final hasRefreshError = wordsState.isErrorWithPreviousResult ||
        (hasDisplayResult && reviewsState.hasError);
    final isRefreshing = hasDisplayResult &&
        !hasRefreshError &&
        (wordsState.isRefreshing ||
            reviewsState.isRefreshing ||
            reviewsState.isInitialLoading);

    Widget content;
    if (wordsState.isInitialLoading) {
      final label = localizations.getVariableText(
        ruText: 'Загрузка словаря',
        enText: 'Loading dictionary',
      );
      content = Semantics(
        key: wordsInitialLoadingKey,
        container: true,
        liveRegion: true,
        label: label,
        child: const ExcludeSemantics(
          child: Center(child: AppLoadingIndicator()),
        ),
      );
    } else if (wordsState.isErrorWithoutData) {
      content = Padding(
        padding: EdgeInsetsDirectional.only(
          bottom: _contentBottomPadding(
            context,
            showReviewBar: showReviewBar,
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: UxErrorState(
                    stateKey: wordsFullErrorStateKey,
                    title: localizations.getVariableText(
                      ruText: 'Не удалось загрузить словарь',
                      enText: 'Could not load dictionary',
                    ),
                    message: localizations.getVariableText(
                      ruText: 'Проверьте подключение и попробуйте снова.',
                      enText: 'Check your connection and try again.',
                    ),
                    onRetry: _retryData,
                    retryLabel: localizations.getVariableText(
                      ruText: 'Повторить',
                      enText: 'Try again',
                    ),
                    retryButtonKey: wordsRetryButtonKey,
                  ),
                ),
              ),
            );
          },
        ),
      );
    } else if (displayedResult?.isEmpty ?? false) {
      content = KeyedSubtree(
        key: wordsEmptyStateKey,
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            bottom: _contentBottomPadding(
              context,
              showReviewBar: showReviewBar,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: EmptyWidget(
                      shrinkWrap: true,
                      topPadding: ExpatlioDesign.space0,
                      txt: localizations.getVariableText(
                        ruText: 'В этом разделе будут появляться слова, '
                            'которые вы добавите во время занятий. '
                            'Сохраните первое слово, чтобы начать '
                            'формировать свой личный словарь.',
                        enText:
                            'Words you save during lessons will appear here. '
                            'Save your first word to start building your '
                            'personal dictionary.',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );
    } else {
      final words = displayedResult?.data ?? const <UserWordsRecord>[];
      content = ListView.separated(
        key: wordsListKey,
        primary: false,
        padding: EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.compactSpacing,
          ExpatlioDesign.pagePadding,
          _contentBottomPadding(
            context,
            showReviewBar: showReviewBar,
          ),
        ),
        itemCount: words.length,
        separatorBuilder: (context, index) => const Divider(
          height: 1.0,
          thickness: 1.0,
          color: ExpatlioDesign.border,
        ),
        itemBuilder: (context, index) {
          final word = words[index];
          final entry = word.entry.firstOrNull;
          return DictionaryWordRow(
            key: wordsRowKey(word.reference.path),
            sourceText: valueOrDefault<String>(entry?.text, '-'),
            translationText: valueOrDefault<String>(
              entry?.tr.firstOrNull?.text,
              '-',
            ),
            onTap: () async => _openWordPage(word),
          );
        },
      );
    }

    content = UxRefreshingIndicatorOverlay(
      isRefreshing: isRefreshing,
      semanticsLabel: localizations.getVariableText(
        ruText: 'Обновление словаря',
        enText: 'Refreshing dictionary',
      ),
      indicator: const UxRefreshingIndicatorPill(
        key: wordsRefreshingIndicatorKey,
        semanticsLabel: null,
      ),
      child: content,
    );

    content = Stack(
      fit: StackFit.passthrough,
      children: [
        content,
        if (hasRefreshError)
          PositionedDirectional(
            top: ExpatlioDesign.space8,
            start: ExpatlioDesign.space8,
            end: ExpatlioDesign.space8,
            child: Center(
              child: _WordsRefreshErrorPill(onRetry: _retryData),
            ),
          ),
      ],
    );

    return SizedBox.expand(
      key: wordsContentViewportKey,
      child: content,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: ExpatlioDesign.background,
        body: _RetainedWordsQueryBuilder<WordReviewsRecord>(
          key: ValueKey<Object>(_wordReviewsDataKey),
          stream: _wordReviewsStream,
          dataKey: _wordReviewsDataKey,
          initialItems: _model.cachedWordReviews,
          onAcceptedItems: _model.cacheWordReviews,
          builder: (context, reviewsState) {
            return _RetainedWordsQueryBuilder<UserWordsRecord>(
              key: ValueKey<Object>(_wordsDataKey),
              stream: _wordsStream,
              dataKey: _wordsDataKey,
              initialItems: _model.cachedWords,
              onAcceptedItems: _model.cacheWords,
              builder: (context, wordsState) {
                final dueCount = _reviewCountForState(reviewsState);
                final hasDueWords = (dueCount ?? 0) > 0;
                final showReviewBar =
                    wordsState.displayedResult?.data?.isNotEmpty ?? false;
                final localizations = FFLocalizations.of(context);
                final countText = dueCount == null
                    ? '—'
                    : reviewWordsVisibleLabel(
                        count: dueCount,
                        languageCode: localizations.languageCode,
                      );
                final countSemanticsLabel = dueCount == null
                    ? localizations.getVariableText(
                        ruText: reviewsState.hasError
                            ? 'Не удалось загрузить данные повторения'
                            : 'Данные повторения загружаются',
                        enText: reviewsState.hasError
                            ? 'Could not load review data'
                            : 'Review data is loading',
                      )
                    : reviewWordsCountSemanticsLabel(
                        count: dueCount,
                        languageCode: localizations.languageCode,
                      );

                return Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SafeArea(
                          bottom: false,
                          child: SizedBox(
                            key: wordsHeaderKey,
                            height: ExpatlioDesign.pageHeaderHeight,
                            child: Center(
                              child: Text(
                                localizations.getVariableText(
                                  ruText: 'Словарь',
                                  enText: 'Dictionary',
                                ),
                                style: ExpatlioDesign.pageHeaderTitleStyle(
                                  context,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: _buildWordsViewport(
                            wordsState: wordsState,
                            reviewsState: reviewsState,
                            showReviewBar: showReviewBar,
                          ),
                        ),
                      ],
                    ),
                    if (showReviewBar) ...[
                      PositionedDirectional(
                        start: 0.0,
                        end: 0.0,
                        bottom: 0.0,
                        child: IgnorePointer(
                          child: Container(
                            height: _reviewBarBottomOffset(context) +
                                reviewWordsBarHeight +
                                _reviewBarFadeExtraHeight,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  ExpatlioDesign.background
                                      .withValues(alpha: 0.0),
                                  ExpatlioDesign.background
                                      .withValues(alpha: 0.92),
                                  ExpatlioDesign.background,
                                ],
                                stops: const [0.0, 0.42, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),
                      PositionedDirectional(
                        start: ExpatlioDesign.pagePadding,
                        end: ExpatlioDesign.pagePadding,
                        bottom: _reviewBarBottomOffset(context),
                        child: ReviewWordsBar(
                          text: countText,
                          semanticsLabel: countSemanticsLabel,
                          onTap: hasDueWords
                              ? () {
                                  context.pushNamed(FlashcardWidget.routeName);
                                }
                              : null,
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _WordsRefreshErrorPill extends StatelessWidget {
  const _WordsRefreshErrorPill({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = FFLocalizations.of(context);
    final label = localizations.getVariableText(
      ruText: 'Не удалось обновить словарь',
      enText: 'Could not refresh dictionary',
    );
    final semanticsLabel = localizations.getVariableText(
      ruText: '$label. Повторить',
      enText: '$label. Try again',
    );

    return Semantics(
      key: wordsRefreshErrorIndicatorKey,
      container: true,
      liveRegion: true,
      button: true,
      label: semanticsLabel,
      onTap: onRetry,
      child: ExcludeSemantics(
        child: Material(
          color: ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
          elevation: 2.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 48.0,
              minHeight: 48.0,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
              onTap: onRetry,
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space8,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off_outlined,
                      size: 16.0,
                      color: ExpatlioDesign.danger,
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: ExpatlioDesign.textStyle(
                          context,
                          size: 14.0,
                          weight: FontWeight.w600,
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
