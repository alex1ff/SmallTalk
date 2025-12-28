import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'woed_model.dart';
export 'woed_model.dart';

class WoedWidget extends StatefulWidget {
  const WoedWidget({
    super.key,
    required this.word,
  });

  final UserWordsRecord? word;

  @override
  State<WoedWidget> createState() => _WoedWidgetState();
}

class _WoedWidgetState extends State<WoedWidget> {
  late WoedModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WoedModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.entry = widget.word!.entry.toList().cast<EntryStruct>();
      _model.sentence = widget.word!.sentence.toList().cast<SentenceStruct>();
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            height: 16.0,
            child: custom_widgets.NotchedClipper(
              width: double.infinity,
              height: 16.0,
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(6.0, 16.0, 6.0, 0.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(26.0),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        6.0, 0.0, 0.0, 0.0),
                                    child: Container(
                                      width: 50.0,
                                      height: 50.0,
                                      decoration: BoxDecoration(),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            '3d0bey8j' /* 🇺🇸 */,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                fontSize: 18.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.normal,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    valueOrDefault<String>(
                                      _model.entry.firstOrNull?.text,
                                      '-',
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          fontSize: 17.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                              Divider(
                                height: 1.0,
                                thickness: 1.0,
                                indent: 56.0,
                                endIndent: 16.0,
                                color: FlutterFlowTheme.of(context).alternate,
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        6.0, 0.0, 0.0, 0.0),
                                    child: Container(
                                      width: 50.0,
                                      height: 50.0,
                                      decoration: BoxDecoration(),
                                      child: Align(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'scaig71z' /* 🇷🇺 */,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                fontSize: 18.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.normal,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Text(
                                    valueOrDefault<String>(
                                      _model.entry.firstOrNull?.tr.firstOrNull
                                          ?.text,
                                      '-',
                                    ),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          fontSize: 17.0,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Flexible(
                        child: AnimatedOpacity(
                          opacity:
                              widget.word!.sentence.isNotEmpty ? 1.0 : 0.0,
                          duration: 200.0.ms,
                          curve: Curves.easeInOut,
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 0.0, 16.0, 0.0),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Builder(
                                    builder: (context) {
                                      final wwww = _model.entry.toList();

                                      return ListView.separated(
                                        padding: EdgeInsets.zero,
                                        primary: false,
                                        shrinkWrap: true,
                                        scrollDirection: Axis.vertical,
                                        itemCount: wwww.length,
                                        separatorBuilder: (_, __) =>
                                            SizedBox(height: 24.0),
                                        itemBuilder: (context, wwwwIndex) {
                                          final wwwwItem = wwww[wwwwIndex];
                                          return Column(
                                            mainAxisSize: MainAxisSize.max,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              RichText(
                                                textScaler:
                                                    MediaQuery.of(context)
                                                        .textScaler,
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: wwwwItem.text,
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            fontFamily: 'Cool',
                                                            fontSize: 20.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight
                                                                    .normal,
                                                          ),
                                                    ),
                                                    TextSpan(
                                                      text:
                                                          ' [${wwwwItem.ts}] ',
                                                      style: TextStyle(
                                                        fontFamily: 'Cool',
                                                        color:
                                                            Color(0xFF727272),
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontSize: 20.0,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: () {
                                                        if (wwwwItem.pos ==
                                                            'noun') {
                                                          return 'сущ';
                                                        } else if (wwwwItem
                                                                .pos ==
                                                            'abjective') {
                                                          return 'прил';
                                                        } else if (wwwwItem
                                                                .pos ==
                                                            'participle') {
                                                          return 'прич';
                                                        } else if (wwwwItem
                                                                .pos ==
                                                            'verb') {
                                                          return 'гл';
                                                        } else {
                                                          return ' ';
                                                        }
                                                      }(),
                                                      style: TextStyle(
                                                        fontFamily: 'Cool',
                                                        color:
                                                            Color(0xFF727272),
                                                        fontWeight:
                                                            FontWeight.normal,
                                                        fontSize: 20.0,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    )
                                                  ],
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color: Colors.black,
                                                        fontSize: 20.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                      ),
                                                ),
                                              ),
                                              Builder(
                                                builder: (context) {
                                                  final tr = wwwwItem.tr
                                                      .toList()
                                                      .take(3)
                                                      .toList();

                                                  return ListView.separated(
                                                    padding: EdgeInsets.zero,
                                                    primary: false,
                                                    shrinkWrap: true,
                                                    scrollDirection:
                                                        Axis.vertical,
                                                    itemCount: tr.length,
                                                    separatorBuilder: (_, __) =>
                                                        SizedBox(height: 8.0),
                                                    itemBuilder:
                                                        (context, trIndex) {
                                                      final trItem =
                                                          tr[trIndex];
                                                      return Column(
                                                        mainAxisSize:
                                                            MainAxisSize.max,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        12.0,
                                                                        0.0,
                                                                        0.0),
                                                            child: Builder(
                                                              builder:
                                                                  (context) {
                                                                final sssss = functions
                                                                        .syn(
                                                                            trItem.gen,
                                                                            trItem.text,
                                                                            trItem.syn.toList())
                                                                        ?.toList() ??
                                                                    [];

                                                                return Wrap(
                                                                  spacing: 4.0,
                                                                  runSpacing:
                                                                      8.0,
                                                                  alignment:
                                                                      WrapAlignment
                                                                          .start,
                                                                  crossAxisAlignment:
                                                                      WrapCrossAlignment
                                                                          .start,
                                                                  direction: Axis
                                                                      .horizontal,
                                                                  runAlignment:
                                                                      WrapAlignment
                                                                          .start,
                                                                  verticalDirection:
                                                                      VerticalDirection
                                                                          .down,
                                                                  clipBehavior:
                                                                      Clip.none,
                                                                  children: List
                                                                      .generate(
                                                                          sssss
                                                                              .length,
                                                                          (sssssIndex) {
                                                                    final sssssItem =
                                                                        sssss[
                                                                            sssssIndex];
                                                                    return Container(
                                                                      height:
                                                                          24.0,
                                                                      decoration:
                                                                          BoxDecoration(
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .primaryBackground,
                                                                        borderRadius:
                                                                            BorderRadius.circular(50.0),
                                                                      ),
                                                                      child:
                                                                          Padding(
                                                                        padding: EdgeInsetsDirectional.fromSTEB(
                                                                            12.0,
                                                                            1.0,
                                                                            12.0,
                                                                            1.0),
                                                                        child:
                                                                            RichText(
                                                                          textScaler:
                                                                              MediaQuery.of(context).textScaler,
                                                                          text:
                                                                              TextSpan(
                                                                            children: [
                                                                              TextSpan(
                                                                                text: sssssItem.text,
                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                      fontFamily: 'sf pro display',
                                                                                      color: Colors.black,
                                                                                      fontSize: 15.0,
                                                                                      letterSpacing: 0.0,
                                                                                      fontWeight: FontWeight.w500,
                                                                                    ),
                                                                              ),
                                                                              TextSpan(
                                                                                text: FFLocalizations.of(context).getText(
                                                                                  'lpzroxlx' /*   */,
                                                                                ),
                                                                                style: TextStyle(),
                                                                              ),
                                                                              TextSpan(
                                                                                text: sssssItem.gen,
                                                                                style: TextStyle(
                                                                                  color: Color(0xFF727272),
                                                                                ),
                                                                              )
                                                                            ],
                                                                            style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                  fontFamily: 'sf pro display',
                                                                                  fontSize: 16.0,
                                                                                  letterSpacing: 0.0,
                                                                                  fontWeight: FontWeight.normal,
                                                                                ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    );
                                                                  }),
                                                                );
                                                              },
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        6.0,
                                                                        0.0,
                                                                        0.0),
                                                            child: Container(
                                                              height: 17.0,
                                                              decoration:
                                                                  BoxDecoration(),
                                                              child: Builder(
                                                                builder:
                                                                    (context) {
                                                                  final meanb =
                                                                      trItem
                                                                          .mean
                                                                          .toList();

                                                                  return ListView
                                                                      .builder(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    primary:
                                                                        false,
                                                                    shrinkWrap:
                                                                        true,
                                                                    scrollDirection:
                                                                        Axis.horizontal,
                                                                    itemCount: meanb
                                                                        .length,
                                                                    itemBuilder:
                                                                        (context,
                                                                            meanbIndex) {
                                                                      final meanbItem =
                                                                          meanb[
                                                                              meanbIndex];
                                                                      return Text(
                                                                        '${meanbItem.text}. ',
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              fontFamily: 'sf pro display',
                                                                              color: Color(0xFF727272),
                                                                              fontSize: 15.0,
                                                                              letterSpacing: 0.0,
                                                                            ),
                                                                      );
                                                                    },
                                                                  );
                                                                },
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0.0, 16.0, 0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        '7118sl5m' /* Примеры */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'Cool',
                                            fontSize: 20.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0.0, 12.0, 0.0, 0.0),
                                      child: Builder(
                                        builder: (context) {
                                          final sss = _model.sentence.toList();

                                          return ListView.separated(
                                            padding: EdgeInsets.zero,
                                            primary: false,
                                            shrinkWrap: true,
                                            scrollDirection: Axis.vertical,
                                            itemCount: sss.length,
                                            separatorBuilder: (_, __) =>
                                                SizedBox(height: 8.0),
                                            itemBuilder: (context, sssIndex) {
                                              final sssItem = sss[sssIndex];
                                              return Container(
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryBackground,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          26.0),
                                                ),
                                                child: Padding(
                                                  padding: EdgeInsets.all(16.0),
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        sssItem.text,
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'sf pro display',
                                                              color:
                                                                  Colors.black,
                                                              fontSize: 16.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                      ),
                                                      Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    6.0,
                                                                    0.0,
                                                                    0.0),
                                                        child: Text(
                                                          valueOrDefault<
                                                              String>(
                                                            sssItem
                                                                .translations
                                                                .firstOrNull
                                                                ?.text,
                                                            '-',
                                                          ),
                                                          style: FlutterFlowTheme
                                                                  .of(context)
                                                              .bodyMedium
                                                              .override(
                                                                fontFamily:
                                                                    'sf pro display',
                                                                color: Color(
                                                                    0xFF727272),
                                                                fontSize: 16.0,
                                                                letterSpacing:
                                                                    0.0,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ]
                                    .addToStart(SizedBox(height: 24.0))
                                    .addToEnd(SizedBox(height: 35.0)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: AlignmentDirectional(1.0, 1.0),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 6.0, 35.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FlutterFlowIconButton(
                          borderRadius: 70.0,
                          buttonSize: 45.0,
                          fillColor: Colors.white,
                          icon: Icon(
                            Icons.close_rounded,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 20.0,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                          },
                        ),
                        StreamBuilder<List<UserWordsRecord>>(
                          stream: queryUserWordsRecord(
                            parent: currentUserReference,
                            queryBuilder: (userWordsRecord) =>
                                userWordsRecord.where(
                              'entry',
                              arrayContains: getEntryFirestoreData(
                                _model.entry.firstOrNull,
                                true,
                              ),
                            ),
                            singleRecord: true,
                          ),
                          builder: (context, snapshot) {
                            // Customize what your widget looks like when it's loading.
                            if (!snapshot.hasData) {
                              return Center(
                                child: SizedBox(
                                  width: 50.0,
                                  height: 50.0,
                                  child: SpinKitCircle(
                                    color:
                                        FlutterFlowTheme.of(context).secondary,
                                    size: 50.0,
                                  ),
                                ),
                              );
                            }
                            List<UserWordsRecord>
                                conditionalBuilderUserWordsRecordList =
                                snapshot.data!;
                            final conditionalBuilderUserWordsRecord =
                                conditionalBuilderUserWordsRecordList.isNotEmpty
                                    ? conditionalBuilderUserWordsRecordList
                                        .first
                                    : null;

                            return Builder(
                              builder: (context) {
                                if (conditionalBuilderUserWordsRecord != null) {
                                  return FlutterFlowIconButton(
                                    borderRadius: 70.0,
                                    buttonSize: 45.0,
                                    fillColor: Colors.white,
                                    icon: Icon(
                                      Icons.favorite_rounded,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 20.0,
                                    ),
                                    onPressed: () async {
                                      unawaited(
                                        () async {
                                          await conditionalBuilderUserWordsRecord
                                              .reference
                                              .delete();
                                        }(),
                                      );
                                    },
                                  );
                                } else {
                                  return FlutterFlowIconButton(
                                    borderRadius: 70.0,
                                    buttonSize: 45.0,
                                    fillColor: Colors.white,
                                    icon: Icon(
                                      Icons.favorite_border,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 20.0,
                                    ),
                                    onPressed: () async {
                                      var userWordsRecordReference =
                                          UserWordsRecord.createDoc(
                                              currentUserReference!);
                                      await userWordsRecordReference.set({
                                        ...createUserWordsRecordData(
                                          addedAt: getCurrentTimestamp,
                                        ),
                                        ...mapToFirestore(
                                          {
                                            'entry': getEntryListFirestoreData(
                                              _model.entry,
                                            ),
                                            'Sentence':
                                                getSentenceListFirestoreData(
                                              _model.sentence,
                                            ),
                                          },
                                        ),
                                      });
                                      _model.erweerw =
                                          UserWordsRecord.getDocumentFromData({
                                        ...createUserWordsRecordData(
                                          addedAt: getCurrentTimestamp,
                                        ),
                                        ...mapToFirestore(
                                          {
                                            'entry': getEntryListFirestoreData(
                                              _model.entry,
                                            ),
                                            'Sentence':
                                                getSentenceListFirestoreData(
                                              _model.sentence,
                                            ),
                                          },
                                        ),
                                      }, userWordsRecordReference);

                                      safeSetState(() {});
                                    },
                                  );
                                }
                              },
                            );
                          },
                        ),
                      ].divide(SizedBox(height: 12.0)),
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
