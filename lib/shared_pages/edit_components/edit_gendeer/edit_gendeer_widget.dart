import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
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
  }

  @override
  void dispose() {
    _model.maybeDispose();

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
                                      'assets/images/dzwds_4.jpg',
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
                                      'assets/images/33.jpg',
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
              wrapWithModel(
                model: _model.buttonModel,
                updateCallback: () => safeSetState(() {}),
                child: ButtonWidget(
                  text: 'Сохранить',
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
                        _model.genderISMALE ? Gender.male : Gender.female,
                      );
                    }
                    Navigator.pop(context);
                  },
                ),
              ),
            ].divide(SizedBox(height: 16.0)).addToStart(SizedBox(height: 16.0)),
          ),
        ),
      ],
    );
  }
}
