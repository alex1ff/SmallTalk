import '/components/button/button_widget.dart';
import '/components/onboarding_card.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
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
        backgroundColor: ExpatlioDesign.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.pagePadding,
              ExpatlioDesign.compactSpacing,
              ExpatlioDesign.pagePadding,
              ExpatlioDesign.pagePaddingLarge,
            ),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 64.0,
                  decoration: ExpatlioDesign.cardDecoration(
                    radius: ExpatlioDesign.cardRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(4.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          width: 56.0,
                          height: 56.0,
                          decoration: BoxDecoration(
                            color:
                                ExpatlioDesign.primary.withValues(alpha: 0.10),
                            shape: BoxShape.circle,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional(0, 0),
                            child: Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                9.0,
                                7.0,
                                9.0,
                                3.0,
                              ),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.contain,
                                alignment: Alignment(0, -0.2),
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
                                    12, 0, 12, 0),
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
                                        fontSize: 15.0,
                                        letterSpacing: 0.0,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ),
                              Container(
                                width: 56.0,
                                height: 56.0,
                                decoration: BoxDecoration(
                                  color: ExpatlioDesign.mutedSurface,
                                  shape: BoxShape.circle,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional(0, 0),
                                  child: Icon(
                                    Icons.close_rounded,
                                    color: FlutterFlowTheme.of(context)
                                        .primaryText,
                                    size: 20,
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
                const SizedBox(height: ExpatlioDesign.sectionSpacing),
                Expanded(
                  child: FlutterFlowSwipeableStack(
                    onSwipeFn: (swipeableStackIndex) async {
                      if (_model.index <= 2) {
                        _model.index = _model.index + 1;
                        safeSetState(() {});
                      } else {
                        await Future.delayed(
                          const Duration(milliseconds: 500),
                        );

                        context.pushNamed(LoginWidget.routeName);
                      }
                    },
                    onLeftSwipe: (swipeableStackIndex) {},
                    onRightSwipe: (swipeableStackIndex) {},
                    onUpSwipe: (swipeableStackIndex) {},
                    onDownSwipe: (swipeableStackIndex) {},
                    itemBuilder: (context, index) {
                      return [
                        () => OnboardingCard(
                              assetPath: 'assets/images/group_1171275328.webp',
                            ),
                        () => OnboardingCard(
                              assetPath: 'assets/images/frame_1321318905.webp',
                            ),
                        () => OnboardingCard(
                              assetPath: 'assets/images/frame_1321318906.webp',
                            ),
                      ][index]();
                    },
                    itemCount: 3,
                    controller: _model.swipeableStackController,
                    loop: false,
                    cardDisplayCount: 1,
                    scale: 1.0,
                    cardPadding: const EdgeInsetsDirectional.only(bottom: 20.0),
                    backCardOffset: Offset.zero,
                    allowedSwipeDirection:
                        AllowedSwipeDirection.symmetric(horizontal: true),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ButtonWidget(
                    text: FFLocalizations.of(context).getVariableText(
                      ruText: 'Далее',
                      enText: 'Next',
                    ),
                    action: () async {
                      if (_model.index <= 2) {
                        _model.swipeableStackController.swipeLeft();
                      } else {
                        context.pushNamed(LoginWidget.routeName);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
