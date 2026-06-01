import '/auth/firebase_auth/auth_util.dart';
import '/authorization/acquaintance_s_t_u_d_e_n_t/student_onboarding_logic.dart';
import '/components/native_speaker_entry_toggle.dart';
import '/authorization/shared/social_auth_entry_logic.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/components/wrapper.dart';
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
  String? _errorMessage;
  bool _showRoleRecoveryChoice = false;
  bool _recoverySwitchValue = false;
  AuthenticatedUserProfileResolution? _latestProfileResolution;
  UsersRecord? _latestResolvedUserDocument;

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

  Future<AuthenticatedUserProfileResolution>
      _resolveUserProfileForRouting() async {
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
      refreshFromBackend: true,
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
        _errorMessage = 'Не удалось загрузить профиль. Попробуйте ещё раз.';
        _showRoleRecoveryChoice = false;
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
        _errorMessage = 'Не удалось загрузить профиль. Попробуйте ещё раз.';
        _showRoleRecoveryChoice = false;
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
        _errorMessage = 'Не удалось сохранить профиль. Попробуйте ещё раз.';
        _showRoleRecoveryChoice = false;
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
        _errorMessage = 'Не удалось загрузить профиль. Попробуйте ещё раз.';
        _showRoleRecoveryChoice = false;
      });
      return;
    }

    safeSetState(() {
      _latestResolvedUserDocument = updatedUser;
      _errorMessage = null;
      _showRoleRecoveryChoice = false;
    });
    _navigateToResolvedDestination(destination);
  }

  Future<void> _continueManualRoleRecovery() async {
    if (_isResolvingRoute) {
      return;
    }

    final resolution =
        _latestProfileResolution ?? await _resolveUserProfileForRouting();
    if (!mounted) {
      return;
    }

    final selectedRole =
        _recoverySwitchValue ? UserRole.native_speaker : UserRole.student;
    await _applyRoleRecoveryAndNavigate(
      resolution: resolution,
      role: selectedRole,
      grantStudentBonus: selectedRole == UserRole.student &&
          !(_latestResolvedUserDocument?.hasBalanceST() ?? false),
      recoverySource: UserRoleRecoverySource.manualRecovery,
    );
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

      _model.check = await actions.checkActiveSessionAndNavigate(context);
      if (_model.check == true || !mounted) {
        return;
      }

      final resolution = await _resolveUserProfileForRouting();
      final userDocument = resolution.userDocument;
      _latestProfileResolution = resolution;
      _latestResolvedUserDocument = userDocument;
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
          _showRoleRecoveryChoice = false;
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
        case LoadingRecoveryAction.showManualRoleChoice:
          safeSetState(() {
            _showRoleRecoveryChoice = true;
            _recoverySwitchValue = recoveryDecision.suggestedNativeSpeakerValue;
            _errorMessage = null;
          });
          return;
        case LoadingRecoveryAction.fatalError:
          safeSetState(() {
            _showRoleRecoveryChoice = false;
            _errorMessage = recoveryDecision.errorMessage ??
                'Не удалось загрузить профиль. Попробуйте ещё раз.';
          });
          return;
      }
    } finally {
      _isResolvingRoute = false;
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
              ],
              if (_showRoleRecoveryChoice) ...[
                const SizedBox(height: ExpatlioDesign.space20),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ExpatlioDesign.space20),
                  child: Text(
                    'Мы нашли аккаунт, но не смогли определить тип профиля. Выберите, как продолжить вход.',
                    textAlign: TextAlign.center,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          color: FlutterFlowTheme.of(context).secondaryText,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
                const SizedBox(height: ExpatlioDesign.space12),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: ExpatlioDesign.space20),
                  child: NativeSpeakerEntryToggle(
                    value: _recoverySwitchValue,
                    onChanged: (newValue) {
                      safeSetState(() => _recoverySwitchValue = newValue);
                    },
                  ),
                ),
                Wrapper(
                  padding: const EdgeInsets.fromLTRB(
                      ExpatlioDesign.space20,
                      ExpatlioDesign.space12,
                      ExpatlioDesign.space20,
                      ExpatlioDesign.space0),
                  child: ButtonWidget(
                    text: 'Продолжить',
                    loadingText: 'Сохраняем...',
                    busyStyle: ButtonBusyStyle.spinner,
                    action: _continueManualRoleRecovery,
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
