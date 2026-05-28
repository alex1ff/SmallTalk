import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import '/students_pages/words/word_detail_widget.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
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
  late WordsModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WordsModel());
    _model.wordsStream = queryUserWordsRecord(
      parent: currentUserReference,
    );
    _model.wordReviewsStream = queryWordReviewsRecord(
      parent: currentUserReference,
    );

    final userRef = currentUserReference;
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
      ruText:
          '${_dueCountLabel(dueCount)} ${_ruWordsPlural(dueCount)} к повторению',
      enText:
          '${_dueCountLabel(dueCount)} ${dueCount == 1 ? 'word' : 'words'} to review',
    );
  }

  double _reviewBarBottomOffset(BuildContext context) {
    final navClearance =
        Theme.of(context).platform == TargetPlatform.android ? 12.0 : 10.0;
    return MediaQuery.paddingOf(context).bottom + navClearance;
  }

  double _contentBottomPadding(BuildContext context) {
    return _reviewBarBottomOffset(context) + 76.0;
  }

  Future<void> _openWordPage(UserWordsRecord wordDoc) async {
    await Navigator.of(context).push<void>(
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
          builder: (context, reviewSnapshot) {
            final reviews = reviewSnapshot.data ?? const <WordReviewsRecord>[];
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
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return Center(
                              child: SizedBox(
                                width: 50.0,
                                height: 50.0,
                                child: SpinKitCircle(
                                  color: FlutterFlowTheme.of(context).secondary,
                                  size: 50.0,
                                ),
                              ),
                            );
                          }

                          final words = snapshot.data!;
                          if (words.isEmpty) {
                            return Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                0.0,
                                0.0,
                                0.0,
                                _contentBottomPadding(context),
                              ),
                              child: EmptyWidget(
                                txt:
                                    'В этом разделе будут появляться слова, \nкоторые вы добавите во время занятий. \nСохраните первое слово, чтобы начать формировать свой личный словарь',
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
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 0.0),
                            itemBuilder: (context, index) {
                              final word = words[index];
                              return _DictionaryWordRow(
                                wordDoc: word,
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
                      height: _reviewBarBottomOffset(context) + 96.0,
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
                  child: _ReviewWordsBar(
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

class _DictionaryWordRow extends StatelessWidget {
  const _DictionaryWordRow({
    required this.wordDoc,
    required this.onTap,
  });

  final UserWordsRecord wordDoc;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final entry = wordDoc.entry.firstOrNull;
    final sourceText = valueOrDefault<String>(entry?.text, '-');
    final translationText =
        valueOrDefault<String>(entry?.tr.firstOrNull?.text, '-');
    final textStyle = FlutterFlowTheme.of(context).bodyMedium.override(
          fontFamily: 'sf pro display',
          color: ExpatlioDesign.text,
          fontSize: 16.0,
          letterSpacing: 0.0,
          fontWeight: FontWeight.w500,
          lineHeight: 1.2,
        );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12.0),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 49.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: ExpatlioDesign.border,
              width: 1.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16.0, 8.0, 16.0, 8.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Text(
                    sourceText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
                  ),
                ),
                const SizedBox(width: 24.0),
                Expanded(
                  flex: 7,
                  child: Text(
                    translationText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: textStyle,
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

class _ReviewWordsBar extends StatelessWidget {
  const _ReviewWordsBar({
    required this.text,
    required this.onTap,
  });

  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final decoration = enabled
        ? BoxDecoration(
            gradient: ExpatlioDesign.primaryGradient,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: const [
              BoxShadow(
                color: Color(0x302B0B63),
                blurRadius: 20.0,
                offset: Offset(0.0, 8.0),
              ),
            ],
          )
        : BoxDecoration(
            color: ExpatlioDesign.mutedSurface,
            borderRadius: BorderRadius.circular(16.0),
            border: Border.all(color: ExpatlioDesign.border),
          );
    final foregroundColor = enabled ? Colors.white : ExpatlioDesign.muted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        onTap: onTap,
        child: Ink(
          height: 60.0,
          decoration: decoration,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18.0, 0.0, 13.0, 0.0),
            child: Row(
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: foregroundColor,
                  size: 21.0,
                ),
                const SizedBox(width: 14.0),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: foregroundColor,
                          fontSize: 16.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (enabled) ...[
                  const SizedBox(width: 12.0),
                  Container(
                    height: 44.0,
                    constraints: const BoxConstraints(minWidth: 96.0),
                    decoration: BoxDecoration(
                      color: const Color(0x33FFFFFF),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        20.0, 0.0, 20.0, 0.0),
                    alignment: Alignment.center,
                    child: Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Повторить',
                        enText: 'Review',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: Colors.white,
                            fontSize: 16.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
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
