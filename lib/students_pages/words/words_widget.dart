import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/word_pos_chip/word_pos_chip_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/students_pages/components/new_word/new_word_widget.dart';
import '/students_pages/components/word_card/word_card_widget.dart';
import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
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
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
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
        body: Stack(
          children: [
            SingleChildScrollView(
              primary: false,
              child: Column(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20.0),
                      child: Container(
                        width: double.infinity,
                        height: 172.0,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFFA765FC),
                              FlutterFlowTheme.of(context).secondary
                            ],
                            stops: [0.0, 1.0],
                            begin: AlignmentDirectional(-0.07, 1.0),
                            end: AlignmentDirectional(0.07, -1.0),
                          ),
                          borderRadius: BorderRadius.circular(20.0),
                        ),
                        child: Stack(
                          children: [
                            Align(
                              alignment: AlignmentDirectional(1.0, 0.0),
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
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
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 16.0, 16.0, 16.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      InkWell(
                                        splashColor: Colors.transparent,
                                        focusColor: Colors.transparent,
                                        hoverColor: Colors.transparent,
                                        highlightColor: Colors.transparent,
                                        onTap: () async {
                                          await showModalBottomSheet(
                                            isScrollControlled: true,
                                            backgroundColor: Colors.transparent,
                                            enableDrag: false,
                                            context: context,
                                            builder: (context) {
                                              return WebViewAware(
                                                child: GestureDetector(
                                                  onTap: () {
                                                    FocusScope.of(context)
                                                        .unfocus();
                                                    FocusManager
                                                        .instance.primaryFocus
                                                        ?.unfocus();
                                                  },
                                                  child: Padding(
                                                    padding:
                                                        MediaQuery.viewInsetsOf(
                                                            context),
                                                    child: NewWordWidget(
                                                      word: 'hello',
                                                      langCode: 'eng',
                                                    ),
                                                  ),
                                                ),
                                              );
                                            },
                                          ).then(
                                              (value) => safeSetState(() {}));
                                        },
                                        child: CircularPercentIndicator(
                                          percent: 0.75,
                                          radius: 30.0,
                                          lineWidth: 3.0,
                                          animation: true,
                                          animateFromLastPercent: true,
                                          progressColor: Colors.white,
                                          backgroundColor: Color(0x30FFFFFF),
                                          center: Text(
                                            FFLocalizations.of(context).getText(
                                              'mh59o8kl' /* 75% */,
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .headlineSmall
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: Colors.white,
                                                  fontSize: 17.0,
                                                  letterSpacing: 0.0,
                                                ),
                                          ),
                                        ),
                                      ),
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
                                    ],
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 0.0, 8.0, 0.0),
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
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(30.0, 0.0, 30.0, 0.0),
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
                    padding:
                        EdgeInsetsDirectional.fromSTEB(50.0, 0.0, 50.0, 0.0),
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
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 40.0, 0.0, 0.0),
                    child: Container(
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
                                    _model.pos == null || _model.pos == ''
                                        ? FlutterFlowTheme.of(context).primary
                                        : FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                    FlutterFlowTheme.of(context).primary,
                                  ),
                                  borderRadius: BorderRadius.circular(24.0),
                                  shape: BoxShape.rectangle,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        16.0, 0.0, 16.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'itgwbmq6' /* Все */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: valueOrDefault<Color>(
                                              _model.pos == null ||
                                                      _model.pos == ''
                                                  ? FlutterFlowTheme.of(context)
                                                      .primaryBackground
                                                  : FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              FlutterFlowTheme.of(context)
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                              updateCallback: () => safeSetState(() {}),
                              child: WordPosChipWidget(
                                text: FFLocalizations.of(context).getText(
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
                  ),
                  Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(6.0, 12.0, 6.0, 0.0),
                    child: StreamBuilder<List<UserWordsRecord>>(
                      stream: _model.wordsStream,
                      builder: (context, snapshot) {
                        List<UserWordsRecord> containerUserWordsRecordList =
                            snapshot.data ?? [];

                        return Container(
                          decoration: BoxDecoration(),
                          child: Builder(
                            builder: (context) {
                              final pronoun = containerUserWordsRecordList
                                  .where((e) => _model.pos != null &&
                                          _model.pos != ''
                                      ? (e.entry.firstOrNull?.pos == _model.pos)
                                      : true)
                                  .toList();
                              if (pronoun.isEmpty) {
                                return Center(
                                  child: Image.asset(
                                    'assets/images/Group_117127509d5.png',
                                    width: 100.0,
                                    fit: BoxFit.contain,
                                  ),
                                );
                              }

                              return ListView.separated(
                                padding: EdgeInsets.zero,
                                primary: false,
                                shrinkWrap: true,
                                scrollDirection: Axis.vertical,
                                itemCount: pronoun.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: 6.0),
                                itemBuilder: (context, pronounIndex) {
                                  final pronounItem = pronoun[pronounIndex];
                                  return WordCardWidget(
                                    key: Key(
                                        'Keyeax_${pronounIndex}_of_${pronoun.length}'),
                                    wordDoc: pronounItem,
                                  );
                                },
                              );
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
            Container(
              width: double.infinity,
              height: 55.0,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    FlutterFlowTheme.of(context).secondaryBackground,
                    Color(0xEFF2F2F7),
                    Color(0x00F2F2F7)
                  ],
                  stops: [0.0, 0.7, 1.0],
                  begin: AlignmentDirectional(0.0, -1.0),
                  end: AlignmentDirectional(0, 1.0),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
