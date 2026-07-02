import 'dart:async';
import 'dart:math' as math;

import '/auth/firebase_auth/auth_util.dart';
import '/services/subscription_service.dart';
import '/components/acquaintance_n_s_s_t_a_r_t_widget.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/profile_dropdown_menu_item.dart';
import '/components/support_contact_menu.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/lang_app_widget.dart';
import '/components/delete_widget.dart';
import '/components/logout_widget.dart';
import '/components/rate_app_widget.dart';
import '/components/report_widget.dart';
import '/components/stats_widget.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import '/services/email_verification_service.dart';
import '/services/teacher_verification_request_service.dart';
import '/services/user_match_profile.dart';
import '/utils/subscription_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const double _statTileCompactBreakpoint = 132.0;
  static const double _statTileStackedBreakpoint = 92.0;

  late ProfileModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _appLanguageMenuKey = GlobalKey();
  final _supportMenuKey = GlobalKey();
  static const _emailVerificationPollInterval = Duration(seconds: 8);
  Timer? _emailVerificationPollTimer;
  Timer? _giftExpiryTimer;
  DateTime? _scheduledGiftExpiryAt;
  bool _emailVerificationBusy = false;
  bool _emailVerificationRefreshing = false;
  bool _isAppLanguageMenuOpen = false;
  bool _isSupportMenuOpen = false;
  OverlayEntry? _supportOverlayEntry;
  static const _supportEmail = 'support@expatlio.com';
  static const _supportTelegram = '@expatlio_support';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ProfileModel());
    unawaited(_refreshEmailVerificationStatus(showResult: false));
    _syncEmailVerificationPolling();
  }

  @override
  void dispose() {
    _giftExpiryTimer?.cancel();
    _stopEmailVerificationPolling();
    _supportOverlayEntry?.remove();
    _model.dispose();

    super.dispose();
  }

  void _scheduleGiftExpiryRefresh(DateTime? expiresAt) {
    if (expiresAt == null || !expiresAt.isAfter(DateTime.now())) {
      _giftExpiryTimer?.cancel();
      _giftExpiryTimer = null;
      _scheduledGiftExpiryAt = null;
      return;
    }

    if (_scheduledGiftExpiryAt?.isAtSameMomentAs(expiresAt) == true &&
        (_giftExpiryTimer?.isActive ?? false)) {
      return;
    }

    _giftExpiryTimer?.cancel();
    _scheduledGiftExpiryAt = expiresAt;
    final delay = expiresAt.difference(DateTime.now()) +
        const Duration(milliseconds: 500);
    _giftExpiryTimer = Timer(delay, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _giftExpiryTimer = null;
        _scheduledGiftExpiryAt = null;
      });
    });
  }

  String _giftMinutesProfileSubtitle(
    BuildContext context, {
    required double minutes,
    required DateTime? expiresAt,
  }) {
    final availableText = FFLocalizations.of(context).getVariableText(
      ruText: 'мин доступно',
      enText: 'min available',
    );
    final deadline = formatGiftExpiry(expiresAt);
    if (deadline.isEmpty) {
      return '${formatGiftMinutes(minutes)} $availableText';
    }

    final untilText = FFLocalizations.of(context).getVariableText(
      ruText: 'до',
      enText: 'until',
    );
    return '${formatGiftMinutes(minutes)} $availableText $untilText $deadline';
  }

  String _inactiveTariffSubtitle(BuildContext context, UsersRecord? user) {
    final gift = user?.giftMinutes;
    final expiresAt = gift?.expiresAt;
    final giftExpired = expiresAt != null && !expiresAt.isAfter(DateTime.now());
    final giftDrained = gift != null &&
        !giftExpired &&
        gift.totalGranted > 0 &&
        gift.minutes <= 0;
    return FFLocalizations.of(context).getVariableText(
      ruText: giftExpired
          ? 'Подарочные минуты истекли'
          : giftDrained
              ? 'Подарочные минуты закончились'
              : 'Оформите подписку для звонков',
      enText: giftExpired
          ? 'Gift minutes expired'
          : giftDrained
              ? 'Gift minutes used up'
              : 'Subscribe to make calls',
    );
  }

  String _formatProfileMinutes(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return '0';
    }

    final minutesMatch = RegExp(r'^(\d+)\s*:').firstMatch(trimmed);
    if (minutesMatch != null) {
      return minutesMatch.group(1) ?? '0';
    }

    final numericMatch = RegExp(r'^(\d+(?:[.,]\d+)?)').firstMatch(trimmed);
    if (numericMatch == null) {
      return trimmed;
    }

    final value = double.tryParse(numericMatch.group(1)!.replaceAll(',', '.'));
    if (value == null) {
      return trimmed;
    }

    return value.floor().toString();
  }

  Future<void> _showRateAppSheet() async {
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
            child: RateAppWidget(),
          ),
        );
      },
    ).then((value) => safeSetState(() {}));
  }

  bool get _hasCurrentEmail => currentUserEmail.trim().isNotEmpty;

  bool get _isCurrentEmailVerified =>
      FirebaseAuth.instance.currentUser?.emailVerified ?? false;

  void _syncEmailVerificationPolling() {
    if (loggedIn && _hasCurrentEmail && !_isCurrentEmailVerified) {
      _startEmailVerificationPolling();
    } else {
      _stopEmailVerificationPolling();
    }
  }

  void _startEmailVerificationPolling() {
    if (_emailVerificationPollTimer?.isActive ?? false) {
      return;
    }

    _emailVerificationPollTimer = Timer.periodic(
      _emailVerificationPollInterval,
      (_) {
        if (!mounted) {
          _stopEmailVerificationPolling();
          return;
        }
        if (!loggedIn || !_hasCurrentEmail || _isCurrentEmailVerified) {
          _stopEmailVerificationPolling();
          safeSetState(() {});
          return;
        }

        unawaited(_refreshEmailVerificationStatus(showResult: false));
      },
    );
  }

  void _stopEmailVerificationPolling() {
    _emailVerificationPollTimer?.cancel();
    _emailVerificationPollTimer = null;
  }

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

  String _planNameFor(UsersRecord? user) {
    final productId = user?.subscription?.productId;
    if (productId == SubscriptionProductIds.monthly) {
      return 'Basic';
    }
    if (productId == SubscriptionProductIds.quarterly) {
      return 'Pro';
    }
    return hasActiveSubscription(user) ? 'Pro' : 'Нет тарифа';
  }

  String _planPriceFor(UsersRecord? user) {
    final productId = user?.subscription?.productId;
    if (productId == SubscriptionProductIds.monthly) {
      return r'$10';
    }
    if (productId == SubscriptionProductIds.quarterly) {
      return r'$20';
    }
    return hasActiveSubscription(user) ? r'$20' : '';
  }

  String _planPeriodFor(UsersRecord? user) {
    final productId = user?.subscription?.productId;
    if (productId == SubscriptionProductIds.monthly) {
      return 'мес';
    }
    if (productId == SubscriptionProductIds.quarterly) {
      return '3 мес';
    }
    return hasActiveSubscription(user) ? '3 мес' : '';
  }

  Widget _buildCurrentTariffSection(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    final user = currentUserDocument;
    final showTeacherBalance = shouldShowTeacherProfileBalance(user);
    final canWithdraw = canAccessTeacherSurfaces(user);
    final active = hasActiveSubscription(user);
    final hasGift = hasUsableGiftMinutes(user);
    final giftMinutes = remainingGiftMinutes(user);
    final giftExpiresAt = giftMinutesExpiresAt(user);
    _scheduleGiftExpiryRefresh(active ? null : giftExpiresAt);
    final planName = _planNameFor(user);
    final planPrice = _planPriceFor(user);
    final planPeriod = _planPeriodFor(user);
    final teacherBalance = formatNumber(
      valueOrDefault(user?.balanceNS, 0.0),
      formatType: FormatType.decimal,
      decimalType: DecimalType.automatic,
    );

    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space0,
          ExpatlioDesign.space24, ExpatlioDesign.space0, ExpatlioDesign.space0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            FFLocalizations.of(context).getVariableText(
              ruText: showTeacherBalance ? 'Баланс' : 'Мой тариф',
              enText: showTeacherBalance ? 'Balance' : 'My plan',
            ),
            style: ExpatlioDesign.sectionTitleStyle(context).copyWith(
              color: theme.primaryText,
            ),
          ),
          SizedBox(height: ExpatlioDesign.space16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.primaryBackground,
              borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
              border: Border.all(
                color: ExpatlioDesign.border,
                width: 1.0,
              ),
            ),
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.primary.withValues(alpha: 0.10),
                          borderRadius:
                              BorderRadius.circular(ExpatlioDesign.radiusLarge),
                        ),
                        child: const Icon(
                          FFIcons.kwallet02,
                          color: ExpatlioDesign.primary,
                          size: 31,
                        ),
                      ),
                      SizedBox(width: ExpatlioDesign.space24),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (showTeacherBalance || !active) ...[
                              Text(
                                showTeacherBalance
                                    ? FFLocalizations.of(context)
                                        .getVariableText(
                                        ruText: 'Текущий баланс',
                                        enText: 'Current balance',
                                      )
                                    : hasGift
                                        ? FFLocalizations.of(context)
                                            .getVariableText(
                                            ruText: 'Подарочные минуты',
                                            enText: 'Gift minutes',
                                          )
                                        : FFLocalizations.of(context)
                                            .getVariableText(
                                            ruText: 'Нет подписки',
                                            enText: 'No subscription',
                                          ),
                                style: theme.bodyMedium.override(
                                  fontFamily: 'sf pro display',
                                  color: theme.secondaryText,
                                  fontSize: 22,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              SizedBox(height: ExpatlioDesign.space8),
                            ],
                            showTeacherBalance
                                ? Text(
                                    '$teacherBalance ₽',
                                    style: theme.titleMedium.override(
                                      fontFamily: 'sf pro display',
                                      color: theme.primaryText,
                                      fontSize: 28.0,
                                      letterSpacing: 0.0,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : active
                                    ? RichText(
                                        textScaler:
                                            MediaQuery.of(context).textScaler,
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text: planName,
                                              style: theme.titleMedium.override(
                                                fontFamily: 'sf pro display',
                                                color: theme.primaryText,
                                                fontSize: 28.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            TextSpan(
                                              text: ' · ',
                                              style: theme.titleMedium.override(
                                                fontFamily: 'sf pro display',
                                                color: theme.primaryText,
                                                fontSize: 28.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            TextSpan(
                                              text: planPrice,
                                              style: theme.titleMedium.override(
                                                fontFamily: 'sf pro display',
                                                color: ExpatlioDesign.primary,
                                                fontSize: 28.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            TextSpan(
                                              text: ' / $planPeriod',
                                              style: theme.titleMedium.override(
                                                fontFamily: 'sf pro display',
                                                color: theme.secondaryText,
                                                fontSize: 28.0,
                                                letterSpacing: 0.0,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : hasGift
                                        ? Text(
                                            _giftMinutesProfileSubtitle(
                                              context,
                                              minutes: giftMinutes,
                                              expiresAt: giftExpiresAt,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.titleMedium.override(
                                              fontFamily: 'sf pro display',
                                              color: theme.primaryText,
                                              fontSize: 28.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : Text(
                                            FFLocalizations.of(context)
                                                .getVariableText(
                                              ruText: 'Нет подписки',
                                              enText: 'No subscription',
                                            ),
                                            style: theme.titleMedium.override(
                                              fontFamily: 'sf pro display',
                                              color: theme.primaryText,
                                              fontSize: 28.0,
                                              letterSpacing: 0.0,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: ExpatlioDesign.space24),
                  _tariffActionButton(
                    context,
                    label: FFLocalizations.of(context).getVariableText(
                      ruText: showTeacherBalance
                          ? canWithdraw
                              ? 'Вывести'
                              : 'На проверке'
                          : active
                              ? 'Изменить тариф'
                              : 'Оформить подписку',
                      enText: showTeacherBalance
                          ? canWithdraw
                              ? 'Withdraw'
                              : 'In review'
                          : active
                              ? 'Change plan'
                              : 'Subscribe',
                    ),
                    filled: !showTeacherBalance || canWithdraw,
                    fullWidth: true,
                    onTap: () {
                      if (showTeacherBalance) {
                        if (canWithdraw) {
                          context.pushNamed(PayCopyWidget.routeName);
                        } else {
                          unawaited(_showProfileNotification(
                            FFLocalizations.of(context).getVariableText(
                              ruText:
                                  'Вывод будет доступен после подтверждения заявки.',
                              enText:
                                  'Withdrawals will be available after review.',
                            ),
                          ));
                        }
                        return;
                      }
                      context.pushNamed(PayWidget.routeName);
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tariffActionButton(
    BuildContext context, {
    required String label,
    required bool filled,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        height: 70,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? ExpatlioDesign.primary : ExpatlioDesign.mutedSurface,
          borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
          border: Border.all(color: ExpatlioDesign.border),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.titleMedium.override(
            fontFamily: 'sf pro display',
            color: filled ? Colors.white : theme.primaryText,
            fontSize: 22,
            letterSpacing: 0.0,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Future<void> _refreshEmailVerificationStatus({
    bool showResult = true,
  }) async {
    if (_emailVerificationRefreshing || !loggedIn) {
      return;
    }

    final wasVerified = _isCurrentEmailVerified;
    _emailVerificationRefreshing = true;
    if (showResult) {
      safeSetState(() {});
    }

    try {
      await authManager.refreshUser();
      final isVerified = _isCurrentEmailVerified;
      if (!mounted) {
        return;
      }

      if (isVerified) {
        _stopEmailVerificationPolling();
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
      _emailVerificationRefreshing = false;
      if (mounted) {
        _syncEmailVerificationPolling();
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
        fallbackToFirebaseDefault: false,
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
        _syncEmailVerificationPolling();
        safeSetState(() {});
      }
    }
  }

  Widget _buildEmailVerificationStatus(BuildContext context) {
    if (!_hasCurrentEmail || _isCurrentEmailVerified) {
      return const SizedBox.shrink();
    }

    final actionLabel = _emailVerificationBusy
        ? FFLocalizations.of(context).getVariableText(
            ruText: 'Отправляем...',
            enText: 'Sending...',
          )
        : FFLocalizations.of(context).getVariableText(
            ruText: 'Отправить письмо',
            enText: 'Send email',
          );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF2F2F2),
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
      ),
      padding: const EdgeInsets.all(ExpatlioDesign.itemSpacing),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: ExpatlioDesign.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_rounded,
              color: ExpatlioDesign.text,
              size: 17,
            ),
          ),
          const SizedBox(width: ExpatlioDesign.itemSpacing),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Подтвердите email',
                    enText: 'Verify your email',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    size: 14,
                    weight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.compactSpacing / 4),
                Text(
                  currentUserEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.muted,
                    size: 12,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: ExpatlioDesign.compactSpacing),
          _emailVerificationTextAction(
            context,
            label: actionLabel,
            enabled: !_emailVerificationBusy,
            busy: _emailVerificationBusy,
            onTap: _sendEmailVerification,
          ),
        ],
      ),
    );
  }

  Widget _emailVerificationTextAction(
    BuildContext context, {
    required String label,
    required bool enabled,
    bool busy = false,
    required Future<void> Function() onTap,
  }) {
    return TextButton(
      style: TextButton.styleFrom(
        foregroundColor: ExpatlioDesign.primary,
        disabledForegroundColor: ExpatlioDesign.inactive,
        padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space8,
            ExpatlioDesign.space4,
            ExpatlioDesign.space8,
            ExpatlioDesign.space4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        textStyle: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.primary,
          size: 13,
          weight: FontWeight.w700,
        ),
      ),
      onPressed: enabled ? () => unawaited(onTap()) : null,
      child: busy
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(ExpatlioDesign.primary),
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            )
          : Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
    );
  }

  Future<void> _showProfileSheet(Widget child) async {
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
            child: child,
          ),
        );
      },
    ).then((value) => safeSetState(() {}));
  }

  String _appLanguageLabel(String languageCode) {
    switch (languageCode) {
      case 'ru':
        return '🇷🇺 Русский';
      case 'en':
      default:
        return '🇬🇧 English';
    }
  }

  Future<void> _openAppLanguagePicker() async {
    final anchorContext = _appLanguageMenuKey.currentContext;
    if (anchorContext == null || !mounted) {
      return;
    }

    final currentLanguageCode = FFLocalizations.of(context).languageCode;
    safeSetState(() => _isAppLanguageMenuOpen = true);
    final selectedCode = await _showProfileOptionsMenu<String>(
      anchorContext,
      options: [
        _ProfileMenuOption<String>(
          value: 'en',
          label: _appLanguageLabel('en'),
          selected: currentLanguageCode == 'en',
        ),
        _ProfileMenuOption<String>(
          value: 'ru',
          label: _appLanguageLabel('ru'),
          selected: currentLanguageCode == 'ru',
        ),
      ],
    );

    if (mounted) {
      safeSetState(() => _isAppLanguageMenuOpen = false);
    }
    if (!mounted || selectedCode == null) {
      return;
    }

    if (selectedCode != FFLocalizations.of(context).languageCode) {
      setAppLanguage(context, selectedCode);
    }
    safeSetState(() {});
  }

  Future<void> _openSupportContactPicker() async {
    final anchorContext = _supportMenuKey.currentContext;
    if (anchorContext == null || !mounted) {
      return;
    }

    if (_supportOverlayEntry != null) {
      _closeSupportContactPicker();
      return;
    }

    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(anchorContext);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (anchorBox == null || overlayBox == null || !anchorBox.attached) {
      return;
    }

    final anchorOffset =
        anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    const viewportMargin = ExpatlioDesign.pagePadding;
    final menuWidth = math.min(
      292.0,
      overlayBox.size.width - (viewportMargin * 2),
    );
    final maxMenuLeft = math.max(
        viewportMargin, overlayBox.size.width - menuWidth - viewportMargin);
    final menuLeft = (anchorOffset.dx + anchorBox.size.width - menuWidth)
        .clamp(viewportMargin, maxMenuLeft)
        .toDouble();
    final menuTop = anchorOffset.dy + anchorBox.size.height + 8.0;

    safeSetState(() => _isSupportMenuOpen = true);
    _supportOverlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _closeSupportContactPicker,
            ),
          ),
          PositionedDirectional(
            start: menuLeft,
            top: menuTop,
            width: menuWidth,
            child: SupportContactMenu(
              email: _supportEmail,
              telegram: _supportTelegram,
              onEmailTap: () {
                _closeSupportContactPicker();
                unawaited(launchURL('mailto:$_supportEmail'));
              },
              onTelegramTap: () {
                _closeSupportContactPicker();
                unawaited(launchURL('https://t.me/expatlio_support'));
              },
            ),
          ),
        ],
      ),
    );
    overlay.insert(_supportOverlayEntry!);
  }

  void _closeSupportContactPicker() {
    _supportOverlayEntry?.remove();
    _supportOverlayEntry = null;
    if (mounted) {
      safeSetState(() => _isSupportMenuOpen = false);
    }
  }

  Future<T?> _showProfileOptionsMenu<T>(
    BuildContext anchorContext, {
    required List<_ProfileMenuOption<T>> options,
  }) {
    final anchorBox = anchorContext.findRenderObject() as RenderBox?;
    final overlayBox =
        Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;

    if (anchorBox == null || overlayBox == null || !anchorBox.attached) {
      return Future<T?>.value(null);
    }

    const viewportMargin = 16.0;
    const minMenuWidth = 206.0;
    const preferredMenuWidth = 280.0;
    final anchorOffset =
        anchorBox.localToGlobal(Offset.zero, ancestor: overlayBox);
    final availableMenuWidth =
        math.max(0.0, overlayBox.size.width - (viewportMargin * 2));
    final menuWidth = math.max(
      math.min(minMenuWidth, availableMenuWidth),
      math.min(preferredMenuWidth, availableMenuWidth),
    );
    final maxMenuLeft = math.max(
        viewportMargin, overlayBox.size.width - menuWidth - viewportMargin);
    final menuLeft = (anchorOffset.dx + anchorBox.size.width - menuWidth)
        .clamp(viewportMargin, maxMenuLeft)
        .toDouble();
    final anchorRect = Rect.fromLTWH(
      menuLeft,
      anchorOffset.dy + anchorBox.size.height + 8.0,
      menuWidth,
      0.0,
    );

    return showMenu<T>(
      context: anchorContext,
      position:
          RelativeRect.fromRect(anchorRect, Offset.zero & overlayBox.size),
      color: ExpatlioDesign.card,
      elevation: 8.0,
      shadowColor: const Color(0x12000000),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        side: const BorderSide(color: ExpatlioDesign.border),
      ),
      clipBehavior: Clip.antiAlias,
      popUpAnimationStyle: AnimationStyle.noAnimation,
      constraints: BoxConstraints(
        minWidth: menuWidth,
        maxWidth: menuWidth,
        maxHeight: 320.0,
      ),
      items: [
        for (final option in options)
          PopupMenuItem<T>(
            value: option.value,
            height: 42.0,
            padding: EdgeInsets.zero,
            child: ProfileDropdownMenuItem(
              label: option.label,
              selected: option.selected,
            ),
          ),
      ],
    );
  }

  Future<void> _handleTeacherTrackAction() async {
    TeacherAccreditationStatus? existingRequestStatus;
    if (currentUserReference != null) {
      try {
        final existingRequestSnapshot =
            await teacherVerificationRequestRefForUser(
          currentUserReference!.id,
        ).get();
        existingRequestStatus = resolveTeacherVerificationRequestStatus(
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
          availabilityToday: createAvailabilityTodayStruct(
            enabled: false,
            clearUnsetFields: false,
          ),
        ),
      };
      if (shouldMirrorPendingTeacherStatusOnRestore(
        currentUserDocument,
        requestStatus: existingRequestStatus,
      )) {
        restoreData.addAll(
          createUsersRecordData(
            teacherAccreditationStatus: TeacherAccreditationStatus.pending,
            verifNS: false,
          ),
        );
      }

      await currentUserReference!.update(restoreData);
      await ensureCanonicalCurrentUserDocument(
        preferredUid: currentUserUid,
        canonicalUserRef: currentUserReference,
      );
      if (!mounted) {
        return;
      }
      context.goNamed(DashboardNSWidget.routeName);
    } else {
      await _showProfileSheet(AcquaintanceNSSTARTWidget());
    }
  }

  Widget _profileTitle(BuildContext context, String text) {
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

  Widget _iconBox(BuildContext context, IconData icon, {Color? color}) {
    final iconColor = color ?? ExpatlioDesign.primary;
    return SizedBox(
      width: 20,
      height: 40,
      child: Center(
        child: Icon(icon, color: iconColor, size: 20),
      ),
    );
  }

  Widget _profileAvatar(BuildContext context, {double size = 88}) {
    final firstLetter = ExpatlioDesign.avatarInitial(currentUserDisplayName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ExpatlioDesign.avatarFallbackBackground,
        shape: BoxShape.circle,
        border: Border.all(color: ExpatlioDesign.border),
      ),
      child: currentUserPhoto.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                imageUrl: currentUserPhoto,
                width: size,
                height: size,
                fit: BoxFit.cover,
                memCacheWidth: 220,
                memCacheHeight: 220,
              ),
            )
          : Center(
              child: Text(
                firstLetter,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.avatarFallbackText,
                  size: 28,
                  weight: FontWeight.w700,
                ),
              ),
            ),
    );
  }

  Widget _profileHeaderCard(BuildContext context) {
    final displayName = currentUserDisplayName.trim().isNotEmpty
        ? currentUserDisplayName.trim()
        : FFLocalizations.of(context).getVariableText(
            ruText: 'Профиль',
            enText: 'Profile',
          );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncEmailVerificationPolling();
      }
    });

    return Container(
      decoration: ExpatlioDesign.cardDecoration(),
      padding: ExpatlioDesign.cardPadding,
      child: Column(
        children: [
          Row(
            children: [
              Stack(
                alignment: AlignmentDirectional.bottomEnd,
                children: [
                  _profileAvatar(context),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: ExpatlioDesign.border),
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: ExpatlioDesign.primary,
                      size: 15,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: ExpatlioDesign.sectionSpacing),
              Expanded(
                child: InkWell(
                  splashColor: Colors.transparent,
                  highlightColor: Colors.transparent,
                  onTap: () => context.pushNamed(ProfileEditWidget.routeName),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ExpatlioDesign.textStyle(
                                context,
                                size: 18,
                                weight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: ExpatlioDesign.space4),
                            Text(
                              currentUserEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ExpatlioDesign.textStyle(
                                context,
                                color: ExpatlioDesign.muted,
                                size: 13,
                                weight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (_hasCurrentEmail && !_isCurrentEmailVerified) ...[
            const SizedBox(height: ExpatlioDesign.sectionSpacing),
            _buildEmailVerificationStatus(context),
          ],
          const SizedBox(height: ExpatlioDesign.sectionSpacing),
          _outlineAction(
            context,
            icon: FFIcons.kedit05,
            label: FFLocalizations.of(context).getVariableText(
              ruText: 'Редактировать профиль',
              enText: 'Edit profile',
            ),
            onTap: () => context.pushNamed(ProfileEditWidget.routeName),
          ),
        ],
      ),
    );
  }

  Widget _outlineAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
      onTap: onTap,
      child: SizedBox(
        height: 44,
        width: double.infinity,
        child: Row(
          children: [
            Icon(icon, color: ExpatlioDesign.primary, size: 16),
            const SizedBox(width: ExpatlioDesign.itemSpacing),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              FFIcons.kchevronRight,
              color: ExpatlioDesign.inactive,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statTile(
    BuildContext context, {
    required IconData icon,
    required String value,
    required List<String> labels,
    VoidCallback? onTap,
  }) {
    final content = LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < _statTileCompactBreakpoint;
        final isStacked = constraints.maxWidth < _statTileStackedBreakpoint;

        if (isStacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(child: _iconBox(context, icon)),
              const SizedBox(height: ExpatlioDesign.compactSpacing),
              _statValue(
                context,
                value,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: ExpatlioDesign.compactSpacing / 2),
              _statLabels(
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
                  _iconBox(context, icon),
                  const SizedBox(width: ExpatlioDesign.space4),
                  Flexible(
                    child: _statValue(
                      context,
                      value,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ExpatlioDesign.compactSpacing / 2),
              _statLabels(
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
            _iconBox(context, icon),
            const SizedBox(width: ExpatlioDesign.space4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _statValue(context, value),
                  const SizedBox(height: ExpatlioDesign.compactSpacing / 2),
                  _statLabels(context, labels),
                ],
              ),
            ),
          ],
        );
      },
    );

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: content,
    );
  }

  Widget _statValue(
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
        size: 20,
        weight: FontWeight.w700,
        height: 1,
      ),
    );
  }

  Widget _statLabels(
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
              size: 13,
              weight: FontWeight.w400,
              height: 1.16,
            ),
          ),
      ],
    );
  }

  Widget _progressSection(BuildContext context) {
    final isTeacher = canAccessTeacherSurfaces(currentUserDocument);
    final wordsStream = isTeacher || currentUserReference == null
        ? Stream.value(const <UserWordsRecord>[])
        : queryUserWordsRecord(parent: currentUserReference);
    final statsStream = currentUserReference == null
        ? Stream.value(const <StatsRecord>[])
        : queryStatsRecord(
            parent: currentUserReference,
            queryBuilder: (statsRecord) => statsRecord.where(
              'isAllTime',
              isEqualTo: true,
            ),
            singleRecord: true,
          );

    return StreamBuilder<List<UserWordsRecord>>(
      stream: wordsStream,
      builder: (context, wordsSnapshot) {
        final wordsCount = wordsSnapshot.data?.length ?? 0;
        return StreamBuilder<List<StatsRecord>>(
          stream: statsStream,
          builder: (context, statsSnapshot) {
            final stats = (statsSnapshot.data ?? const <StatsRecord>[]);
            final allTimeStats = stats.isNotEmpty ? stats.first : null;
            final calls = allTimeStats?.totalCalls ??
                (currentUserDocument?.totalCalls ?? 0).toString();
            final minutes =
                _formatProfileMinutes(allTimeStats?.totalMinutes ?? '0');
            final earned = allTimeStats?.totalEarned ?? '0';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _profileTitle(
                  context,
                  FFLocalizations.of(context).getVariableText(
                    ruText: isTeacher ? 'Статистика' : 'Мой прогресс',
                    enText: isTeacher ? 'Statistics' : 'My progress',
                  ),
                ),
                Container(
                  decoration: ExpatlioDesign.cardDecoration(),
                  padding: ExpatlioDesign.cardPadding,
                  child: Row(
                    children: [
                      Expanded(
                        child: _statTile(
                          context,
                          icon: isTeacher
                              ? FFIcons.kcoinsStacked01
                              : FFIcons.kbookOpen01,
                          value:
                              isTeacher ? '$earned ₽' : wordsCount.toString(),
                          labels: isTeacher
                              ? [
                                  FFLocalizations.of(context).getVariableText(
                                    ruText: 'заработано',
                                    enText: 'earned',
                                  ),
                                  FFLocalizations.of(context).getVariableText(
                                    ruText: 'за всё время',
                                    enText: 'all time',
                                  ),
                                ]
                              : [
                                  FFLocalizations.of(context).getVariableText(
                                    ruText: 'слов',
                                    enText: 'words',
                                  ),
                                  FFLocalizations.of(context).getVariableText(
                                    ruText: 'в словаре',
                                    enText: 'in dictionary',
                                  ),
                                ],
                          onTap: isTeacher
                              ? null
                              : () => context.pushNamed(WordsWidget.routeName),
                        ),
                      ),
                      _verticalDivider(),
                      Expanded(
                        child: _statTile(
                          context,
                          icon: FFIcons.kphone,
                          value: calls,
                          labels: [
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'звонков',
                              enText: 'calls',
                            ),
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'всего',
                              enText: 'total',
                            ),
                          ],
                          onTap: () =>
                              context.pushNamed(MyCallsWidget.routeName),
                        ),
                      ),
                      _verticalDivider(),
                      Expanded(
                        child: _statTile(
                          context,
                          icon: FFIcons.kclock,
                          value: minutes,
                          labels: [
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'минут',
                              enText: 'minutes',
                            ),
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'в разговоре',
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
      },
    );
  }

  Widget _verticalDivider() {
    return Container(
      height: 60,
      width: 1,
      margin: const EdgeInsets.symmetric(
        horizontal: ExpatlioDesign.compactSpacing,
      ),
      color: ExpatlioDesign.border,
    );
  }

  Widget _filledProfileButton({
    required BuildContext context,
    required String label,
    required VoidCallback onTap,
    bool primary = true,
  }) {
    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
      onTap: onTap,
      child: Container(
        height: 44,
        width: double.infinity,
        decoration: BoxDecoration(
          color: primary ? ExpatlioDesign.primary : ExpatlioDesign.mutedSurface,
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
          style: ExpatlioDesign.textStyle(
            context,
            color: primary ? Colors.white : ExpatlioDesign.text,
            size: 14,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _tariffSection(BuildContext context) {
    final user = currentUserDocument;
    final showTeacherBalance = shouldShowTeacherProfileBalance(user);
    final canWithdraw = canAccessTeacherSurfaces(user);
    final active = hasActiveSubscription(user);
    final hasGift = hasUsableGiftMinutes(user);
    final giftMinutes = remainingGiftMinutes(user);
    final giftExpiresAt = giftMinutesExpiresAt(user);
    _scheduleGiftExpiryRefresh(active ? null : giftExpiresAt);
    final planTitle = showTeacherBalance
        ? FFLocalizations.of(context).getVariableText(
            ruText: 'Баланс',
            enText: 'Balance',
          )
        : active
            ? _planNameFor(user)
            : hasGift
                ? FFLocalizations.of(context).getVariableText(
                    ruText: 'Подарочные минуты',
                    enText: 'Gift minutes',
                  )
                : FFLocalizations.of(context).getVariableText(
                    ruText: 'Нет подписки',
                    enText: 'No subscription',
                  );
    final planPrice = _planPriceFor(user);
    final planPeriod = _planPeriodFor(user);
    final planSubtitle = showTeacherBalance
        ? '${formatNumber(
            valueOrDefault(user?.balanceNS, 0.0),
            formatType: FormatType.decimal,
            decimalType: DecimalType.automatic,
          )} ₽'
        : hasGift
            ? _giftMinutesProfileSubtitle(
                context,
                minutes: giftMinutes,
                expiresAt: giftExpiresAt,
              )
            : _inactiveTariffSubtitle(context, user);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _profileTitle(
          context,
          showTeacherBalance
              ? FFLocalizations.of(context).getVariableText(
                  ruText: 'Баланс',
                  enText: 'Balance',
                )
              : FFLocalizations.of(context).getVariableText(
                  ruText: 'Мой тариф',
                  enText: 'My plan',
                ),
        ),
        Container(
          decoration: ExpatlioDesign.cardDecoration(),
          padding: ExpatlioDesign.cardPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.primary.withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusMedium),
                    ),
                    child: Icon(
                      FFIcons.kwallet02,
                      color: ExpatlioDesign.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: ExpatlioDesign.itemSpacing),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showTeacherBalance) ...[
                          Text(
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'Текущий баланс',
                              enText: 'Current balance',
                            ),
                            style: ExpatlioDesign.textStyle(
                              context,
                              color: ExpatlioDesign.muted,
                              size: 13,
                              weight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: ExpatlioDesign.compactSpacing),
                        ],
                        if (showTeacherBalance)
                          Text(
                            planSubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ExpatlioDesign.textStyle(
                              context,
                              size: 22,
                              weight: FontWeight.w700,
                            ),
                          )
                        else if (active)
                          RichText(
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textScaler: MediaQuery.of(context).textScaler,
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: planTitle,
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    size: 20,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: ' · ',
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    size: 20,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: planPrice,
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    color: ExpatlioDesign.primary,
                                    size: 20,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                                TextSpan(
                                  text: ' / $planPeriod',
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    color: ExpatlioDesign.muted,
                                    size: 14,
                                    weight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                planTitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  size: 20,
                                  weight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: ExpatlioDesign.space4),
                              Text(
                                planSubtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: ExpatlioDesign.textStyle(
                                  context,
                                  color: ExpatlioDesign.muted,
                                  size: 13,
                                  weight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: ExpatlioDesign.sectionSpacing),
              _filledProfileButton(
                context: context,
                label: showTeacherBalance
                    ? canWithdraw
                        ? FFLocalizations.of(context).getVariableText(
                            ruText: 'Вывести',
                            enText: 'Withdraw',
                          )
                        : FFLocalizations.of(context).getVariableText(
                            ruText: 'На проверке',
                            enText: 'In review',
                          )
                    : active
                        ? FFLocalizations.of(context).getVariableText(
                            ruText: 'Изменить тариф',
                            enText: 'Change plan',
                          )
                        : FFLocalizations.of(context).getVariableText(
                            ruText: 'Оформить подписку',
                            enText: 'Subscribe',
                          ),
                primary: !showTeacherBalance || canWithdraw,
                onTap: () {
                  if (showTeacherBalance) {
                    if (canWithdraw) {
                      context.pushNamed(PayCopyWidget.routeName);
                    } else {
                      unawaited(_showProfileNotification(
                        FFLocalizations.of(context).getVariableText(
                          ruText:
                              'Вывод будет доступен после подтверждения заявки.',
                          enText: 'Withdrawals will be available after review.',
                        ),
                      ));
                    }
                  } else {
                    context.pushNamed(PayWidget.routeName);
                  }
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _roleSwitchMenuRow(BuildContext context) {
    return AuthUserStreamWidget(
      builder: (context) {
        final teacherTrackAction = resolveTeacherTrackProfileAction(
          currentUserDocument,
        );
        final label = switch (teacherTrackAction) {
          TeacherTrackProfileAction.reapply =>
            FFLocalizations.of(context).getVariableText(
              ruText: 'Подать заявку снова',
              enText: 'Submit again',
            ),
          TeacherTrackProfileAction.apply =>
            FFLocalizations.of(context).getVariableText(
              ruText: 'Стать учителем',
              enText: 'Become a teacher',
            ),
          TeacherTrackProfileAction.none => FFLocalizations.of(context).getText(
              'dmupsasg' /* Стать учеником */,
            ),
        };

        return _menuRow(
          context,
          icon: teacherTrackAction == TeacherTrackProfileAction.none
              ? FFIcons.kuserCircle
              : FFIcons.kgraduationHat02,
          label: label,
          color: teacherTrackAction == TeacherTrackProfileAction.none
              ? null
              : ExpatlioDesign.orange,
          onTap: () async {
            if (teacherTrackAction != TeacherTrackProfileAction.none) {
              await _handleTeacherTrackAction();
            } else {
              if (currentUserReference == null) {
                return;
              }
              final studentTrackUpdate = createUsersRecordData(
                role: UserRole.student,
              );
              studentTrackUpdate['availabilityToday'] = FieldValue.delete();
              await currentUserReference!.update(studentTrackUpdate);
              safeSetState(() {});
            }
          },
        );
      },
    );
  }

  Widget _menuRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Key? rowKey,
    Color? color,
    Widget? trailing,
    IconData? trailingIcon,
  }) {
    final resolvedColor = color ?? ExpatlioDesign.primary;

    return InkWell(
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Container(
        key: rowKey,
        height: 52,
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space0,
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space0,
        ),
        child: Row(
          children: [
            Icon(icon, color: resolvedColor, size: 20),
            const SizedBox(width: ExpatlioDesign.itemSpacing),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: color ?? ExpatlioDesign.text,
                  size: 15,
                  weight: color == null ? FontWeight.w500 : FontWeight.w600,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: ExpatlioDesign.itemSpacing),
              trailing,
            ],
            const SizedBox(width: ExpatlioDesign.compactSpacing),
            Icon(
              trailingIcon ?? FFIcons.kchevronRight,
              color: color ?? ExpatlioDesign.inactive,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: ExpatlioDesign.border,
    );
  }

  Widget _settingsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _profileTitle(
          context,
          FFLocalizations.of(context).getVariableText(
            ruText: 'Настройки приложения',
            enText: 'App settings',
          ),
        ),
        Container(
          decoration: ExpatlioDesign.cardDecoration(),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              _roleSwitchMenuRow(context),
              _menuDivider(),
              _menuRow(
                context,
                rowKey: _appLanguageMenuKey,
                icon: Icons.language_rounded,
                label: FFLocalizations.of(context).getText(
                  '0yjewgwu' /* Язык приложения */,
                ),
                trailing: Text(
                  _appLanguageLabel(FFLocalizations.of(context).languageCode),
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.muted,
                    size: 14,
                    weight: FontWeight.w400,
                  ),
                ),
                trailingIcon: _isAppLanguageMenuOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                onTap: () => unawaited(_openAppLanguagePicker()),
              ),
              _menuDivider(),
              _menuRow(
                context,
                icon: Icons.event_available_outlined,
                label: FFLocalizations.of(context).getVariableText(
                  ruText: 'Мои события',
                  enText: 'My events',
                ),
                onTap: () => context.pushNamed(EventHistoryWidget.routeName),
              ),
              _menuDivider(),
              _menuRow(
                context,
                icon: FFIcons.kuserCircle,
                label: FFLocalizations.of(context).getText(
                  'uo96qs94' /* Черный список */,
                ),
                trailing: Text(
                  (currentUserDocument?.blockedUsers.length ?? 0).toString(),
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.muted,
                    size: 14,
                    weight: FontWeight.w500,
                  ),
                ),
                onTap: () => context.pushNamed(BlackListWidget.routeName),
              ),
              _menuDivider(),
              _menuRow(
                context,
                rowKey: _supportMenuKey,
                icon: Icons.headset_mic_outlined,
                label: FFLocalizations.of(context).getText(
                  '7benyvw2' /* Служба поддержки */,
                ),
                trailingIcon: _isSupportMenuOpen
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                onTap: () => unawaited(_openSupportContactPicker()),
              ),
              _menuDivider(),
              _menuRow(
                context,
                icon: Icons.info_outline_rounded,
                label: FFLocalizations.of(context).getText(
                  'u9y8laa9' /* Как вам приложение? */,
                ),
                onTap: () => unawaited(_showRateAppSheet()),
              ),
              _menuDivider(),
              _menuRow(
                context,
                icon: Icons.logout_rounded,
                label: FFLocalizations.of(context).getText(
                  'ss5m5bt2' /* Выйти */,
                ),
                color: ExpatlioDesign.danger,
                onTap: () => unawaited(_showProfileSheet(LogoutWidget())),
              ),
              _menuDivider(),
              _menuRow(
                context,
                icon: Icons.delete_outline_rounded,
                label: FFLocalizations.of(context).getVariableText(
                  ruText: 'Удалить аккаунт',
                  enText: 'Delete account',
                ),
                color: ExpatlioDesign.danger,
                onTap: () => unawaited(_showProfileSheet(DeleteWidget())),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _profileFooter(BuildContext context) {
    final muted = ExpatlioDesign.muted;
    final accountIdLabel = '${FFLocalizations.of(context).getVariableText(
      ruText: 'ID аккаунта: ',
      enText: 'Account ID: ',
    )}$currentUserUid';

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusSmall),
              onTap: () => context.pushNamed(PolicyWidget.routeName),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExpatlioDesign.space8,
                  vertical: ExpatlioDesign.space4,
                ),
                child: Text(
                  FFLocalizations.of(context).getText(
                    'g1hqddj1' /* Политика конфиденциальности */,
                  ),
                  textAlign: TextAlign.center,
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: muted.withValues(alpha: 0.70),
                    size: 12,
                    weight: FontWeight.w400,
                  ),
                ),
              ),
            ),
            InkWell(
              borderRadius: BorderRadius.circular(ExpatlioDesign.radiusSmall),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: currentUserUid));
                HapticFeedback.mediumImpact();
                await actions.showTopNotification(
                  context,
                  '',
                  'ID аккаунта скопирован',
                  false,
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: ExpatlioDesign.space8,
                  vertical: ExpatlioDesign.space4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        accountIdLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: muted.withValues(alpha: 0.66),
                          size: 11,
                          weight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space4),
                    Icon(
                      FFIcons.kcopy01,
                      color: muted.withValues(alpha: 0.55),
                      size: 13,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space4),
            Text(
              FFLocalizations.of(context).getText(
                'l1x4xu81' /* © 2025 Expatlio. Версия 1.0.0 */,
              ),
              textAlign: TextAlign.center,
              style: ExpatlioDesign.textStyle(
                context,
                color: muted.withValues(alpha: 0.60),
                size: 11,
                weight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _newProfileBody(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space0,
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.pageBottomSpacing,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Профиль',
                enText: 'Profile',
              ),
              textAlign: TextAlign.center,
              style: ExpatlioDesign.textStyle(
                context,
                size: 28,
                weight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: ExpatlioDesign.itemSpacing),
            _profileHeaderCard(context),
            _progressSection(context),
            const SizedBox(height: ExpatlioDesign.sectionGap),
            _tariffSection(context),
            const SizedBox(height: ExpatlioDesign.sectionGap),
            _settingsSection(context),
            const SizedBox(height: ExpatlioDesign.sectionGap),
            _profileFooter(context),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _redesignedBuild(context);
  }

  Widget _redesignedBuild(BuildContext context) {
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

        return GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus();
            FocusManager.instance.primaryFocus?.unfocus();
          },
          child: Scaffold(
            key: scaffoldKey,
            backgroundColor: ExpatlioDesign.background,
            body: SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.pagePadding,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.pagePadding,
                  ExpatlioDesign.pageBottomSpacing,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: ExpatlioDesign.pageHeaderHeight,
                      child: Center(
                        child: Text(
                          FFLocalizations.of(context).getVariableText(
                            ruText: 'Профиль',
                            enText: 'Profile',
                          ),
                          style: ExpatlioDesign.pageHeaderTitleStyle(context),
                        ),
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.itemSpacing),
                    _profileHeaderCard(context),
                    const SizedBox(height: ExpatlioDesign.sectionGap),
                    _progressSection(context),
                    const SizedBox(height: ExpatlioDesign.sectionGap),
                    _tariffSection(context),
                    const SizedBox(height: ExpatlioDesign.sectionGap),
                    _settingsSection(context),
                    const SizedBox(height: ExpatlioDesign.sectionGap),
                    _profileFooter(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Widget _legacyBuild(BuildContext context) {
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
            body: Stack(
              children: [
                _newProfileBody(context),
                Offstage(
                  offstage: true,
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                        ExpatlioDesign.pagePadding,
                        ExpatlioDesign.space0,
                        ExpatlioDesign.pagePadding,
                        ExpatlioDesign.space0),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              borderRadius: BorderRadius.circular(
                                  ExpatlioDesign.cardRadius),
                              border: Border.all(
                                color: ExpatlioDesign.border,
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(ExpatlioDesign.space4),
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
                                        color: ExpatlioDesign.border,
                                        width: 1,
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
                                              memCacheWidth: 200,
                                              memCacheHeight: 200,
                                            ),
                                          );
                                        } else {
                                          return Align(
                                            alignment:
                                                AlignmentDirectional(0, 0),
                                            child: AuthUserStreamWidget(
                                              builder: (context) {
                                                final displayName =
                                                    currentUserDisplayName
                                                        .trim();
                                                final firstLetter =
                                                    displayName.isNotEmpty
                                                        ? displayName[0]
                                                            .toUpperCase()
                                                        : '?';
                                                return Text(
                                                  firstLetter,
                                                  textAlign: TextAlign.center,
                                                  style: FlutterFlowTheme.of(
                                                          context)
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
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          AuthUserStreamWidget(
                                            builder: (context) => Text(
                                              '${currentUserEmail}${currentUserDocument?.role == UserRole.native_speaker ? ' | ${FFLocalizations.of(context).getVariableText(
                                                  ruText: currentUserDocument
                                                      ?.countryNS.nameRu,
                                                  enText: currentUserDocument
                                                      ?.countryNS.nameEn,
                                                )}' : ''}',
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15,
                                                        letterSpacing: 0.0,
                                                      ),
                                            ),
                                          ),
                                          AuthUserStreamWidget(
                                            builder: (context) => Text(
                                              currentUserDisplayName,
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    fontFamily:
                                                        'sf pro display',
                                                    color: FlutterFlowTheme.of(
                                                            context)
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
                                      context.pushNamed(
                                          ProfileEditWidget.routeName);
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
                                      context
                                          .pushNamed(MyRewNSWidget.routeName);
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
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusExtraLarge),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                          ExpatlioDesign.space16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            alignment:
                                                AlignmentDirectional(1, 0),
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                FFIcons.kstar01,
                                                color:
                                                    FlutterFlowTheme.of(context)
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
                                    // ─── SUBSCRIPTION REWORK ─────────────
                                    // Teachers go to their earnings/history
                                    // page (PayCopyWidget). Students open the
                                    // custom RevenueCat-backed tariff screen.
                                    if (canAccessTeacherSurfaces(
                                        currentUserDocument)) {
                                      context
                                          .pushNamed(PayCopyWidget.routeName);
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
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusExtraLarge),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                          ExpatlioDesign.space16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            alignment:
                                                AlignmentDirectional(1, 0),
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                FFIcons.kwallet02,
                                                color:
                                                    FlutterFlowTheme.of(context)
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
                            ].divide(SizedBox(width: ExpatlioDesign.space8)),
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
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusExtraLarge),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                          ExpatlioDesign.space16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            alignment:
                                                AlignmentDirectional(1, 0),
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                FFIcons.kphone,
                                                color:
                                                    FlutterFlowTheme.of(context)
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
                                        return GestureDetector(
                                          onTap: () {
                                            FocusScope.of(context).unfocus();
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                          },
                                          child: Padding(
                                            padding: MediaQuery.viewInsetsOf(
                                                context),
                                            child: StatsWidget(),
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
                                      borderRadius: BorderRadius.circular(
                                          ExpatlioDesign.radiusExtraLarge),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.all(
                                          ExpatlioDesign.space16),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.max,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                            alignment:
                                                AlignmentDirectional(1, 0),
                                            child: Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryBackground,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                FFIcons.klineChartUp01,
                                                color:
                                                    FlutterFlowTheme.of(context)
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
                            ].divide(SizedBox(width: ExpatlioDesign.space8)),
                          ),
                          _buildCurrentTariffSection(context),
                          Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space20,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusExtraLarge),
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
                                        final actionLabel =
                                            teacherTrackAction ==
                                                    TeacherTrackProfileAction
                                                        .reapply
                                                ? FFLocalizations.of(context)
                                                    .getVariableText(
                                                    ruText:
                                                        'Подать заявку снова',
                                                    enText: 'Submit again',
                                                  )
                                                : FFLocalizations.of(context)
                                                    .getVariableText(
                                                    ruText: 'Стать учителем',
                                                    enText: 'Become a teacher',
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
                                                            currentUserReference!
                                                                .id)
                                                        .get();
                                                existingRequestStatus =
                                                    resolveTeacherVerificationRequestStatus(
                                                  existingRequestSnapshot
                                                      .data(),
                                                );
                                              } catch (error) {
                                                debugPrint(
                                                  'Profile: failed to load existing teacher verification request: $error',
                                                );
                                              }
                                            }

                                            if (canRestoreNativeSpeakerTrack(
                                              currentUserDocument,
                                              requestStatus:
                                                  existingRequestStatus,
                                            )) {
                                              final restoreData =
                                                  <String, dynamic>{
                                                ...createUsersRecordData(
                                                  role: UserRole.native_speaker,
                                                  availabilityToday:
                                                      createAvailabilityTodayStruct(
                                                    enabled: false,
                                                    clearUnsetFields: false,
                                                  ),
                                                ),
                                              };
                                              if (shouldMirrorPendingTeacherStatusOnRestore(
                                                currentUserDocument,
                                                requestStatus:
                                                    existingRequestStatus,
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
                                                backgroundColor:
                                                    Colors.transparent,
                                                context: context,
                                                builder: (context) {
                                                  return GestureDetector(
                                                    onTap: () {
                                                      FocusScope.of(context)
                                                          .unfocus();
                                                      FocusManager
                                                          .instance.primaryFocus
                                                          ?.unfocus();
                                                    },
                                                    child: Padding(
                                                      padding: MediaQuery
                                                          .viewInsetsOf(
                                                              context),
                                                      child:
                                                          AcquaintanceNSSTARTWidget(),
                                                    ),
                                                  );
                                                },
                                              ).then((value) =>
                                                  safeSetState(() {}));
                                            }
                                          },
                                          child: Container(
                                            height: 50,
                                            decoration: BoxDecoration(),
                                            child: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(16, 0, 16, 0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    actionLabel,
                                                    style: FlutterFlowTheme.of(
                                                            context)
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
                                            final studentTrackUpdate =
                                                createUsersRecordData(
                                              role: UserRole.student,
                                            );
                                            studentTrackUpdate[
                                                    'availabilityToday'] =
                                                FieldValue.delete();
                                            await currentUserReference!
                                                .update(studentTrackUpdate);
                                            safeSetState(() {});
                                          },
                                          child: Container(
                                            height: 45,
                                            decoration: BoxDecoration(),
                                            child: Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(16, 0, 16, 0),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.max,
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    FFLocalizations.of(context)
                                                        .getText(
                                                      'dmupsasg' /* Стать учеником */,
                                                    ),
                                                    style: FlutterFlowTheme.of(
                                                            context)
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
                                                    color: FlutterFlowTheme.of(
                                                            context)
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
                                    color: ExpatlioDesign.border,
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
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'u9y8laa9' /* Как вам приложение? */,
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
                                    color: ExpatlioDesign.border,
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
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: LangAppWidget(),
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
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                '0yjewgwu' /* Язык приложения */,
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
                                    color: ExpatlioDesign.border,
                                  ),
                                  InkWell(
                                    splashColor: Colors.transparent,
                                    focusColor: Colors.transparent,
                                    hoverColor: Colors.transparent,
                                    highlightColor: Colors.transparent,
                                    onTap: () async {
                                      context
                                          .pushNamed(BlackListWidget.routeName);
                                    },
                                    child: Container(
                                      height: 50,
                                      decoration: BoxDecoration(),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'uo96qs94' /* Черный список */,
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
                                    color: ExpatlioDesign.border,
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
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: ReportWidget(),
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
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                '7benyvw2' /* Служба поддержки */,
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
                                    color: ExpatlioDesign.border,
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
                                          return GestureDetector(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              FocusManager.instance.primaryFocus
                                                  ?.unfocus();
                                            },
                                            child: Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: LogoutWidget(),
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
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.max,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              FFLocalizations.of(context)
                                                  .getText(
                                                'ss5m5bt2' /* Выйти */,
                                              ),
                                              style: FlutterFlowTheme.of(
                                                      context)
                                                  .bodyMedium
                                                  .override(
                                                    fontFamily:
                                                        'sf pro display',
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .error,
                                                    fontSize: 15,
                                                    letterSpacing: 0.0,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                            ),
                                            Icon(
                                              FFIcons.kchevronRight,
                                              color:
                                                  FlutterFlowTheme.of(context)
                                                      .error,
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
                            padding: EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space20,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.circular(
                                    ExpatlioDesign.radiusExtraLarge),
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
                                          padding:
                                              EdgeInsetsDirectional.fromSTEB(
                                                  ExpatlioDesign.space16,
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space0,
                                                  ExpatlioDesign.space0),
                                          child: Text(
                                            FFLocalizations.of(context).getText(
                                              'g1hqddj1' /* Политика конфиденциальности */,
                                            ),
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
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    height: 1,
                                    thickness: 1,
                                    indent: 16,
                                    endIndent: 16,
                                    color: ExpatlioDesign.border,
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
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0),
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
                                              style:
                                                  FlutterFlowTheme.of(context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        color:
                                                            FlutterFlowTheme.of(
                                                                    context)
                                                                .secondaryText,
                                                        fontSize: 15,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
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
                                    color: ExpatlioDesign.border,
                                  ),
                                  Container(
                                    height: 50,
                                    decoration: BoxDecoration(),
                                    child: Align(
                                      alignment: AlignmentDirectional(-1, 0),
                                      child: Padding(
                                        padding: EdgeInsetsDirectional.fromSTEB(
                                            ExpatlioDesign.space16,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space0,
                                            ExpatlioDesign.space0),
                                        child: Text(
                                          FFLocalizations.of(context).getText(
                                            'l1x4xu81' /* © 2025 Expatlio. Версия 1.0.0 */,
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
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ]
                            .divide(SizedBox(height: ExpatlioDesign.space8))
                            .addToStart(
                                SizedBox(height: ExpatlioDesign.space56))
                            .addToEnd(SizedBox(height: ExpatlioDesign.space96)),
                      ),
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

class _ProfileMenuOption<T> {
  const _ProfileMenuOption({
    required this.value,
    required this.label,
    this.selected = false,
  });

  final T value;
  final String label;
  final bool selected;
}
