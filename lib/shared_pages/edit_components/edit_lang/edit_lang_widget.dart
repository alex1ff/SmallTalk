import '/authorization/components/lang/lang_widget.dart';
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
    _model = createModel(context, () => EditLangModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      _model.selectedLang = widget.selected;
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
          Stack(
            alignment: AlignmentDirectional(0.0, 1.0),
            children: [
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
                      valueOrDefault<String>(
                        widget.title,
                        'Язык',
                      ),
                      textAlign: TextAlign.center,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'Cool',
                            fontSize: 26.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.normal,
                          ),
                    ),
                    Flexible(
                      child: Padding(
                        padding:
                            EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
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
                            ]
                                .addToStart(SizedBox(height: 16.0))
                                .addToEnd(SizedBox(height: 120.0)),
                          ),
                        ),
                      ),
                    ),
                  ]
                      .divide(SizedBox(height: 16.0))
                      .addToStart(SizedBox(height: 16.0)),
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
                            'wp5usl3v' /* Сохранить */,
                          ),
                          action: () async {
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
                                    ? MediaQuery.viewInsetsOf(context).bottom >
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
            ],
          ),
        ],
      ),
    );
  }
}
