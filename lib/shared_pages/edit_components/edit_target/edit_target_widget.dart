import '/auth/firebase_auth/auth_util.dart';
import '/authorization/components/chips/chips_widget.dart';
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
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
  }

  @override
  void dispose() {
    _model.maybeDispose();

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
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/m3l806hbtb67/%E2%9C%88%EF%B8%8F.png',
                                  text: 'Путешествия',
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
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/k5p0kovi04k6/%F0%9F%92%BC.png',
                                  text: 'Работа',
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
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/6g5od84p1tjg/%F0%9F%93%9A.png',
                                  text: 'Учеба',
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
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/ysodbdg787sg/%F0%9F%8E%AD.png',
                                  text: 'Культура',
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
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/inxg3bvrbq5u/%F0%9F%92%AC.png',
                                  text: 'Общение',
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
                                      'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/1nye1ugilrx4/%F0%9F%8E%AF.png',
                                  text: 'Другое',
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
                wrapWithModel(
                  model: _model.buttonModel,
                  updateCallback: () => safeSetState(() {}),
                  child: ButtonWidget(
                    text: 'Сохранить',
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
