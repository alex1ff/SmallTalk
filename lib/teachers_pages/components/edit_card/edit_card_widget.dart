import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/teachers_pages/components/delete_card/delete_card_widget.dart';
import 'package:flutter/material.dart';
import 'edit_card_model.dart';
export 'edit_card_model.dart';

class EditCardWidget extends StatefulWidget {
  const EditCardWidget({super.key});

  @override
  State<EditCardWidget> createState() => _EditCardWidgetState();
}

class _EditCardWidgetState extends State<EditCardWidget> {
  late EditCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditCardModel());
    _model.cardsStream = queryCardsRecord(
      parent: currentUserReference,
    );
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
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration: BoxDecoration(
            color: ExpatlioDesign.background,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BottomSheetHeader(
                title: FFLocalizations.of(context).getText(
                  'o063iu8b' /* Изменение способов вывода */,
                ),
                onConfirm: () => Navigator.pop(context),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6.0, 6.0, 6.0, 6.0),
                child: StreamBuilder<List<CardsRecord>>(
                  stream: _model.cardsStream,
                  builder: (context, snapshot) {
                    List<CardsRecord> listViewCardsRecordList =
                        snapshot.data ?? [];

                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      itemCount: listViewCardsRecordList.length,
                      separatorBuilder: (_, __) => SizedBox(height: 6.0),
                      itemBuilder: (context, listViewIndex) {
                        final listViewCardsRecord =
                            listViewCardsRecordList[listViewIndex];
                        return Container(
                          width: double.infinity,
                          height: 60.0,
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(16.0),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(4.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  width: 52.0,
                                  height: 52.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(22.0),
                                  ),
                                  child: Align(
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    child: Icon(
                                      FFIcons.kcreditCardEdit,
                                      color: FlutterFlowTheme.of(context)
                                          .primaryText,
                                      size: 20.0,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.fromSTEB(
                                        12.0, 0.0, 8.0, 0.0),
                                    child: Text(
                                      listViewCardsRecord.pan,
                                      style: FlutterFlowTheme.of(context)
                                          .bodyMedium
                                          .override(
                                            fontFamily: 'sf pro display',
                                            fontSize: 16.0,
                                            letterSpacing: 0.0,
                                          ),
                                    ),
                                  ),
                                ),
                                FlutterFlowIconButton(
                                  borderRadius: 22.0,
                                  buttonSize: 52.0,
                                  icon: Icon(
                                    FFIcons.ktrash03,
                                    color: FlutterFlowTheme.of(context).error,
                                    size: 18.0,
                                  ),
                                  onPressed: () async {
                                    await showModalBottomSheet(
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      context: context,
                                      builder: (context) {
                                        return Padding(
                                          padding:
                                              MediaQuery.viewInsetsOf(context),
                                          child: DeleteCardWidget(
                                            doc: listViewCardsRecord,
                                          ),
                                        );
                                      },
                                    ).then((value) => safeSetState(() {}));
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
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
