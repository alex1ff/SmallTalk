import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/components/wrapper.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'delete_card_model.dart';
export 'delete_card_model.dart';

typedef DeleteCardHandler = Future<void> Function(CardsRecord card);

const deleteCardRevokedKey = ValueKey<String>('delete_card_revoked');
const deleteCardConfirmButtonKey =
    ValueKey<String>('delete_card_confirm_button');

class DeleteCardWidget extends StatefulWidget {
  const DeleteCardWidget({
    super.key,
    required this.doc,
    required this.owner,
    required this.ownerIsCurrent,
    this.deleteCard,
  });

  final CardsRecord? doc;
  final DocumentReference owner;
  final bool Function() ownerIsCurrent;
  final DeleteCardHandler? deleteCard;

  @override
  State<DeleteCardWidget> createState() => _DeleteCardWidgetState();
}

class _DeleteCardWidgetState extends State<DeleteCardWidget> {
  late DeleteCardModel _model;
  bool _isDeleting = false;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => DeleteCardModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  bool get _canDeleteCurrentOwnerCard {
    final card = widget.doc;
    return card != null &&
        widget.ownerIsCurrent() &&
        card.reference.parent.parent?.path == widget.owner.path;
  }

  Future<void> _deleteCard() async {
    if (_isDeleting || !_canDeleteCurrentOwnerCard) {
      return;
    }
    safeSetState(() => _isDeleting = true);
    final card = widget.doc!;
    try {
      final deleteCard = widget.deleteCard;
      if (deleteCard != null) {
        await deleteCard(card);
      } else {
        await card.reference.delete();
      }
    } finally {
      if (mounted) {
        safeSetState(() => _isDeleting = false);
      }
    }
    if (mounted && widget.ownerIsCurrent()) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canDeleteCurrentOwnerCard) {
      return const SizedBox.shrink(key: deleteCardRevokedKey);
    }

    return Stack(
      alignment: AlignmentDirectional(0.0, 1.0),
      children: [
        Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: ExpatlioDesign.sheetDecoration(
                    color: ExpatlioDesign.background),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    BottomSheetHeader(
                      title: FFLocalizations.of(context).getText(
                        '8iw8rarz' /* Удалить сохраненную карту? */,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.pagePadding,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.pagePadding,
                          ExpatlioDesign.space0),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: ExpatlioDesign.card,
                          borderRadius: BorderRadius.circular(
                              ExpatlioDesign.radiusExtraLarge),
                        ),
                        child: Container(
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
                                        ExpatlioDesign.radiusExtraLarge),
                                  ),
                                  child: Align(
                                    alignment: AlignmentDirectional(0.0, 0.0),
                                    child: Icon(
                                      FFIcons.kcreditCard02,
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
                                      valueOrDefault<String>(
                                        widget.doc?.pan,
                                        FFLocalizations.of(context).getText(
                                          'j3b1pdz7' /* *** 4334 */,
                                        ),
                                      ),
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
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space24,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0),
                      child: FFButtonWidget(
                        key: deleteCardConfirmButtonKey,
                        onPressed: _isDeleting ? null : _deleteCard,
                        text: FFLocalizations.of(context).getText(
                          'ikt9ul7g' /* Удалить карту */,
                        ),
                        icon: Icon(
                          FFIcons.kchevronRight,
                          size: 15.0,
                        ),
                        options: FFButtonOptions(
                          height: ExpatlioDesign.buttonHeight,
                          padding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space16,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space16,
                              ExpatlioDesign.space0),
                          iconAlignment: IconAlignment.end,
                          iconPadding: EdgeInsetsDirectional.fromSTEB(
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0,
                              ExpatlioDesign.space0),
                          color: Colors.transparent,
                          textStyle:
                              FlutterFlowTheme.of(context).titleSmall.override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context).error,
                                    fontSize: 15.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                          elevation: 0.0,
                          borderRadius:
                              BorderRadius.circular(ExpatlioDesign.radiusSmall),
                        ),
                        showLoadingIndicator: false,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space12,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0),
                      child: wrapWithModel(
                        model: _model.buttonModel,
                        updateCallback: () => safeSetState(() {}),
                        child: Wrapper.keyboardAware(
                          child: ButtonWidget(
                            text: FFLocalizations.of(context).getText(
                              'c3z3ihcx' /* Не сейчас */,
                            ),
                            action: () async {
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ),
                    ),
                  ].divide(SizedBox(height: ExpatlioDesign.space16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
