import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';

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
  static const _ctaAnimationDuration = Duration(milliseconds: 180);

  late CallSummaryModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CallSummaryModel());
    _model.userFuture = UsersRecord.getDocumentOnce(widget.userRef!);

    _model.aboutMeTextController ??= TextEditingController();
    _model.aboutMeFocusNode ??= FocusNode();
    _model.aboutMeFocusNode!.addListener(() => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  String _normalizeLanguageCode(String? code) {
    return (code ?? '').trim().toLowerCase().replaceAll('_', '-');
  }

  LanguageStruct? _findLanguageByCode(String? code) {
    final normalizedCode = _normalizeLanguageCode(code);
    if (normalizedCode.isEmpty) {
      return null;
    }

    final fallbackCodes = <String>{
      normalizedCode,
      normalizedCode.split('-').first,
    };

    for (final language in FFAppState().languagesList) {
      final normalizedCandidates = <String>{
        _normalizeLanguageCode(language.code),
        ...language.alternateCodes.map(_normalizeLanguageCode),
      }..removeWhere((value) => value.isEmpty);

      if (normalizedCandidates.any(fallbackCodes.contains)) {
        return language;
      }
    }

    return null;
  }

  String _resolvedSessionLanguageName(BuildContext context) {
    final language = _findLanguageByCode(widget.lang);
    if (language == null) {
      return valueOrDefault<String>(widget.lang, '-');
    }

    final useRussian = FFLocalizations.of(context).languageCode == 'ru';
    final localizedName = useRussian ? language.nameRu : language.nameEn;
    if (localizedName.isNotEmpty) {
      return localizedName;
    }

    return language.nameEn.isNotEmpty
        ? language.nameEn
        : valueOrDefault<String>(widget.lang, '-');
  }

  bool _referenceListContains(
    Iterable<DocumentReference>? references,
    DocumentReference? target,
  ) {
    if (target == null) {
      return false;
    }

    for (final reference in references ?? const <DocumentReference>[]) {
      if (reference.path == target.path) {
        return true;
      }
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final isComposerActive =
        (_model.aboutMeFocusNode?.hasFocus ?? false) || isKeyboardVisible;

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: FutureBuilder<UsersRecord>(
          future: _model.userFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox.shrink();
            }

            final stackUsersRecord = snapshot.data!;

            return AuthUserStreamWidget(
              builder: (context) {
                final initiallyFavorite = _referenceListContains(
                  currentUserDocument?.favoriteNativeSpeakers,
                  widget.userRef,
                );
                final initiallyBlocked = _referenceListContains(
                  currentUserDocument?.blockedUsers,
                  widget.userRef,
                );
                final effectiveBlack =
                    _model.blackTouched ? _model.black : initiallyBlocked;
                final effectiveFav = effectiveBlack
                    ? false
                    : (_model.favTouched ? _model.fav : initiallyFavorite);

                return Stack(
                  children: [
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(10, 16, 10, 0),
                              child: Text(
                                FFLocalizations.of(context).getText(
                                  'nkmvs84c' /* Как прошёл звонок? */,
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Cool',
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      fontSize: 43,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                      lineHeight: 1.1,
                                    ),
                              ),
                            ),
                            Padding(
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(10, 4, 10, 0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    () {
                                      final totalSeconds = widget.dur;
                                      final minutes = totalSeconds ~/ 60;
                                      final seconds = totalSeconds % 60;
                                      return '$minutes:${seconds.toString().padLeft(2, '0')} мин';
                                    }(),
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
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      _resolvedSessionLanguageName(context),
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
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(0, 40, 0, 0),
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  borderRadius: BorderRadius.circular(26),
                                ),
                                alignment: AlignmentDirectional(0, 0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      8, 35, 8, 35),
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
                                                  return FlutterFlowTheme.of(
                                                          context)
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
                                                  return FlutterFlowTheme.of(
                                                          context)
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
                                                  return FlutterFlowTheme.of(
                                                          context)
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
                                                  return FlutterFlowTheme.of(
                                                          context)
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
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
                              child: Container(
                                width: double.infinity,
                                child: TextFormField(
                                  controller: _model.aboutMeTextController,
                                  focusNode: _model.aboutMeFocusNode,
                                  onChanged: (_) => EasyDebounce.debounce(
                                    '_model.aboutMeTextController',
                                    Duration(milliseconds: 0),
                                    () => safeSetState(() {}),
                                  ),
                                  autofocus: false,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textInputAction: TextInputAction.done,
                                  obscureText: false,
                                  decoration: InputDecoration(
                                    isDense: false,
                                    hintText: valueOrDefault<String>(
                                      reviewCommentHintText(
                                        context,
                                        _model.rait,
                                      ),
                                      reviewCommentHintText(context, 0),
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
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color: Color(0x00000000),
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    errorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    focusedErrorBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        width: 1,
                                      ),
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    contentPadding: EdgeInsets.all(16),
                                    hoverColor: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        fontSize: 16,
                                        letterSpacing: 0.0,
                                      ),
                                  maxLines: 12,
                                  minLines: 2,
                                  cursorColor:
                                      FlutterFlowTheme.of(context).primaryText,
                                  enableInteractiveSelection: true,
                                  validator: _model
                                      .aboutMeTextControllerValidator
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
                              padding:
                                  EdgeInsetsDirectional.fromSTEB(0, 40, 0, 0),
                              child: Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  if ((currentUserDocument?.role ==
                                          UserRole.student) &&
                                      !effectiveBlack)
                                    Expanded(
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            0, 0, 6, 0),
                                        child: InkWell(
                                          splashColor: Colors.transparent,
                                          focusColor: Colors.transparent,
                                          hoverColor: Colors.transparent,
                                          highlightColor: Colors.transparent,
                                          onTap: () async {
                                            _model.favTouched = true;
                                            _model.fav = !effectiveFav;
                                            safeSetState(() {});
                                          },
                                          child: Container(
                                            width: 222,
                                            height: 60,
                                            decoration: BoxDecoration(
                                              color: valueOrDefault<Color>(
                                                effectiveFav
                                                    ? FlutterFlowTheme.of(
                                                            context)
                                                        .primary
                                                    : FlutterFlowTheme.of(
                                                            context)
                                                        .primaryBackground,
                                                FlutterFlowTheme.of(context)
                                                    .primaryBackground,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(55),
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
                                                      color:
                                                          valueOrDefault<Color>(
                                                        effectiveFav
                                                            ? FlutterFlowTheme
                                                                    .of(context)
                                                                .primaryBackground
                                                            : FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryBackground,
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .secondaryBackground,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              55),
                                                    ),
                                                    child: Icon(
                                                      FFIcons.kheart,
                                                      color:
                                                          valueOrDefault<Color>(
                                                        effectiveFav
                                                            ? FlutterFlowTheme
                                                                    .of(context)
                                                                .error
                                                            : FlutterFlowTheme
                                                                    .of(context)
                                                                .secondaryText,
                                                        FlutterFlowTheme.of(
                                                                context)
                                                            .secondaryText,
                                                      ),
                                                      size: 20,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    child: Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  12, 0, 0, 0),
                                                      child: Text(
                                                        FFLocalizations.of(
                                                                context)
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
                                                                    effectiveFav
                                                                        ? FlutterFlowTheme.of(context)
                                                                            .primaryBackground
                                                                        : FlutterFlowTheme.of(context)
                                                                            .primaryText,
                                                                    FlutterFlowTheme.of(
                                                                            context)
                                                                        .primaryText,
                                                                  ),
                                                                  fontSize: 15,
                                                                  letterSpacing:
                                                                      0.0,
                                                                ),
                                                        overflow: TextOverflow
                                                            .ellipsis,
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
                                  Expanded(
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.blackTouched = true;
                                        _model.black = !effectiveBlack;
                                        if (_model.black) {
                                          _model.favTouched = true;
                                          _model.fav = false;
                                        }
                                        safeSetState(() {});
                                      },
                                      child: Container(
                                        width: 222,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: valueOrDefault<Color>(
                                            effectiveBlack
                                                ? FlutterFlowTheme.of(context)
                                                    .error
                                                : FlutterFlowTheme.of(context)
                                                    .primaryBackground,
                                            FlutterFlowTheme.of(context)
                                                .primaryBackground,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(55),
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
                                                    effectiveBlack
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
                                                  FFIcons.kthumbsDown,
                                                  color: valueOrDefault<Color>(
                                                    effectiveBlack
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
                                                      'kth7l1fn' /* Не соединять */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: valueOrDefault<
                                                              Color>(
                                                            effectiveBlack
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
                                ],
                              ),
                            ),
                          ].addToStart(SizedBox(height: 115)).addToEnd(
                                const SizedBox(height: 120),
                              ),
                        ),
                      ),
                    ),
                    SizedBox(
                      height: 120.0,
                      child: Align(
                        alignment: AlignmentDirectional(0, 1),
                        child: AnimatedPadding(
                          duration: _ctaAnimationDuration,
                          curve: Curves.easeOutCubic,
                          padding: EdgeInsetsDirectional.fromSTEB(
                            0.0,
                            0.0,
                            0.0,
                            isComposerActive ? 24.0 : 0.0,
                          ),
                          child: IgnorePointer(
                            ignoring: isComposerActive,
                            child: AnimatedOpacity(
                              duration: _ctaAnimationDuration,
                              curve: Curves.easeOutCubic,
                              opacity: isComposerActive ? 0.0 : 1.0,
                              child: AnimatedSlide(
                                duration: _ctaAnimationDuration,
                                curve: Curves.easeOutCubic,
                                offset: isComposerActive
                                    ? const Offset(0.0, 0.24)
                                    : Offset.zero,
                                child: wrapWithModel(
                                  model: _model.buttonModel,
                                  updateCallback: () => safeSetState(() {}),
                                  child: ButtonWidget(
                                    text: FFLocalizations.of(context).getText(
                                      'duynuhus' /* Готово */,
                                    ),
                                    loadingText: FFLocalizations.of(context)
                                        .getVariableText(
                                      ruText: 'Сохраняем...',
                                      enText: 'Saving...',
                                    ),
                                    busyStyle: ButtonBusyStyle.spinner,
                                    keyboardAwarePadding: false,
                                    padding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                            6.0, 0.0, 6.0, 35.0),
                                    action: () async {
                                      if (_model.rait != 0) {
                                        final sessionRef = widget.sessionID;
                                        final toUserRef = widget.userRef;
                                        if (sessionRef == null ||
                                            toUserRef == null) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                FFLocalizations.of(context)
                                                    .getVariableText(
                                                  ruText:
                                                      'Не удалось отправить отзыв: отсутствуют данные сессии.',
                                                  enText:
                                                      'Unable to submit review: missing session data.',
                                                ),
                                              ),
                                            ),
                                          );
                                          return;
                                        }

                                        try {
                                          await submitSessionReview(
                                            sessionRef: sessionRef,
                                            toUserRef: toUserRef,
                                            rating: _model.rait,
                                            isTeacher:
                                                currentUserDocument?.role ==
                                                    UserRole.native_speaker,
                                            comment: _model
                                                .aboutMeTextController.text,
                                          );
                                        } on FirebaseFunctionsException catch (e) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                reviewErrorMessage(context, e),
                                              ),
                                            ),
                                          );
                                          return;
                                        } catch (_) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                unexpectedReviewErrorMessage(
                                                    context),
                                              ),
                                            ),
                                          );
                                          return;
                                        }
                                      }
                                      if (effectiveFav) {
                                        await currentUserReference!.update({
                                          ...mapToFirestore(
                                            {
                                              'favoriteNativeSpeakers':
                                                  FieldValue.arrayUnion(
                                                      [widget.userRef]),
                                            },
                                          ),
                                        });
                                      } else if (effectiveBlack) {
                                        await currentUserReference!.update({
                                          ...mapToFirestore(
                                            {
                                              'favoriteNativeSpeakers':
                                                  FieldValue.arrayRemove(
                                                      [widget.userRef]),
                                              'blockedUsers':
                                                  FieldValue.arrayUnion(
                                                      [widget.userRef]),
                                            },
                                          ),
                                        });
                                      }

                                      if (currentUserDocument?.role ==
                                          UserRole.student) {
                                        context.goNamed(
                                            StudentsDashboardWidget.routeName);
                                      } else {
                                        context.goNamed(
                                            DashboardNSWidget.routeName);
                                      }
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
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
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: FlutterFlowTheme.of(context)
                                  .secondaryBackground,
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
                                      image: CachedNetworkImageProvider(
                                        stackUsersRecord.photoUrl,
                                        maxWidth: 200,
                                        maxHeight: 200,
                                      ),
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        12, 0, 0, 0),
                                    child: Text(
                                      stackUsersRecord.displayName,
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
                                    context.goNamed(
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
                                                color:
                                                    FlutterFlowTheme.of(context)
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
                );
              },
            );
          },
        ),
      ),
    );
  }
}
