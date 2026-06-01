import '/auth/firebase_auth/auth_util.dart';
import '/components/celebration_n_s_widget.dart';
import '/backend/backend.dart';
import '/components/pending_teacher_review_bottom_sheet.dart';
import '/components/pending_teacher_review_card.dart';
import '/components/teacher_availability_switch_control.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/user_match_profile.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/add_inter_widget.dart';
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dashboard_n_s_model.dart';
export 'dashboard_n_s_model.dart';

class DashboardNSWidget extends StatefulWidget {
  const DashboardNSWidget({
    super.key,
    this.zn,
    this.statsStreamOverride,
  });

  final bool? zn;
  final Stream<List<StatsRecord>>? statsStreamOverride;

  static String routeName = 'Dashboard_NS';
  static String routePath = '/dashboardNS';

  @override
  State<DashboardNSWidget> createState() => _DashboardNSWidgetState();
}

class _DashboardNSWidgetState extends State<DashboardNSWidget> {
  late DashboardNSModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _redirectingToStudentDashboard = false;
  bool _pendingAvailabilityReconcileInFlight = false;

  bool get _canUseTeacherShell => canUseNativeSpeakerShell(currentUserDocument);

  bool get _hasPendingTeacherReview =>
      hasPendingTeacherVerification(currentUserDocument);

  bool get _effectiveAvailabilityEnabled =>
      !_hasPendingTeacherReview &&
      (currentUserDocument?.availabilityToday.enabled ?? false);

  bool get _effectiveSwitchValue =>
      !_hasPendingTeacherReview && (_model.switchValue ?? false);

  Map<String, dynamic> _buildTimezoneMetadataUpdate() {
    final now = DateTime.now();
    return {
      'timezoneOffsetMinutes': now.timeZoneOffset.inMinutes,
      'timezoneName': now.timeZoneName,
      'timezoneUpdatedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> _syncTimezoneMetadata() async {
    if (currentUserReference == null) {
      return;
    }

    try {
      await currentUserReference!.update(_buildTimezoneMetadataUpdate());
    } catch (error) {
      debugPrint('DashboardNS: failed to sync timezone metadata: $error');
    }
  }

  void _scheduleStudentDashboardRedirect() {
    if (_redirectingToStudentDashboard || !mounted) {
      return;
    }

    _redirectingToStudentDashboard = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.goNamed(
        StudentsDashboardWidget.routeName,
        queryParameters: {
          'zn': serializeParam(false, ParamType.bool),
        }.withoutNulls,
      );
    });
  }

  Future<bool> _guardTeacherShellAccess() async {
    if (_canUseTeacherShell) {
      return false;
    }

    _scheduleStudentDashboardRedirect();
    return true;
  }

  Future<bool> _openAddInterBottomSheet() async {
    if (await _guardTeacherShellAccess()) {
      return false;
    }

    final latestUser = await _reloadAvailabilityGuardUser();
    if (latestUser == null) {
      return false;
    }

    if (!canUseNativeSpeakerShell(latestUser)) {
      _scheduleStudentDashboardRedirect();
      return false;
    }

    if (hasPendingTeacherVerification(latestUser)) {
      await _showPendingTeacherReviewSheet();
      return false;
    }

    final intervalAdded = await showModalBottomSheet<bool>(
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Padding(
            padding: MediaQuery.viewInsetsOf(context),
            child: AddInterWidget(),
          ),
        );
      },
    );

    if (!mounted) {
      return intervalAdded ?? false;
    }

    safeSetState(() {});
    return intervalAdded ?? false;
  }

  Future<void> _showPendingTeacherReviewSheet() async {
    await showModalBottomSheet<void>(
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) => PendingTeacherReviewBottomSheet(),
    );
  }

  Future<bool> _guardPendingTeacherOnlineAction() async {
    if (!_hasPendingTeacherReview) {
      return false;
    }

    await _showPendingTeacherReviewSheet();
    return true;
  }

  Future<UsersRecord?> _reloadAvailabilityGuardUser() async {
    if (currentUserReference == null) {
      return null;
    }

    try {
      final snapshot = await currentUserReference!.get();
      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      final latestUser = UsersRecord.fromSnapshot(snapshot);
      currentUserDocument = latestUser;
      return latestUser;
    } catch (error) {
      debugPrint(
          'DashboardNS: failed to reload availability guard user: $error');
      return null;
    }
  }

  Future<void> _handlePendingAvailabilitySwitchTap() async {
    if (mounted) {
      safeSetState(() => _model.switchValue = false);
    }

    if (await _guardTeacherShellAccess()) {
      return;
    }

    await _guardPendingTeacherOnlineAction();
  }

  Future<void> _handleAvailabilitySwitchChanged(bool newValue) async {
    if (newValue) {
      final latestUser = await _reloadAvailabilityGuardUser();
      if (latestUser == null) {
        if (mounted) {
          safeSetState(() => _model.switchValue = false);
        }
        return;
      }

      if (!canUseNativeSpeakerShell(latestUser)) {
        if (mounted) {
          safeSetState(() => _model.switchValue = false);
        }
        _scheduleStudentDashboardRedirect();
        return;
      }

      if (hasPendingTeacherVerification(latestUser)) {
        if (mounted) {
          safeSetState(() => _model.switchValue = false);
        }
        await _showPendingTeacherReviewSheet();
        return;
      }
    } else if (await _guardTeacherShellAccess()) {
      if (mounted) {
        safeSetState(() => _model.switchValue = false);
      }
      return;
    }

    safeSetState(() => _model.switchValue = newValue);
    if (newValue) {
      if (currentUserDocument!.availabilityToday.intervals.isNotEmpty) {
        final availabilityUpdate = createUsersRecordData(
          availabilityToday: createAvailabilityTodayStruct(
            enabled: true,
            clearUnsetFields: false,
          ),
        );
        availabilityUpdate.addAll(_buildTimezoneMetadataUpdate());
        await currentUserReference!.update(availabilityUpdate);
      } else {
        safeSetState(() {
          _model.switchValue = false;
        });
        final intervalAdded = await _openAddInterBottomSheet();
        if (!mounted) {
          return;
        }

        if (intervalAdded) {
          safeSetState(() {
            _model.switchValue = true;
          });
        } else {
          if (currentUserReference != null) {
            final availabilityUpdate = createUsersRecordData(
              availabilityToday: createAvailabilityTodayStruct(
                enabled: false,
                clearUnsetFields: false,
              ),
            );
            availabilityUpdate.addAll(_buildTimezoneMetadataUpdate());
            await currentUserReference!.update(availabilityUpdate);
          }

          if (mounted) {
            safeSetState(() {
              _model.switchValue = false;
            });
          }
        }
      }
      safeSetState(() {});
    } else {
      await currentUserReference!.update(createUsersRecordData(
        availabilityToday: createAvailabilityTodayStruct(
          enabled: false,
          clearUnsetFields: false,
        ),
      ));
      safeSetState(() {});
    }
  }

  Widget _buildAvailabilitySwitch() {
    return AvailabilitySwitchControl(
      value: _effectiveSwitchValue,
      isPendingTeacherReview: _hasPendingTeacherReview,
      onChanged: (newValue) async {
        await _handleAvailabilitySwitchChanged(newValue);
      },
      onPendingTap: () async {
        await _handlePendingAvailabilitySwitchTap();
      },
    );
  }

  void _schedulePendingAvailabilityReconcileIfNeeded() {
    if (_pendingAvailabilityReconcileInFlight ||
        currentUserReference == null ||
        !_hasPendingTeacherReview) {
      return;
    }

    final hasPersistedAvailability =
        currentUserDocument?.availabilityToday.enabled ?? false;
    final isPersistedInCall = currentUserDocument?.isInCall ?? false;
    if (!hasPersistedAvailability && !isPersistedInCall) {
      return;
    }

    _pendingAvailabilityReconcileInFlight = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await currentUserReference!.update(
          createUsersRecordData(
            availabilityToday: createAvailabilityTodayStruct(
              enabled: false,
              clearUnsetFields: false,
            ),
          ),
        );
      } catch (error) {
        debugPrint(
          'DashboardNS: failed to reconcile pending availability: $error',
        );
      } finally {
        _pendingAvailabilityReconcileInFlight = false;
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DashboardNSModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      unawaited(_syncTimezoneMetadata());
      if (widget.zn == true) {
        await showModalBottomSheet(
          useRootNavigator: true,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          context: context,
          builder: (context) {
            return GestureDetector(
              onTap: () {
                FocusScope.of(context).unfocus();
                FocusManager.instance.primaryFocus?.unfocus();
              },
              child: Padding(
                padding: MediaQuery.viewInsetsOf(context),
                child: CelebrationNSWidget(),
              ),
            );
          },
        ).then((value) => safeSetState(() {}));
      }
    });

    _model.switchValue =
        valueOrDefault<bool>(_effectiveAvailabilityEnabled, false);

    // Create stats stream once, not on every build().
    final now = DateTime.now().toUtc();
    final todayMidnight = DateTime.utc(now.year, now.month, now.day);
    _model.statsStream = widget.statsStreamOverride ??
        queryStatsRecord(
          parent: currentUserReference,
          queryBuilder: (statsRecord) => statsRecord.where(
            'date',
            isEqualTo: todayMidnight,
          ),
          singleRecord: true,
        );
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        if (loggedIn && currentUserDocument == null) {
          return Scaffold(
            backgroundColor: ExpatlioDesign.background,
            body: const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          );
        }

        if (!_canUseTeacherShell) {
          _scheduleStudentDashboardRedirect();
          return Scaffold(
            backgroundColor: ExpatlioDesign.background,
            body: const SizedBox.shrink(),
          );
        }

        _schedulePendingAvailabilityReconcileIfNeeded();

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: ExpatlioDesign.background,
            body: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space16,
                  ExpatlioDesign.space0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 70.0,
                      decoration: ExpatlioDesign.cardDecoration(radius: 24.0),
                      child: Padding(
                        padding: EdgeInsets.all(ExpatlioDesign.space4),
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Container(
                              width: 66.0,
                              height: 66.0,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: ExpatlioDesign.border,
                                ),
                              ),
                              child: Builder(
                                builder: (context) {
                                  if (currentUserPhoto != '') {
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusCapsule),
                                      child: CachedNetworkImage(
                                        fadeInDuration:
                                            Duration(milliseconds: 0),
                                        fadeOutDuration:
                                            Duration(milliseconds: 0),
                                        imageUrl: currentUserPhoto,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 132,
                                        memCacheHeight: 132,
                                      ),
                                    );
                                  } else {
                                    return Align(
                                      alignment: AlignmentDirectional(0.0, 0.0),
                                      child: AuthUserStreamWidget(
                                        builder: (context) {
                                          final displayName =
                                              currentUserDisplayName.trim();
                                          final firstLetter =
                                              displayName.isNotEmpty
                                                  ? displayName[0].toUpperCase()
                                                  : '?';
                                          return Text(
                                            firstLetter,
                                            textAlign: TextAlign.center,
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'Cool',
                                                  fontSize: 22.0,
                                                  letterSpacing: 0.0,
                                                ),
                                          );
                                        },
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    ExpatlioDesign.space12,
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space0,
                                    ExpatlioDesign.space0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthUserStreamWidget(
                                      builder: (context) => Text(
                                        '${FFLocalizations.of(context).getVariableText(
                                          ruText: 'Привет, ',
                                          enText: 'Hi, ',
                                        )}${currentUserDisplayName}',
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
                                    Text(
                                      FFLocalizations.of(context).getText(
                                        '1u9apwk3' /* Welcome to Expatlio */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w600,
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
                    if (canAccessTeacherSurfaces(currentUserDocument))
                      InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          context.pushNamed(PayCopyWidget.routeName);
                        },
                        child: Stack(
                          children: [
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  ExpatlioDesign.space56,
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space56,
                                  ExpatlioDesign.space0),
                              child: Container(
                                width: double.infinity,
                                height: 165.0,
                                decoration:
                                    ExpatlioDesign.cardDecoration(radius: 24.0),
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.max,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Image.asset(
                                  'assets/images/Group_1171275327_2.png',
                                  width: 65.0,
                                  fit: BoxFit.contain,
                                ),
                                Image.asset(
                                  'assets/images/Group_1171275327_1.png',
                                  width: 65.0,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                            Padding(
                              padding: EdgeInsets.all(ExpatlioDesign.space16),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisSize: MainAxisSize.max,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        FFLocalizations.of(context).getText(
                                          'znnn9lq2' /* Текущий баланс */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                      ),
                                      Icon(
                                        FFIcons.kchevronRight,
                                        color: Color(0xFFC5C5C6),
                                        size: 18.0,
                                      ),
                                    ],
                                  ),
                                  RichText(
                                    textScaler:
                                        MediaQuery.of(context).textScaler,
                                    text: TextSpan(
                                      children: [
                                        TextSpan(
                                          text: formatNumber(
                                            valueOrDefault(
                                                currentUserDocument?.balanceNS,
                                                0.0),
                                            formatType: FormatType.decimal,
                                            decimalType: DecimalType.automatic,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 34.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w300,
                                              ),
                                        ),
                                        TextSpan(
                                          text: ' ₽',
                                          style: TextStyle(
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontWeight: FontWeight.w300,
                                            fontSize: 20.0,
                                          ),
                                        )
                                      ],
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            fontSize: 34.0,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w300,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space24,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space0),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        context
                                            .pushNamed(PayCopyWidget.routeName);
                                      },
                                      child: Container(
                                        height: 45.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          borderRadius: BorderRadius.circular(
                                              ExpatlioDesign.radiusCapsule),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(
                                              ExpatlioDesign.space4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        16.0, 0.0, 12.0, 0.0),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'm4d0g5ub' /* Вывести */,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .primaryText,
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                              ),
                                              Container(
                                                width: 41.0,
                                                height: 41.0,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0.0, 0.0),
                                                  child: Icon(
                                                    FFIcons.kchevronRight,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 18.0,
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
                          ],
                        ),
                      ),
                    if (_hasPendingTeacherReview)
                      const PendingTeacherReviewCard(),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space12,
                          ExpatlioDesign.space20,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0),
                      child: AuthUserStreamWidget(
                        builder: (context) => Text(
                          _effectiveAvailabilityEnabled
                              ? FFLocalizations.of(context).getVariableText(
                                  ruText: 'Вы доступны для звонков',
                                  enText: 'Are you available for calls',
                                )
                              : FFLocalizations.of(context).getVariableText(
                                  ruText: 'Вы не доступны для звонков',
                                  enText: 'You are not available for calls',
                                ),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'Cool',
                                color: FlutterFlowTheme.of(context).primaryText,
                                fontSize: 22.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.normal,
                              ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space4,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0),
                      child: Container(
                        width: double.infinity,
                        height: 60.0,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.card,
                          borderRadius:
                              BorderRadius.circular(ExpatlioDesign.radiusLarge),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(ExpatlioDesign.space16),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                FFLocalizations.of(context).getText(
                                  'n1zbzn9y' /* Доступен сегодня */,
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      fontSize: 16.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.normal,
                                    ),
                              ),
                              _buildAvailabilitySwitch(),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_effectiveAvailabilityEnabled)
                      AuthUserStreamWidget(
                        builder: (context) => Column(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Builder(
                              builder: (context) {
                                final intervals = currentUserDocument
                                        ?.availabilityToday.intervals
                                        .toList() ??
                                    [];

                                return ListView.separated(
                                  padding: EdgeInsets.zero,
                                  primary: false,
                                  shrinkWrap: true,
                                  scrollDirection: Axis.vertical,
                                  itemCount: intervals.length,
                                  separatorBuilder: (_, __) =>
                                      SizedBox(height: ExpatlioDesign.space8),
                                  itemBuilder: (context, intervalsIndex) {
                                    final intervalsItem =
                                        intervals[intervalsIndex];
                                    return Container(
                                      width: double.infinity,
                                      height: 60.0,
                                      decoration: BoxDecoration(
                                        color: FlutterFlowTheme.of(context)
                                            .primaryBackground,
                                        borderRadius: BorderRadius.circular(
                                            ExpatlioDesign.radiusExtraLarge),
                                      ),
                                      child: Padding(
                                        padding: EdgeInsets.all(
                                            ExpatlioDesign.space4),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          children: [
                                            Container(
                                              width: 52.0,
                                              height: 52.0,
                                              decoration: BoxDecoration(
                                                color:
                                                    ExpatlioDesign.mutedSurface,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        ExpatlioDesign
                                                            .radiusExtraLarge),
                                              ),
                                              child: Align(
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                child: Icon(
                                                  FFIcons.kclock,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  size: 20.0,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        12.0, 0.0, 0.0, 0.0),
                                                child: Text(
                                                  '${intervalsItem.start} - ${intervalsItem.end}',
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ),
                                            FlutterFlowIconButton(
                                              borderRadius: ExpatlioDesign
                                                  .radiusExtraLarge,
                                              buttonSize: 52.0,
                                              icon: Icon(
                                                FFIcons.ktrash03,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .error,
                                                size: 18.0,
                                              ),
                                              onPressed: () async {
                                                if (await _guardTeacherShellAccess()) {
                                                  return;
                                                }

                                                await currentUserReference!
                                                    .update(
                                                        createUsersRecordData(
                                                  availabilityToday:
                                                      createAvailabilityTodayStruct(
                                                    fieldValues: {
                                                      'intervals': FieldValue
                                                          .arrayRemove([
                                                        getIntervalsFirestoreData(
                                                          updateIntervalsStruct(
                                                            intervalsItem,
                                                            clearUnsetFields:
                                                                false,
                                                          ),
                                                          true,
                                                        )
                                                      ]),
                                                    },
                                                    clearUnsetFields: false,
                                                  ),
                                                ));
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space8,
                                  ExpatlioDesign.space0,
                                  ExpatlioDesign.space0),
                              child: InkWell(
                                splashColor: Colors.transparent,
                                focusColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                onTap: () async {
                                  if (await _guardTeacherShellAccess()) {
                                    return;
                                  }

                                  await _openAddInterBottomSheet();
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: 60.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    borderRadius: BorderRadius.circular(
                                        ExpatlioDesign.radiusLarge),
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                    ),
                                  ),
                                  child: Padding(
                                    padding:
                                        EdgeInsets.all(ExpatlioDesign.space4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        FlutterFlowIconButton(
                                          borderRadius:
                                              ExpatlioDesign.radiusMedium,
                                          buttonSize: 35.0,
                                          fillColor:
                                              FlutterFlowTheme.of(context)
                                                  .secondaryBackground,
                                          icon: Icon(
                                            Icons.add_sharp,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 18.0,
                                          ),
                                          onPressed: () {
                                            print('IconButton pressed ...');
                                          },
                                        ),
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            'ws9tu06c' /* Добавить интервал */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryText,
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w500,
                                              ),
                                        ),
                                      ].divide(SizedBox(
                                          width: ExpatlioDesign.space8)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space12,
                          ExpatlioDesign.space20,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0),
                      child: Text(
                        FFLocalizations.of(context).getText(
                          '5e7lo84r' /* Статистика за сегодня */,
                        ),
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              color: FlutterFlowTheme.of(context).primaryText,
                              fontSize: 22.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space4,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space112),
                      child: StreamBuilder<List<StatsRecord>>(
                        stream: _model.statsStream,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return const SizedBox.shrink();
                          }
                          List<StatsRecord> conditionalBuilderStatsRecordList =
                              snapshot.data ?? [];
                          final conditionalBuilderStatsRecord =
                              conditionalBuilderStatsRecordList.isNotEmpty
                                  ? conditionalBuilderStatsRecordList.first
                                  : null;

                          return Builder(
                            builder: (context) {
                              if (conditionalBuilderStatsRecord != null) {
                                return Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    borderRadius: BorderRadius.circular(
                                        ExpatlioDesign.radiusLarge),
                                  ),
                                  child: Padding(
                                    padding:
                                        EdgeInsets.all(ExpatlioDesign.space16),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      children: [
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  valueOrDefault<String>(
                                                    conditionalBuilderStatsRecord
                                                        .earnedToday
                                                        .toString(),
                                                    '0',
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 28.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                                Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'g97rtbgg' /* Заработано */,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              width: 64.0,
                                              height: 64.0,
                                              decoration: BoxDecoration(
                                                image: DecorationImage(
                                                  fit: BoxFit.cover,
                                                  image: Image.asset(
                                                    'assets/images/Frame_22.png',
                                                  ).image,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        ExpatlioDesign
                                                            .radiusExtraLarge),
                                                border: Border.all(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  valueOrDefault<String>(
                                                    conditionalBuilderStatsRecord
                                                        .minutesToday
                                                        .toString(),
                                                    '0',
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 28.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                                Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'hyjj1xqg' /* Продолжительность звонков */,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              width: 64.0,
                                              height: 64.0,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        ExpatlioDesign
                                                            .radiusExtraLarge),
                                                border: Border.all(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                ),
                                              ),
                                              child: Icon(
                                                FFIcons.kclock,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                size: 20.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Column(
                                              mainAxisSize: MainAxisSize.max,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  valueOrDefault<String>(
                                                    conditionalBuilderStatsRecord
                                                        .callsToday
                                                        .toString(),
                                                    '0',
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily: 'Cool',
                                                        fontSize: 28.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                                Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'q3rpok1f' /* Звонков принято */,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ],
                                            ),
                                            Container(
                                              width: 64.0,
                                              height: 64.0,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        ExpatlioDesign
                                                            .radiusExtraLarge),
                                                border: Border.all(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryBackground,
                                                ),
                                              ),
                                              child: Icon(
                                                FFIcons.kphone,
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                size: 20.0,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ].divide(SizedBox(
                                          height: ExpatlioDesign.space16)),
                                    ),
                                  ),
                                );
                              } else {
                                return Container(
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    borderRadius: BorderRadius.circular(
                                        ExpatlioDesign.radiusLarge),
                                  ),
                                  child: Padding(
                                    padding:
                                        EdgeInsets.all(ExpatlioDesign.space4),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      children: [
                                        Image.asset(
                                          'assets/images/Group_21.png',
                                          width: 96.0,
                                          height: 96.0,
                                          fit: BoxFit.cover,
                                          alignment: Alignment(0.0, -1.0),
                                        ),
                                        Padding(
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  ExpatlioDesign.space12,
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space0),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.max,
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                FFLocalizations.of(context)
                                                    .getText(
                                                  't1u8xuhi' /* Звонков ещё не было */,
                                                ),
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryText,
                                                          fontSize: 16.0,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                              ),
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(
                                                        0.0, 6.0, 0.0, 0.0),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'vf0nsiuy' /* Убедитесь, что вы онлайн.
Студ... */
                                                    ,
                                                  ),
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15.0,
                                                        letterSpacing: 0.0,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ]
                      .divide(SizedBox(height: ExpatlioDesign.space8))
                      .addToStart(SizedBox(height: ExpatlioDesign.space56)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
