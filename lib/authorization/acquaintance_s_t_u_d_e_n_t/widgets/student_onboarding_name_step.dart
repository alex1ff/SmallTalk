import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class StudentOnboardingNameStep extends StatelessWidget {
  const StudentOnboardingNameStep({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Future<void> Function()? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('student_onboarding_step_name'),
      padding: const EdgeInsetsDirectional.fromSTEB(6.0, 32.0, 6.0, 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 10.0),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Как вас зовут?',
                enText: 'What is your name?',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
                    fontSize: 43.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10.0, 4.0, 0.0, 0.0),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Лучше написать настоящее имя',
                enText: 'It is better to use your real name',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: ExpatlioDesign.muted,
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 60.0),
            child: Container(
              decoration: ExpatlioDesign.formGroupDecoration(),
              padding: ExpatlioDesign.formGroupPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'Ваше имя',
                      enText: 'Your name',
                    ),
                    style: ExpatlioDesign.formLabelStyle(context),
                  ),
                  const SizedBox(height: 6.0),
                  TextFormField(
                    key:
                        const ValueKey<String>('student_onboarding_name_field'),
                    controller: controller,
                    focusNode: focusNode,
                    onFieldSubmitted: (_) async {
                      await onSubmitted?.call();
                    },
                    autofocus: false,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: ExpatlioDesign.formFieldDecoration(context),
                    style: ExpatlioDesign.formTextStyle(context),
                    cursorColor: ExpatlioDesign.primary,
                    enableInteractiveSelection: true,
                    inputFormatters: [
                      if (!isAndroid && !isiOS)
                        TextInputFormatter.withFunction(
                          (oldValue, newValue) => TextEditingValue(
                            selection: newValue.selection,
                            text: newValue.text.toCapitalization(
                              TextCapitalization.sentences,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
