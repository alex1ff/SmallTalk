import '/auth/firebase_auth/auth_util.dart';
import '/components/celebration_n_s_widget.dart';
import '/backend/backend.dart';
import '/components/availability_schedule_card.dart';
import '/components/pending_teacher_review_bottom_sheet.dart';
import '/components/pending_teacher_review_card.dart';
import '/components/teacher_availability_switch_control.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/user_match_profile.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/add_inter_widget.dart';
import '/index.dart';
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
  static const double _statTileCompactBreakpoint = 132.0;
  static const double _statTileStackedBreakpoint = 92.0;

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

  Widget _dashboardSectionTitle(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.space0,
        ExpatlioDesign.space0,
        ExpatlioDesign.space0,
        ExpatlioDesign.titleContentGap,
      ),
      child: Text(
        text,
        style: ExpatlioDesign.sectionTitleStyle(context),
      ),
    );
  }

  Widget _dashboardIconBox(
    BuildContext context,
    IconData icon, {
    double size = 40.0,
    double iconSize = 20.0,
    bool showBackground = true,
  }) {
    if (!showBackground) {
      return SizedBox(
        width: iconSize,
        height: size,
        child: Center(
          child: Icon(
            icon,
            color: ExpatlioDesign.primary,
            size: iconSize,
          ),
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ExpatlioDesign.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
      ),
      child: Icon(
        icon,
        color: ExpatlioDesign.primary,
        size: iconSize,
      ),
    );
  }

  Widget _dashboardFilledButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
      onTap: onTap,
      child: Container(
        height: 44.0,
        width: double.infinity,
        decoration: BoxDecoration(
          color: ExpatlioDesign.primary,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(
          horizontal: ExpatlioDesign.itemSpacing,
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ExpatlioDesign.buttonTextStyle(context),
        ),
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    final balance = formatNumber(
      valueOrDefault(currentUserDocument?.balanceNS, 0.0),
      formatType: FormatType.decimal,
      decimalType: DecimalType.automatic,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          decoration: ExpatlioDesign.cardDecoration(),
          padding: ExpatlioDesign.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _dashboardIconBox(
                    context,
                    FFIcons.kwallet02,
                    size: 48.0,
                    iconSize: 22.0,
                  ),
                  const SizedBox(width: ExpatlioDesign.itemSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getVariableText(
                            ruText: 'Текущий баланс',
                            enText: 'Current balance',
                          ),
                          style: ExpatlioDesign.textStyle(
                            context,
                            color: ExpatlioDesign.muted,
                            size: 13.0,
                            weight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(
                          height: ExpatlioDesign.compactSpacing,
                        ),
                        Text(
                          '$balance ₽',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ExpatlioDesign.textStyle(
                            context,
                            size: 22.0,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ExpatlioDesign.sectionSpacing),
              _dashboardFilledButton(
                context: context,
                label: FFLocalizations.of(context).getVariableText(
                  ruText: 'Вывести',
                  enText: 'Withdraw',
                ),
                onTap: () => context.pushNamed(PayCopyWidget.routeName),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _dashboardStatTile(
    BuildContext context, {
    required IconData icon,
    required String value,
    required List<String> labels,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _statTileCompactBreakpoint;
        final isStacked = constraints.maxWidth < _statTileStackedBreakpoint;

        if (isStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                child: _dashboardIconBox(
                  context,
                  icon,
                  showBackground: false,
                ),
              ),
              const SizedBox(height: ExpatlioDesign.compactSpacing),
              _dashboardStatValue(
                context,
                value,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ExpatlioDesign.compactSpacing / 2),
              _dashboardStatLabels(
                context,
                labels,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ],
          );
        }

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _dashboardIconBox(
                    context,
                    icon,
                    showBackground: false,
                  ),
                  const SizedBox(width: ExpatlioDesign.space4),
                  Flexible(
                    child: _dashboardStatValue(
                      context,
                      value,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ExpatlioDesign.compactSpacing / 2),
              _dashboardStatLabels(
                context,
                labels,
                maxLines: 2,
                textAlign: TextAlign.center,
              ),
            ],
          );
        }

        return Row(
          children: [
            _dashboardIconBox(
              context,
              icon,
              showBackground: false,
            ),
            const SizedBox(width: ExpatlioDesign.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dashboardStatValue(context, value),
                  const SizedBox(height: ExpatlioDesign.compactSpacing / 2),
                  _dashboardStatLabels(context, labels),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _dashboardStatValue(
    BuildContext context,
    String value, {
    TextAlign textAlign = TextAlign.start,
  }) {
    return Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: ExpatlioDesign.textStyle(
        context,
        color: ExpatlioDesign.text,
        size: 20.0,
        weight: FontWeight.w700,
        height: 1.0,
      ),
    );
  }

  Widget _dashboardStatLabels(
    BuildContext context,
    List<String> labels, {
    int maxLines = 1,
    TextAlign textAlign = TextAlign.start,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final label in labels)
          Text(
            label,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: textAlign,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.muted,
              size: 13.0,
              weight: FontWeight.w400,
              height: 1.16,
            ),
          ),
      ],
    );
  }

  Widget _dashboardVerticalDivider() {
    return Container(
      height: 60.0,
      width: 1.0,
      margin: const EdgeInsets.symmetric(
        horizontal: ExpatlioDesign.compactSpacing,
      ),
      color: ExpatlioDesign.border,
    );
  }

  Widget _buildTodayStatsSection(BuildContext context) {
    return StreamBuilder<List<StatsRecord>>(
      stream: _model.statsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data ?? const <StatsRecord>[];
        final todayStats = stats.isNotEmpty ? stats.first : null;
        final earnedToday = todayStats?.earnedToday ?? '0';
        final minutesToday = todayStats?.minutesToday ?? '0';
        final callsToday = todayStats?.callsToday ?? '0';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dashboardSectionTitle(
              context,
              FFLocalizations.of(context).getVariableText(
                ruText: 'Статистика за сегодня',
                enText: 'Today stats',
              ),
            ),
            Container(
              width: double.infinity,
              decoration: ExpatlioDesign.cardDecoration(),
              padding: ExpatlioDesign.cardPadding,
              child: Row(
                children: [
                  Expanded(
                    child: _dashboardStatTile(
                      context,
                      icon: FFIcons.kcoinsStacked01,
                      value: '$earnedToday ₽',
                      labels: [
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'заработано',
                          enText: 'earned',
                        ),
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'сегодня',
                          enText: 'today',
                        ),
                      ],
                    ),
                  ),
                  _dashboardVerticalDivider(),
                  Expanded(
                    child: _dashboardStatTile(
                      context,
                      icon: FFIcons.kphone,
                      value: callsToday,
                      labels: [
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'звонков',
                          enText: 'calls',
                        ),
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'принято',
                          enText: 'accepted',
                        ),
                      ],
                    ),
                  ),
                  _dashboardVerticalDivider(),
                  Expanded(
                    child: _dashboardStatTile(
                      context,
                      icon: FFIcons.kclock,
                      value: minutesToday,
                      labels: [
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'минут',
                          enText: 'minutes',
                        ),
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'в звонках',
                          enText: 'in calls',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
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
                    Align(
                      alignment: AlignmentDirectional.center,
                      child: Image.asset(
                        'assets/images/logo.png',
                        width: 246.0,
                        height: 72.0,
                        fit: BoxFit.contain,
                      ),
                    ),
                    if (canAccessTeacherSurfaces(currentUserDocument))
                      _buildBalanceCard(context),
                    if (_hasPendingTeacherReview)
                      const PendingTeacherReviewCard(),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space0,
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
                          style: ExpatlioDesign.sectionTitleStyle(context),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space4,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0),
                      child: AuthUserStreamWidget(
                        builder: (context) {
                          final intervals = currentUserDocument
                                  ?.availabilityToday.intervals
                                  .toList() ??
                              [];

                          return AvailabilityScheduleCard(
                            availabilityEnabled: _effectiveAvailabilityEnabled,
                            intervals: intervals,
                            switchControl: _buildAvailabilitySwitch(),
                            onAddInterval: () async {
                              if (await _guardTeacherShellAccess()) {
                                return;
                              }

                              await _openAddInterBottomSheet();
                            },
                            onRemoveInterval: (intervalsItem) async {
                              if (await _guardTeacherShellAccess()) {
                                return;
                              }

                              final userRef = currentUserReference;
                              if (userRef == null) {
                                return;
                              }

                              await userRef.update(createUsersRecordData(
                                availabilityToday:
                                    createAvailabilityTodayStruct(
                                  fieldValues: {
                                    'intervals': FieldValue.arrayRemove([
                                      getIntervalsFirestoreData(
                                        updateIntervalsStruct(
                                          intervalsItem,
                                          clearUnsetFields: false,
                                        ),
                                        true,
                                      )
                                    ]),
                                  },
                                  clearUnsetFields: false,
                                ),
                              ));
                            },
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space20,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space112),
                      child: _buildTodayStatsSection(context),
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
