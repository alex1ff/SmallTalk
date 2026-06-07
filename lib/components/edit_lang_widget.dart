import '/components/lang_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/custom_code/actions/index.dart' as actions;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'edit_lang_model.dart';
export 'edit_lang_model.dart';

class EditLangWidget extends StatefulWidget {
  const EditLangWidget({
    super.key,
    required this.action,
    required this.selected,
    required this.title,
  });

  final Future Function(LanguageStruct lang)? action;
  final LanguageStruct? selected;
  final String? title;

  @override
  State<EditLangWidget> createState() => _EditLangWidgetState();
}

class _EditLangWidgetState extends State<EditLangWidget> {
  late EditLangModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => EditLangModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.selectedLang = widget.selected;
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  Future<void> _saveLang() async {
    if (_model.selectedLang != widget.selected) {
      if (_model.selectedLang != null) {
        await widget.action?.call(
          _model.selectedLang!,
        );
      } else {
        await actions.showTopNotification(
          context,
          'Выберите язык из списка',
          '',
          true,
        );
        return;
      }
    }
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
                  title: valueOrDefault<String>(
                    widget.title,
                    'Язык',
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: EdgeInsetsDirectional.fromSTEB(
                        ExpatlioDesign.pagePadding,
                        ExpatlioDesign.space0,
                        ExpatlioDesign.pagePadding,
                        ExpatlioDesign.space0),
                    child: SingleChildScrollView(
                      primary: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        mainAxisAlignment: MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          wrapWithModel(
                            model: _model.langModel,
                            updateCallback: () => safeSetState(() {}),
                            child: LangWidget(
                              selected: _model.selectedLang,
                              action: (lang) async {
                                _model.selectedLang = null;
                                safeSetState(() {});
                                _model.selectedLang = lang;
                                safeSetState(() {});
                              },
                            ),
                          ),
                        ].addToEnd(SizedBox(height: ExpatlioDesign.space32)),
                      ),
                    ),
                  ),
                ),
                BottomSheetPrimaryButton(
                  text: FFLocalizations.of(context).getVariableText(
                    ruText: 'Сохранить',
                    enText: 'Save',
                  ),
                  onPressed: _saveLang,
                ),
              ].divide(SizedBox(height: ExpatlioDesign.space16)),
            ),
          ),
        ],
      ),
    );
  }
}
