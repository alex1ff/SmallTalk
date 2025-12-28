import '/auth/firebase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lottie/lottie.dart';
import 'new_word_model.dart';
export 'new_word_model.dart';

class NewWordWidget extends StatefulWidget {
  const NewWordWidget({
    super.key,
    required this.word,
  });

  final String? word;

  @override
  State<NewWordWidget> createState() => _NewWordWidgetState();
}

class _NewWordWidgetState extends State<NewWordWidget> {
  late NewWordModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NewWordModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await Future.wait([
        Future(() async {
          _model.worrd = await YandexCall.call(
            text: widget.word,
          );
        }),
        Future(() async {
          _model.ssss = await TatoebaCall.call(
            lang: 'eng',
            q: widget.word,
          );
        }),
      ]);
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
      padding: EdgeInsetsDirectional.fromSTEB(4.0, 0.0, 4.0, 35.0),
      child: GestureDetector(
        onVerticalDragEnd: (details) async {
          if (_model.size <= 400.0) {
            _model.size = 250.0;
            safeSetState(() {});
          } else if (_model.size <= 200.0) {
            Navigator.pop(context);
          } else {
            _model.size = 750.0;
            safeSetState(() {});
          }
        },
        onVerticalDragUpdate: (details) async {
          if (_model.size <= 200.0) {
            Navigator.pop(context);
          } else {
            _model.size = _model.size - details.delta.dy;
            safeSetState(() {});
          }
        },
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          curve: Curves.elasticOut,
          width: double.infinity,
          height: _model.size,
          decoration: BoxDecoration(),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(0.0, 40.0, 0.0, 0.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    width: double.infinity,
                    height: double.infinity,
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(44.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(44.0),
                              border: Border.all(
                                color: Colors.white,
                                width: 0.5,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0.0, 8.0, 0.0, 8.0),
                                  child: Container(
                                    width: 45.0,
                                    height: 5.0,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      borderRadius: BorderRadius.circular(16.0),
                                    ),
                                  ),
                                ),
                                Flexible(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  16.0, 0.0, 16.0, 0.0),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                              borderRadius:
                                                  BorderRadius.circular(26.0),
                                            ),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  6.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Container(
                                                        width: 50.0,
                                                        height: 50.0,
                                                        decoration:
                                                            BoxDecoration(),
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  0.0, 0.0),
                                                          child: Text(
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                              'dciexor0' /* 🇺🇸 */,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  fontSize:
                                                                      18.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Text(
                                                      '${valueOrDefault<String>(
                                                        widget.word,
                                                        '-',
                                                      )} ',
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            fontFamily:
                                                                'sf pro display',
                                                            fontSize: 17.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w600,
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                Divider(
                                                  height: 1.0,
                                                  thickness: 1.0,
                                                  indent: 56.0,
                                                  endIndent: 16.0,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .alternate,
                                                ),
                                                Row(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  children: [
                                                    Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  6.0,
                                                                  0.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Container(
                                                        width: 50.0,
                                                        height: 50.0,
                                                        decoration:
                                                            BoxDecoration(),
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  0.0, 0.0),
                                                          child: Text(
                                                            FFLocalizations.of(
                                                                    context)
                                                                .getText(
                                                              'p23lw41o' /* 🇷🇺 */,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  fontSize:
                                                                      18.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .normal,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                    Builder(
                                                      builder: (context) {
                                                        if (_model.worrd !=
                                                            null) {
                                                          return Text(
                                                            YyStruct.maybeFromMap(
                                                                    (_model.worrd
                                                                            ?.jsonBody ??
                                                                        ''))!
                                                                .def
                                                                .firstOrNull!
                                                                .tr
                                                                .firstOrNull!
                                                                .text,
                                                            style: FlutterFlowTheme
                                                                    .of(context)
                                                                .bodyMedium
                                                                .override(
                                                                  fontFamily:
                                                                      'sf pro display',
                                                                  fontSize:
                                                                      17.0,
                                                                  letterSpacing:
                                                                      0.0,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w600,
                                                                ),
                                                          );
                                                        } else {
                                                          return Padding(
                                                            padding:
                                                                EdgeInsetsDirectional
                                                                    .fromSTEB(
                                                                        0.0,
                                                                        0.0,
                                                                        0.0,
                                                                        20.0),
                                                            child: Lottie.asset(
                                                              'assets/jsons/Material_Wave_Loading_Animation.json',
                                                              width: 44.67,
                                                              height: 20.2,
                                                              fit: BoxFit.cover,
                                                              animate: true,
                                                            ),
                                                          );
                                                        }
                                                      },
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        AnimatedOpacity(
                                          opacity:
                                              _model.worrd != null ? 1.0 : 0.0,
                                          duration: 200.0.ms,
                                          curve: Curves.easeInOut,
                                          child: Padding(
                                            padding: EdgeInsets.all(16.0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Builder(
                                                  builder: (context) {
                                                    final wwww =
                                                        YyStruct.maybeFromMap((_model
                                                                        .worrd
                                                                        ?.jsonBody ??
                                                                    ''))
                                                                ?.def
                                                                .toList() ??
                                                            [];

                                                    return ListView.separated(
                                                      padding: EdgeInsets.zero,
                                                      primary: false,
                                                      shrinkWrap: true,
                                                      scrollDirection:
                                                          Axis.vertical,
                                                      itemCount: wwww.length,
                                                      separatorBuilder:
                                                          (_, __) => SizedBox(
                                                              height: 24.0),
                                                      itemBuilder:
                                                          (context, wwwwIndex) {
                                                        final wwwwItem =
                                                            wwww[wwwwIndex];
                                                        return Column(
                                                          mainAxisSize:
                                                              MainAxisSize.max,
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            RichText(
                                                              textScaler:
                                                                  MediaQuery.of(
                                                                          context)
                                                                      .textScaler,
                                                              text: TextSpan(
                                                                children: [
                                                                  TextSpan(
                                                                    text: wwwwItem
                                                                        .text,
                                                                    style: FlutterFlowTheme.of(
                                                                            context)
                                                                        .bodyMedium
                                                                        .override(
                                                                          fontFamily:
                                                                              'sf pro display',
                                                                          fontSize:
                                                                              20.0,
                                                                          letterSpacing:
                                                                              0.0,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                        ),
                                                                  ),
                                                                  TextSpan(
                                                                    text:
                                                                        ' [${wwwwItem.ts}] ',
                                                                    style:
                                                                        TextStyle(
                                                                      fontFamily:
                                                                          'sf pro display',
                                                                      color: Color(
                                                                          0xFF727272),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .normal,
                                                                      fontSize:
                                                                          20.0,
                                                                    ),
                                                                  ),
                                                                  TextSpan(
                                                                    text: () {
                                                                      if (wwwwItem
                                                                              .pos ==
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
                                                                    style:
                                                                        TextStyle(
                                                                      fontFamily:
                                                                          'sf pro display',
                                                                      color: Color(
                                                                          0xFF727272),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .normal,
                                                                      fontSize:
                                                                          20.0,
                                                                      fontStyle:
                                                                          FontStyle
                                                                              .italic,
                                                                    ),
                                                                  )
                                                                ],
                                                                style: FlutterFlowTheme.of(
                                                                        context)
                                                                    .bodyMedium
                                                                    .override(
                                                                      fontFamily:
                                                                          'sf pro display',
                                                                      color: Colors
                                                                          .black,
                                                                      fontSize:
                                                                          20.0,
                                                                      letterSpacing:
                                                                          0.0,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .normal,
                                                                    ),
                                                              ),
                                                            ),
                                                            Builder(
                                                              builder:
                                                                  (context) {
                                                                final tr = wwwwItem
                                                                    .tr
                                                                    .toList()
                                                                    .take(3)
                                                                    .toList();

                                                                return ListView
                                                                    .separated(
                                                                  padding:
                                                                      EdgeInsets
                                                                          .zero,
                                                                  primary:
                                                                      false,
                                                                  shrinkWrap:
                                                                      true,
                                                                  scrollDirection:
                                                                      Axis.vertical,
                                                                  itemCount:
                                                                      tr.length,
                                                                  separatorBuilder: (_,
                                                                          __) =>
                                                                      SizedBox(
                                                                          height:
                                                                              8.0),
                                                                  itemBuilder:
                                                                      (context,
                                                                          trIndex) {
                                                                    final trItem =
                                                                        tr[trIndex];
                                                                    return Column(
                                                                      mainAxisSize:
                                                                          MainAxisSize
                                                                              .max,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .start,
                                                                      children: [
                                                                        Padding(
                                                                          padding: EdgeInsetsDirectional.fromSTEB(
                                                                              0.0,
                                                                              12.0,
                                                                              0.0,
                                                                              0.0),
                                                                          child:
                                                                              Builder(
                                                                            builder:
                                                                                (context) {
                                                                              final sssss = functions.syn(trItem.gen, trItem.text, trItem.syn.toList())?.toList() ?? [];

                                                                              return Wrap(
                                                                                spacing: 4.0,
                                                                                runSpacing: 8.0,
                                                                                alignment: WrapAlignment.start,
                                                                                crossAxisAlignment: WrapCrossAlignment.start,
                                                                                direction: Axis.horizontal,
                                                                                runAlignment: WrapAlignment.start,
                                                                                verticalDirection: VerticalDirection.down,
                                                                                clipBehavior: Clip.none,
                                                                                children: List.generate(sssss.length, (sssssIndex) {
                                                                                  final sssssItem = sssss[sssssIndex];
                                                                                  return Container(
                                                                                    height: 24.0,
                                                                                    decoration: BoxDecoration(
                                                                                      color: FlutterFlowTheme.of(context).primaryBackground,
                                                                                      borderRadius: BorderRadius.circular(50.0),
                                                                                    ),
                                                                                    child: Padding(
                                                                                      padding: EdgeInsetsDirectional.fromSTEB(12.0, 1.0, 12.0, 1.0),
                                                                                      child: RichText(
                                                                                        textScaler: MediaQuery.of(context).textScaler,
                                                                                        text: TextSpan(
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
                                                                                                'wwfgr0mf' /*   */,
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
                                                                          padding: EdgeInsetsDirectional.fromSTEB(
                                                                              0.0,
                                                                              6.0,
                                                                              0.0,
                                                                              0.0),
                                                                          child:
                                                                              Container(
                                                                            height:
                                                                                17.0,
                                                                            decoration:
                                                                                BoxDecoration(),
                                                                            child:
                                                                                Builder(
                                                                              builder: (context) {
                                                                                final meanb = trItem.mean.toList();

                                                                                return ListView.builder(
                                                                                  padding: EdgeInsets.zero,
                                                                                  primary: false,
                                                                                  shrinkWrap: true,
                                                                                  scrollDirection: Axis.horizontal,
                                                                                  itemCount: meanb.length,
                                                                                  itemBuilder: (context, meanbIndex) {
                                                                                    final meanbItem = meanb[meanbIndex];
                                                                                    return Text(
                                                                                      '${meanbItem.text}. ',
                                                                                      style: FlutterFlowTheme.of(context).bodyMedium.override(
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
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(
                                                          0.0, 16.0, 0.0, 0.0),
                                                  child: Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'c1hnqtt4' /* Примеры */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          fontSize: 20.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                  ),
                                                ),
                                                Container(
                                                  decoration: BoxDecoration(),
                                                  child: Padding(
                                                    padding:
                                                        EdgeInsetsDirectional
                                                            .fromSTEB(0.0, 12.0,
                                                                0.0, 0.0),
                                                    child: Builder(
                                                      builder: (context) {
                                                        final sss = DataStruct
                                                                    .maybeFromMap(
                                                                        (_model.ssss?.jsonBody ??
                                                                            ''))
                                                                ?.data
                                                                .toList() ??
                                                            [];

                                                        return ListView
                                                            .separated(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          primary: false,
                                                          shrinkWrap: true,
                                                          scrollDirection:
                                                              Axis.vertical,
                                                          itemCount: sss.length,
                                                          separatorBuilder: (_,
                                                                  __) =>
                                                              SizedBox(
                                                                  height: 8.0),
                                                          itemBuilder: (context,
                                                              sssIndex) {
                                                            final sssItem =
                                                                sss[sssIndex];
                                                            return Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            26.0),
                                                              ),
                                                              child: Padding(
                                                                padding:
                                                                    EdgeInsets
                                                                        .all(
                                                                            16.0),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      sssItem
                                                                          .text,
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            fontFamily:
                                                                                'sf pro display',
                                                                            color:
                                                                                Colors.black,
                                                                            fontSize:
                                                                                16.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                          ),
                                                                    ),
                                                                    Padding(
                                                                      padding: EdgeInsetsDirectional.fromSTEB(
                                                                          0.0,
                                                                          6.0,
                                                                          0.0,
                                                                          0.0),
                                                                      child:
                                                                          Text(
                                                                        valueOrDefault<
                                                                            String>(
                                                                          sssItem
                                                                              .translations
                                                                              .firstOrNull
                                                                              ?.text,
                                                                          '-',
                                                                        ),
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              fontFamily: 'sf pro display',
                                                                              color: Color(0xFF727272),
                                                                              fontSize: 16.0,
                                                                              letterSpacing: 0.0,
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
                                              ],
                                            ),
                                          ),
                                        ),
                                      ].addToEnd(SizedBox(height: 24.0)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      splashColor: Colors.transparent,
                      focusColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      onTap: () async {
                        Navigator.pop(context);
                      },
                      child: Stack(
                        alignment: AlignmentDirectional(0.0, 0.0),
                        children: [
                          Icon(
                            Icons.close,
                            color: FlutterFlowTheme.of(context).primaryText,
                            size: 24.0,
                          ),
                        ],
                      ),
                    ),
                    Builder(
                      builder: (context) {
                        if (_model.size >= 400.0) {
                          return InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              _model.size = 250.0;
                              safeSetState(() {});
                            },
                            child: Stack(
                              alignment: AlignmentDirectional(0.0, 0.0),
                              children: [
                                Icon(
                                  FFIcons.kexpand01,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                              ],
                            ),
                          );
                        } else {
                          return InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              _model.size = 750.0;
                              safeSetState(() {});
                            },
                            child: Stack(
                              alignment: AlignmentDirectional(0.0, 0.0),
                              children: [
                                Icon(
                                  FFIcons.kexpand01,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 24.0,
                                ),
                              ],
                            ),
                          );
                        }
                      },
                    ),
                    StreamBuilder<List<UserWordsRecord>>(
                      stream: queryUserWordsRecord(
                        parent: currentUserReference,
                      ),
                      builder: (context, snapshot) {
                        // Customize what your widget looks like when it's loading.
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
                        List<UserWordsRecord>
                            conditionalBuilderUserWordsRecordList =
                            snapshot.data!;

                        return Builder(
                          builder: (context) {
                            if (conditionalBuilderUserWordsRecordList
                                .where((e) =>
                                    e.entry.firstOrNull?.text ==
                                    YyStruct.maybeFromMap(
                                            (_model.worrd?.jsonBody ?? ''))
                                        ?.def
                                        .firstOrNull
                                        ?.text)
                                .toList()
                                .isNotEmpty) {
                              return InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
                                  unawaited(
                                    () async {
                                      await conditionalBuilderUserWordsRecordList
                                          .where((e) =>
                                              e.entry.firstOrNull?.text ==
                                              YyStruct.maybeFromMap(
                                                      (_model.worrd?.jsonBody ??
                                                          ''))
                                                  ?.def
                                                  .firstOrNull
                                                  ?.text)
                                          .toList()
                                          .firstOrNull!
                                          .reference
                                          .delete();
                                    }(),
                                  );
                                },
                                child: Stack(
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  children: [
                                    Icon(
                                      FFIcons.kstar012,
                                      color: Colors.black,
                                      size: 24.0,
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              return InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
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
                                          YyStruct.maybeFromMap(
                                                  (_model.worrd?.jsonBody ??
                                                      ''))
                                              ?.def,
                                        ),
                                        'Sentence':
                                            getSentenceListFirestoreData(
                                          DataStruct.maybeFromMap(
                                                  (_model.ssss?.jsonBody ?? ''))
                                              ?.data,
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
                                          YyStruct.maybeFromMap(
                                                  (_model.worrd?.jsonBody ??
                                                      ''))
                                              ?.def,
                                        ),
                                        'Sentence':
                                            getSentenceListFirestoreData(
                                          DataStruct.maybeFromMap(
                                                  (_model.ssss?.jsonBody ?? ''))
                                              ?.data,
                                        ),
                                      },
                                    ),
                                  }, userWordsRecordReference);

                                  safeSetState(() {});
                                },
                                child: Stack(
                                  alignment: AlignmentDirectional(0.0, 0.0),
                                  children: [
                                    Icon(
                                      FFIcons.kstar01,
                                      color: Colors.black,
                                      size: 24.0,
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        );
                      },
                    ),
                  ].divide(SizedBox(height: 12.0)),
                ),
              ].divide(SizedBox(width: 4.0)),
            ),
          ),
        ),
      ),
    );
  }
}
