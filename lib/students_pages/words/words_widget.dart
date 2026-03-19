import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/components/word_pos_chip/word_pos_chip_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/students_pages/components/new_word/new_word_widget.dart';
import '/students_pages/components/word_card/word_card_widget.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
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

  Future<void> _openNewWordSheet() async {
    await showModalBottomSheet(
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      context: context,
      builder: (context) {
        return WebViewAware(
          child: GestureDetector(
            onTap: () {
              FocusScope.of(context).unfocus();
              FocusManager.instance.primaryFocus?.unfocus();
            },
            child: Padding(
              padding: MediaQuery.viewInsetsOf(context),
              child: const NewWordWidget(
                word: 'hello',
                langCode: 'eng',
              ),
            ),
          ),
        );
      },
    ).then((value) => safeSetState(() {}));
  }

  String _dueCountLabel(int dueCount) {
    if (dueCount > 99) {
      return '99+';
    }
    return dueCount.toString();
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
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: SingleChildScrollView(
          primary: false,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              StreamBuilder<List<WordReviewsRecord>>(
                stream: _model.wordReviewsStream,
                builder: (context, reviewSnapshot) {
                  final reviews = reviewSnapshot.data ?? const <WordReviewsRecord>[];
                  final now = DateTime.now();
                  final dueCount = reviews
                      .where(
                        (review) =>
                            review.dueAt != null && !review.dueAt!.isAfter(now),
                      )
                      .length;

                  return Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20.0),
                        onTap: () async {
                          context.pushNamed(FlashcardWidget.routeName);
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20.0),
                          child: Container(
                            width: double.infinity,
                            height: 172.0,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFA765FC),
                                  FlutterFlowTheme.of(context).secondary,
                                ],
                                stops: const [0.0, 1.0],
                                begin: const AlignmentDirectional(-0.07, 1.0),
                                end: const AlignmentDirectional(0.07, -1.0),
                              ),
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                            child: Stack(
                              children: [
                                Align(
                                  alignment: const AlignmentDirectional(1.0, 0.0),
                                  child: Padding(
                                    padding: const EdgeInsetsDirectional.fromSTEB(
                                        128.0, 0.0, 0.0, 0.0),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8.0),
                                      child: Image.asset(
                                        'assets/images/Dot_pattern.png',
                                        width: 300.0,
                                        height: 200.0,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding:
                                      const EdgeInsetsDirectional.fromSTEB(16.0, 16.0, 16.0, 16.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            InkWell(
                                              splashColor: Colors.transparent,
                                              focusColor: Colors.transparent,
                                              hoverColor: Colors.transparent,
                                              highlightColor: Colors.transparent,
                                              onTap: _openNewWordSheet,
                                              child: Container(
                                                width: 60.0,
                                                height: 60.0,
                                                decoration: BoxDecoration(
                                                  color: const Color(0x24FFFFFF),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: const Color(0x4DFFFFFF),
                                                    width: 2.0,
                                                  ),
                                                ),
                                                child: const Icon(
                                                  Icons.add_rounded,
                                                  color: Colors.white,
                                                  size: 28.0,
                                                ),
                                              ),
                                            ),
                                            const Spacer(),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 10.0,
                                                vertical: 6.0,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0x24FFFFFF),
                                                borderRadius: BorderRadius.circular(18.0),
                                              ),
                                              child: Text(
                                                FFLocalizations.of(context).getVariableText(
                                                  ruText:
                                                      '${_dueCountLabel(dueCount)} к повторению',
                                                  enText:
                                                      '${_dueCountLabel(dueCount)} due now',
                                                ),
                                                style: FlutterFlowTheme.of(context)
                                                    .bodyMedium
                                                    .override(
                                                      fontFamily: 'sf pro display',
                                                      color: Colors.white,
                                                      fontSize: 13.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 10.0),
                                            Text(
                                              FFLocalizations.of(context).getText(
                                                'w44p5wo4' /* Flash‑cards */,
                                              ),
                                              style: FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .override(
                                                    fontFamily: 'sf pro display',
                                                    color: Colors.white,
                                                    fontSize: 20.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            const SizedBox(height: 4.0),
                                            Text(
                                              FFLocalizations.of(context).getVariableText(
                                                ruText: 'Откройте карточки и повторите слова по интервальному плану.',
                                                enText:
                                                    'Open flashcards and review words on their interval schedule.',
                                              ),
                                              style: FlutterFlowTheme.of(context)
                                                  .bodyMedium
                                                  .override(
                                                    fontFamily: 'sf pro display',
                                                    color: const Color(0xCCFFFFFF),
                                                    fontSize: 13.0,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.normal,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsetsDirectional.fromSTEB(
                                            12.0, 0.0, 8.0, 0.0),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8.0),
                                          child: Image.asset(
                                            'assets/images/Cards-2.png',
                                            height: 124.0,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(30.0, 0.0, 30.0, 0.0),
                child: Container(
                  width: double.infinity,
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20.0),
                      bottomRight: Radius.circular(20.0),
                      topLeft: Radius.circular(0.0),
                      topRight: Radius.circular(0.0),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(50.0, 0.0, 50.0, 0.0),
                child: Container(
                  width: double.infinity,
                  height: 8.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primary,
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20.0),
                      bottomRight: Radius.circular(20.0),
                      topLeft: Radius.circular(0.0),
                      topRight: Radius.circular(0.0),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 40.0, 0.0, 0.0),
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
                    List<UserWordsRecord> containerUserWordsRecordList =
                        snapshot.data!;

                    return Container(
                      decoration: BoxDecoration(),
                      child: Builder(
                        builder: (context) {
                          if (containerUserWordsRecordList.isNotEmpty) {
                            return Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  height: 45.0,
                                  decoration: BoxDecoration(),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        InkWell(
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          onTap: () async {
                                            _model.pos = '';
                                            safeSetState(() {});
                                          },
                                          child: Container(
                                            height: 100.0,
                                            decoration: BoxDecoration(
                                              color: valueOrDefault<Color>(
                                                _model.pos == null ||
                                                        _model.pos == ''
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primary
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(24.0),
                                              shape: BoxShape.rectangle,
                                            ),
                                            child: Align(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              child: Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        16.0, 0.0, 16.0, 0.0),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'itgwbmq6' /* Все */,
                                                  ),
                                                  style:
                                                      FlutterFlowTheme.of(
                                                              context)
                                                          .bodyMedium
                                                          .override(
                                                            fontFamily:
                                                                'sf pro display',
                                                            color:
                                                                valueOrDefault<
                                                                    Color>(
                                                              _model.pos == null ||
                                                                      _model.pos ==
                                                                          ''
                                                                  ? FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryBackground
                                                                  : FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .primaryBackground,
                                                            ),
                                                            fontSize: 16.0,
                                                            letterSpacing: 0.0,
                                                          ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel1,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'lgijjwoy' /* Существительное */,
                                            ),
                                            pos: 'noun',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel2,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'o5rmy0ju' /* Глагол */,
                                            ),
                                            pos: 'verb',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel3,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'e5h653gn' /* Прилагательное */,
                                            ),
                                            pos: 'adjective',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel4,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'afe30qzp' /* Наречие */,
                                            ),
                                            pos: 'adverb',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel5,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'wyn9ioic' /* Местоимение */,
                                            ),
                                            pos: 'pronoun',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel6,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'jeewyk0t' /* Предлог */,
                                            ),
                                            pos: 'preposition',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel7,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              '09jddjbc' /* Союз */,
                                            ),
                                            pos: 'conjunction',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel8,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'd8fv2zgh' /* Междометие */,
                                            ),
                                            pos: 'interjection',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel9,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              '6jcnedaf' /* Частица */,
                                            ),
                                            pos: 'particle',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel10,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'qhknk21t' /* Артикль */,
                                            ),
                                            pos: 'article',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel11,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              't6bc6qig' /* Числительное */,
                                            ),
                                            pos: 'numeral',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                        wrapWithModel(
                                          model: _model.wordPosChipModel12,
                                          updateCallback: () =>
                                              safeSetState(() {}),
                                          child: WordPosChipWidget(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'cev0022q' /* Причастие */,
                                            ),
                                            pos: 'participle',
                                            selectedPos: valueOrDefault<String>(
                                              _model.pos,
                                              '-',
                                            ),
                                            action: (pos) async {
                                              _model.pos = pos;
                                              safeSetState(() {});
                                            },
                                          ),
                                        ),
                                      ]
                                          .divide(SizedBox(width: 6.0))
                                          .around(SizedBox(width: 6.0)),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      6.0, 12.0, 6.0, 0.0),
                                  child: Container(
                                    decoration: BoxDecoration(),
                                    child: Builder(
                                      builder: (context) {
                                        final pronoun =
                                            containerUserWordsRecordList
                                                .where((e) =>
                                                    _model.pos != null &&
                                                            _model.pos != ''
                                                        ? (e.entry.firstOrNull
                                                                ?.pos ==
                                                            _model.pos)
                                                        : true)
                                                .toList();
                                        if (pronoun.isEmpty) {
                                          return Center(
                                            child: EmptyWidget(
                                              txt:
                                                  'По выбранной части речи пока ничего нет. Попробуйте другой фильтр.',
                                            ),
                                          );
                                        }

                                        return Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: List.generate(
                                              pronoun.length, (pronounIndex) {
                                            final pronounItem =
                                                pronoun[pronounIndex];
                                            return Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                0.0,
                                                pronounIndex == 0 ? 0.0 : 6.0,
                                                0.0,
                                                0.0,
                                              ),
                                              child: WordCardWidget(
                                                key: Key(
                                                    'Keyeax_${pronounIndex}_of_${pronoun.length}'),
                                                wordDoc: pronounItem,
                                              ),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            );
                          } else {
                            return EmptyWidget(
                              txt:
                                  'В этом разделе будут появляться слова, \nкоторые вы добавите во время занятий. \nСохраните первое слово, чтобы начать формировать свой личный словарь',
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ]
                .addToStart(SizedBox(height: 55.0))
                .addToEnd(SizedBox(height: 120.0)),
          ),
        ),
      ),
    );
  }
}
