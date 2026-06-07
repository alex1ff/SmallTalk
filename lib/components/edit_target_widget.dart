import '/auth/firebase_auth/auth_util.dart';
import '/components/chips_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/custom_code/actions/index.dart' as actions;
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
      _model.purpose =
          (currentUserDocument?.purpose.toList() ?? []).toList().cast<String>();
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _saveTarget() async {
    if (_model.purpose.isEmpty) {
      await actions.showTopNotification(
        context,
        'Выберите минимум одну цель',
        '',
        true,
      );
      return;
    }
    await currentUserReference!.update({
      ...mapToFirestore(
        {
          'purpose': _model.purpose,
        },
      ),
    });
    await widget.action?.call(
      _model.purpose.length <= 1
          ? _model.purpose.firstOrNull!
          : '${_model.purpose.firstOrNull}, +${(_model.purpose.length - 1).toString()}',
    );
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space0,
          ExpatlioDesign.space0, ExpatlioDesign.space0, ExpatlioDesign.space0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9,
            ),
            decoration: ExpatlioDesign.sheetDecoration(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BottomSheetHeader(
                  title: FFLocalizations.of(context).getText(
                    '2sp7ybe9' /* Цели изучения языка */,
                  ),
                ),
                Padding(
                  padding: EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.space0),
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            ExpatlioDesign.space0,
                            ExpatlioDesign.space12,
                            ExpatlioDesign.space0,
                            ExpatlioDesign.space0),
                        child: Container(
                          height: 364.13,
                          decoration: BoxDecoration(),
                          child: GridView(
                            padding: EdgeInsets.zero,
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: ExpatlioDesign.space8,
                              mainAxisSpacing: ExpatlioDesign.space8,
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
                BottomSheetPrimaryButton(
                  text: FFLocalizations.of(context).getVariableText(
                    ruText: 'Сохранить',
                    enText: 'Save',
                  ),
                  onPressed: _saveTarget,
                ),
              ].divide(SizedBox(height: ExpatlioDesign.space16)),
            ),
          ),
        ],
      ),
    );
  }
}
