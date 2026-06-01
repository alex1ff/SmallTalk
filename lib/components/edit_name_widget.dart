import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/custom_code/actions/index.dart' as actions;
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:easy_debounce/easy_debounce.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'edit_name_model.dart';
export 'edit_name_model.dart';

class EditNameWidget extends StatefulWidget {
  const EditNameWidget({
    super.key,
    required this.action,
  });

  final Future Function(String name)? action;

  @override
  State<EditNameWidget> createState() => _EditNameWidgetState();
}

class _EditNameWidgetState extends State<EditNameWidget> {
  late EditNameModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditNameModel());

    _model.nameTextController ??=
        TextEditingController(text: currentUserDisplayName);
    _model.nameFocusNode ??= FocusNode();
    _model.nameFocusNode!.addListener(() => safeSetState(() {}));
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    if (_model.nameTextController.text == '') {
      await actions.showTopNotification(
        context,
        'Пожалуйста, представьтесь',
        '',
        true,
      );
      return;
    }
    if (!functions.isValidName(_model.nameTextController.text)) {
      await actions.showTopNotification(
        context,
        'Неверное имя',
        '',
        true,
      );
      return;
    }
    if (_model.nameTextController.text != currentUserDisplayName) {
      await currentUserReference!.update(createUsersRecordData(
        displayName: _model.nameTextController.text,
      ));
      await widget.action?.call(
        _model.nameTextController.text,
      );
      await actions.showTopNotification(
        context,
        'Имя изменено',
        '',
        false,
      );
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
                  'rivukcpq' /* Имя */,
                ),
                onConfirm: _saveName,
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space0),
                child: AuthUserStreamWidget(
                  builder: (context) => Container(
                    decoration: ExpatlioDesign.formGroupDecoration(),
                    padding: ExpatlioDesign.formGroupPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            'vvf76qj0' /* Ваше имя */,
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
                          onFieldSubmitted: (_) => _saveName(),
                          autofocus: true,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          textAlignVertical: TextAlignVertical.center,
                          obscureText: false,
                          decoration:
                              ExpatlioDesign.formFieldDecoration(context),
                          style: ExpatlioDesign.formTextStyle(context),
                          cursorColor: ExpatlioDesign.primary,
                          enableInteractiveSelection: true,
                          validator:
                              _model.nameTextControllerValidator.asValidator(
                            context,
                          ),
                          inputFormatters: [
                            if (!isAndroid && !isiOS)
                              TextInputFormatter.withFunction(
                                (oldValue, newValue) {
                                  return TextEditingValue(
                                    selection: newValue.selection,
                                    text: newValue.text.toCapitalization(
                                      TextCapitalization.sentences,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: ExpatlioDesign.space32),
            ].divide(SizedBox(height: ExpatlioDesign.space16)),
          ),
        ),
      ],
    );
  }
}
