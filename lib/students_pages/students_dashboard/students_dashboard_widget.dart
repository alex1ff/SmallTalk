import '/auth/firebase_auth/auth_util.dart';
import '/authorization/acquaintance_s_t_u_d_e_n_t/widgets/student_onboarding_level_step.dart';
import '/authorization/components/country/country_widget.dart';
import '/authorization/components/celebration_s_t/celebration_s_t_widget.dart';
import '/authorization/components/celebration_top_up/celebration_top_up_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/permissions_util.dart';
import '/services/user_match_profile.dart';
import '/shared_pages/profile_components/no_balance/no_balance_widget.dart';
import '/students_pages/components/fav/fav_widget.dart';
import '/index.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

import 'students_dashboard_model.dart';
export 'students_dashboard_model.dart';

class StudentsDashboardWidget extends StatefulWidget {
  const StudentsDashboardWidget({
    super.key,
    bool? zn,
    this.done,
    bool? topUpSuccess,
  })  : this.zn = zn ?? false,
        this.topUpSuccess = topUpSuccess ?? false;

  final bool zn;
  final bool? done;
  final bool topUpSuccess;

  static String routeName = 'Students_Dashboard';
  static String routePath = '/studentsDashboard';

  @override
  State<StudentsDashboardWidget> createState() =>
      _StudentsDashboardWidgetState();
}

class _StudentsDashboardWidgetState extends State<StudentsDashboardWidget> {
  late StudentsDashboardModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _buildLoadingState(BuildContext context) {
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

  String _formatAvailableMinutes(BuildContext context, double? value) {
    return formatNumber(
      value ?? 0.0,
      formatType: FormatType.custom,
      format: '#,##0.#',
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  String _formatSmallTalkBalance(BuildContext context, double? value) {
    return formatNumber(
      value ?? 0.0,
      formatType: FormatType.custom,
      format: '#,##0.##',
      locale: FFLocalizations.of(context).languageCode,
    );
  }

  String _localizedText({
    required BuildContext context,
    required String ruText,
    required String enText,
  }) {
    return FFLocalizations.of(context).getVariableText(
      ruText: ruText,
      enText: enText,
    );
  }

  bool _hasCountryData(CountryStruct? country) {
    if (country == null) {
      return false;
    }

    return country.code.trim().isNotEmpty;
  }

  CountryStruct? _preferredLocation(UsersRecord? user) {
    if (user == null || !user.preferences.hasPreferredLocation()) {
      return null;
    }

    final preferredLocation = user.preferences.preferredLocation;
    return _hasCountryData(preferredLocation) ? preferredLocation : null;
  }

  String _preferredLocationLabel(BuildContext context, CountryStruct? country) {
    if (!_hasCountryData(country)) {
      return _localizedText(
        context: context,
        ruText: 'Любая',
        enText: 'Any',
      );
    }

    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    final localizedName = isRu ? country!.nameRu : country!.nameEn;
    if (localizedName.trim().isNotEmpty) {
      return localizedName;
    }

    final fallbackName = isRu ? country.nameEn : country.nameRu;
    if (fallbackName.trim().isNotEmpty) {
      return fallbackName;
    }

    return country.code.toUpperCase();
  }

  String _levelShortLabel(Level level) {
    switch (level) {
      case Level.Beginner:
        return 'A1';
      case Level.Basic:
        return 'A2';
      case Level.Intermediate:
        return 'B1';
      case Level.Fluent:
        return 'C1';
    }
  }

  String _defaultPartnerLevelLabel(BuildContext context, UsersRecord? user) {
    final currentUserLevel = resolveUserMatchLevel(user);
    if (currentUserLevel == null) {
      return _localizedText(
        context: context,
        ruText: 'Любой',
        enText: 'Any',
      );
    }

    return _levelShortLabel(currentUserLevel);
  }

  Future<void> _clearPreferredLocation() async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return;
    }

    await userRef.update(
      createUsersRecordData(
        preferences: createPreferencesStruct(
          fieldValues: {
            'preferredLocation': FieldValue.delete(),
          },
          clearUnsetFields: false,
        ),
      ),
    );
  }

  Future<void> _setPreferredPartnerLevel(Level? level) async {
    final userRef = currentUserReference;
    if (userRef == null) {
      return;
    }

    await userRef.update(
      createUsersRecordData(
        preferences: level == null
            ? createPreferencesStruct(
                fieldValues: {
                  'preferredPartnerLevel': FieldValue.delete(),
                },
                clearUnsetFields: false,
              )
            : createPreferencesStruct(
                preferredPartnerLevel: level,
                clearUnsetFields: false,
              ),
      ),
    );
  }

  Future<void> _openPreferredPartnerLevelPicker() async {
    final initialLevel = currentUserDocument?.preferences.preferredPartnerLevel;
    final fallbackLevel = initialLevel ??
        resolveUserMatchLevel(currentUserDocument) ??
        Level.Basic;

    final result = await showModalBottomSheet<_PartnerLevelResult>(
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return WebViewAware(
          child: _PartnerLevelBottomSheet(
            initialLevel: initialLevel,
            fallbackLevel: fallbackLevel,
          ),
        );
      },
    );

    if (result == null) {
      return;
    }

    if (!result.didInteract) {
      safeSetState(() {});
      return;
    }

    final livePreferredPartnerLevel =
        currentUserDocument?.preferences.preferredPartnerLevel;
    if (result.resetFilter) {
      if (livePreferredPartnerLevel != null) {
        await _setPreferredPartnerLevel(null);
      }
      safeSetState(() {});
      return;
    }

    if (result.level == livePreferredPartnerLevel) {
      safeSetState(() {});
      return;
    }

    await _setPreferredPartnerLevel(result.level);
    safeSetState(() {});
  }

  Future<void> _openPreferredLocationPicker() async {
    if (!mounted) {
      return;
    }

    final initialPreferredLocation = _preferredLocation(currentUserDocument);
    final result = await showModalBottomSheet<_LocationPickerResult>(
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (context) {
        return WebViewAware(
          child: _PartnerLocationBottomSheet(
            initialCountry: initialPreferredLocation,
            title: _localizedText(
              context: context,
              ruText: 'Локация собеседника',
              enText: 'Partner location',
            ),
          ),
        );
      },
    );

    if (!mounted || result == null) {
      return;
    }

    if (!result.didInteract) {
      safeSetState(() {});
      return;
    }

    final selectedCountry = result.country;
    final livePreferredLocation = _preferredLocation(currentUserDocument);
    if (result.resetFilter) {
      if (livePreferredLocation != null) {
        await _clearPreferredLocation();
      }
      safeSetState(() {});
      return;
    }

    if (selectedCountry == livePreferredLocation) {
      safeSetState(() {});
      return;
    }

    if (selectedCountry == null) {
      await _clearPreferredLocation();
      safeSetState(() {});
      return;
    }

    await currentUserReference!.update(
      createUsersRecordData(
        preferences: createPreferencesStruct(
          preferredLocation: updateCountryStruct(
            selectedCountry,
            clearUnsetFields: false,
          ),
          clearUnsetFields: false,
        ),
      ),
    );

    safeSetState(() {});
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => StudentsDashboardModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (widget.topUpSuccess) {
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
                  child: CelebrationTopUpWidget(),
                ),
              ),
            );
          },
        ).then((value) => safeSetState(() {}));
      } else if (widget.zn) {
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
                  child: CelebrationSTWidget(
                    done: widget.done ?? false,
                  ),
                ),
              ),
            );
          },
        ).then((value) => safeSetState(() {}));
      }
    });

    // Create stats stream once, not on every build().
    final now = DateTime.now().toUtc();
    final todayMidnight = DateTime.utc(now.year, now.month, now.day);
    _model.statsStream = queryStatsRecord(
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: AuthUserStreamWidget(
          builder: (context) {
            if (currentUserUid.isEmpty || currentUserDocument == null) {
              return _buildLoadingState(context);
            }

            return Stack(
              children: [
                SingleChildScrollView(
                  primary: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
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
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryBackground,
                                      width: 1,
                                    ),
                                  ),
                                  child: Builder(
                                    builder: (context) {
                                      if (currentUserPhoto != '') {
                                        return ClipRRect(
                                          borderRadius:
                                              BorderRadius.circular(100),
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
                                          alignment: AlignmentDirectional(0, 0),
                                          child: AuthUserStreamWidget(
                                            builder: (context) {
                                              final displayName =
                                                  currentUserDisplayName.trim();
                                              final firstLetter = displayName
                                                      .isNotEmpty
                                                  ? displayName[0].toUpperCase()
                                                  : '?';
                                              return Text(
                                                firstLetter,
                                                textAlign: TextAlign.center,
                                                style:
                                                    FlutterFlowTheme.of(context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily: 'Cool',
                                                          fontSize: 24,
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
                                        12, 0, 0, 0),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.max,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AuthUserStreamWidget(
                                          builder: (context) => Text(
                                            'Привет, ${currentUserDisplayName}',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  fontSize: 15,
                                                  letterSpacing: 0.0,
                                                ),
                                          ),
                                        ),
                                        Text(
                                          FFLocalizations.of(context).getText(
                                            'xocrym2z' /* Welcome to SmallTalk */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                fontSize: 16,
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
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(6, 6, 6, 0),
                        child: InkWell(
                          splashColor: Colors.transparent,
                          focusColor: Colors.transparent,
                          hoverColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onTap: () async {
                            context.pushNamed(PayWidget.routeName);
                          },
                          child: Stack(
                            children: [
                              Padding(
                                padding: EdgeInsetsDirectional.fromSTEB(
                                    55, 0, 55, 0),
                                child: Container(
                                  width: double.infinity,
                                  height: 165,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Color(0xFFE0E3E7),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Image.asset(
                                    'assets/images/Group_1171275327_2.png',
                                    width: 65,
                                    fit: BoxFit.contain,
                                  ),
                                  Image.asset(
                                    'assets/images/Group_1171275327_1.png',
                                    width: 65,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                              Padding(
                                padding: EdgeInsets.all(16),
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
                                            'o7w214bz' /* Текущий баланс */,
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 15,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.normal,
                                              ),
                                        ),
                                        AuthUserStreamWidget(
                                          builder: (context) => Text(
                                            '~ ${_formatAvailableMinutes(context, currentUserDocument?.balanceST.minutes)} минут',
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  fontSize: 15,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    RichText(
                                      textScaler:
                                          MediaQuery.of(context).textScaler,
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: valueOrDefault<String>(
                                              _formatSmallTalkBalance(
                                                context,
                                                currentUserDocument
                                                    ?.balanceST.smallTalks,
                                              ),
                                              '0',
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'sf pro display',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  fontSize: 40,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.w300,
                                                ),
                                          ),
                                          TextSpan(
                                            text: FFLocalizations.of(context)
                                                .getText(
                                              'et82m26d' /* .small talks */,
                                            ),
                                            style: TextStyle(
                                              fontFamily: 'Cool',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontWeight: FontWeight.w300,
                                              fontSize: 24,
                                            ),
                                          )
                                        ],
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'Cool',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              fontSize: 40,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.normal,
                                            ),
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          0, 22, 0, 0),
                                      child: Container(
                                        height: 45,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Padding(
                                                padding: EdgeInsetsDirectional
                                                    .fromSTEB(16, 0, 12, 0),
                                                child: Text(
                                                  FFLocalizations.of(context)
                                                      .getText(
                                                    'nes89ax1' /* Пополнить */,
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
                                                        fontSize: 16,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                              ),
                                              Container(
                                                width: 41,
                                                height: 41,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0, 0),
                                                  child: Icon(
                                                    FFIcons.kchevronRight,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .primaryText,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                            ],
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
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(6, 10, 6, 0),
                        child: AuthUserStreamWidget(
                          builder: (context) {
                            final selectedPartnerLevel = currentUserDocument
                                ?.preferences.preferredPartnerLevel;
                            final preferredLocation =
                                _preferredLocation(currentUserDocument);

                            return Row(
                              children: [
                                Expanded(
                                  child: _DashboardInlineFilterButton(
                                    title: preferredLocation == null
                                        ? _localizedText(
                                            context: context,
                                            ruText: 'Локация',
                                            enText: 'Location',
                                          )
                                        : '',
                                    label: preferredLocation == null
                                        ? ''
                                        : _preferredLocationLabel(
                                            context,
                                            preferredLocation,
                                          ),
                                    selected: preferredLocation != null,
                                    icon: Icons.public_rounded,
                                    onTap: _openPreferredLocationPicker,
                                    onClear: preferredLocation == null
                                        ? null
                                        : () async {
                                            await _clearPreferredLocation();
                                            safeSetState(() {});
                                          },
                                  ),
                                ),
                                const SizedBox(width: 8.0),
                                Expanded(
                                  child: _DashboardInlineFilterButton(
                                    title: _localizedText(
                                      context: context,
                                      ruText: 'Уровень',
                                      enText: 'Level',
                                    ),
                                    label: selectedPartnerLevel == null
                                        ? _defaultPartnerLevelLabel(
                                            context,
                                            currentUserDocument,
                                          )
                                        : _levelShortLabel(
                                            selectedPartnerLevel,
                                          ),
                                    selected: selectedPartnerLevel != null,
                                    icon: Icons.tune_rounded,
                                    onTap: _openPreferredPartnerLevelPicker,
                                    onClear: selectedPartnerLevel == null
                                        ? null
                                        : () async {
                                            await _setPreferredPartnerLevel(
                                              null,
                                            );
                                            safeSetState(() {});
                                          },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(0, 40, 0, 0),
                        child: Stack(
                          alignment: AlignmentDirectional(0, -1),
                          children: [
                            Image.asset(
                              'assets/images/group_11712750962.webp',
                              width: double.infinity,
                              height: 294.27,
                              fit: BoxFit.contain,
                            ),
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  60, 110, 60, 0),
                              child: Column(
                                mainAxisSize: MainAxisSize.max,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    FFLocalizations.of(context).getText(
                                      'a3nqo0ec' /* Найди собеседника
для практики */
                                      ,
                                    ),
                                    textAlign: TextAlign.center,
                                    style: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'Cool',
                                          fontSize: 21,
                                          letterSpacing: 0.0,
                                          fontWeight: FontWeight.normal,
                                          lineHeight: 1.1,
                                        ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0, 10, 0, 0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'crtk35jr' /* Первая минута бесплатно! */,
                                      ),
                                      textAlign: TextAlign.center,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            fontSize: 15,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        0, 29, 0, 0),
                                    child: InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        final balance = currentUserDocument
                                                ?.balanceST.smallTalks ??
                                            0.0;
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
                                                    child: NoBalanceWidget(),
                                                  ),
                                                ),
                                              );
                                            },
                                          ).then(
                                              (value) => safeSetState(() {}));
                                          return;
                                        }

                                        if (!(await getPermissionStatus(
                                            cameraPermission))) {
                                          await requestPermission(
                                              cameraPermission);
                                          if (!(await getPermissionStatus(
                                              microphonePermission))) {
                                            await requestPermission(
                                                microphonePermission);
                                            return;
                                          }
                                        }

                                        context.pushNamed(
                                            WaitingForTeacherPageWidget
                                                .routeName);
                                      },
                                      child: Container(
                                        width: 233.9,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          borderRadius:
                                              BorderRadius.circular(100),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.max,
                                            children: [
                                              Expanded(
                                                child: Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(16, 0, 0, 0),
                                                  child: Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'flmz1vkr' /* Начать разговор */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily: 'Cool',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .primaryBackground,
                                                          fontSize: 20,
                                                          letterSpacing: 0.0,
                                                          fontWeight:
                                                              FontWeight.normal,
                                                        ),
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryBackground,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Align(
                                                  alignment:
                                                      AlignmentDirectional(
                                                          0, 0),
                                                  child: Icon(
                                                    FFIcons.karrowRight,
                                                    color: Colors.black,
                                                    size: 20,
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
                      if (resolveFriendsForUser(currentUserDocument).isNotEmpty)
                        Padding(
                          padding: EdgeInsetsDirectional.fromSTEB(0, 30, 0, 0),
                          child: AuthUserStreamWidget(
                            builder: (context) => Column(
                              mainAxisSize: MainAxisSize.max,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                InkWell(
                                  splashColor: Colors.transparent,
                                  focusColor: Colors.transparent,
                                  hoverColor: Colors.transparent,
                                  highlightColor: Colors.transparent,
                                  onTap: () async {
                                    context.pushNamed(FavoriteWidget.routeName);
                                  },
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(),
                                    child: Padding(
                                      padding: EdgeInsetsDirectional.fromSTEB(
                                          16, 0, 16, 0),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            FFLocalizations.of(context).getText(
                                              'a4u0etcs' /* Друзья */,
                                            ),
                                            style: FlutterFlowTheme.of(context)
                                                .bodyMedium
                                                .override(
                                                  fontFamily: 'Cool',
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .primaryText,
                                                  fontSize: 21,
                                                  letterSpacing: 0.0,
                                                  fontWeight: FontWeight.normal,
                                                ),
                                          ),
                                          Icon(
                                            FFIcons.kchevronRight,
                                            color: FlutterFlowTheme.of(context)
                                                .secondaryText,
                                            size: 18,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      0, 10, 0, 0),
                                  child: Container(
                                    width: double.infinity,
                                    height: 180,
                                    decoration: BoxDecoration(),
                                    child: Builder(
                                      builder: (context) {
                                        final favs = resolveFriendsForUser(
                                                currentUserDocument)
                                            .toList();

                                        return ListView.separated(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 6),
                                          scrollDirection: Axis.horizontal,
                                          itemCount: favs.length,
                                          separatorBuilder: (_, __) =>
                                              SizedBox(width: 6),
                                          itemBuilder: (context, favsIndex) {
                                            final favsItem = favs[favsIndex];
                                            return FavWidget(
                                              key: Key(
                                                  'Keyy7d_${favsIndex}_of_${favs.length}'),
                                              nsUser: favsItem,
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
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(16, 40, 0, 0),
                        child: Text(
                          FFLocalizations.of(context).getText(
                            'lffx4k7x' /* Статистика за сегодня */,
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'Cool',
                                color: FlutterFlowTheme.of(context).primaryText,
                                fontSize: 21,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.normal,
                              ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(6, 10, 6, 0),
                        child: StreamBuilder<List<StatsRecord>>(
                          stream: _model.statsStream,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const SizedBox.shrink();
                            }
                            if (!snapshot.hasData) {
                              return Center(
                                child: SizedBox(
                                  width: 50,
                                  height: 50,
                                  child: SpinKitCircle(
                                    color:
                                        FlutterFlowTheme.of(context).secondary,
                                    size: 50,
                                  ),
                                ),
                              );
                            }
                            List<StatsRecord>
                                conditionalBuilderStatsRecordList =
                                snapshot.data!;
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
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(16),
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
                                                          .minutesToday
                                                          .toString(),
                                                      '0',
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily: 'Cool',
                                                          fontSize: 30,
                                                          letterSpacing: 0.0,
                                                        ),
                                                  ),
                                                  Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      '2dq1u1yc' /* Продолжительность звонков */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 16,
                                                          letterSpacing: 0.0,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(26),
                                                  border: Border.all(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryBackground,
                                                  ),
                                                ),
                                                child: Icon(
                                                  FFIcons.kclock,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  size: 20,
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
                                                          fontSize: 30,
                                                          letterSpacing: 0.0,
                                                        ),
                                                  ),
                                                  Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'f4nn7fxp' /* Звонков всего */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 16,
                                                          letterSpacing: 0.0,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                              Container(
                                                width: 64,
                                                height: 64,
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(26),
                                                  border: Border.all(
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .secondaryBackground,
                                                  ),
                                                ),
                                                child: Icon(
                                                  FFIcons.kphone,
                                                  color: FlutterFlowTheme.of(
                                                          context)
                                                      .secondaryText,
                                                  size: 20,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ].divide(SizedBox(height: 16)),
                                      ),
                                    ),
                                  );
                                } else {
                                  return Container(
                                    width: double.infinity,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      borderRadius: BorderRadius.circular(26),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(2),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.start,
                                        children: [
                                          Image.asset(
                                            'assets/images/Group_21.png',
                                            width: 96,
                                            height: 96,
                                            fit: BoxFit.cover,
                                            alignment: Alignment(0, -1),
                                          ),
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    12, 0, 0, 0),
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
                                                    'laxcndbb' /* Звонков ещё не было */,
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
                                                        fontSize: 16,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                ),
                                                Padding(
                                                  padding: EdgeInsetsDirectional
                                                      .fromSTEB(0, 6, 0, 0),
                                                  child: Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      '0hw93aax' /* Самое время это исправить.
Нач... */
                                                      ,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
                                                        .bodyMedium
                                                        .override(
                                                          fontFamily:
                                                              'sf pro display',
                                                          color: FlutterFlowTheme
                                                                  .of(context)
                                                              .secondaryText,
                                                          fontSize: 14,
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
                        .addToStart(SizedBox(height: 55))
                        .addToEnd(SizedBox(height: 116)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _DashboardInlineFilterButton extends StatelessWidget {
  const _DashboardInlineFilterButton({
    required this.title,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.icon,
    this.onClear,
  });

  final String title;
  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final clearVisible = selected && onClear != null;
    final hasTitle = title.trim().isNotEmpty;
    final hasLabel = label.trim().isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999.0),
        onTap: onTap,
        child: Container(
          height: 45.0,
          padding: const EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 12.0, 0.0),
          decoration: BoxDecoration(
            color: selected ? theme.primaryText : theme.primaryBackground,
            borderRadius: BorderRadius.circular(999.0),
            border: Border.all(
              color: selected ? theme.primaryText : theme.alternate,
            ),
          ),
          child: Row(
            children: [
              const SizedBox(width: 18.0),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 16.0,
                      color: selected
                          ? theme.primaryBackground
                          : theme.secondaryText,
                    ),
                    const SizedBox(width: 8.0),
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasTitle)
                            Text(
                              title,
                              maxLines: 1,
                              style: theme.bodyMedium.override(
                                fontFamily: 'sf pro display',
                                color: selected
                                    ? theme.primaryBackground
                                    : theme.secondaryText,
                                fontSize: 15.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (hasTitle && hasLabel)
                            Text(
                              ' · ',
                              maxLines: 1,
                              style: theme.bodyMedium.override(
                                fontFamily: 'sf pro display',
                                color: selected
                                    ? theme.primaryBackground
                                    : theme.secondaryText,
                                fontSize: 15.0,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          if (hasLabel)
                            Flexible(
                              child: Text(
                                label,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: theme.bodyMedium.override(
                                  fontFamily: 'sf pro display',
                                  color: selected
                                      ? theme.primaryBackground
                                      : theme.primaryText,
                                  fontSize: 15.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 18.0,
                child: clearVisible
                    ? InkWell(
                        borderRadius: BorderRadius.circular(999.0),
                        onTap: onClear,
                        child: Icon(
                          Icons.close_rounded,
                          size: 16.0,
                          color: selected
                              ? theme.primaryBackground
                              : theme.secondaryText,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PartnerLocationBottomSheet extends StatefulWidget {
  const _PartnerLocationBottomSheet({
    required this.initialCountry,
    required this.title,
  });

  final CountryStruct? initialCountry;
  final String title;

  @override
  State<_PartnerLocationBottomSheet> createState() =>
      _PartnerLocationBottomSheetState();
}

class _PartnerLocationBottomSheetState
    extends State<_PartnerLocationBottomSheet> {
  CountryStruct? _selectedCountry;
  bool _didInteract = false;

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.initialCountry;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 16.0,
              child: custom_widgets.NotchedClipper(
                width: double.infinity,
                height: 16.0,
              ),
            ),
            Stack(
              alignment: const AlignmentDirectional(0.0, 1.0),
              children: [
                Container(
                  width: double.infinity,
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                  ),
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).secondaryBackground,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              fontSize: 26.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                      Flexible(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            6.0,
                            0.0,
                            6.0,
                            0.0,
                          ),
                          child: SingleChildScrollView(
                            primary: false,
                            child: Column(
                              children: [
                                CountryWidget(
                                  selected: _selectedCountry,
                                  action: (country) async {
                                    setState(() {
                                      _selectedCountry = country;
                                      _didInteract = true;
                                    });
                                  },
                                ),
                              ]
                                  .addToStart(const SizedBox(height: 16.0))
                                  .addToEnd(const SizedBox(height: 120.0)),
                            ),
                          ),
                        ),
                      ),
                    ]
                        .divide(const SizedBox(height: 16.0))
                        .addToStart(const SizedBox(height: 16.0)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    6.0,
                    0.0,
                    6.0,
                    35.0,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _DashboardSheetPrimaryButton(
                          label: FFLocalizations.of(context).getText(
                            'z2pbajmj' /* Сохранить */,
                          ),
                          onTap: () => Navigator.pop(
                            context,
                            _LocationPickerResult(
                              country: _selectedCountry,
                              didInteract: _didInteract,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      _DashboardSheetResetButton(
                        label: FFLocalizations.of(context).getVariableText(
                          ruText: 'Сброс',
                          enText: 'Reset',
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          const _LocationPickerResult(
                            country: null,
                            didInteract: true,
                            resetFilter: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      _DashboardSheetCloseButton(
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPickerResult {
  const _LocationPickerResult({
    required this.country,
    required this.didInteract,
    this.resetFilter = false,
  });

  final CountryStruct? country;
  final bool didInteract;
  final bool resetFilter;
}

class _PartnerLevelBottomSheet extends StatefulWidget {
  const _PartnerLevelBottomSheet({
    required this.initialLevel,
    required this.fallbackLevel,
  });

  final Level? initialLevel;
  final Level fallbackLevel;

  @override
  State<_PartnerLevelBottomSheet> createState() =>
      _PartnerLevelBottomSheetState();
}

class _PartnerLevelBottomSheetState extends State<_PartnerLevelBottomSheet> {
  late Level _selectedLevel;
  late bool _hasExplicitSelection;
  bool _didInteract = false;

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.initialLevel ?? widget.fallbackLevel;
    _hasExplicitSelection = widget.initialLevel != null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            height: 16.0,
            child: custom_widgets.NotchedClipper(
              width: double.infinity,
              height: 16.0,
            ),
          ),
          Stack(
            alignment: const AlignmentDirectional(0.0, 1.0),
            children: [
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.9,
                ),
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Уровень собеседника',
                        enText: 'Partner level',
                      ),
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Cool',
                            fontSize: 26.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.normal,
                          ),
                    ),
                    Flexible(
                      child: StudentOnboardingLevelStep(
                        level: _selectedLevel,
                        showTitle: false,
                        onChanged: (level) {
                          setState(() {
                            _selectedLevel = level;
                            _hasExplicitSelection = true;
                            _didInteract = true;
                          });
                        },
                      ),
                    ),
                  ]
                      .divide(const SizedBox(height: 16.0))
                      .addToStart(const SizedBox(height: 16.0)),
                ),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  6.0,
                  0.0,
                  6.0,
                  35.0,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _DashboardSheetPrimaryButton(
                        label: FFLocalizations.of(context).getText(
                          'z2pbajmj' /* Сохранить */,
                        ),
                        onTap: () => Navigator.pop(
                          context,
                          _PartnerLevelResult(
                            level:
                                _hasExplicitSelection ? _selectedLevel : null,
                            didInteract: _didInteract,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    _DashboardSheetResetButton(
                      label: FFLocalizations.of(context).getVariableText(
                        ruText: 'Сброс',
                        enText: 'Reset',
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        const _PartnerLevelResult(
                          level: null,
                          didInteract: true,
                          resetFilter: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8.0),
                    _DashboardSheetCloseButton(
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PartnerLevelResult {
  const _PartnerLevelResult({
    required this.level,
    required this.didInteract,
    this.resetFilter = false,
  });

  final Level? level;
  final bool didInteract;
  final bool resetFilter;
}

class _DashboardSheetPrimaryButton extends StatelessWidget {
  const _DashboardSheetPrimaryButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FlutterFlowTheme.of(context).primaryText,
      borderRadius: BorderRadius.circular(100.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(100.0),
        onTap: onTap,
        child: SizedBox(
          height: 60.0,
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    fontSize: 20.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSheetResetButton extends StatelessWidget {
  const _DashboardSheetResetButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FlutterFlowTheme.of(context).primaryBackground,
      borderRadius: BorderRadius.circular(100.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(100.0),
        onTap: onTap,
        child: SizedBox(
          height: 60.0,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 18.0),
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: FlutterFlowTheme.of(context).primaryText,
                      fontSize: 15.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashboardSheetCloseButton extends StatelessWidget {
  const _DashboardSheetCloseButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FlutterFlowTheme.of(context).primaryBackground,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 60.0,
          height: 60.0,
          child: Icon(
            Icons.close_sharp,
            color: FlutterFlowTheme.of(context).error,
            size: 20.0,
          ),
        ),
      ),
    );
  }
}
