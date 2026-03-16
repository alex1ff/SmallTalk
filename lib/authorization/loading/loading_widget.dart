import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
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

    return user?.hasAcquaintance() == true &&
        user?.acquaintance == true &&
        user?.hasDisplayName() == true &&
        user!.displayName.trim().isNotEmpty &&
        user.hasPhotoUrl() &&
        user.photoUrl.trim().isNotEmpty &&
        user.hasLearningLanguage();
  }

  Future<UsersRecord?> _resolveUserDocumentForRouting() async {
    final authUid = resolveAuthenticatedUserId();
    if (authUid == null) {
      _debugLoadingLog('auth uid unavailable during route resolution');
      return null;
    }
    _debugLoadingLog(
      'starting route resolution '
      'uid=$authUid '
      'firebase=${FirebaseAuth.instance.currentUser?.uid ?? 'null'} '
      'current=${currentUser?.uid ?? 'null'} '
      'cachedDoc=${hasCurrentUserDocumentForUid(authUid)}',
    );
    return waitForResolvedCurrentUserDocument(
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
        context.goNamed(
          AcquaintanceSTUDENTWidget.routeName,
          queryParameters: {
            'index': serializeParam(4, ParamType.int),
          }.withoutNulls,
        );
        return;
    }
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

      final userDocument = await _resolveUserDocumentForRouting();
      if (!mounted) {
        return;
      }

      final destination = resolveLoadingRouteDestination(
        role: userDocument?.role,
        acquaintance: userDocument?.hasAcquaintance() == true
            ? userDocument?.acquaintance
            : null,
        isProfileComplete: userDocument?.hasIsProfileComplete() == true
            ? userDocument?.isProfileComplete
            : null,
        hasInferredStudentProfileCompletion:
            _hasInferredStudentProfileCompletion(userDocument),
      );
      _debugLoadingLog(
        'resolved destination=${destination?.name ?? 'null'} '
        'rawRole=${userDocument?.snapshotData['role']} '
        'role=${userDocument?.role?.name ?? 'null'} '
        'acquaintance=${userDocument?.hasAcquaintance() == true ? userDocument?.acquaintance : 'null'} '
        'isProfileComplete=${userDocument?.hasIsProfileComplete() == true ? userDocument?.isProfileComplete : 'null'}',
      );

      if (destination == null) {
        safeSetState(() {
          _errorMessage = 'Не удалось загрузить профиль. Попробуйте ещё раз.';
        });
        return;
      }

      _navigateToResolvedDestination(destination);
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
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Align(
          alignment: AlignmentDirectional(0.0, 0.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100.0,
                height: 100.0,
                decoration: BoxDecoration(
                  color: const Color(0xFFE88CD4),
                  shape: BoxShape.circle,
                ),
                child: Align(
                  alignment: AlignmentDirectional(0.0, 0.0),
                  child: Padding(
                    padding:
                        EdgeInsetsDirectional.fromSTEB(10.0, 8.0, 10.0, 2.0),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      alignment: const Alignment(0.0, -0.2),
                    ),
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 20.0),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
            ],
          ),
        ),
      ),
    );
  }
}
