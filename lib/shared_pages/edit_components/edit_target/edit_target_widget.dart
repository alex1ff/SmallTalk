import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/chips/chips_widget.dart';
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart';
import 'edit_target_model.dart';
export 'edit_target_model.dart';

class EditTargetWidget extends StatefulWidget {
  const EditTargetWidget({
    super.key,
    required this.action,
  });

  final Future Function(String targ)? action;

  @override
  State<EditTargetWidget> createState() => _EditTargetWidgetState();
}

class _EditTargetWidgetState extends State<EditTargetWidget> {
  late EditTargetModel _model;

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
    _model = createModel(context, () => EditTargetModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.purpose = (currentUserDocument?.purpose.toList() ?? [])
          .toList()
          .cast<String>();
      safeSetState(() {});
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
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 55.0, 0.0, 0.0),
      child: Column(
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
                    '2sp7ybe9' /* Цели изучения языка */,
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'Cool',
                        fontSize: 26.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.normal,
                      ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(0.0, 10.0, 0.0, 0.0),
                        child: Container(
                          height: 364.13,
                          decoration: BoxDecoration(),
                          child: GridView(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 6.0,
                              mainAxisSpacing: 6.0,
                              childAspectRatio: 0.8,
                            ),
                            scrollDirection: Axis.vertical,
                            children: [
                              wrapWithModel(
                                model: _model.chipsModel1,
                                updateCallback: () => safeSetState(() {}),
                                child: ChipsWidget(
                                  icon:
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/5tvth2denlpx/%E2%9C%88%EF%B8%8F.png',
                                  text: FFLocalizations.of(context).getText(
                                    'ttv2n2du' /* Путешествия */,
                                  ),
                                  selected:
                                      _model.purpose.contains('Путешествия'),
                                  actionadd: (select) async {
                                    _model.addToPurpose(select);
                                    safeSetState(() {});
                                  },
                                  actiondeelete: (select) async {
                                    _model.removeFromPurpose(select);
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                              wrapWithModel(
                                model: _model.chipsModel2,
                                updateCallback: () => safeSetState(() {}),
                                child: ChipsWidget(
                                  icon:
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/lerjql614l6t/%F0%9F%92%BC.png',
                                  text: FFLocalizations.of(context).getText(
                                    'id571obg' /* Работа */,
                                  ),
                                  selected: _model.purpose.contains('Работа'),
                                  actionadd: (select) async {
                                    _model.addToPurpose(select);
                                    safeSetState(() {});
                                  },
                                  actiondeelete: (select) async {
                                    _model.removeFromPurpose(select);
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                              wrapWithModel(
                                model: _model.chipsModel3,
                                updateCallback: () => safeSetState(() {}),
                                child: ChipsWidget(
                                  icon:
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/aacr3gooehck/%F0%9F%93%9A.png',
                                  text: FFLocalizations.of(context).getText(
                                    'wc6ds33w' /* Учеба */,
                                  ),
                                  selected: _model.purpose.contains('Учеба'),
                                  actionadd: (select) async {
                                    _model.addToPurpose(select);
                                    safeSetState(() {});
                                  },
                                  actiondeelete: (select) async {
                                    _model.removeFromPurpose(select);
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                              wrapWithModel(
                                model: _model.chipsModel4,
                                updateCallback: () => safeSetState(() {}),
                                child: ChipsWidget(
                                  icon:
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/zn3jlcka2lbc/%F0%9F%92%A1.png',
                                  text: FFLocalizations.of(context).getText(
                                    '4zdz2z83' /* Культура */,
                                  ),
                                  selected: _model.purpose.contains('Культура'),
                                  actionadd: (select) async {
                                    _model.addToPurpose(select);
                                    safeSetState(() {});
                                  },
                                  actiondeelete: (select) async {
                                    _model.removeFromPurpose(select);
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                              wrapWithModel(
                                model: _model.chipsModel5,
                                updateCallback: () => safeSetState(() {}),
                                child: ChipsWidget(
                                  icon:
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/odie4pcem3fn/%F0%9F%92%AC.png',
                                  text: FFLocalizations.of(context).getText(
                                    'iu8bnfx7' /* Общение */,
                                  ),
                                  selected: _model.purpose.contains('Общение'),
                                  actionadd: (select) async {
                                    _model.addToPurpose(select);
                                    safeSetState(() {});
                                  },
                                  actiondeelete: (select) async {
                                    _model.removeFromPurpose(select);
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                              wrapWithModel(
                                model: _model.chipsModel6,
                                updateCallback: () => safeSetState(() {}),
                                child: ChipsWidget(
                                  icon:
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/68cdtneygm0v/%F0%9F%9A%80.png',
                                  text: FFLocalizations.of(context).getText(
                                    'cc6sb20q' /* Другое */,
                                  ),
                                  selected: _model.purpose.contains('Другое'),
                                  actionadd: (select) async {
                                    _model.addToPurpose(select);
                                    safeSetState(() {});
                                  },
                                  actiondeelete: (select) async {
                                    _model.removeFromPurpose(select);
                                    safeSetState(() {});
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
                              '6k2h1hbt' /* Сохранить */,
                            ),
                            action: () async {
                              if (_model.purpose.isNotEmpty) {
                                unawaited(
                                  () async {
                                    await currentUserReference!.update({
                                      ...mapToFirestore(
                                        {
                                          'purpose': _model.purpose,
                                        },
                                      ),
                                    });
                                  }(),
                                );
                                await widget.action?.call(
                                  _model.purpose.length <= 1
                                      ? _model.purpose.firstOrNull!
                                      : '${_model.purpose.firstOrNull}, +${(_model.purpose.length - 1).toString()}',
                                );
                              } else {
                                await actions.showTopNotification(
                                  context,
                                  'Выберите минимум одну цель',
                                  '',
                                  true,
                                );
                                return;
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
                                      ? MediaQuery.viewInsetsOf(context)
                                              .bottom >
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
              ]
                  .divide(SizedBox(height: 16.0))
                  .addToStart(SizedBox(height: 16.0)),
            ),
          ),
        ],
      ),
    );
  }
}
