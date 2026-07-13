import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/dictionary_word_row.dart';
import '/components/empty/empty_widget.dart';
import '/components/review_words_bar.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import '/students_pages/words/word_detail_widget.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'words_model.dart';
export 'words_model.dart';

class WordsWidget extends StatefulWidget {
  const WordsWidget({super.key});

  static String routeName = 'Words';
  static String routePath = '/words';

  @override
  State<WordsWidget> createState() => _WordsWidgetState();
}

class _WordsWidgetState extends State<WordsWidget> {
  static const double _reviewBarFadeExtraHeight = 36.0;

  late WordsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WordsModel());
    final userRef = currentUserReference;
    _model.userCacheKey = userRef?.path;
    _model.wordsStream = queryUserWordsRecord(
      parent: userRef,
    );
    _model.wordReviewsStream = queryWordReviewsRecord(
      parent: userRef,
    );

    if (userRef != null) {
      unawaited(
        FlashcardReviewRepository.ensureWordReviewsBackfilled(
          userRef: userRef,
        ),
      );
    }
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  String _dueCountLabel(int dueCount) {
    if (dueCount > 99) {
      return '99+';
    }
    return dueCount.toString();
  }

  int _dueWordsCount(List<WordReviewsRecord> reviews) {
    final now = DateTime.now();
    return reviews
        .where(
          (review) => review.dueAt != null && !review.dueAt!.isAfter(now),
        )
        .length;
  }

  String _ruWordsPlural(int count) {
    final mod100 = count % 100;
    final mod10 = count % 10;
    if (mod100 >= 11 && mod100 <= 14) {
      return 'слов';
    }
    if (mod10 == 1) {
      return 'слово';
    }
    if (mod10 >= 2 && mod10 <= 4) {
      return 'слова';
    }
    return 'слов';
  }

  String _reviewCountText(BuildContext context, int dueCount) {
    return FFLocalizations.of(context).getVariableText(
      ruText: '${_dueCountLabel(dueCount)} ${_ruWordsPlural(dueCount)}',
      enText: '${_dueCountLabel(dueCount)} ${dueCount == 1 ? 'word' : 'words'}',
    );
  }

  double _reviewBarBottomOffset(BuildContext context) {
    final navClearance =
        Theme.of(context).platform == TargetPlatform.android ? 12.0 : 10.0;
    return MediaQuery.paddingOf(context).bottom + navClearance;
  }

  double _contentBottomPadding(BuildContext context) {
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
        body: StreamBuilder<List<WordReviewsRecord>>(
          stream: _model.wordReviewsStream,
          initialData: _model.cachedWordReviews,
          builder: (context, reviewSnapshot) {
            final reviews = reviewSnapshot.data ?? const <WordReviewsRecord>[];
            if (WordsModel.shouldCacheStreamSnapshot(reviewSnapshot)) {
              _model.cacheWordReviews(reviews);
            }
            final dueCount = _dueWordsCount(reviews);
            final hasDueWords = dueCount > 0;

            return Stack(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    SafeArea(
                      bottom: false,
                      child: SizedBox(
                        height: ExpatlioDesign.pageHeaderHeight,
                        child: Stack(
                          alignment: AlignmentDirectional.center,
                          children: [
                            Center(
                              child: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Словарь',
                                  enText: 'Dictionary',
                                ),
                                style: ExpatlioDesign.pageHeaderTitleStyle(
                                    context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: StreamBuilder<List<UserWordsRecord>>(
                        stream: _model.wordsStream,
                        initialData: _model.cachedWords,
                        builder: (context, snapshot) {
                          final words = snapshot.data;
                          if (words == null) {
                            return const SizedBox.shrink();
                          }
                          if (WordsModel.shouldCacheStreamSnapshot(snapshot)) {
                            _model.cacheWords(words);
                          }

                          if (words.isEmpty) {
                            return Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0,
                                _contentBottomPadding(context),
                              ),
                              child: Center(
                                child: EmptyWidget(
                                  shrinkWrap: true,
                                  topPadding: ExpatlioDesign.space0,
                                  txt:
                                      'В этом разделе будут появляться слова, \nкоторые вы добавите во время занятий. \nСохраните первое слово, чтобы начать формировать свой личный словарь',
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            primary: false,
                            padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.pagePadding,
                              ExpatlioDesign.compactSpacing,
                              ExpatlioDesign.pagePadding,
                              _contentBottomPadding(context),
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
                                sourceText:
                                    valueOrDefault<String>(entry?.text, '-'),
                                translationText: valueOrDefault<String>(
                                  entry?.tr.firstOrNull?.text,
                                  '-',
                                ),
                                onTap: () async => _openWordPage(word),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
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
                            ExpatlioDesign.background.withValues(alpha: 0.0),
                            ExpatlioDesign.background.withValues(alpha: 0.92),
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
                    text: _reviewCountText(context, dueCount),
                    onTap: hasDueWords
                        ? () {
                            context.pushNamed(FlashcardWidget.routeName);
                          }
                        : null,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
