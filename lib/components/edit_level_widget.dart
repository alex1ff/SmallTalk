import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'edit_level_model.dart';
export 'edit_level_model.dart';

class EditLevelWidget extends StatefulWidget {
  const EditLevelWidget({
    super.key,
    required this.action,
  });

  final Future Function(Level lang)? action;

  @override
  State<EditLevelWidget> createState() => _EditLevelWidgetState();
}

class _EditLevelWidgetState extends State<EditLevelWidget> {
  late EditLevelModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditLevelModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.level = currentUserDocument?.level;
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _saveLevel() async {
    if (currentUserDocument?.level != _model.level) {
      await currentUserReference!.update(createUsersRecordData(
        level: _model.level,
      ));
      await widget.action?.call(
        _model.level!,
      );
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: ExpatlioDesign.sheetDecoration(),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BottomSheetHeader(
                        title: FFLocalizations.of(context).getText(
                          'si04kwhp' /* Ваш текущий уровень */,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            ExpatlioDesign.pagePadding,
                            ExpatlioDesign.space32,
                            ExpatlioDesign.pagePadding,
                            ExpatlioDesign.space0),
                        child: Stack(
                          alignment: AlignmentDirectional(0.0, 1.0),
                          children: [
                            Container(
                              width: double.infinity,
                              height: 350.0,
                              child: custom_widgets.SemiCircleSlider(
                                width: double.infinity,
                                height: 350.0,
                                initialLevel: _model.level,
                                onChanged: (level) async {
                                  _model.level = level;
                                  safeSetState(() {});
                                },
                              ),
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space12),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space32),
                                    child: Builder(
                                      builder: (context) {
                                        if (_model.level == Level.Beginner) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 0.0, 0.0, 12.0),
                                                child: Image.asset(
                                                  'assets/images/34kgr_.png',
                                                  width: 100.0,
                                                  height: 70.0,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'jdmn59oq' /* Начальный */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          fontSize: 22.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'dtdv1d38' /* Знаю базовые фразы и слова
A1-... */
                                                  ,
                                                ),
                                                textAlign: TextAlign.center,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 13.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                            ],
                                          );
                                        } else if (_model.level ==
                                            Level.Basic) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 0.0, 0.0, 12.0),
                                                child: Image.asset(
                                                  'assets/images/iom0u_.png',
                                                  width: 100.0,
                                                  height: 70.0,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  '9h701ha8' /* Базовый */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          fontSize: 22.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'nhcwv72l' /* Могу поддержать простой разгов... */,
                                                ),
                                                textAlign: TextAlign.center,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 13.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                            ],
                                          );
                                        } else if (_model.level ==
                                            Level.Intermediate) {
                                          return Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 0.0, 0.0, 12.0),
                                                child: Image.asset(
                                                  'assets/images/g08g4_.png',
                                                  width: 100.0,
                                                  height: 70.0,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'dapjexca' /* Уверенный */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          fontSize: 22.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  '9jdrum1l' /* Говорю свободно на большинство... */,
                                                ),
                                                textAlign: TextAlign.center,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 13.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                            ],
                                          );
                                        } else {
                                          return Column(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 0.0, 0.0, 12.0),
                                                child: Image.asset(
                                                  'assets/images/e1xjd_.png',
                                                  width: 100.0,
                                                  height: 70.0,
                                                  fit: BoxFit.contain,
                                                ),
                                              ),
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'sr30phpi' /* Свободно */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          fontSize: 22.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'bh0f4y7s' /* Владею как родным
Native */
                                                  ,
                                                ),
                                                textAlign: TextAlign.center,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 13.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                            ],
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  Stack(
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        height: 22.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                          borderRadius: BorderRadius.circular(
                                              ExpatlioDesign.radiusSmall),
                                        ),
                                      ),
                                      Padding(
                                        padding: EdgeInsets.all(
                                            ExpatlioDesign.space4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: InkWell(
                                                splashColor: Colors.transparent,
                                                focusColor: Colors.transparent,
                                                hoverColor: Colors.transparent,
                                                highlightColor:
                                                    Colors.transparent,
                                                onTap: () async {
                                                  _model.level = Level.Beginner;
                                                  safeSetState(() {});
                                                },
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: valueOrDefault<
                                                          double>(
                                                        _model.level ==
                                                                Level.Beginner
                                                            ? 32.0
                                                            : 18.0,
                                                        32.0,
                                                      ),
                                                      height: valueOrDefault<
                                                          double>(
                                                        _model.level ==
                                                                Level.Beginner
                                                            ? 32.0
                                                            : 18.0,
                                                        32.0,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: valueOrDefault<
                                                            Color>(
                                                          _model.level ==
                                                                  Level.Beginner
                                                              ? FlutterFlowTheme
                                                                      .of(
                                                                          context)
                                                                  .primaryBackground
                                                              : FlutterFlowTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryBackground,
                                                        ),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.level ==
                                                                    Level
                                                                        .Beginner
                                                                ? ExpatlioDesign
                                                                    .primary
                                                                : Colors
                                                                    .transparent,
                                                            ExpatlioDesign
                                                                .primary,
                                                          ),
                                                          width: 6.0,
                                                        ),
                                                      ),
                                                      child: Visibility(
                                                        visible: _model.level !=
                                                            Level.Beginner,
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  0.0, 0.0),
                                                          child: Container(
                                                            width: 2.0,
                                                            height: 2.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primaryText,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 0.0, 6.0, 0.0),
                                                child: InkWell(
                                                  splashColor:
                                                      Colors.transparent,
                                                  focusColor:
                                                      Colors.transparent,
                                                  hoverColor:
                                                      Colors.transparent,
                                                  highlightColor:
                                                      Colors.transparent,
                                                  onTap: () async {
                                                    _model.level = Level.Basic;
                                                    safeSetState(() {});
                                                  },
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Container(
                                                        width: valueOrDefault<
                                                            double>(
                                                          _model.level ==
                                                                  Level.Basic
                                                              ? 32.0
                                                              : 18.0,
                                                          32.0,
                                                        ),
                                                        height: valueOrDefault<
                                                            double>(
                                                          _model.level ==
                                                                  Level.Basic
                                                              ? 32.0
                                                              : 18.0,
                                                          32.0,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.level ==
                                                                    Level.Basic
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground
                                                                : FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryBackground,
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryBackground,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color:
                                                                valueOrDefault<
                                                                    Color>(
                                                              _model.level ==
                                                                      Level
                                                                          .Basic
                                                                  ? ExpatlioDesign
                                                                      .primary
                                                                  : Colors
                                                                      .transparent,
                                                              ExpatlioDesign
                                                                  .primary,
                                                            ),
                                                            width: 6.0,
                                                          ),
                                                        ),
                                                        child: Visibility(
                                                          visible:
                                                              _model.level !=
                                                                  Level.Basic,
                                                          child: Align(
                                                            alignment:
                                                                AlignmentDirectional(
                                                                    0.0, 0.0),
                                                            child: Container(
                                                              width: 2.0,
                                                              height: 2.0,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        6.0, 0.0, 0.0, 0.0),
                                                child: InkWell(
                                                  splashColor:
                                                      Colors.transparent,
                                                  focusColor:
                                                      Colors.transparent,
                                                  hoverColor:
                                                      Colors.transparent,
                                                  highlightColor:
                                                      Colors.transparent,
                                                  onTap: () async {
                                                    _model.level =
                                                        Level.Intermediate;
                                                    safeSetState(() {});
                                                  },
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .center,
                                                    children: [
                                                      Container(
                                                        width: valueOrDefault<
                                                            double>(
                                                          _model.level ==
                                                                  Level
                                                                      .Intermediate
                                                              ? 32.0
                                                              : 18.0,
                                                          32.0,
                                                        ),
                                                        height: valueOrDefault<
                                                            double>(
                                                          _model.level ==
                                                                  Level
                                                                      .Intermediate
                                                              ? 32.0
                                                              : 18.0,
                                                          32.0,
                                                        ),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.level ==
                                                                    Level
                                                                        .Intermediate
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground
                                                                : FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryBackground,
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryBackground,
                                                          ),
                                                          shape:
                                                              BoxShape.circle,
                                                          border: Border.all(
                                                            color:
                                                                valueOrDefault<
                                                                    Color>(
                                                              _model.level ==
                                                                      Level
                                                                          .Intermediate
                                                                  ? ExpatlioDesign
                                                                      .primary
                                                                  : Colors
                                                                      .transparent,
                                                              ExpatlioDesign
                                                                  .primary,
                                                            ),
                                                            width: 6.0,
                                                          ),
                                                        ),
                                                        child: Visibility(
                                                          visible: _model
                                                                  .level !=
                                                              Level
                                                                  .Intermediate,
                                                          child: Align(
                                                            alignment:
                                                                AlignmentDirectional(
                                                                    0.0, 0.0),
                                                            child: Container(
                                                              width: 2.0,
                                                              height: 2.0,
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText,
                                                                shape: BoxShape
                                                                    .circle,
                                                              ),
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: InkWell(
                                                splashColor: Colors.transparent,
                                                focusColor: Colors.transparent,
                                                hoverColor: Colors.transparent,
                                                highlightColor:
                                                    Colors.transparent,
                                                onTap: () async {
                                                  _model.level = Level.Fluent;
                                                  safeSetState(() {});
                                                },
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.max,
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    Container(
                                                      width: valueOrDefault<
                                                          double>(
                                                        _model.level ==
                                                                Level.Fluent
                                                            ? 32.0
                                                            : 18.0,
                                                        32.0,
                                                      ),
                                                      height: valueOrDefault<
                                                          double>(
                                                        _model.level ==
                                                                Level.Fluent
                                                            ? 32.0
                                                            : 18.0,
                                                        32.0,
                                                      ),
                                                      decoration: BoxDecoration(
                                                        color: valueOrDefault<
                                                            Color>(
                                                          _model.level ==
                                                                  Level.Fluent
                                                              ? FlutterFlowTheme
                                                                      .of(
                                                                          context)
                                                                  .primaryBackground
                                                              : FlutterFlowTheme
                                                                      .of(context)
                                                                  .secondaryBackground,
                                                          FlutterFlowTheme.of(
                                                                  context)
                                                              .primaryBackground,
                                                        ),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.level ==
                                                                    Level.Fluent
                                                                ? ExpatlioDesign
                                                                    .primary
                                                                : Colors
                                                                    .transparent,
                                                            ExpatlioDesign
                                                                .primary,
                                                          ),
                                                          width: 6.0,
                                                        ),
                                                      ),
                                                      child: Visibility(
                                                        visible: _model.level !=
                                                            Level.Fluent,
                                                        child: Align(
                                                          alignment:
                                                              AlignmentDirectional(
                                                                  0.0, 0.0),
                                                          child: Container(
                                                            width: 2.0,
                                                            height: 2.0,
                                                            decoration:
                                                                BoxDecoration(
                                                              color: FlutterFlowTheme
                                                                      .of(context)
                                                                  .primaryText,
                                                              shape: BoxShape
                                                                  .circle,
                                                            ),
                                                          ),
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
                                    ],
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space4,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'qxr4lsyg' /* Начальный */,
                                                ),
                                                textAlign: TextAlign.start,
                                                style: FlutterFlowTheme.of(
                                                        context)
                                                    .bodyMedium
                                                    .override(
                                                      fontFamily:
                                                          'sf pro display',
                                                      color:
                                                          valueOrDefault<Color>(
                                                        _model.level ==
                                                                Level.Beginner
                                                            ? FlutterFlowTheme
                                                                    .of(context)
                                                                .primaryText
                                                            : FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .primaryText,
                                                      ),
                                                      fontSize: 13.0,
                                                      letterSpacing: 0.0,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    ExpatlioDesign.space0,
                                                    ExpatlioDesign.space0,
                                                    ExpatlioDesign.space8,
                                                    ExpatlioDesign.space0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'gkwtxis0' /* Базовый */,
                                                  ),
                                                  textAlign: TextAlign.center,
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
                                                              _model.level ==
                                                                      Level
                                                                          .Basic
                                                                  ? FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText
                                                                  : FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .secondaryText,
                                                            ),
                                                            fontSize: 13.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    ExpatlioDesign.space8,
                                                    ExpatlioDesign.space0,
                                                    ExpatlioDesign.space0,
                                                    ExpatlioDesign.space0),
                                            child: Column(
                                              mainAxisSize: MainAxisSize.max,
                                              children: [
                                                Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'xiioo516' /* Уверенный */,
                                                  ),
                                                  textAlign: TextAlign.center,
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
                                                              _model.level ==
                                                                      Level
                                                                          .Intermediate
                                                                  ? FlutterFlowTheme.of(
                                                                          context)
                                                                      .primaryText
                                                                  : FlutterFlowTheme.of(
                                                                          context)
                                                                      .secondaryText,
                                                              FlutterFlowTheme.of(
                                                                      context)
                                                                  .secondaryText,
                                                            ),
                                                            fontSize: 13.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  'av3obfx6' /* Свободно */,
                                                ),
                                                textAlign: TextAlign.end,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: valueOrDefault<
                                                              Color>(
                                                            _model.level ==
                                                                    Level.Fluent
                                                                ? FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryText
                                                                : FlutterFlowTheme.of(
                                                                        context)
                                                                    .secondaryText,
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                          ),
                                                          fontSize: 13.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      BottomSheetPrimaryButton(
                        text: FFLocalizations.of(context).getVariableText(
                          ruText: 'Сохранить',
                          enText: 'Save',
                        ),
                        onPressed: _saveLevel,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
