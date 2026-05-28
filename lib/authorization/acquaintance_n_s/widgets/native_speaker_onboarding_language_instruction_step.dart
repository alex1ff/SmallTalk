import '/authorization/components/lang/lang_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class NativeSpeakerOnboardingLanguageInstructionStep extends StatelessWidget {
  const NativeSpeakerOnboardingLanguageInstructionStep({
    super.key,
    required this.selectedLanguage,
    required this.onChanged,
  });

  final LanguageStruct? selectedLanguage;
  final Future<void> Function(LanguageStruct lang) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>(
        'native_speaker_onboarding_step_language_instruction',
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(6.0, 32.0, 6.0, 0.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
            child: AutoSizeText(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Язык, которому будете обучать',
                enText: 'Language you will teach',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
                    color: ExpatlioDesign.text,
                    fontSize: 43.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                    lineHeight: 1.1,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10.0, 4.0, 0.0, 0.0),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Выберите один язык',
                enText: 'Choose one language',
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
          const SizedBox(height: 60.0),
          Expanded(
            child: RepaintBoundary(
              child: LangWidget(
                key: const ValueKey<String>(
                  'native_speaker_onboarding_language_instruction_picker',
                ),
                selected: selectedLanguage,
                expandList: true,
                listBottomPadding: 120.0,
                action: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
