import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/button/button_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:async';
import '/custom_code/actions/index.dart' as actions;
import '/custom_code/widgets/index.dart' as custom_widgets;
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

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return Column(
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
                  'rivukcpq' /* Имя */,
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Cool',
                      fontSize: 22.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                    ),
              ),
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
                child: Container(
                  width: double.infinity,
                  height: 60.0,
                  decoration: BoxDecoration(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                    borderRadius: BorderRadius.circular(100.0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(2.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Container(
                          width: 56.0,
                          height: 56.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            shape: BoxShape.circle,
                          ),
                          child: Align(
                            alignment: AlignmentDirectional(0.0, 0.0),
                            child: Icon(
                              FFIcons.kuser03,
                              color: FlutterFlowTheme.of(context).primaryText,
                              size: 20.0,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.fromSTEB(
                                8.0, 0.0, 8.0, 0.0),
                            child: AuthUserStreamWidget(
                              builder: (context) => Container(
                                width: double.infinity,
                                child: TextFormField(
                                  controller: _model.nameTextController,
                                  focusNode: _model.nameFocusNode,
                                  onChanged: (_) => EasyDebounce.debounce(
                                    '_model.nameTextController',
                                    Duration(milliseconds: 0),
                                    () => safeSetState(() {}),
                                  ),
                                  onFieldSubmitted: (_) async {
                                    if (_model.nameTextController.text != '') {
                                      if (functions.isValidName(
                                          _model.nameTextController.text)) {
                                        if (_model.nameTextController.text ==
                                            currentUserDisplayName) {
                                          Navigator.pop(context);
                                        } else {
                                          unawaited(
                                            () async {
                                              await currentUserReference!
                                                  .update(createUsersRecordData(
                                                displayName: _model
                                                    .nameTextController.text,
                                              ));
                                            }(),
                                          );
                                          await widget.action?.call(
                                            _model.nameTextController.text,
                                          );
                                          Navigator.pop(context);
                                          await actions.showTopNotification(
                                            context,
                                            'Имя изменено',
                                            '',
                                            false,
                                          );
                                        }
                                      } else {
                                        await actions.showTopNotification(
                                          context,
                                          'Неверное имя',
                                          '',
                                          true,
                                        );
                                        return;
                                      }
                                    } else {
                                      await actions.showTopNotification(
                                        context,
                                        'Пожалуйста, представьтесь',
                                        '',
                                        true,
                                      );
                                      return;
                                    }
                                  },
                                  autofocus: true,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textInputAction: TextInputAction.done,
                                  obscureText: false,
                                  decoration: InputDecoration(
                                    isDense: false,
                                    labelText:
                                        FFLocalizations.of(context).getText(
                                      'vvf76qj0' /* Ваше имя */,
                                    ),
                                    labelStyle: FlutterFlowTheme.of(context)
                                        .bodyMedium
                                        .override(
                                          fontFamily: 'sf pro display',
                                          color: FlutterFlowTheme.of(context)
                                              .secondaryText,
                                          fontSize: 16.0,
                                          letterSpacing: 0.0,
                                        ),
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                    errorBorder: InputBorder.none,
                                    focusedErrorBorder: InputBorder.none,
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        fontSize: 16.0,
                                        letterSpacing: 0.0,
                                      ),
                                  cursorColor:
                                      FlutterFlowTheme.of(context).primaryText,
                                  enableInteractiveSelection: true,
                                  validator: _model.nameTextControllerValidator
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
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedPadding(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                padding: EdgeInsetsDirectional.fromSTEB(
                    0.0, 0.0, 6.0, keyboardVisible ? 6.0 : 35.0),
                child: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Expanded(
                      child: wrapWithModel(
                        model: _model.buttonModel,
                        updateCallback: () => safeSetState(() {}),
                        child: ButtonWidget(
                          text: FFLocalizations.of(context).getText(
                            'p3ygumv3' /* Сохранить */,
                          ),
                          keyboardAwarePadding: false,
                          padding: EdgeInsetsDirectional.fromSTEB(
                              6.0, 0.0, 6.0, 0.0),
                          loadingText:
                              FFLocalizations.of(context).getVariableText(
                            ruText: 'Сохраняем...',
                            enText: 'Saving...',
                          ),
                          busyStyle: ButtonBusyStyle.spinner,
                          action: () async {
                            if (_model.nameTextController.text != '') {
                              if (functions.isValidName(
                                  _model.nameTextController.text)) {
                                if (_model.nameTextController.text ==
                                    currentUserDisplayName) {
                                  Navigator.pop(context);
                                } else {
                                  await currentUserReference!
                                      .update(createUsersRecordData(
                                    displayName: _model.nameTextController.text,
                                  ));
                                  await widget.action?.call(
                                    _model.nameTextController.text,
                                  );
                                  Navigator.pop(context);
                                  await actions.showTopNotification(
                                    context,
                                    'Имя изменено',
                                    '',
                                    false,
                                  );
                                }
                              } else {
                                await actions.showTopNotification(
                                  context,
                                  'Неверное имя',
                                  '',
                                  true,
                                );
                                return;
                              }
                            } else {
                              await actions.showTopNotification(
                                context,
                                'Пожалуйста, представьтесь',
                                '',
                                true,
                              );
                              return;
                            }
                          },
                        ),
                      ),
                    ),
                    Container(
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
                  ],
                ),
              ),
            ].divide(SizedBox(height: 16.0)).addToStart(SizedBox(height: 16.0)),
          ),
        ),
      ],
    );
  }
}
