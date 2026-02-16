import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/review_card/review_card_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'my_rew_model.dart';
export 'my_rew_model.dart';

class MyRewWidget extends StatefulWidget {
  const MyRewWidget({super.key});

  static String routeName = 'myRew';
  static String routePath = '/myRew';

  @override
  State<MyRewWidget> createState() => _MyRewWidgetState();
}

class _MyRewWidgetState extends State<MyRewWidget> {
  late MyRewModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => MyRewModel());
    _model.reviewsFuture = queryReviewsRecordOnce(
      queryBuilder: (reviewsRecord) => reviewsRecord
          .where(
            'fromUserId',
            isEqualTo: currentUserReference,
          )
          .orderBy('createdAt', descending: true),
    );
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ReviewsRecord>>(
      future: _model.reviewsFuture,
      builder: (context, snapshot) {
        List<ReviewsRecord> myRewReviewsRecordList = snapshot.data ?? [];

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
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
                        child: Container(
                          width: double.infinity,
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
                                    _model.rate = 0;
                                    safeSetState(() {});
                                  },
                                  child: Container(
                                    width: 75.0,
                                    height: 40.0,
                                    decoration: BoxDecoration(
                                      color: valueOrDefault<Color>(
                                        _model.rate == 0
                                            ? FlutterFlowTheme.of(context)
                                                .primary
                                            : FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                        FlutterFlowTheme.of(context).primary,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                    ),
                                    child: Align(
                                      alignment: AlignmentDirectional(0.0, 0.0),
                                      child: Text(
                                        FFLocalizations.of(context).getText(
                                          '15c59bwa' /* Все */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color: valueOrDefault<Color>(
                                                _model.rate == 0
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                FlutterFlowTheme.of(context)
                                                    .primaryBackground,
                                              ),
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _model.rate = 5;
                                    safeSetState(() {});
                                  },
                                  child: Container(
                                    width: 75.0,
                                    height: 40.0,
                                    decoration: BoxDecoration(
                                      color: valueOrDefault<Color>(
                                        _model.rate == 5
                                            ? FlutterFlowTheme.of(context)
                                                .primary
                                            : FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                        FlutterFlowTheme.of(context).primary,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            'q7mf0a7y' /* 5 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 5
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
                                                          .primaryText,
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                                ),
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Icon(
                                          FFIcons.kstar012,
                                          color: Color(0xFFFFCC31),
                                          size: 13.0,
                                        ),
                                      ].divide(SizedBox(width: 3.0)),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _model.rate = 4;
                                    safeSetState(() {});
                                  },
                                  child: Container(
                                    width: 75.0,
                                    height: 40.0,
                                    decoration: BoxDecoration(
                                      color: valueOrDefault<Color>(
                                        _model.rate == 4
                                            ? FlutterFlowTheme.of(context)
                                                .primary
                                            : FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                        FlutterFlowTheme.of(context).primary,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            'nq0k4jpp' /* 4 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 4
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
                                                          .primaryText,
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                                ),
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Icon(
                                          FFIcons.kstar012,
                                          color: Color(0xFFFFCC31),
                                          size: 13.0,
                                        ),
                                      ].divide(SizedBox(width: 3.0)),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _model.rate = 3;
                                    safeSetState(() {});
                                  },
                                  child: Container(
                                    width: 75.0,
                                    height: 40.0,
                                    decoration: BoxDecoration(
                                      color: valueOrDefault<Color>(
                                        _model.rate == 3
                                            ? FlutterFlowTheme.of(context)
                                                .primary
                                            : FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                        FlutterFlowTheme.of(context).primary,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            '4jivq2w2' /* 3 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 3
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
                                                          .primaryText,
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                                ),
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Icon(
                                          FFIcons.kstar012,
                                          color: Color(0xFFFFCC31),
                                          size: 13.0,
                                        ),
                                      ].divide(SizedBox(width: 3.0)),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _model.rate = 2;
                                    safeSetState(() {});
                                  },
                                  child: Container(
                                    width: 75.0,
                                    height: 40.0,
                                    decoration: BoxDecoration(
                                      color: valueOrDefault<Color>(
                                        _model.rate == 2
                                            ? FlutterFlowTheme.of(context)
                                                .primary
                                            : FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                        FlutterFlowTheme.of(context).primary,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            'ojmpi3dm' /* 2 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 2
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
                                                          .primaryText,
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                                ),
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Icon(
                                          FFIcons.kstar012,
                                          color: Color(0xFFFFCC31),
                                          size: 13.0,
                                        ),
                                      ].divide(SizedBox(width: 3.0)),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    _model.rate = 1;
                                    safeSetState(() {});
                                  },
                                  child: Container(
                                    width: 75.0,
                                    height: 40.0,
                                    decoration: BoxDecoration(
                                      color: valueOrDefault<Color>(
                                        _model.rate == 1
                                            ? FlutterFlowTheme.of(context)
                                                .primary
                                            : FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                        FlutterFlowTheme.of(context).primary,
                                      ),
                                      borderRadius:
                                          BorderRadius.circular(100.0),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            'wn2mqzpv' /* 1 */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: valueOrDefault<Color>(
                                                  _model.rate == 1
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
                                                          .primaryText,
                                                  FlutterFlowTheme.of(context)
                                                      .primaryBackground,
                                                ),
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                        Icon(
                                          FFIcons.kstar012,
                                          color: Color(0xFFFFCC31),
                                          size: 13.0,
                                        ),
                                      ].divide(SizedBox(width: 3.0)),
                                    ),
                                  ),
                                ),
                              ]
                                  .divide(SizedBox(width: 5.0))
                                  .addToStart(SizedBox(width: 16.0))
                                  .addToEnd(SizedBox(width: 16.0)),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
                        child: Builder(
                          builder: (context) {
                            final rew = myRewReviewsRecordList
                                .where((e) => _model.rate == 0
                                    ? true
                                    : (_model.rate == e.rating))
                                .toList();

                            return ListView.separated(
                              padding: EdgeInsets.zero,
                              primary: false,
                              shrinkWrap: true,
                              scrollDirection: Axis.vertical,
                              itemCount: rew.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: 6.0),
                              itemBuilder: (context, rewIndex) {
                                final rewItem = rew[rewIndex];
                                return Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      16.0, 0.0, 16.0, 0.0),
                                  child: ReviewCardWidget(
                                    key: Key(
                                        'Keyg6a_${rewIndex}_of_${rew.length}'),
                                    rewDoc: rewItem,
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ]
                        .addToStart(SizedBox(height: 115.0))
                        .addToEnd(SizedBox(height: 35.0)),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        FlutterFlowTheme.of(context).secondaryBackground,
                        Color(0xEFF2F2F7),
                        Color(0x00F2F2F7)
                      ],
                      stops: [0.0, 0.8, 1.0],
                      begin: AlignmentDirectional(0.0, -1.0),
                      end: AlignmentDirectional(0, 1.0),
                    ),
                  ),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(12.0, 55.0, 12.0, 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 45.0,
                          height: 45.0,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                blurRadius: 7.0,
                                color: Color(0x0D2C2C2C),
                                offset: Offset(
                                  0.0,
                                  2.0,
                                ),
                              )
                            ],
                            shape: BoxShape.circle,
                          ),
                          child: FlutterFlowIconButton(
                            borderRadius: 70.0,
                            buttonSize: 45.0,
                            fillColor: Colors.white,
                            icon: Icon(
                              FFIcons.kchevronLeft,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 20.0,
                            ),
                            onPressed: () async {
                              context.safePop();
                            },
                          ),
                        ),
                        Text(
                          FFLocalizations.of(context).getText(
                            'r4c8ksc9' /* Мои отзывы */,
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'Cool',
                                    fontSize: 18.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                        ),
                        Container(
                          width: 45.0,
                          height: 45.0,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
