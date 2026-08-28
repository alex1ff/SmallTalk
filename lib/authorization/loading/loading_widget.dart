import '/auth/firebase_auth/auth_util.dart';
import '/authorization/acquaintance_s_t_u_d_e_n_t/student_onboarding_logic.dart';
import '/authorization/shared/social_auth_entry_logic.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import '/services/user_match_profile.dart';
import '/services/voip_service.dart';
import 'loading_route_logic.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/foundation.dart';
import 'loading_model.dart';
export 'loading_model.dart';

class LoadingWidget extends StatefulWidget {
  const LoadingWidget({super.key});

  static String routeName = 'Loading';
  static String routePath = '/loading';

  @override
  State<LoadingWidget> createState() => _LoadingWidgetState();
}

class _LoadingWidgetState extends State<LoadingWidget> {
  late LoadingModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isResolvingRoute = false;
  bool _isSigningOut = false;
  String? _errorMessage;

  String _localized(String ru, String en) =>
      FFLocalizations.of(context).getVariableText(ruText: ru, enText: en);

  String _profileLoadError() => _localized(
        'Не удалось загрузить профиль. Попробуйте ещё раз.',
        'Could not load your profile. Please try again.',
      );

  String _recoveryFailureMessage(LoadingRecoveryFailure? failure) {
    switch (failure) {
      case LoadingRecoveryFailure.duplicateProfiles:
        return _localized(
          'Найдено несколько профилей для этого аккаунта. Попробуйте ещё раз позже.',
          'Multiple profiles were found for this account. Please try again later.',
        );
      case LoadingRecoveryFailure.ambiguousProfile:
        return _localized(
          'Не удалось определить тип профиля. Обратитесь в поддержку.',
          'Could not determine the profile type. Please contact support.',
        );
      case LoadingRecoveryFailure.profileUnavailable:
      case null:
        return _profileLoadError();
    }
  }

  bool _hasPendingVoipNavigationSafe() {
    try {
      return VoIPService().hasPendingNavigation();
    } catch (error) {
      debugPrint(
          '⚠️ LoadingWidget: VoIP pending navigation check skipped: $error');
      return false;
    }
  }

  void _debugLoadingLog(String message) {
    if (!kDebugMode) {
      return;
    }
    debugPrint('⏳ LoadingWidget: $message');
  }

  bool _hasInferredStudentProfileCompletion(UsersRecord? user) {
    if (user?.role != UserRole.student) {
      return false;
    }

    return hasCompletedStudentOnboardingContract(
      acquaintance:
          user?.hasAcquaintance() == true && user?.acquaintance == true,
      displayName: user?.hasDisplayName() == true ? user?.displayName : null,
      gender: user?.hasGender() == true ? user?.gender : null,
      level: user?.hasLevel() == true ? user?.level : null,
      learningLanguage:
          user?.hasLearningLanguage() == true ? user?.learningLanguage : null,
      country: user?.hasCountryNS() == true ? user?.countryNS : null,
    );
  }

  LoadingRouteDestination? _resolveDestinationForUser(
      UsersRecord? userDocument) {
    return resolveLoadingRouteDestination(
      role: userDocument?.role,
      acquaintance: userDocument?.hasAcquaintance() == true
          ? userDocument?.acquaintance
          : null,
      isProfileComplete: userDocument?.hasIsProfileComplete() == true
          ? userDocument?.isProfileComplete
          : null,
      hasInferredStudentProfileCompletion:
          _hasInferredStudentProfileCompletion(userDocument),
      canUseNativeSpeakerShell: canUseNativeSpeakerShell(userDocument),
    );
  }

  Future<AuthenticatedUserProfileResolution> _resolveUserProfileForRouting(
      {bool refreshFromBackend = true}) async {
    final authUid = resolveAuthenticatedUserId();
    if (authUid == null) {
      _debugLoadingLog('auth uid unavailable during route resolution');
      return const AuthenticatedUserProfileResolution(
        status: AuthenticatedUserProfileResolutionStatus.missingAuthUid,
        uidResolution: AuthenticatedUserIdResolution(
          uid: null,
          source: AuthenticatedUserIdSource.unavailable,
        ),
        canonicalUserRef: null,
      );
    }
    _debugLoadingLog(
      'starting route resolution '
      'uid=$authUid '
      'firebase=${FirebaseAuth.instance.currentUser?.uid ?? 'null'} '
      'current=${currentUser?.uid ?? 'null'} '
      'cachedDoc=${hasCurrentUserDocumentForUid(authUid)}',
    );
    return resolveAuthenticatedUserProfile(
      preferredUid: authUid,
      refreshFromBackend: refreshFromBackend,
      onDebugLog: _debugLoadingLog,
    );
  }

  void _navigateToResolvedDestination(LoadingRouteDestination destination) {
    switch (destination) {
      case LoadingRouteDestination.dashboardNativeSpeaker:
        context.goNamed(DashboardNSWidget.routeName);
        return;
      case LoadingRouteDestination.acquaintanceNativeSpeaker:
        context.goNamed(
          AcquaintanceNSWidget.routeName,
          queryParameters: {
            'index': serializeParam(0, ParamType.int),
          }.withoutNulls,
          extra: <String, dynamic>{
            kTransitionInfoKey: const TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.fade,
              duration: Duration(milliseconds: 0),
            ),
          },
        );
        return;
      case LoadingRouteDestination.studentsDashboard:
        context.goNamed(StudentsDashboardWidget.routeName);
        return;
      case LoadingRouteDestination.acquaintanceStudentStart:
        context.goNamed(
          AcquaintanceSTUDENTWidget.routeName,
          queryParameters: {
            'index': serializeParam(0, ParamType.int),
          }.withoutNulls,
          extra: <String, dynamic>{
            kTransitionInfoKey: const TransitionInfo(
              hasTransition: true,
              transitionType: PageTransitionType.fade,
              duration: Duration(milliseconds: 0),
            ),
          },
        );
        return;
      case LoadingRouteDestination.acquaintanceStudentResume:
        // The student flow is now compact and editable, so resume reopens the
        // first step instead of relying on legacy raw step indexes.
        context.goNamed(
          AcquaintanceSTUDENTWidget.routeName,
          queryParameters: {
            'index': serializeParam(0, ParamType.int),
          }.withoutNulls,
        );
        return;
    }
  }

  Future<void> _applyRoleRecoveryAndNavigate({
    required AuthenticatedUserProfileResolution resolution,
    required UserRole role,
    required bool grantStudentBonus,
    required UserRoleRecoverySource recoverySource,
  }) async {
    final userRef = resolution.canonicalUserRef;
    if (userRef == null) {
      safeSetState(() {
        _errorMessage = _profileLoadError();
      });
      return;
    }

    final baseUser = resolution.userDocument ??
        await ensureCanonicalCurrentUserDocument(
          preferredUid: resolution.uid,
          canonicalUserRef: userRef,
          onDebugLog: _debugLoadingLog,
        );
    if (!mounted || baseUser == null) {
      safeSetState(() {
        _errorMessage = _profileLoadError();
      });
      return;
    }

    final updatedUser = await persistCanonicalUserRole(
      userRef: userRef,
      role: role,
      recoverySource: recoverySource,
      authUserUid: resolution.uid ?? userRef.id,
      existingUser: baseUser,
      grantStudentBonus: grantStudentBonus,
      onDebugLog: _debugLoadingLog,
    );
    if (!mounted || updatedUser == null) {
      safeSetState(() {
        _errorMessage = _localized(
          'Не удалось сохранить профиль. Попробуйте ещё раз.',
          'Could not save your profile. Please try again.',
        );
      });
      return;
    }

    final destination = _resolveDestinationForUser(updatedUser);
    _debugLoadingLog(
      'role recovery completed '
      'uid=${userRef.id} '
      'role=${updatedUser.role?.name ?? role.name} '
      'recoverySource=${recoverySource.name} '
      'destination=${destination?.name ?? 'null'}',
    );

    if (destination == null) {
      safeSetState(() {
        _errorMessage = _profileLoadError();
      });
      return;
    }

    safeSetState(() {
      _errorMessage = null;
    });
    _navigateToResolvedDestination(destination);
  }

  Future<void> _resolveAndNavigate() async {
    if (_isResolvingRoute) {
      return;
    }
    _isResolvingRoute = true;
    try {
      if (_hasPendingVoipNavigationSafe()) {
        debugPrint('⚡ LoadingWidget: VoIP call pending, skipping delay');
        return;
      }

      UsersRecord? activeSessionUserDocument;
      _model.check = await actions.checkActiveSessionAndNavigate(
        context,
        onUserDocumentRead: (userDocument) {
          activeSessionUserDocument = userDocument;
          currentUserDocument = userDocument;
        },
      );
      if (_model.check == true || !mounted) {
        return;
      }

      final resolution = await _resolveUserProfileForRouting(
        refreshFromBackend: activeSessionUserDocument == null,
      );
      final userDocument = resolution.userDocument;
      if (!mounted) {
        return;
      }

      final destination = _resolveDestinationForUser(userDocument);
      _debugLoadingLog(
        'resolved destination=${destination?.name ?? 'null'} '
        'resolutionStatus=${resolution.status.name} '
        'uidSource=${resolution.uidResolution.source.name} '
        'legacyMatchCount=${resolution.legacyMatchCount} '
        'rawRole=${userDocument?.snapshotData['role']} '
        'role=${userDocument?.role?.name ?? 'null'} '
        'acquaintance=${userDocument?.hasAcquaintance() == true ? userDocument?.acquaintance : 'null'} '
        'isProfileComplete=${userDocument?.hasIsProfileComplete() == true ? userDocument?.isProfileComplete : 'null'}',
      );

      if (destination != null) {
        safeSetState(() {
          _errorMessage = null;
        });
        _navigateToResolvedDestination(destination);
        return;
      }

      final pendingContext = getValidPendingSocialAuthContext(
        currentAuthUid: resolution.uid,
      );
      final recoveryDecision = resolveLoadingRecoveryDecision(
        resolution: resolution,
        userDocument: userDocument,
        pendingContext: pendingContext,
      );
      _debugLoadingLog(
        'recovery action=${recoveryDecision.action.name} '
        'pendingContext=${pendingContext != null} '
        'recoverySource=${recoveryDecision.recoverySource?.name ?? 'null'} '
        'roleToAssign=${recoveryDecision.roleToAssign?.name ?? 'null'} '
        'grantStudentBonus=${recoveryDecision.grantStudentBonus}',
      );

      switch (recoveryDecision.action) {
        case LoadingRecoveryAction.assignRole:
          await _applyRoleRecoveryAndNavigate(
            resolution: resolution,
            role: recoveryDecision.roleToAssign!,
            grantStudentBonus: recoveryDecision.grantStudentBonus,
            recoverySource: recoveryDecision.recoverySource!,
          );
          return;
        case LoadingRecoveryAction.fatalError:
          safeSetState(() {
            _errorMessage = _recoveryFailureMessage(recoveryDecision.failure);
          });
          return;
      }
    } finally {
      if (mounted) {
        safeSetState(() {
          _isResolvingRoute = false;
        });
      } else {
        _isResolvingRoute = false;
      }
    }
  }

  Future<void> _retryResolution() async {
    if (_isResolvingRoute || _isSigningOut) {
      return;
    }
    safeSetState(() {
      _errorMessage = null;
    });
    await _resolveAndNavigate();
  }

  Future<void> _signOutAndReturnToLogin() async {
    if (_isSigningOut) {
      return;
    }
    safeSetState(() {
      _isSigningOut = true;
    });
    try {
      GoRouter.of(context).prepareAuthEvent();
      clearPendingSocialAuthContext();
      unawaited(
        VoIPService()
            .deinitialize()
            .timeout(const Duration(seconds: 2))
            .catchError((Object error, StackTrace stackTrace) {
          debugPrint(
            '⚠️ LoadingWidget: VoIP cleanup before sign-out failed: '
            '$error\n$stackTrace',
          );
        }),
      );
      await authManager.signOut();
      GoRouter.of(context).clearRedirectLocation();
      if (mounted) {
        context.goNamedAuth(LoginWidget.routeName, context.mounted);
      }
    } finally {
      if (mounted) {
        safeSetState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoadingModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      await _resolveAndNavigate();
    });
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
        backgroundColor: ExpatlioDesign.background,
        body: Align(
          alignment: AlignmentDirectional(0.0, 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 120.0,
                height: 64.0,
                child: Image.asset(
                  'assets/images/logo.png',
                  cacheWidth: 984,
                  fit: BoxFit.contain,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: ExpatlioDesign.space20),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ExpatlioDesign.space32),
                  child: Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space20),
                FilledButton(
                  onPressed: _isResolvingRoute || _isSigningOut
                      ? null
                      : _retryResolution,
                  child: Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'Повторить',
                      enText: 'Try again',
                    ),
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space8),
                TextButton(
                  onPressed: _isSigningOut ? null : _signOutAndReturnToLogin,
                  child: Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'Выйти из аккаунта',
                      enText: 'Sign out',
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
