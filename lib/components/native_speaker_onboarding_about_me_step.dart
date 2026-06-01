import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class NativeSpeakerOnboardingAboutMeStep extends StatelessWidget {
  const NativeSpeakerOnboardingAboutMeStep({
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
      key: const ValueKey<String>('native_speaker_onboarding_step_about_me'),
      padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space8,
          ExpatlioDesign.space32,
          ExpatlioDesign.space8,
          ExpatlioDesign.space112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space12,
                ExpatlioDesign.space0,
                ExpatlioDesign.space12,
                ExpatlioDesign.space0),
            child: AutoSizeText(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Расскажите\nо себе',
                enText: 'Tell us\nabout yourself',
              ),
              maxLines: 2,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
                    color: ExpatlioDesign.text,
                    fontSize: 34.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                    lineHeight: 1.1,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space12,
                ExpatlioDesign.space4,
                ExpatlioDesign.space12,
                ExpatlioDesign.space0),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Это поможет ученикам узнать вас поближе.',
                enText: 'This helps students get to know you better.',
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
            padding:
                const EdgeInsetsDirectional.only(top: ExpatlioDesign.space64),
            child: Container(
              decoration: ExpatlioDesign.formGroupDecoration(),
              padding: ExpatlioDesign.formGroupPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'О себе',
                      enText: 'About you',
                    ),
                    style: ExpatlioDesign.formLabelStyle(context),
                  ),
                  const SizedBox(height: ExpatlioDesign.space8),
                  TextFormField(
                    key: const ValueKey<String>(
                        'native_speaker_onboarding_about_me_field'),
                    controller: controller,
                    focusNode: focusNode,
                    onFieldSubmitted: (_) async {
                      await onSubmitted?.call();
                    },
                    autofocus: false,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.done,
                    decoration: ExpatlioDesign.formFieldDecoration(
                      context,
                      hintText: FFLocalizations.of(context).getVariableText(
                        ruText:
                            'Люблю готовить, изучаю испанский и много путешествую',
                        enText:
                            'I love cooking, study Spanish, and travel a lot',
                      ),
                      maxLines: 4,
                    ),
                    style: ExpatlioDesign.formTextStyle(context),
                    maxLines: 12,
                    minLines: 4,
                    cursorColor: ExpatlioDesign.primary,
                    enableInteractiveSelection: true,
                    inputFormatters: [
                      if (!isAndroid && !isiOS)
                        TextInputFormatter.withFunction((oldValue, newValue) {
                          return TextEditingValue(
                            selection: newValue.selection,
                            text: newValue.text.toCapitalization(
                              TextCapitalization.sentences,
                            ),
                          );
                        }),
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
