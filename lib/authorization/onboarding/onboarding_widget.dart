import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'onboarding_model.dart';
export 'onboarding_model.dart';

class OnboardingWidget extends StatefulWidget {
  const OnboardingWidget({super.key});

  static String routeName = 'Onboarding';
  static String routePath = '/onboarding';

  @override
  State<OnboardingWidget> createState() => _OnboardingWidgetState();
}

class _OnboardingWidgetState extends State<OnboardingWidget> {
  late OnboardingModel _model;

  final scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OnboardingModel());
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
        body: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(6.0, 55.0, 6.0, 35.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                height: 70.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(100.0),
                ),
                child: Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 66.0,
                        height: 66.0,
                        decoration: BoxDecoration(
                          color: Color(0xFFE88CD4),
                          shape: BoxShape.circle,
                        ),
                        child: Align(
                          alignment: AlignmentDirectional(0.0, 0.0),
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                10.0, 8.0, 10.0, 2.0),
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
                      InkWell(
                        splashColor: Colors.transparent,
                        focusColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        onTap: () async {
                          context.pushNamed(LoginWidget.routeName);
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Padding(
                              padding: EdgeInsetsDirectional.fromSTEB(
                                  12.0, 0.0, 12.0, 0.0),
                              child: Text(
                                FFLocalizations.of(context).getText(
                                  'on7eoqhl' /* Пропустить */,
                                ),
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                            Container(
                              width: 66.0,
                              height: 66.0,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .secondaryBackground,
                                shape: BoxShape.circle,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Icon(
                                  Icons.close_rounded,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 20.0,
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
              Expanded(
                child: FlutterFlowSwipeableStack(
                  onSwipeFn: (index) async {
                    if (_model.index <= 2) {
                      _model.index = _model.index + 1;
                      safeSetState(() {});
                    } else {
                      await Future.delayed(
                        Duration(
                          milliseconds: 500,
                        ),
                      );

                      context.pushNamed(LoginWidget.routeName);
                    }
                  },
                  onLeftSwipe: (index) {},
                  onRightSwipe: (index) {},
                  onUpSwipe: (index) {},
                  onDownSwipe: (index) {},
                  itemBuilder: (context, index) {
                    return [
                      () => Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: Image.asset(
                                  'assets/images/Frame_1321318904.jpg',
                                ).image,
                              ),
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                          ),
                      () => Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: Image.asset(
                                  'assets/images/Frame_1321318905.jpg',
                                ).image,
                              ),
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                          ),
                      () => Container(
                            width: double.infinity,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              image: DecorationImage(
                                fit: BoxFit.cover,
                                image: Image.asset(
                                  'assets/images/Frame_1321318906.jpg',
                                ).image,
                              ),
                              borderRadius: BorderRadius.circular(20.0),
                            ),
                          ),
                    ][index]();
                  },
                  itemCount: 3,
                  controller: _model.swipeableStackController,
                  loop: false,
                  cardDisplayCount: 3,
                  scale: 0.88,
                  cardPadding:
                      EdgeInsetsDirectional.fromSTEB(0.0, 5.0, 0.0, 50.0),
                  backCardOffset: const Offset(0.0, 45.0),
                  allowedSwipeDirection:
                      AllowedSwipeDirection.symmetric(horizontal: true),
                ),
              ),
              Container(
                height: 60.0,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(100.0),
                ),
                child: Padding(
                  padding: EdgeInsets.all(2.0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 56.0,
                        height: 56.0,
                        child: custom_widgets.ProggresBar(
                          width: 56.0,
                          height: 56.0,
                          currentStep: _model.index,
                          totalSteps: 3,
                        ),
                      ),
                      FlutterFlowIconButton(
                        borderRadius: 60.0,
                        buttonSize: 56.0,
                        fillColor:
                            FlutterFlowTheme.of(context).primaryBackground,
                        icon: Icon(
                          FFIcons.karrowRight,
                          color: FlutterFlowTheme.of(context).primaryText,
                          size: 24.0,
                        ),
                        onPressed: () async {
                          if (_model.index <= 2) {
                            _model.swipeableStackController.swipeLeft();
                          } else {
                            context.pushNamed(LoginWidget.routeName);
                          }
                        },
                      ),
                    ].divide(SizedBox(width: 2.0)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
