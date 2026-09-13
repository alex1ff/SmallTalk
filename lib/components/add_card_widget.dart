import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'add_card_model.dart';
export 'add_card_model.dart';

typedef AddCardWriter = Future<void> Function({
  required DocumentReference owner,
  required String number,
  required String pan,
});

const addCardRevokedKey = ValueKey<String>('add_card_revoked');
const addCardSaveButtonKey = ValueKey<String>('add_card_save_button');

class AddCardWidget extends StatefulWidget {
  const AddCardWidget({
    super.key,
    required this.owner,
    required this.ownerIsCurrent,
    this.cardWriter,
  });

  final DocumentReference owner;
  final bool Function() ownerIsCurrent;
  final AddCardWriter? cardWriter;

  @override
  State<AddCardWidget> createState() => _AddCardWidgetState();
}

class _AddCardWidgetState extends State<AddCardWidget> {
  late AddCardModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => AddCardModel());

    _model.nameTextController ??= TextEditingController();
    _model.nameFocusNode ??= FocusNode();
    _model.nameFocusNode!.addListener(() => safeSetState(() {}));
    _model.nameMask = MaskTextInputFormatter(mask: '#### #### #### #### ####');
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    if (_model.formKey.currentState == null ||
        !_model.formKey.currentState!.validate()) {
      return;
    }
    if (!widget.ownerIsCurrent()) {
      return;
    }

    final number = _model.nameTextController.text;
    final pan = functions.maskCardNumber(number);
    final cardWriter = widget.cardWriter;
    if (cardWriter != null) {
      await cardWriter(owner: widget.owner, number: number, pan: pan);
    } else {
      await CardsRecord.createDoc(widget.owner).set(
        createCardsRecordData(num: number, pan: pan),
      );
    }
    if (mounted && widget.ownerIsCurrent()) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.ownerIsCurrent()) {
      return const SizedBox.shrink(key: addCardRevokedKey);
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
                  '6wfkgk3t' /* Добавить способ вывода */,
                ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.pagePadding,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.pagePadding,
                    ExpatlioDesign.space0),
                child: Form(
                  key: _model.formKey,
                  autovalidateMode: AutovalidateMode.disabled,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.card,
                      borderRadius:
                          BorderRadius.circular(ExpatlioDesign.radiusMedium),
                      border: Border.all(color: ExpatlioDesign.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(ExpatlioDesign.space16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            FFLocalizations.of(context).getText(
                              '3yeveeq0' /* Номер карты */,
                            ),
                            style: ExpatlioDesign.formLabelStyle(context),
                          ),
                          const SizedBox(height: ExpatlioDesign.space8),
                          TextFormField(
                            controller: _model.nameTextController,
                            focusNode: _model.nameFocusNode,
                            onChanged: (_) => EasyDebounce.debounce(
                              '_model.nameTextController',
                              Duration.zero,
                              () => safeSetState(() {}),
                            ),
                            autofocus: false,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.done,
                            textAlignVertical: TextAlignVertical.center,
                            obscureText: false,
                            decoration:
                                ExpatlioDesign.formFieldDecoration(context),
                            style: ExpatlioDesign.formTextStyle(context),
                            keyboardType: TextInputType.number,
                            cursorColor: ExpatlioDesign.primary,
                            enableInteractiveSelection: true,
                            validator: _model.nameTextControllerValidator
                                .asValidator(context),
                            inputFormatters: [_model.nameMask],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              BottomSheetPrimaryButton(
                key: addCardSaveButtonKey,
                text: FFLocalizations.of(context).getVariableText(
                  ruText: 'Сохранить',
                  enText: 'Save',
                ),
                onPressed: _saveCard,
              ),
            ].divide(SizedBox(height: ExpatlioDesign.space16)),
          ),
        ),
      ],
    );
  }
}
