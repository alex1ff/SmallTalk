import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'edit_about_model.dart';
export 'edit_about_model.dart';

class EditAboutWidget extends StatefulWidget {
  const EditAboutWidget({
    super.key,
    required this.action,
  });

  final Future Function(String name)? action;

  @override
  State<EditAboutWidget> createState() => _EditAboutWidgetState();
}

class _EditAboutWidgetState extends State<EditAboutWidget> {
  late EditAboutModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditAboutModel());

    _model.aboutMeTextController ??= TextEditingController(
        text: valueOrDefault(currentUserDocument?.aboutMe, ''));
    _model.aboutMeFocusNode ??= FocusNode();
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _saveAbout() async {
    if (_model.aboutMeTextController.text == '') {
      await actions.showTopNotification(
        context,
        'Напишите хотя бы пару слов',
        '',
        true,
      );
      return;
    }
    if (_model.aboutMeTextController.text !=
        valueOrDefault(currentUserDocument?.aboutMe, '')) {
      await currentUserReference!.update(createUsersRecordData(
        aboutMe: _model.aboutMeTextController.text,
      ));
      await widget.action?.call(
        _model.aboutMeTextController.text,
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
                  'v997ihxn' /* Расскажите о себе */,
                ),
                onConfirm: _saveAbout,
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space0),
                child: AuthUserStreamWidget(
                  builder: (context) => Container(
                    width: double.infinity,
                    decoration: ExpatlioDesign.formGroupDecoration(),
                    padding: ExpatlioDesign.formGroupPadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FFLocalizations.of(context).getText(
                            'v997ihxn' /* Расскажите о себе */,
                          ),
                          style: ExpatlioDesign.formLabelStyle(context),
                        ),
                        const SizedBox(height: ExpatlioDesign.space8),
                        TextFormField(
                          controller: _model.aboutMeTextController,
                          focusNode: _model.aboutMeFocusNode,
                          onFieldSubmitted: (_) => _saveAbout(),
                          autofocus: false,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.done,
                          obscureText: false,
                          decoration: ExpatlioDesign.formFieldDecoration(
                            context,
                            hintText: FFLocalizations.of(context).getText(
                              'tjmgsp1u' /* Люблю готовить, изучаю испанск... */,
                            ),
                            maxLines: 4,
                          ),
                          style: ExpatlioDesign.formTextStyle(context),
                          maxLines: 12,
                          minLines: 4,
                          cursorColor: ExpatlioDesign.primary,
                          enableInteractiveSelection: true,
                          validator: _model.aboutMeTextControllerValidator
                              .asValidator(context),
                          inputFormatters: [
                            if (!isAndroid && !isiOS)
                              TextInputFormatter.withFunction(
                                  (oldValue, newValue) {
                                return TextEditingValue(
                                  selection: newValue.selection,
                                  text: newValue.text.toCapitalization(
                                      TextCapitalization.sentences),
                                );
                              }),
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
