import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_swipeable_stack.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
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
      }
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _saveGender() async {
    final selectedGender = _model.genderISMALE ? Gender.male : Gender.female;
    if (currentUserDocument?.gender != selectedGender) {
      await currentUserReference!.update(createUsersRecordData(
        gender: selectedGender,
      ));
      await widget.action?.call(selectedGender);
    }
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: ExpatlioDesign.card,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BottomSheetHeader(
                title: FFLocalizations.of(context).getText(
                  '06nighy4' /* Как вы себя идентифицируете? */,
                ),
                onConfirm: _saveGender,
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
                                      FFLocalizations.of(context)
                                                  .languageCode ==
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
                                      FFLocalizations.of(context)
                                                  .languageCode ==
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
              const SizedBox(height: 35.0),
            ].divide(SizedBox(height: 16.0)),
          ),
        ),
      ],
    );
  }
}
