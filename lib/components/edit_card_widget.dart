import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/delete_card_widget.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'edit_card_model.dart';
export 'edit_card_model.dart';

const editCardRevokedKey = ValueKey<String>('edit_card_revoked');

ValueKey<String> editCardDeleteButtonKey(String cardPath) =>
    ValueKey<String>('edit_card_delete_$cardPath');

class EditCardWidget extends StatefulWidget {
  const EditCardWidget({
    super.key,
    required this.owner,
    required this.ownerIsCurrent,
    this.cardsStream,
    this.deleteCard,
    this.revocation,
    this.onPaymentRouteBuilt,
  });

  final DocumentReference owner;
  final bool Function() ownerIsCurrent;
  final Stream<List<CardsRecord>>? cardsStream;
  final DeleteCardHandler? deleteCard;
  final ValueListenable<bool>? revocation;
  final ValueChanged<Route<dynamic>?>? onPaymentRouteBuilt;

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
    _model.cardsStream = widget.cardsStream ??
        queryCardsRecord(
          parent: widget.owner,
        );
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ownerIsCurrent()) {
      return const SizedBox.shrink(key: editCardRevokedKey);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          decoration:
              ExpatlioDesign.sheetDecoration(color: ExpatlioDesign.background),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              BottomSheetHeader(
                title: FFLocalizations.of(context).getText(
                  'o063iu8b' /* Изменение способов вывода */,
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.pagePadding,
                    ExpatlioDesign.space8,
                    ExpatlioDesign.pagePadding,
                    ExpatlioDesign.space8),
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
                      separatorBuilder: (_, __) =>
                          SizedBox(height: ExpatlioDesign.space8),
                      itemBuilder: (context, listViewIndex) {
                        final listViewCardsRecord =
                            listViewCardsRecordList[listViewIndex];
                        return Container(
                          width: double.infinity,
                          height: 60.0,
                          decoration: BoxDecoration(
                            color:
                                FlutterFlowTheme.of(context).primaryBackground,
                            borderRadius: BorderRadius.circular(
                                ExpatlioDesign.radiusLarge),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(ExpatlioDesign.space4),
                            child: Row(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Container(
                                  width: 52.0,
                                  height: 52.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryBackground,
                                    borderRadius: BorderRadius.circular(
                                        ExpatlioDesign.controlRadius),
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
                                        ExpatlioDesign.space12,
                                        ExpatlioDesign.space0,
                                        ExpatlioDesign.space8,
                                        ExpatlioDesign.space0),
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
                                  key: editCardDeleteButtonKey(
                                    listViewCardsRecord.reference.path,
                                  ),
                                  borderRadius: ExpatlioDesign.controlRadius,
                                  buttonSize: 52.0,
                                  icon: Icon(
                                    FFIcons.ktrash03,
                                    color: FlutterFlowTheme.of(context).error,
                                    size: 18.0,
                                  ),
                                  onPressed: () async {
                                    if (!widget.ownerIsCurrent()) {
                                      return;
                                    }
                                    await showModalBottomSheet(
                                      isScrollControlled: true,
                                      backgroundColor: Colors.transparent,
                                      context: context,
                                      builder: (context) {
                                        widget.onPaymentRouteBuilt?.call(
                                          ModalRoute.of(context),
                                        );
                                        Widget buildDeleteCard() => Padding(
                                              padding: MediaQuery.viewInsetsOf(
                                                  context),
                                              child: DeleteCardWidget(
                                                doc: listViewCardsRecord,
                                                owner: widget.owner,
                                                ownerIsCurrent:
                                                    widget.ownerIsCurrent,
                                                deleteCard: widget.deleteCard,
                                              ),
                                            );

                                        final revocation = widget.revocation;
                                        if (revocation == null) {
                                          return buildDeleteCard();
                                        }
                                        return ValueListenableBuilder<bool>(
                                          valueListenable: revocation,
                                          builder: (context, revoked, _) {
                                            if (revoked) {
                                              return const SizedBox.shrink();
                                            }
                                            return buildDeleteCard();
                                          },
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
              BottomSheetPrimaryButton(
                text: FFLocalizations.of(context).getVariableText(
                  ruText: 'Готово',
                  enText: 'Done',
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ].divide(SizedBox(height: ExpatlioDesign.space16)),
          ),
        ),
      ],
    );
  }
}
