import 'dart:async';

import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/acquaintance_n_s_s_t_a_r_t/acquaintance_n_s_s_t_a_r_t_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/profile_components/lang_app/lang_app_widget.dart';
import '/shared_pages/profile_components/logout/logout_widget.dart';
import '/shared_pages/profile_components/rate_app/rate_app_widget.dart';
import '/shared_pages/profile_components/report/report_widget.dart';
import '/shared_pages/profile_components/stats/stats_widget.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import '/services/email_verification_service.dart';
import '/services/teacher_verification_request_service.dart';
import '/services/user_match_profile.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webviewx_plus/webviewx_plus.dart';

import 'profile_model.dart';
export 'profile_model.dart';

class ProfileWidget extends StatefulWidget {
  const ProfileWidget({super.key});

  static String routeName = 'Profile';
  static String routePath = '/profile';

  @override
  State<ProfileWidget> createState() => _ProfileWidgetState();
}

class _ProfileWidgetState extends State<ProfileWidget> {
  late ProfileModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _emailVerificationBusy = false;
  bool _emailVerificationRefreshing = false;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileModel());
    unawaited(_refreshEmailVerificationStatus(showResult: false));
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  Future<void> _showRateAppSheet() async {
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
              child: RateAppWidget(),
            ),
          ),
        );
      },
    ).then((value) => safeSetState(() {}));
  }

  bool get _hasCurrentEmail => currentUserEmail.trim().isNotEmpty;

  bool get _isCurrentEmailVerified =>
      FirebaseAuth.instance.currentUser?.emailVerified ?? false;

  Future<void> _showProfileNotification(
    String message, {
    bool isError = false,
    String? text,
  }) async {
    if (!mounted) {
      return;
    }
    await actions.showTopNotification(
      context,
      message,
      text ?? '',
      isError,
    );
  }

  Future<void> _refreshEmailVerificationStatus({
    bool showResult = true,
  }) async {
    if (_emailVerificationRefreshing || !loggedIn) {
      return;
    }

    final wasVerified = _isCurrentEmailVerified;
    if (showResult) {
      _emailVerificationRefreshing = true;
      safeSetState(() {});
    }

    try {
      await authManager.refreshUser();
      final isVerified = _isCurrentEmailVerified;
      if (!mounted) {
        return;
      }

      if (showResult) {
        await _showProfileNotification(
          isVerified
              ? FFLocalizations.of(context).getVariableText(
                  ruText: 'Email подтверждён.',
                  enText: 'Email is verified.',
                )
              : FFLocalizations.of(context).getVariableText(
                  ruText: 'Email пока не подтверждён.',
                  enText: 'Email is not verified yet.',
                ),
          isError: !isVerified,
        );
      } else if (wasVerified != isVerified) {
        safeSetState(() {});
      }
    } catch (e) {
      if (showResult) {
        await _showProfileNotification(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Не удалось обновить статус email.',
            enText: 'Could not refresh email status.',
          ),
          isError: true,
        );
      }
    } finally {
      if (showResult) {
        _emailVerificationRefreshing = false;
      }
      if (mounted && showResult) {
        safeSetState(() {});
      }
    }
  }

  Future<void> _sendEmailVerification() async {
    if (_emailVerificationBusy || !_hasCurrentEmail || !loggedIn) {
      return;
    }

    _emailVerificationBusy = true;
    if (mounted) {
      safeSetState(() {});
    }

    try {
      final result = await sendCustomEmailVerification(
        locale: FFLocalizations.of(context).languageCode,
      );
      if (!mounted) {
        return;
      }

      if (result.alreadyVerified) {
        await authManager.refreshUser();
        if (mounted) {
          safeSetState(() {});
        }
        await _showProfileNotification(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Email уже подтверждён.',
            enText: 'Email is already verified.',
          ),
        );
        return;
      }

      await _showProfileNotification(
        FFLocalizations.of(context).getVariableText(
          ruText: 'Письмо для подтверждения отправлено.',
          enText: 'Verification email has been sent.',
        ),
      );
    } catch (e) {
      await _showProfileNotification(
        FFLocalizations.of(context).getVariableText(
          ruText: 'Не удалось отправить письмо. Попробуйте позже.',
          enText: 'Could not send the email. Please try again later.',
        ),
        isError: true,
      );
    } finally {
      _emailVerificationBusy = false;
      if (mounted) {
        safeSetState(() {});
      }
    }
  }

  Widget _buildEmailVerificationStatus(BuildContext context) {
    if (!_hasCurrentEmail || _isCurrentEmailVerified) {
      return const SizedBox.shrink();
    }

    final theme = FlutterFlowTheme.of(context);
    final actionBusy = _emailVerificationBusy || _emailVerificationRefreshing;
    final statusIconBackground = theme.primary.withValues(alpha: 0.18);

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0, 12, 0, 0),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.primaryBackground,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusIconBackground,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.mark_email_unread_rounded,
                      color: theme.primaryText,
                      size: 22,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getVariableText(
                            ruText: 'Подтвердите email',
                            enText: 'Verify your email',
                          ),
                          style: theme.bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: theme.primaryText,
                            fontSize: 16,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          FFLocalizations.of(context).getVariableText(
                            ruText:
                                'Подтвердите адрес, чтобы сохранить доступ к важным письмам и восстановлению аккаунта. Это не ограничивает звонки, чаты или профиль.',
                            enText:
                                'Verify the address to keep access to important emails and account recovery. This does not limit calls, chats, or profile access.',
                          ),
                          style: theme.bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: theme.secondaryText,
                            fontSize: 13,
                            letterSpacing: 0.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.secondaryBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        color: theme.secondaryText,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          currentUserEmail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: theme.primaryText,
                            fontSize: 14,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _emailVerificationAction(
                    context,
                    icon: Icons.email_outlined,
                    label: _emailVerificationBusy
                        ? FFLocalizations.of(context).getVariableText(
                            ruText: 'Отправляем...',
                            enText: 'Sending...',
                          )
                        : FFLocalizations.of(context).getVariableText(
                            ruText: 'Отправить письмо',
                            enText: 'Send email',
                          ),
                    filled: true,
                    enabled: !actionBusy,
                    onTap: _sendEmailVerification,
                  ),
                  _emailVerificationAction(
                    context,
                    icon: Icons.refresh_rounded,
                    label: _emailVerificationRefreshing
                        ? FFLocalizations.of(context).getVariableText(
                            ruText: 'Обновляем...',
                            enText: 'Refreshing...',
                          )
                        : FFLocalizations.of(context).getVariableText(
                            ruText: 'Обновить статус',
                            enText: 'Refresh status',
                          ),
                    filled: false,
                    enabled: !actionBusy,
                    onTap: () => _refreshEmailVerificationStatus(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emailVerificationAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool filled,
    required bool enabled,
    required Future<void> Function() onTap,
  }) {
    final theme = FlutterFlowTheme.of(context);
    final backgroundColor = filled
        ? theme.primaryText.withValues(alpha: enabled ? 1.0 : 0.45)
        : theme.secondaryBackground.withValues(alpha: enabled ? 1.0 : 0.7);
    final borderColor = filled
        ? theme.primaryText.withValues(alpha: enabled ? 1.0 : 0.45)
        : theme.alternate.withValues(alpha: enabled ? 0.7 : 0.45);
    final foregroundColor =
        filled ? theme.primaryBackground : theme.primaryText;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: enabled ? () => unawaited(onTap()) : null,
      child: Container(
        padding: EdgeInsetsDirectional.fromSTEB(14, 11, 14, 11),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: foregroundColor,
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: theme.bodyMedium.override(
                fontFamily: 'sf pro display',
                color: foregroundColor,
                fontSize: 13,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        if (loggedIn && currentUserDocument == null) {
          return Scaffold(
            backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
            body: const Center(
              child: CircularProgressIndicator.adaptive(),
            ),
          );
        }

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
            body: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(6, 0, 6, 0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 70,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primaryBackground,
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color:
                              FlutterFlowTheme.of(context).secondaryBackground,
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
                                      borderRadius: BorderRadius.circular(100),
                                      child: CachedNetworkImage(
                                        fadeInDuration:
                                            Duration(milliseconds: 0),
                                        fadeOutDuration:
                                            Duration(milliseconds: 0),
                                        imageUrl: currentUserPhoto,
                                        width: double.infinity,
                                        height: double.infinity,
                                        fit: BoxFit.cover,
                                        memCacheWidth: 200,
                                        memCacheHeight: 200,
                                      ),
                                    );
                                  } else {
                                    return Align(
                                      alignment: AlignmentDirectional(0, 0),
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
                                padding:
                                    EdgeInsetsDirectional.fromSTEB(12, 0, 0, 0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthUserStreamWidget(
                                      builder: (context) => Text(
                                        '${currentUserEmail}${currentUserDocument?.role == UserRole.native_speaker ? ' | ${FFLocalizations.of(context).getVariableText(
                                            ruText: currentUserDocument
                                                ?.countryNS.nameRu,
                                            enText: currentUserDocument
                                                ?.countryNS.nameEn,
                                          )}' : ''}',
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                            ),
                                      ),
                                    ),
                                    AuthUserStreamWidget(
                                      builder: (context) => Text(
                                        currentUserDisplayName,
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .primaryText,
                                              fontSize: 16,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.pushNamed(ProfileEditWidget.routeName);
                              },
                              child: Container(
                                width: 66,
                                height: 66,
                                decoration: BoxDecoration(
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryBackground,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  FFIcons.kedit05,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    AuthUserStreamWidget(
                      builder: (context) =>
                          _buildEmailVerificationStatus(context),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              if (canAccessTeacherSurfaces(
                                  currentUserDocument)) {
                                context.pushNamed(MyRewNSWidget.routeName);
                              } else {
                                context.pushNamed(MyRewWidget.routeName);
                              }
                            },
                            child: Container(
                              width: 100,
                              height: 115,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      FFLocalizations.of(context).getText(
                                        'w5x0ak9h' /* Мои отзывы */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            fontSize: 15,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Align(
                                      alignment: AlignmentDirectional(1, 0),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          FFIcons.kstar01,
                                          color: FlutterFlowTheme.of(context)
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
                        ),
                        Expanded(
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              if (canAccessTeacherSurfaces(
                                  currentUserDocument)) {
                                context.pushNamed(PayCopyWidget.routeName);
                              } else {
                                context.pushNamed(PayWidget.routeName);
                              }
                            },
                            child: Container(
                              width: 100,
                              height: 115,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      FFLocalizations.of(context).getText(
                                        'xxkubsii' /* Финансы */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            fontSize: 15,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Align(
                                      alignment: AlignmentDirectional(1, 0),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          FFIcons.kwallet02,
                                          color: FlutterFlowTheme.of(context)
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
                        ),
                      ].divide(SizedBox(width: 6)),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
                              context.pushNamed(MyCallsWidget.routeName);
                            },
                            child: Container(
                              width: 100,
                              height: 115,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Мои звонки',
                                        enText: 'My calls',
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            fontSize: 15,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Align(
                                      alignment: AlignmentDirectional(1, 0),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          FFIcons.kphone,
                                          color: FlutterFlowTheme.of(context)
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
                        ),
                        Expanded(
                          child: InkWell(
                            splashColor: Colors.transparent,
                            focusColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            onTap: () async {
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
                                        FocusManager.instance.primaryFocus
                                            ?.unfocus();
                                      },
                                      child: Padding(
                                        padding:
                                            MediaQuery.viewInsetsOf(context),
                                        child: StatsWidget(),
                                      ),
                                    ),
                                  );
                                },
                              ).then((value) => safeSetState(() {}));
                            },
                            child: Container(
                              width: 100,
                              height: 115,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.circular(26),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      FFLocalizations.of(context).getText(
                                        'p8bgfesg' /* Статистика */,
                                      ),
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            fontSize: 15,
                                            letterSpacing: 0.0,
                                            fontWeight: FontWeight.w500,
                                          ),
                                    ),
                                    Align(
                                      alignment: AlignmentDirectional(1, 0),
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryBackground,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          FFIcons.klineChartUp01,
                                          color: FlutterFlowTheme.of(context)
                                              .primaryText,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ].divide(SizedBox(width: 6)),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 18, 0, 0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            AuthUserStreamWidget(
                              builder: (context) {
                                final teacherTrackAction =
                                    resolveTeacherTrackProfileAction(
                                  currentUserDocument,
                                );

                                if (teacherTrackAction !=
                                    TeacherTrackProfileAction.none) {
                                  final actionLabel = teacherTrackAction ==
                                          TeacherTrackProfileAction.reapply
                                      ? FFLocalizations.of(context)
                                          .getVariableText(
                                          ruText: 'Подать заявку снова',
                                          enText: 'Submit again',
                                        )
                                      : FFLocalizations.of(context).getText(
                                          'iuym248z' /* Стать носителем */,
                                        );

                                  return InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      TeacherAccreditationStatus?
                                          existingRequestStatus;
                                      if (currentUserReference != null) {
                                        try {
                                          final existingRequestSnapshot =
                                              await teacherVerificationRequestRefForUser(
                                                      currentUserReference!.id)
                                                  .get();
                                          existingRequestStatus =
                                              resolveTeacherVerificationRequestStatus(
                                            existingRequestSnapshot.data(),
                                          );
                                        } catch (error) {
                                          debugPrint(
                                            'Profile: failed to load existing teacher verification request: $error',
                                          );
                                        }
                                      }

                                      if (canRestoreNativeSpeakerTrack(
                                        currentUserDocument,
                                        requestStatus: existingRequestStatus,
                                      )) {
                                        final restoreData = <String, dynamic>{
                                          ...createUsersRecordData(
                                            role: UserRole.native_speaker,
                                            availabilityToday:
                                                createAvailabilityTodayStruct(
                                              enabled: false,
                                              clearUnsetFields: false,
                                            ),
                                            isInCall: false,
                                          ),
                                        };
                                        if (shouldMirrorPendingTeacherStatusOnRestore(
                                          currentUserDocument,
                                          requestStatus: existingRequestStatus,
                                        )) {
                                          restoreData.addAll(
                                            createUsersRecordData(
                                              teacherAccreditationStatus:
                                                  TeacherAccreditationStatus
                                                      .pending,
                                              verifNS: false,
                                            ),
                                          );
                                        }

                                        await currentUserReference!
                                            .update(restoreData);
                                        await ensureCanonicalCurrentUserDocument(
                                          preferredUid: currentUserUid,
                                          canonicalUserRef:
                                              currentUserReference,
                                        );
                                        if (!mounted) {
                                          return;
                                        }
                                        context.goNamed(
                                          DashboardNSWidget.routeName,
                                        );
                                      } else {
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
                                                  child:
                                                      AcquaintanceNSSTARTWidget(),
                                                ),
                                              ),
                                            );
                                          },
                                        ).then((value) => safeSetState(() {}));
                                      }
                                    },
                                    child: Container(
                                      height: 50,
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
                                              actionLabel,
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        fontSize: 15,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                            ),
                                            Icon(
                                              FFIcons.kchevronRight,
                                              color: Color(0xFFC5C5C6),
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  return InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      await currentUserReference!
                                          .update(createUsersRecordData(
                                        role: UserRole.student,
                                      ));
                                      safeSetState(() {});
                                    },
                                    child: Container(
                                      height: 45,
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
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'dmupsasg' /* Стать учеником */,
                                              ),
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        fontSize: 15,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                            ),
                                            Icon(
                                              FFIcons.kchevronRight,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .secondaryText,
                                              size: 18,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 12,
                              endIndent: 16,
                              color: Color(0xFFE7E7E8),
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                await _showRateAppSheet();
                              },
                              child: Container(
                                height: 50,
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
                                          'u9y8laa9' /* Как вам приложение? */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      Icon(
                                        FFIcons.kchevronRight,
                                        color: Color(0xFFC5C5C6),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 12,
                              endIndent: 16,
                              color: Color(0xFFE7E7E8),
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
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
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Padding(
                                          padding:
                                              MediaQuery.viewInsetsOf(context),
                                          child: LangAppWidget(),
                                        ),
                                      ),
                                    );
                                  },
                                ).then((value) => safeSetState(() {}));
                              },
                              child: Container(
                                height: 50,
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
                                          '0yjewgwu' /* Язык приложения */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      Icon(
                                        FFIcons.kchevronRight,
                                        color: Color(0xFFC5C5C6),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 12,
                              endIndent: 16,
                              color: Color(0xFFE7E7E8),
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.pushNamed(BlackListWidget.routeName);
                              },
                              child: Container(
                                height: 50,
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
                                          'uo96qs94' /* Черный список */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      Icon(
                                        FFIcons.kchevronRight,
                                        color: Color(0xFFC5C5C6),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 12,
                              endIndent: 16,
                              color: Color(0xFFE7E7E8),
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
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
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Padding(
                                          padding:
                                              MediaQuery.viewInsetsOf(context),
                                          child: ReportWidget(),
                                        ),
                                      ),
                                    );
                                  },
                                ).then((value) => safeSetState(() {}));
                              },
                              child: Container(
                                height: 50,
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
                                          '7benyvw2' /* Сообщить о проблеме */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      Icon(
                                        FFIcons.kchevronRight,
                                        color: Color(0xFFC5C5C6),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Color(0xFFE7E7E8),
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
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
                                          FocusManager.instance.primaryFocus
                                              ?.unfocus();
                                        },
                                        child: Padding(
                                          padding:
                                              MediaQuery.viewInsetsOf(context),
                                          child: LogoutWidget(),
                                        ),
                                      ),
                                    );
                                  },
                                ).then((value) => safeSetState(() {}));
                              },
                              child: Container(
                                height: 50,
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
                                          'ss5m5bt2' /* Выйти */,
                                        ),
                                        style: FlutterFlowTheme.of(context)
                                            .bodyMedium
                                            .override(
                                              fontFamily: 'sf pro display',
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .error,
                                              fontSize: 15,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                      Icon(
                                        FFIcons.kchevronRight,
                                        color:
                                            FlutterFlowTheme.of(context).error,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(0, 18, 0, 0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: FlutterFlowTheme.of(context).primaryBackground,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.max,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                context.pushNamed(PolicyWidget.routeName);
                              },
                              child: Container(
                                height: 50,
                                decoration: BoxDecoration(),
                                child: Align(
                                  alignment: AlignmentDirectional(-1, 0),
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        16, 0, 0, 0),
                                    child: Text(
                                      FFLocalizations.of(context).getText(
                                        'g1hqddj1' /* Политика конфиденциальности */,
                                      ),
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
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Color(0xFFE7E7E8),
                            ),
                            InkWell(
                              splashColor: Colors.transparent,
                              focusColor: Colors.transparent,
                              hoverColor: Colors.transparent,
                              highlightColor: Colors.transparent,
                              onTap: () async {
                                await Clipboard.setData(
                                    ClipboardData(text: currentUserUid));
                                HapticFeedback.mediumImpact();
                                await actions.showTopNotification(
                                  context,
                                  '',
                                  'ID аккаунта скопирован',
                                  false,
                                );
                              },
                              child: Container(
                                height: 50,
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
                                        '${FFLocalizations.of(context).getVariableText(
                                          ruText: 'ID аккаунта: ',
                                          enText: 'Account ID: ',
                                        )}${currentUserUid}',
                                        maxLines: 1,
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
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Icon(
                                        FFIcons.kcopy01,
                                        color: Color(0xFFC5C5C6),
                                        size: 18,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              thickness: 1,
                              indent: 16,
                              endIndent: 16,
                              color: Color(0xFFE7E7E8),
                            ),
                            Container(
                              height: 50,
                              decoration: BoxDecoration(),
                              child: Align(
                                alignment: AlignmentDirectional(-1, 0),
                                child: Padding(
                                  padding: EdgeInsetsDirectional.fromSTEB(
                                      16, 0, 0, 0),
                                  child: Text(
                                    FFLocalizations.of(context).getText(
                                      'l1x4xu81' /* © 2025 Small Talk. Версия 1.0.... */,
                                    ),
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
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ]
                      .divide(SizedBox(height: 6))
                      .addToStart(SizedBox(height: 55))
                      .addToEnd(SizedBox(height: 100)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
