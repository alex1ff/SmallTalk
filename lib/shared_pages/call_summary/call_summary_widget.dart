import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'dart:async';
import 'dart:ui';
import '/flutter_flow/custom_functions.dart' as functions;
import '/index.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'call_summary_model.dart';
export 'call_summary_model.dart';

class CallSummaryWidget extends StatefulWidget {
  const CallSummaryWidget({
    super.key,
    required this.userRef,
    required this.sessionID,
    String? lang,
    int? dur,
  })  : this.lang = lang ?? '-',
        this.dur = dur ?? 0;

  final DocumentReference? userRef;
  final DocumentReference? sessionID;
  final String lang;
  final int dur;

  static String routeName = 'CallSummary';
  static String routePath = '/callSummary';

  @override
  State<CallSummaryWidget> createState() => _CallSummaryWidgetState();
}

class _CallSummaryWidgetState extends State<CallSummaryWidget> {
  late CallSummaryModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CallSummaryModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.user = await UsersRecord.getDocumentOnce(widget!.userRef!);
    });

    _model.aboutMeTextController ??= TextEditingController();
    _model.aboutMeFocusNode ??= FocusNode();
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
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(10, 16, 10, 0),
                      child: Text(
                        FFLocalizations.of(context).getText(
                          'nkmvs84c' /* Как прошёл звонок? */,
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontSize: 43,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                              lineHeight: 1.1,
                            ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(10, 4, 10, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Text(
                            '${((valueOrDefault<int>(
                                  widget!.dur,
                                  0,
                                ) / 60).round()).toString()}${FFLocalizations.of(context).getVariableText(
                              ruText: ' мин',
                              enText: ' min',
                            )}',
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  fontSize: 15,
                                  letterSpacing: 0.0,
                                ),
                          ),
                          SizedBox(
                            height: 10,
                            child: VerticalDivider(
                              thickness: 1,
                              color: FlutterFlowTheme.of(context).secondaryText,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              valueOrDefault<String>(
                                widget!.lang,
                                '-',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 15,
                                    letterSpacing: 0.0,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 40, 0, 0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: AlignmentDirectional(0, 0),
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(8, 35, 8, 35),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: FlutterFlowIconButton(
                                  borderColor: Colors.transparent,
                                  borderRadius: 8,
                                  buttonSize: 55,
                                  icon: Icon(
                                    FFIcons.kstar012,
                                    color: valueOrDefault<Color>(
                                      () {
                                        if (_model.rait == 1) {
                                          return Color(0xFF850000);
                                        } else if (_model.rait == 2) {
                                          return Color(0xFFFF0000);
                                        } else if (_model.rait == 3) {
                                          return Color(0xFFFF3D00);
                                        } else if (_model.rait == 4) {
                                          return Color(0xFFFF7000);
                                        } else if (_model.rait == 5) {
                                          return Color(0xFFFFC600);
                                        } else {
                                          return FlutterFlowTheme.of(context)
                                              .secondaryBackground;
                                        }
                                      }(),
                                      FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                    ),
                                    size: 40,
                                  ),
                                  onPressed: () async {
                                    _model.rait = 1;
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                              Expanded(
                                child: FlutterFlowIconButton(
                                  borderColor: Colors.transparent,
                                  borderRadius: 8,
                                  buttonSize: 55,
                                  icon: Icon(
                                    FFIcons.kstar012,
                                    color: valueOrDefault<Color>(
                                      () {
                                        if (_model.rait == 2) {
                                          return Color(0xFFFF0000);
                                        } else if (_model.rait == 3) {
                                          return Color(0xFFFF3D00);
                                        } else if (_model.rait == 4) {
                                          return Color(0xFFFF7000);
                                        } else if (_model.rait == 5) {
                                          return Color(0xFFFFC600);
                                        } else {
                                          return FlutterFlowTheme.of(context)
                                              .secondaryBackground;
                                        }
                                      }(),
                                      FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                    ),
                                    size: 40,
                                  ),
                                  onPressed: () async {
                                    _model.rait = 2;
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                              Expanded(
                                child: FlutterFlowIconButton(
                                  borderColor: Colors.transparent,
                                  borderRadius: 8,
                                  buttonSize: 55,
                                  icon: Icon(
                                    FFIcons.kstar012,
                                    color: valueOrDefault<Color>(
                                      () {
                                        if (_model.rait == 3) {
                                          return Color(0xFFFF3D00);
                                        } else if (_model.rait == 4) {
                                          return Color(0xFFFF7000);
                                        } else if (_model.rait == 5) {
                                          return Color(0xFFFFC600);
                                        } else {
                                          return FlutterFlowTheme.of(context)
                                              .secondaryBackground;
                                        }
                                      }(),
                                      FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                    ),
                                    size: 40,
                                  ),
                                  onPressed: () async {
                                    _model.rait = 3;
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                              Expanded(
                                child: FlutterFlowIconButton(
                                  borderColor: Colors.transparent,
                                  borderRadius: 8,
                                  buttonSize: 55,
                                  icon: Icon(
                                    FFIcons.kstar012,
                                    color: valueOrDefault<Color>(
                                      () {
                                        if (_model.rait == 4) {
                                          return Color(0xFFFF7000);
                                        } else if (_model.rait == 5) {
                                          return Color(0xFFFFC600);
                                        } else {
                                          return FlutterFlowTheme.of(context)
                                              .secondaryBackground;
                                        }
                                      }(),
                                      FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                    ),
                                    size: 40,
                                  ),
                                  onPressed: () async {
                                    _model.rait = 4;
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                              Expanded(
                                child: FlutterFlowIconButton(
                                  borderColor: Colors.transparent,
                                  borderRadius: 8,
                                  buttonSize: 55,
                                  icon: Icon(
                                    FFIcons.kstar012,
                                    color: valueOrDefault<Color>(
                                      _model.rait == 5
                                          ? Color(0xFFFFC600)
                                          : FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                      FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                    ),
                                    size: 40,
                                  ),
                                  onPressed: () async {
                                    _model.rait = 5;
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                      child: Container(
                        width: double.infinity,
                        child: TextFormField(
                          controller: _model.aboutMeTextController,
                          focusNode: _model.aboutMeFocusNode,
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          obscureText: false,
                          decoration: InputDecoration(
                            isDense: false,
                            hintText: valueOrDefault<String>(
                              () {
                                if (_model.rait <= 3) {
                                  return 'Расскажтите, что пошло не так';
                                } else if (_model.rait == 4) {
                                  return 'Расскажтите, что могло бы быть лучше';
                                } else if (_model.rait == 5) {
                                  return 'Расскажтите, что понравилось';
                                } else {
                                  return 'Отзыв на собеседника';
                                }
                              }(),
                              'Отзыв на собеседника',
                            ),
                            hintStyle: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  fontSize: 16,
                                  letterSpacing: 0.0,
                                ),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0x00000000),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: Color(0x00000000),
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).error,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderSide: BorderSide(
                                color: FlutterFlowTheme.of(context).error,
                                width: 1,
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            filled: true,
                            fillColor:
                                FlutterFlowTheme.of(context).primaryBackground,
                            contentPadding: EdgeInsets.all(16),
                            hoverColor:
                                FlutterFlowTheme.of(context).primaryBackground,
                          ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'sf pro display',
                                    fontSize: 16,
                                    letterSpacing: 0.0,
                                  ),
                          maxLines: 12,
                          minLines: 2,
                          cursorColor: FlutterFlowTheme.of(context).primaryText,
                          enableInteractiveSelection: true,
                          validator: _model.aboutMeTextControllerValidator
                              .asValidator(context),
                          inputFormatters: [
                            if (!isAndroid && !isiOS)
                              TextInputFormatter.withFunction(
                                  (oldValue, newValue) {
                                return TextEditingValue(
                                  selection: newValue.selection,
                                  text: newValue.text.toCapitalization(
                                      TextCapitalization.sentences),
                                );
                              }),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 40, 0, 0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          if ((currentUserDocument?.role == UserRole.student) &&
                              !_model.black)
                            Expanded(
                              child: Padding(
                                padding:
                                    EdgeInsetsDirectional.fromSTEB(0, 0, 6, 0),
                                child: AuthUserStreamWidget(
                                  builder: (context) => InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      _model.fav = !_model.fav;
                                      safeSetState(() {});
                                    },
                                    child: Container(
                                      width: 222,
                                      height: 60,
                                      decoration: BoxDecoration(
                                        color: valueOrDefault<Color>(
                                          _model.fav
                                              ? FlutterFlowTheme.of(context)
                                                  .primary
                                              : FlutterFlowTheme.of(context)
                                                  .primaryBackground,
                                          FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                        ),
                                        borderRadius: BorderRadius.circular(55),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(2),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                color: valueOrDefault<Color>(
                                                  _model.fav
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .primaryBackground
                                                      : FlutterFlowTheme.of(
                                                              context)
                                                          .secondaryBackground,
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryBackground,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(55),
                                              ),
                                              child: Icon(
                                                FFIcons.kheart,
                                                color: valueOrDefault<Color>(
                                                  _model.fav
                                                      ? FlutterFlowTheme.of(
                                                              context)
                                                          .error
                                                      : FlutterFlowTheme.of(
                                                              context)
                                                          .secondaryText,
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                                ),
                                                size: 20,
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(12, 0, 0, 0),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    '2gz8zlq9' /* В избранное */,
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
                                                              _model.fav
                                                                  ? FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryBackground
                                                                  : FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText,
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .primaryText,
                                                            ),
                                                            fontSize: 15,
                                                            letterSpacing: 0.0,
                                                          ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
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
                            ),
                          Expanded(
                            child: InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                _model.black = !_model.black;
                                _model.fav = false;
                                safeSetState(() {});
                              },
                              child: Container(
                                width: 222,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: valueOrDefault<Color>(
                                    _model.black
                                        ? FlutterFlowTheme.of(context).error
                                        : FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                    FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                  ),
                                  borderRadius: BorderRadius.circular(55),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(2),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: valueOrDefault<Color>(
                                            _model.black
                                                ? FlutterFlowTheme.of(context)
                                                    .primaryBackground
                                                : FlutterFlowTheme.of(context)
                                                    .secondaryBackground,
                                            FlutterFlowTheme.of(context)
                                                .secondaryBackground,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(55),
                                        ),
                                        child: Icon(
                                          FFIcons.kthumbsDown,
                                          color: valueOrDefault<Color>(
                                            _model.black
                                                ? FlutterFlowTheme.of(context)
                                                    .error
                                                : FlutterFlowTheme.of(context)
                                                    .secondaryText,
                                            FlutterFlowTheme.of(context)
                                                .secondaryText,
                                          ),
                                          size: 20,
                                        ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  12, 0, 0, 0),
                                          child: Text(
                                            FFLocalizations.of(context).getText(
                                              'kth7l1fn' /* Не соединять */,
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: valueOrDefault<Color>(
                                                    _model.black
                                                        ? FlutterFlowTheme.of(
                                                                context)
                                                            .primaryBackground
                                                        : FlutterFlowTheme.of(
                                                                context)
                                                            .primaryText,
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                  ),
                                                  fontSize: 15,
                                                  letterSpacing: 0.0,
                                                ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                      .addToStart(SizedBox(height: 115))
                      .addToEnd(SizedBox(height: 120)),
                ),
              ),
            ),
            Align(
              alignment: AlignmentDirectional(0, 1),
              child: wrapWithModel(
                model: _model.buttonModel,
                updateCallback: () => safeSetState(() {}),
                child: ButtonWidget(
                  text: FFLocalizations.of(context).getText(
                    'duynuhus' /* Готово */,
                  ),
                  action: () async {
                    if (_model.rait != null) {
                      if (_model.aboutMeTextController.text != null &&
                          _model.aboutMeTextController.text != '') {
                        await ReviewsRecord.collection
                            .doc()
                            .set(createReviewsRecordData(
                              sessionId: widget!.sessionID,
                              fromUserId: currentUserReference,
                              toUserId: widget!.userRef,
                              rating: _model.rait,
                              comment: _model.aboutMeTextController.text,
                              createdAt: getCurrentTimestamp,
                            ));
                      } else {
                        await ReviewsRecord.collection
                            .doc()
                            .set(createReviewsRecordData(
                              sessionId: widget!.sessionID,
                              fromUserId: currentUserReference,
                              toUserId: widget!.userRef,
                              rating: _model.rait,
                              createdAt: getCurrentTimestamp,
                            ));
                      }

                      unawaited(
                        () async {
                          await widget!.userRef!.update(createUsersRecordData(
                            rating: createURatingStruct(
                              average: functions.recalculateRatingWithNewReview(
                                  _model.user!.rating.totalReviews,
                                  _model.user!.rating.average,
                                  _model.rait),
                              fieldValues: {
                                'totalReviews': FieldValue.increment(1),
                              },
                              clearUnsetFields: false,
                            ),
                          ));
                        }(),
                      );
                    }
                    if (_model.fav) {
                      unawaited(
                        () async {
                          await currentUserReference!.update({
                            ...mapToFirestore(
                              {
                                'favoriteNativeSpeakers':
                                    FieldValue.arrayUnion([widget!.userRef]),
                              },
                            ),
                          });
                        }(),
                      );
                    } else if (_model.black) {
                      unawaited(
                        () async {
                          await currentUserReference!.update({
                            ...mapToFirestore(
                              {
                                'blockedUsers':
                                    FieldValue.arrayUnion([widget!.userRef]),
                              },
                            ),
                          });
                        }(),
                      );
                    }

                    if (currentUserDocument?.role == UserRole.student) {
                      context.pushNamed(StudentsDashboardWidget.routeName);
                    } else {
                      context.pushNamed(DashboardNSWidget.routeName);
                    }
                  },
                ),
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
                  stops: [0, 0.8, 1],
                  begin: AlignmentDirectional(0, -1),
                  end: AlignmentDirectional(0, 1),
                ),
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6, 55, 6, 6),
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    borderRadius: BorderRadius.circular(50),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            image: DecorationImage(
                              fit: BoxFit.cover,
                              image: Image.network(
                                _model.user!.photoUrl,
                              ).image,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding:
                                EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
                            child: Text(
                              valueOrDefault<String>(
                                _model.user?.displayName,
                                '-',
                              ),
                              maxLines: 2,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    fontSize: 16,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context.pushNamed(
                              StudentsDashboardWidget.routeName,
                              queryParameters: {
                                'zn': serializeParam(
                                  false,
                                  ParamType.bool,
                                ),
                              }.withoutNulls,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    12, 0, 12, 0),
                                child: Text(
                                  FFLocalizations.of(context).getText(
                                    's918m7k5' /* Пропустить */,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ),
                              Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional(0, 0),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20,
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
          ],
        ),
      ),
    );
  }
}
