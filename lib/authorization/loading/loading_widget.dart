import '/auth/firebase_auth/auth_util.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/actions/index.dart' as actions;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => LoadingModel());

    // On page load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.check = await actions.checkActiveSessionAndNavigate(
        context,
      );
      if (_model.check == true) {
        return;
      }

      await Future.delayed(
        Duration(
          milliseconds: 1000,
        ),
      );
      if (currentUserDocument?.role == UserRole.native_speaker) {
        if (valueOrDefault<bool>(currentUserDocument?.acquaintance, false)) {
          context.goNamed(
            DashboardNSWidget.routeName,
          );
        } else {
          context.goNamed(
            AcquaintanceNSWidget.routeName,
            queryParameters: {
              'index': serializeParam(
                0,
                ParamType.int,
              ),
            }.withoutNulls,
            extra: <String, dynamic>{
              kTransitionInfoKey: TransitionInfo(
                hasTransition: true,
                transitionType: PageTransitionType.fade,
                duration: Duration(milliseconds: 0),
              ),
            },
          );
        }
      } else {
        if (valueOrDefault<bool>(currentUserDocument?.acquaintance, false)) {
          if (valueOrDefault<bool>(
              currentUserDocument?.isProfileComplete, false)) {
            context.goNamed(
              StudentsDashboardWidget.routeName,
            );
          } else {
            context.pushNamed(
              AcquaintanceSTUDENTWidget.routeName,
              queryParameters: {
                'index': serializeParam(
                  4,
                  ParamType.int,
                ),
              }.withoutNulls,
            );
          }
        } else {
          context.goNamed(
            AcquaintanceSTUDENTWidget.routeName,
            queryParameters: {
              'index': serializeParam(
                0,
                ParamType.int,
              ),
            }.withoutNulls,
            extra: <String, dynamic>{
              kTransitionInfoKey: TransitionInfo(
                hasTransition: true,
                transitionType: PageTransitionType.fade,
                duration: Duration(milliseconds: 0),
              ),
            },
          );
        }
      }
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
          child: Container(
            width: 100.0,
            height: 100.0,
            decoration: BoxDecoration(
              color: Color(0xFFE88CD4),
              shape: BoxShape.circle,
            ),
            child: Align(
              alignment: AlignmentDirectional(0.0, 0.0),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(10.0, 8.0, 10.0, 2.0),
                child: Image.asset(
                  'assets/images/logo.png',
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  alignment: Alignment(0.0, -0.2),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
