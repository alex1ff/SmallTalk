import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'edit_gendeer_model.dart';
export 'edit_gendeer_model.dart';

class EditGendeerWidget extends StatefulWidget {
  const EditGendeerWidget({
    super.key,
    required this.action,
  });

  final Future Function(Gender gender)? action;

  @override
  State<EditGendeerWidget> createState() => _EditGendeerWidgetState();
}

class _EditGendeerWidgetState extends State<EditGendeerWidget> {
  late EditGendeerModel _model;

  late StreamSubscription<bool> _keyboardVisibilitySubscription;
  bool _isKeyboardVisible = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditGendeerModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      if (currentUserDocument?.gender != Gender.male) {
        _model.swipeableStackController.swipeLeft();
        _model.genderISMALE = !_model.genderISMALE;
        safeSetState(() {});
        _model.genderISMALE = !_model.genderISMALE;
        safeSetState(() {});
      }
    });

    if (!isWeb) {
      _keyboardVisibilitySubscription =
          KeyboardVisibilityController().onChange.listen((bool visible) {
        safeSetState(() {
          _isKeyboardVisible = visible;
        });
      });
    }
  }

  @override
  void dispose() {
    _model.maybeDispose();

    if (!isWeb) {
      _keyboardVisibilitySubscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          height: 16.0,
          child: custom_widgets.NotchedClipper(
            width: double.infinity,
            height: 16.0,
          ),
        ),
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
                FFLocalizations.of(context).getText(
                  '06nighy4' /* Как вы себя идентифицируете? */,
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Cool',
                      fontSize: 26.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                    ),
              ),
              Flexible(
                child: Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 16.0),
                  child: Container(
                    height: 350.0,
                    decoration: BoxDecoration(),
                    child: FlutterFlowSwipeableStack(
                      onSwipeFn: (index) async {
                        _model.genderISMALE = !_model.genderISMALE;
                        safeSetState(() {});
                      },
                      onLeftSwipe: (index) {},
                      onRightSwipe: (index) {},
                      onUpSwipe: (index) {},
                      onDownSwipe: (index) {},
                      itemBuilder: (context, index) {
                        return [
                          () => Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Transform.rotate(
                                  angle: 15.0 * (math.pi / 180),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20.0),
                                    child: Image.asset(
                                      FFLocalizations.of(context).languageCode ==
                                              'ru'
                                          ? 'assets/images/group_11712753102.webp'
                                          : 'assets/images/group_1171275311.webp',
                                      width: 228.0,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                          () => Align(
                                alignment: AlignmentDirectional(0.0, 0.0),
                                child: Transform.rotate(
                                  angle: 350.0 * (math.pi / 180),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20.0),
                                    child: Image.asset(
                                      FFLocalizations.of(context).languageCode ==
                                              'ru'
                                          ? 'assets/images/33_2.webp'
                                          : 'assets/images/33_.webp',
                                      width: 228.0,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                        ][index]();
                      },
                      itemCount: 2,
                      controller: _model.swipeableStackController,
                      loop: true,
                      cardDisplayCount: 2,
                      scale: 0.9,
                      backCardOffset: const Offset(100.0, 0.0),
                      allowedSwipeDirection:
                          AllowedSwipeDirection.symmetric(horizontal: true),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 6.0, 0.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: wrapWithModel(
                        model: _model.buttonModel,
                        updateCallback: () => safeSetState(() {}),
                        child: ButtonWidget(
                          text: FFLocalizations.of(context).getText(
                            'snk4d2km' /* Сохранить */,
                          ),
                          action: () async {
                            if (!(_model.genderISMALE &&
                                (currentUserDocument?.gender == Gender.male))) {
                              unawaited(
                                () async {
                                  await currentUserReference!
                                      .update(createUsersRecordData(
                                    gender: _model.genderISMALE
                                        ? Gender.male
                                        : Gender.female,
                                  ));
                                }(),
                              );
                              await widget.action?.call(
                                _model.genderISMALE
                                    ? Gender.male
                                    : Gender.female,
                              );
                            }
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          0.0,
                          0.0,
                          0.0,
                          valueOrDefault<double>(
                            (isWeb
                                    ? MediaQuery.viewInsetsOf(context).bottom >
                                        0
                                    : _isKeyboardVisible)
                                ? 6.0
                                : 35.0,
                            6.0,
                          )),
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              blurRadius: 7.0,
                              color: Color(0x0D2C2C2C),
                              offset: Offset(
                                0.0,
                                2.0,
                              ),
                            )
                          ],
                          shape: BoxShape.circle,
                        ),
                        child: FlutterFlowIconButton(
                          borderRadius: 50.0,
                          buttonSize: 60.0,
                          fillColor:
                              FlutterFlowTheme.of(context).primaryBackground,
                          icon: Icon(
                            Icons.close_sharp,
                            color: FlutterFlowTheme.of(context).error,
                            size: 20.0,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ].divide(SizedBox(height: 16.0)).addToStart(SizedBox(height: 16.0)),
          ),
        ),
      ],
    );
  }
}
