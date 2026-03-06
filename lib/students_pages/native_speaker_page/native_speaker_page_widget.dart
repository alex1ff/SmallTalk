import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/language_card/language_card_widget.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/components/review_card/review_card_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import '/flutter_flow/permissions_util.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/shared_pages/profile_components/no_balance/no_balance_widget.dart';
import '/index.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:webviewx_plus/webviewx_plus.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'native_speaker_page_model.dart';
export 'native_speaker_page_model.dart';

class NativeSpeakerPageWidget extends StatefulWidget {
  const NativeSpeakerPageWidget({
    super.key,
    required this.nsUserDocRef,
  });

  final DocumentReference? nsUserDocRef;

  static String routeName = 'NativeSpeakerPage';
  static String routePath = '/nativeSpeakerPage';

  @override
  State<NativeSpeakerPageWidget> createState() =>
      _NativeSpeakerPageWidgetState();
}

class _NativeSpeakerPageWidgetState extends State<NativeSpeakerPageWidget> {
  late NativeSpeakerPageModel _model;
  late Future<List<StatsRecord>> _statsFuture;
  late Future<List<ReviewsRecord>> _reviewsFuture;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  bool _hapticFired = false;
  bool _isSnapping = false;

  String _localizedText({
    required String ruText,
    required String enText,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ruText,
      enText: enText,
    );
  }

  int? _normalizeOffsetMinutes(dynamic rawValue) {
    if (rawValue is int) {
      return rawValue;
    }
    if (rawValue is double) {
      return rawValue.toInt();
    }
    if (rawValue is String) {
      return int.tryParse(rawValue.trim());
    }
    return null;
  }

  int? _parseTimeBoundary(String? rawValue) {
    if (rawValue == null) {
      return null;
    }

    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(rawValue.trim());
    if (match == null) {
      return null;
    }

    final hours = int.tryParse(match.group(1)!);
    final minutes = int.tryParse(match.group(2)!);
    if (hours == null ||
        minutes == null ||
        hours < 0 ||
        hours > 23 ||
        minutes < 0 ||
        minutes > 59) {
      return null;
    }

    return hours * 60 + minutes;
  }

  bool _intervalContains({
    required int localMinutes,
    required int startMinutes,
    required int endMinutes,
  }) {
    if (startMinutes == endMinutes) {
      return false;
    }

    if (startMinutes < endMinutes) {
      return localMinutes >= startMinutes && localMinutes < endMinutes;
    }

    return localMinutes >= startMinutes || localMinutes < endMinutes;
  }

  bool _isTutorAvailableNow(UsersRecord tutorRecord) {
    final availabilityToday = tutorRecord.availabilityToday;
    final enabled = availabilityToday.enabled;
    if (!enabled) {
      return false;
    }

    final intervals = availabilityToday.intervals;
    if (intervals.isEmpty) {
      return true;
    }

    final timezoneOffsetMinutes =
        _normalizeOffsetMinutes(tutorRecord.snapshotData['timezoneOffsetMinutes']);
    if (timezoneOffsetMinutes == null) {
      return true;
    }

    final localNow =
        DateTime.now().toUtc().add(Duration(minutes: timezoneOffsetMinutes));
    final localMinutes = localNow.hour * 60 + localNow.minute;

    for (final interval in intervals) {
      final startMinutes = _parseTimeBoundary(interval.start);
      final endMinutes = _parseTimeBoundary(interval.end);
      if (startMinutes == null || endMinutes == null) {
        continue;
      }

      if (_intervalContains(
        localMinutes: localMinutes,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
      )) {
        return true;
      }
    }

    return false;
  }

  String _buildTutorStatusLabel(UsersRecord tutorRecord) {
    if (tutorRecord.isInCall) {
      return _localizedText(
        ruText: 'Занят',
        enText: 'Busy',
      );
    }

    if (_isTutorAvailableNow(tutorRecord)) {
      return _localizedText(
        ruText: 'В сети',
        enText: 'Online',
      );
    }

    return _localizedText(
      ruText: 'Не в сети',
      enText: 'Offline',
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NativeSpeakerPageModel());
    _scrollController.addListener(_onScroll);
    _statsFuture = queryStatsRecordOnce(
      parent: widget.nsUserDocRef,
      queryBuilder: (statsRecord) => statsRecord.where(
        'isAllTime',
        isEqualTo: true,
      ),
      singleRecord: true,
    );
    _reviewsFuture = queryReviewsRecordOnce(
      queryBuilder: (reviewsRecord) => reviewsRecord
          .where(
            'toUserId',
            isEqualTo: widget.nsUserDocRef,
          )
          .orderBy('createdAt', descending: true),
    );
  }

  double get _snapOffset {
    final statusBarH = MediaQuery.of(context).padding.top;
    final maxExt = MediaQuery.sizeOf(context).height * 0.5;
    final snapHeaderHeight = statusBarH + 8 + 110 + 8 + 42 + 16;
    final minExt = statusBarH + kToolbarHeight;
    return (maxExt - snapHeaderHeight).clamp(0.0, maxExt - minExt);
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final snap = _snapOffset;

    if (offset > 1.0 && !_hapticFired && !_isSnapping) {
      _hapticFired = true;
      _isSnapping = true;
      HapticFeedback.mediumImpact();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController
            .animateTo(
              snap,
              duration: Duration(milliseconds: 160),
              curve: Curves.easeOut,
            )
            .then((_) => _isSnapping = false);
      });
    } else if (_hapticFired && !_isSnapping && offset < snap - 3) {
      _hapticFired = false;
      _isSnapping = true;
      HapticFeedback.mediumImpact();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController
            .animateTo(
              0.0,
              duration: Duration(milliseconds: 160),
              curve: Curves.easeOut,
            )
            .then((_) => _isSnapping = false);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<UsersRecord>(
      stream: UsersRecord.getDocument(widget.nsUserDocRef!),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
            body: Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: SpinKitCircle(
                  color: FlutterFlowTheme.of(context).secondary,
                  size: 50.0,
                ),
              ),
            ),
          );
        }

        final nativeSpeakerPageUsersRecord = snapshot.data!;
        final hasInstructionLanguage = _hasLanguageData(
          nativeSpeakerPageUsersRecord.languageInstructionNS,
        );
        final hasNativeLanguage = _hasLanguageData(
          nativeSpeakerPageUsersRecord.nativeLanguageNS,
        );
        final isAvailableForCalls =
            _isTutorAvailableNow(nativeSpeakerPageUsersRecord);
        final isBlockedByStudent =
            (currentUserDocument?.blockedUsers.toList() ?? [])
                .contains(widget.nsUserDocRef);
        final canStartDirectCall = !nativeSpeakerPageUsersRecord.isInCall &&
            isAvailableForCalls &&
            !isBlockedByStudent;

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
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _ProfileHeaderDelegate(
                        maxHeaderExtent:
                            MediaQuery.sizeOf(context).height * 0.5,
                        minHeaderExtent:
                            MediaQuery.of(context).padding.top + kToolbarHeight,
                        photoUrl: nativeSpeakerPageUsersRecord.photoUrl,
                        displayName: nativeSpeakerPageUsersRecord.displayName,
                        cityAndStatus:
                            '${nativeSpeakerPageUsersRecord.countryNS.nameEn} | ${_buildTutorStatusLabel(nativeSpeakerPageUsersRecord)}',
                        ratingAverage:
                            nativeSpeakerPageUsersRecord.rating.average,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 24.0, 0.0, 0.0),
                            child: Text(
                              FFLocalizations.of(context).getText(
                                'd7d95pj7' /* О себе */,
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 24.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 10.0, 16.0, 0.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Flexible(
                                  child: FutureBuilder<List<StatsRecord>>(
                                    future: _statsFuture,
                                    builder: (context, snapshot) {
                                      if (!snapshot.hasData) {
                                        return Center(
                                          child: SizedBox(
                                            width: 50.0,
                                            height: 50.0,
                                            child: SpinKitCircle(
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondary,
                                              size: 50.0,
                                            ),
                                          ),
                                        );
                                      }
                                      List<StatsRecord>
                                          containerStatsRecordList =
                                          snapshot.data!;
                                      if (snapshot.data!.isEmpty) {
                                        return Container();
                                      }
                                      final containerStatsRecord =
                                          containerStatsRecordList.isNotEmpty
                                              ? containerStatsRecordList.first
                                              : null;
                                      return Container(
                                        decoration: BoxDecoration(),
                                        child: Text(
                                          functions.getcallNumbString(
                                              containerStatsRecord!.totalCalls
                                                  .toString()),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                SizedBox(
                                  height: 10.0,
                                  child: VerticalDivider(
                                    thickness: 2.0,
                                    color:
                                        FlutterFlowTheme.of(context).alternate,
                                  ),
                                ),
                                Flexible(
                                  child: Text(
                                    functions.getReviewString(
                                        nativeSpeakerPageUsersRecord
                                            .rating.totalReviews
                                            .toString()),
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          fontSize: 15.0,
                                          letterSpacing: 0.0,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 10.0, 16.0, 0.0),
                            child: Text(
                              nativeSpeakerPageUsersRecord.aboutMe,
                              maxLines: _model.numMaxLineAbout,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    fontSize: 15.0,
                                    letterSpacing: 0.0,
                                  ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (functions.aboutt(
                                  nativeSpeakerPageUsersRecord.aboutMe,
                                  MediaQuery.sizeOf(context).width) ==
                              true)
                            FFButtonWidget(
                              onPressed: () async {
                                if (_model.numMaxLineAbout == 4) {
                                  _model.numMaxLineAbout = 15;
                                  safeSetState(() {});
                                } else {
                                  _model.numMaxLineAbout = 4;
                                  safeSetState(() {});
                                }
                              },
                              text: _model.numMaxLineAbout == 4
                                  ? FFLocalizations.of(context).getVariableText(
                                      ruText: 'Показать еще',
                                      enText: 'Show more',
                                    )
                                  : FFLocalizations.of(context).getVariableText(
                                      ruText: 'Скрыть',
                                      enText: 'Hide',
                                    ),
                              options: FFButtonOptions(
                                height: 35.0,
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 0.0, 16.0, 0.0),
                                iconPadding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 0.0, 0.0, 0.0),
                                color: Colors.transparent,
                                textStyle: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color:
                                          FlutterFlowTheme.of(context).primary,
                                      fontSize: 15.0,
                                      letterSpacing: 0.0,
                                    ),
                                elevation: 0.0,
                                borderRadius: BorderRadius.circular(8.0),
                              ),
                            ),
                          if (hasInstructionLanguage)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 24.0, 0.0, 0.0),
                              child: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Я преподаю',
                                  enText: 'I teach',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Cool',
                                      fontSize: 24.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                    ),
                              ),
                            ),
                          if (hasInstructionLanguage)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  6.0, 10.0, 6.0, 0.0),
                              child: wrapWithModel(
                                model: _model.languageCardModel1,
                                updateCallback: () => safeSetState(() {}),
                                child: LanguageCardWidget(
                                  lang: nativeSpeakerPageUsersRecord
                                      .languageInstructionNS,
                                  callbackAction: (selectedLangData) async {},
                                ),
                              ),
                            ),
                          if (hasNativeLanguage)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  16.0, 24.0, 0.0, 0.0),
                              child: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText: 'Мой родной язык',
                                  enText: 'My native language',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Cool',
                                      fontSize: 24.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                    ),
                              ),
                            ),
                          if (hasNativeLanguage)
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  6.0, 10.0, 6.0, 0.0),
                              child: wrapWithModel(
                                model: _model.languageCardModel2,
                                updateCallback: () => safeSetState(() {}),
                                child: LanguageCardWidget(
                                  lang: nativeSpeakerPageUsersRecord
                                      .nativeLanguageNS,
                                  callbackAction: (selectedLangData) async {},
                                ),
                              ),
                            ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                16.0, 24.0, 0.0, 0.0),
                            child: Text(
                              FFLocalizations.of(context).getVariableText(
                                ruText: 'Отзывы',
                                enText: 'Reviews',
                              ),
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'Cool',
                                    fontSize: 24.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.normal,
                                  ),
                            ),
                          ),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                0.0, 10.0, 0.0, 0.0),
                            child: _buildReviewsSection(
                                nativeSpeakerPageUsersRecord),
                          ),
                          SizedBox(height: 140.0),
                        ],
                      ),
                    ),
                  ],
                ),
                if (canStartDirectCall)
                  Align(
                    alignment: AlignmentDirectional(0.0, 1.0),
                    child: _buildBottomCallToAction(),
                  ),
                AnimatedBuilder(
                  animation: _scrollController,
                  builder: (context, _) {
                    return _buildTopActionButtons();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  bool _hasLanguageData(LanguageStruct language) {
    return language.code.isNotEmpty ||
        language.nameEn.isNotEmpty ||
        language.nameRu.isNotEmpty;
  }

  Widget _buildTopCircleIconButton({
    required Widget icon,
    required Future<void> Function() onPressed,
  }) {
    return SizedBox(
      width: 45.0,
      height: 45.0,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              blurRadius: 7.0,
              color: Color(0x0D2C2C2C),
              offset: Offset(0.0, 2.0),
            ),
          ],
          shape: BoxShape.circle,
        ),
        child: FlutterFlowIconButton(
          borderRadius: 70.0,
          buttonSize: 45.0,
          fillColor: Colors.white,
          icon: icon,
          onPressed: onPressed,
        ),
      ),
    );
  }

  Widget _buildTopActionButtons() {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(8.0, 55.0, 8.0, 0.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildTopCircleIconButton(
            onPressed: () async {
              context.safePop();
            },
            icon: Icon(
              FFIcons.kchevronLeft,
              color: FlutterFlowTheme.of(context).primaryText,
              size: 20.0,
            ),
          ),
          AuthUserStreamWidget(
            builder: (context) {
              if ((currentUserDocument?.favoriteNativeSpeakers.toList() ?? [])
                  .contains(widget.nsUserDocRef)) {
                return _buildTopCircleIconButton(
                  onPressed: () async {
                    await currentUserReference!.update({
                      ...mapToFirestore(
                        {
                          'favoriteNativeSpeakers':
                              FieldValue.arrayRemove([widget.nsUserDocRef]),
                        },
                      ),
                    });
                    safeSetState(() {});
                  },
                  icon: Icon(
                    Icons.favorite_rounded,
                    color: FlutterFlowTheme.of(context).error,
                    size: 20.0,
                  ),
                );
              } else {
                return _buildTopCircleIconButton(
                  onPressed: () async {
                    await currentUserReference!.update({
                      ...mapToFirestore(
                        {
                          'favoriteNativeSpeakers':
                              FieldValue.arrayUnion([widget.nsUserDocRef]),
                        },
                      ),
                    });
                    safeSetState(() {});
                  },
                  icon: Icon(
                    FFIcons.kheart,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 20.0,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomCallToAction() {
    return AuthUserStreamWidget(
      builder: (context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0x00F2F2F7),
              Color(0xACF2F2F7),
              FlutterFlowTheme.of(context).secondaryBackground
            ],
            stops: [0.0, 0.2, 1.0],
            begin: AlignmentDirectional(0.0, -1.0),
            end: AlignmentDirectional(0, 1.0),
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(6.0, 12.0, 6.0, 35.0),
          child: Stack(
            children: [
              Container(
                width: double.infinity,
                height: 60.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryText,
                  borderRadius: BorderRadius.circular(50.0),
                ),
                child: Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              16.0, 0.0, 0.0, 0.0),
                          child: Text(
                            FFLocalizations.of(context).getText(
                              '2sabsnp2' /* Начать small talk */,
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'Cool',
                                  color: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  fontSize: 20.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        ),
                      ),
                      Container(
                        width: 56.0,
                        height: 56.0,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          shape: BoxShape.circle,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Icon(
                            FFIcons.karrowRight,
                            color: Colors.black,
                            size: 20.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FFButtonWidget(
                onPressed: () async {
                  final balance =
                      currentUserDocument?.balanceST.smallTalks ?? 0.0;
                  if (balance <= 0) {
                    await showModalBottomSheet(
                      useRootNavigator: true,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
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
                              child: NoBalanceWidget(),
                            ),
                          ),
                        );
                      },
                    ).then((value) => safeSetState(() {}));
                    return;
                  }

                  if (!(await getPermissionStatus(cameraPermission))) {
                    await requestPermission(cameraPermission);
                  }
                  if (!(await getPermissionStatus(microphonePermission))) {
                    await requestPermission(microphonePermission);
                  }

                  final hasCameraPermission =
                      await getPermissionStatus(cameraPermission);
                  final hasMicrophonePermission =
                      await getPermissionStatus(microphonePermission);
                  if (!hasCameraPermission || !hasMicrophonePermission) {
                    return;
                  }

                  final targetTutorId = widget.nsUserDocRef?.id;
                  if (targetTutorId == null || targetTutorId.isEmpty) {
                    debugPrint(
                        'NativeSpeakerPage: missing target tutor id for direct call');
                    return;
                  }

                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => WaitingForTeacherPageWidget(
                        targetTutorId: targetTutorId,
                      ),
                      settings: RouteSettings(
                        name: WaitingForTeacherPageWidget.routeName,
                      ),
                    ),
                  );
                },
                text: FFLocalizations.of(context).getText(
                  '1b1w4r9j' /*  */,
                ),
                options: FFButtonOptions(
                  width: double.infinity,
                  height: 60.0,
                  padding: EdgeInsetsDirectional.fromSTEB(16.0, 0.0, 16.0, 0.0),
                  iconPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 0.0),
                  color: Color(0x00E88CD4),
                  textStyle: FlutterFlowTheme.of(context).titleSmall.override(
                        fontFamily: 'sf pro display',
                        color: Colors.white,
                        letterSpacing: 0.0,
                      ),
                  elevation: 0.0,
                  borderRadius: BorderRadius.circular(60.0),
                ),
                showLoadingIndicator: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewsSection(UsersRecord nativeSpeakerPageUsersRecord) {
    return FutureBuilder<List<ReviewsRecord>>(
      future: _reviewsFuture,
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

        List<ReviewsRecord> containerReviewsRecordList = snapshot.data!;
        final ratingBuckets = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        for (final review in containerReviewsRecordList) {
          if (ratingBuckets.containsKey(review.rating)) {
            ratingBuckets[review.rating] = ratingBuckets[review.rating]! + 1;
          }
        }
        final totalReviews = nativeSpeakerPageUsersRecord.rating.totalReviews;

        int countForRating(int ratingValue) => ratingBuckets[ratingValue] ?? 0;

        double percentForRating(int ratingValue) {
          if (totalReviews <= 0) {
            return 0.0;
          }
          final percent = countForRating(ratingValue) / totalReviews;
          return percent.clamp(0.0, 1.0).toDouble();
        }

        return Container(
          decoration: BoxDecoration(),
          child: Builder(
            builder: (context) {
              if (containerReviewsRecordList.isNotEmpty) {
                return Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.max,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatNumber(
                                  nativeSpeakerPageUsersRecord.rating.average,
                                  formatType: FormatType.custom,
                                  format: '0.0',
                                  locale: '',
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'Cool',
                                      fontSize: 48.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                    ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 6.0, 0.0, 0.0),
                                child: RatingBar.builder(
                                  onRatingUpdate: (newValue) => safeSetState(
                                      () => _model.ratingBarValue = newValue),
                                  itemBuilder: (context, index) => Icon(
                                    Icons.star_rounded,
                                    color: FlutterFlowTheme.of(context).warning,
                                  ),
                                  direction: Axis.horizontal,
                                  initialRating: _model.ratingBarValue ??=
                                      nativeSpeakerPageUsersRecord
                                          .rating.average,
                                  unratedColor: FlutterFlowTheme.of(context)
                                      .primaryBackground,
                                  itemCount: 5,
                                  itemSize: 18.0,
                                  glowColor:
                                      FlutterFlowTheme.of(context).warning,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    0.0, 4.0, 0.0, 0.0),
                                child: Text(
                                  functions
                                      .getReviewString(valueOrDefault<String>(
                                    nativeSpeakerPageUsersRecord
                                        .rating.totalReviews
                                        .toString(),
                                    '0',
                                  )),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        color: FlutterFlowTheme.of(context)
                                            .secondaryText,
                                        fontSize: 15.0,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          Expanded(
                            child: Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  10.0, 0.0, 0.0, 0.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 11.0,
                                        decoration: BoxDecoration(),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'clkcguct' /* 5 */,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        FFIcons.kstar012,
                                        color: Color(0xFFFFCC31),
                                        size: 13.0,
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            2.0, 0.0, 2.0, 0.0),
                                        child: AuthUserStreamWidget(
                                          builder: (context) =>
                                              LinearPercentIndicator(
                                            percent: percentForRating(5),
                                            width: 106.0,
                                            lineHeight: 4.0,
                                            animation: true,
                                            animateFromLastPercent: true,
                                            progressColor:
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                            backgroundColor:
                                                FlutterFlowTheme.of(context)
                                                    .accent4,
                                            barRadius: Radius.circular(8.0),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 33.0,
                                        decoration: BoxDecoration(),
                                        child: AutoSizeText(
                                          countForRating(5).toString(),
                                          maxLines: 1,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 3.0)),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 11.0,
                                        decoration: BoxDecoration(),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            '10vod9dp' /* 4 */,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        FFIcons.kstar012,
                                        color: Color(0xFFFFCC31),
                                        size: 13.0,
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            2.0, 0.0, 2.0, 0.0),
                                        child: AuthUserStreamWidget(
                                          builder: (context) =>
                                              LinearPercentIndicator(
                                            percent: percentForRating(4),
                                            width: 106.0,
                                            lineHeight: 4.0,
                                            animation: true,
                                            animateFromLastPercent: true,
                                            progressColor:
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                            backgroundColor:
                                                FlutterFlowTheme.of(context)
                                                    .accent4,
                                            barRadius: Radius.circular(8.0),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 33.0,
                                        decoration: BoxDecoration(),
                                        child: AutoSizeText(
                                          countForRating(4).toString(),
                                          maxLines: 1,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 3.0)),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 11.0,
                                        decoration: BoxDecoration(),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            's89a9grf' /* 3 */,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        FFIcons.kstar012,
                                        color: Color(0xFFFFCC31),
                                        size: 13.0,
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            2.0, 0.0, 2.0, 0.0),
                                        child: AuthUserStreamWidget(
                                          builder: (context) =>
                                              LinearPercentIndicator(
                                            percent: percentForRating(3),
                                            width: 106.0,
                                            lineHeight: 4.0,
                                            animation: true,
                                            animateFromLastPercent: true,
                                            progressColor:
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                            backgroundColor:
                                                FlutterFlowTheme.of(context)
                                                    .accent4,
                                            barRadius: Radius.circular(8.0),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 33.0,
                                        decoration: BoxDecoration(),
                                        child: AutoSizeText(
                                          countForRating(3).toString(),
                                          maxLines: 1,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 3.0)),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 11.0,
                                        decoration: BoxDecoration(),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'n8svbjr0' /* 2 */,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        FFIcons.kstar012,
                                        color: Color(0xFFFFCC31),
                                        size: 13.0,
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            2.0, 0.0, 2.0, 0.0),
                                        child: AuthUserStreamWidget(
                                          builder: (context) =>
                                              LinearPercentIndicator(
                                            percent: percentForRating(2),
                                            width: 106.0,
                                            lineHeight: 4.0,
                                            animation: true,
                                            animateFromLastPercent: true,
                                            progressColor:
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                            backgroundColor:
                                                FlutterFlowTheme.of(context)
                                                    .accent4,
                                            barRadius: Radius.circular(8.0),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 33.0,
                                        decoration: BoxDecoration(),
                                        child: AutoSizeText(
                                          countForRating(2).toString(),
                                          maxLines: 1,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 3.0)),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 11.0,
                                        decoration: BoxDecoration(),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'g8kj6pac' /* 1 */,
                                          ),
                                          textAlign: TextAlign.center,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        FFIcons.kstar012,
                                        color: Color(0xFFFFCC31),
                                        size: 13.0,
                                      ),
                                      Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            2.0, 0.0, 2.0, 0.0),
                                        child: AuthUserStreamWidget(
                                          builder: (context) =>
                                              LinearPercentIndicator(
                                            percent: percentForRating(1),
                                            width: 106.0,
                                            lineHeight: 4.0,
                                            animation: true,
                                            animateFromLastPercent: true,
                                            progressColor:
                                                FlutterFlowTheme.of(context)
                                                    .primary,
                                            backgroundColor:
                                                FlutterFlowTheme.of(context)
                                                    .accent4,
                                            barRadius: Radius.circular(8.0),
                                            padding: EdgeInsets.zero,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        width: 33.0,
                                        decoration: BoxDecoration(),
                                        child: AutoSizeText(
                                          countForRating(1).toString(),
                                          maxLines: 1,
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      ),
                                    ].divide(SizedBox(width: 3.0)),
                                  ),
                                ].divide(SizedBox(height: 4.0)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
                                          ? FlutterFlowTheme.of(context).primary
                                          : FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                    borderRadius: BorderRadius.circular(100.0),
                                  ),
                                  child: Align(
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'ovjwud7w' /* Все */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: valueOrDefault<Color>(
                                              _model.rate == 0
                                                  ? FlutterFlowTheme.of(context)
                                                      .primaryBackground
                                                  : FlutterFlowTheme.of(context)
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
                                          ? FlutterFlowTheme.of(context).primary
                                          : FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                    borderRadius: BorderRadius.circular(100.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          'h6yocea2' /* 5 */,
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
                                          ? FlutterFlowTheme.of(context).primary
                                          : FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                    borderRadius: BorderRadius.circular(100.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          'm2hjxtoq' /* 4 */,
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
                                          ? FlutterFlowTheme.of(context).primary
                                          : FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                    borderRadius: BorderRadius.circular(100.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          '19bs787g' /* 3 */,
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
                                          ? FlutterFlowTheme.of(context).primary
                                          : FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                    borderRadius: BorderRadius.circular(100.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          'is2w8qlp' /* 2 */,
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
                                          ? FlutterFlowTheme.of(context).primary
                                          : FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                      FlutterFlowTheme.of(context).primary,
                                    ),
                                    borderRadius: BorderRadius.circular(100.0),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          'bk4ndath' /* 1 */,
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
                          final rew = containerReviewsRecordList
                              .where((e) => _model.rate == 0
                                  ? true
                                  : (e.rating == _model.rate))
                              .toList();

                          return ListView.separated(
                            padding: EdgeInsets.zero,
                            primary: false,
                            shrinkWrap: true,
                            scrollDirection: Axis.vertical,
                            itemCount: rew.length,
                            separatorBuilder: (_, __) => SizedBox(height: 6.0),
                            itemBuilder: (context, rewIndex) {
                              final rewItem = rew[rewIndex];
                              return Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    16.0, 0.0, 16.0, 0.0),
                                child: ReviewCardWidget(
                                  key: Key(
                                      'Keyngy_${rewIndex}_of_${rew.length}'),
                                  rewDoc: rewItem,
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ].addToEnd(SizedBox(height: 24.0)),
                );
              } else {
                return EmptyWidget(
                  txt:
                      'У этого преподавателя пока нет оценок и отзывов. После первых занятий студенты смогут поделиться впечатлениями, и отзывы появятся здесь.',
                );
              }
            },
          ),
        );
      },
    );
  }
}

class _ProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ProfileHeaderDelegate({
    required this.maxHeaderExtent,
    required this.minHeaderExtent,
    required this.photoUrl,
    required this.displayName,
    required this.cityAndStatus,
    required this.ratingAverage,
  });

  final double maxHeaderExtent;
  final double minHeaderExtent;
  final String photoUrl;
  final String displayName;
  final String cityAndStatus;
  final double ratingAverage;

  @override
  double get maxExtent => maxHeaderExtent;

  @override
  double get minExtent => minHeaderExtent;

  @override
  bool shouldRebuild(covariant _ProfileHeaderDelegate oldDelegate) {
    return photoUrl != oldDelegate.photoUrl ||
        displayName != oldDelegate.displayName ||
        cityAndStatus != oldDelegate.cityAndStatus ||
        ratingAverage != oldDelegate.ratingAverage;
  }

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = FlutterFlowTheme.of(context);
    final totalShrink = maxExtent - minExtent;
    final progress = (shrinkOffset / totalShrink).clamp(0.0, 1.0);
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final currentExtent =
        (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);

    final snapHeaderHeight = statusBarHeight + 8 + 110 + 8 + 42 + 16;
    final phase1End =
        ((maxExtent - snapHeaderHeight) / totalShrink).clamp(0.05, 0.9);
    const phase2End = 0.88;

    final p1 = (progress / phase1End).clamp(0.0, 1.0);
    final p2 =
        ((progress - phase1End) / (phase2End - phase1End)).clamp(0.0, 1.0);
    final p3 = ((progress - phase2End) / (1.0 - phase2End)).clamp(0.0, 1.0);

    const circleMaxSize = 110.0;
    const circleMinSize = 32.0;
    final circleTop = statusBarHeight + 8.0;

    final double circleSize;
    if (progress <= phase1End) {
      circleSize = circleMaxSize;
    } else if (progress <= phase2End) {
      circleSize = ui.lerpDouble(circleMaxSize, circleMinSize, p2)!;
    } else {
      circleSize = ui.lerpDouble(circleMinSize, 0.0, p3)!;
    }

    // --- Single morphing photo ---
    double photoW, photoH, photoL, photoT;
    BorderRadius photoBR;
    double photoOpacity;

    if (progress <= phase1End) {
      photoW = ui.lerpDouble(screenWidth, circleMaxSize, p1)!;
      photoH = ui.lerpDouble(currentExtent, circleMaxSize, p1)!;
      photoL = ui.lerpDouble(0.0, (screenWidth - circleMaxSize) / 2, p1)!;
      photoT = ui.lerpDouble(0.0, circleTop, p1)!;
      photoBR = BorderRadius.lerp(
        BorderRadius.only(
          bottomLeft: Radius.circular(20.0),
          bottomRight: Radius.circular(20.0),
        ),
        BorderRadius.circular(circleMaxSize / 2),
        p1,
      )!;
      photoOpacity = 1.0;
    } else if (progress <= phase2End) {
      photoW = circleSize;
      photoH = circleSize;
      photoL = (screenWidth - circleSize) / 2;
      photoT = circleTop;
      photoBR = BorderRadius.circular(circleSize / 2);
      photoOpacity = 1.0;
    } else {
      final s = circleSize.clamp(1.0, circleMaxSize);
      photoW = s;
      photoH = s;
      photoL = (screenWidth - s) / 2;
      photoT = circleTop;
      photoBR = BorderRadius.circular(s / 2);
      photoOpacity = (1.0 - p3).clamp(0.0, 1.0);
    }

    // --- Rating badge ---
    final ratingOpacity = (1.0 - p1 * 2.0).clamp(0.0, 1.0);

    // --- Single sliding text block ---
    const estimatedTextHeight = 42.0;
    final expandedTextTop = currentExtent - 16.0 - estimatedTextHeight;
    final collapsedTextTop = circleTop + circleSize + 8.0;

    double textTop;
    double textPadLeft, textPadRight;
    Alignment textAlign;
    double textOpacity;

    if (progress <= phase1End) {
      textTop = ui.lerpDouble(expandedTextTop, collapsedTextTop, p1)!;
      textPadLeft = ui.lerpDouble(16.0, 0.0, p1)!;
      textPadRight = ui.lerpDouble(100.0, 0.0, p1)!;
      textAlign = Alignment.lerp(Alignment.centerLeft, Alignment.center, p1)!;
      textOpacity = 1.0;
    } else if (progress <= phase2End) {
      textTop = collapsedTextTop;
      textPadLeft = 0.0;
      textPadRight = 0.0;
      textAlign = Alignment.center;
      textOpacity = (1.0 - p2).clamp(0.0, 1.0);
    } else {
      textTop = collapsedTextTop;
      textPadLeft = 0.0;
      textPadRight = 0.0;
      textAlign = Alignment.center;
      textOpacity = 0.0;
    }

    final subtitleOpacity =
        progress <= phase1End ? 1.0 : (1.0 - p2 * 1.5).clamp(0.0, 1.0);
    final compactNameOpacity = p3.clamp(0.0, 1.0);

    final nameFontSize =
        progress <= phase1End ? 17.0 : ui.lerpDouble(17.0, 15.0, p2)!;
    final subtitleFontSize =
        progress <= phase1End ? 15.0 : ui.lerpDouble(15.0, 12.0, p2)!;
    final nameColor = Color.lerp(Colors.white, theme.primaryText, p1)!;
    final subtitleColor =
        Color.lerp(Color(0xFFEDEDED), theme.secondaryText, p1)!;
    final bgColor = Colors.transparent;

    return Container(
      color: bgColor,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          // Single morphing photo
          if (photoOpacity > 0.01 && photoW > 1)
            Positioned(
              left: photoL,
              top: photoT,
              width: photoW,
              height: photoH,
              child: Opacity(
                opacity: photoOpacity,
                child: ClipRRect(
                  borderRadius: photoBR,
                  child: CachedNetworkImage(
                    imageUrl: photoUrl,
                    width: photoW,
                    height: photoH,
                    fit: BoxFit.cover,
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    memCacheWidth: 800,
                  ),
                ),
              ),
            ),

          // Rating badge (fades early)
          if (ratingOpacity > 0.01 && ratingAverage > 0.0)
            Positioned(
              right: 16.0,
              bottom: 16.0,
              child: Opacity(
                opacity: ratingOpacity,
                child: Container(
                  width: 82.0,
                  height: 45.0,
                  decoration: BoxDecoration(
                    color: Color(0x3CFFFFFF),
                    borderRadius: BorderRadius.circular(100.0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 41.0,
                          height: 41.0,
                          decoration: BoxDecoration(
                            color: Color(0x58FFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            FFIcons.kstar012,
                            color: Color(0xFFFDFF00),
                            size: 18.0,
                          ),
                        ),
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(
                              6.0, 0.0, 0.0, 0.0),
                          child: Text(
                            formatNumber(
                              ratingAverage,
                              formatType: FormatType.custom,
                              format: '0.0',
                              locale: '',
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: Colors.white,
                                  fontSize: 15.0,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Single sliding name + city/status
          if (textOpacity > 0.01)
            Positioned(
              left: 0,
              right: 0,
              top: textTop,
              child: Opacity(
                opacity: textOpacity,
                child: Padding(
                  padding:
                      EdgeInsets.only(left: textPadLeft, right: textPadRight),
                  child: Align(
                    alignment: textAlign,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: p1 < 0.5
                          ? CrossAxisAlignment.start
                          : CrossAxisAlignment.center,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign:
                              p1 < 0.5 ? TextAlign.left : TextAlign.center,
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'sf pro display',
                                    color: nameColor,
                                    fontSize: nameFontSize,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        if (subtitleOpacity > 0.01)
                          Opacity(
                            opacity: subtitleOpacity,
                            child: Padding(
                              padding: EdgeInsets.only(top: 3.0),
                              child: Text(
                                cityAndStatus,
                                textAlign: p1 < 0.5
                                    ? TextAlign.left
                                    : TextAlign.center,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color: subtitleColor,
                                      fontSize: subtitleFontSize,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (compactNameOpacity > 0.01)
            Positioned(
              top: 0.0,
              left: 0.0,
              right: 0.0,
              child: Opacity(
                opacity: compactNameOpacity,
                child: Container(
                  height: statusBarHeight + kToolbarHeight,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        FlutterFlowTheme.of(context).secondaryBackground,
                        Color(0xEFF2F2F7),
                        Color(0x00F2F2F7)
                      ],
                      stops: [0.0, 0.8, 1.0],
                      begin: AlignmentDirectional(0.0, -1.0),
                      end: AlignmentDirectional(0.0, 1.0),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                        top: statusBarHeight, left: 60.0, right: 60.0),
                    child: Center(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: theme.primaryText,
                              fontSize: 17.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
