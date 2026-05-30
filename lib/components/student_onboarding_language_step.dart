import '/components/lang_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class StudentOnboardingLanguageStep extends StatelessWidget {
  const StudentOnboardingLanguageStep({
    super.key,
    required this.selectedLanguage,
    required this.onChanged,
    this.allowedCodes = const <String>['en', 'ru'],
  });

  final LanguageStruct? selectedLanguage;
  final Future<void> Function(LanguageStruct lang) onChanged;
  final List<String> allowedCodes;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('student_onboarding_step_language'),
      padding: const EdgeInsetsDirectional.fromSTEB(6.0, 32.0, 6.0, 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
            child: AutoSizeText(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Какой язык хотите практиковать?',
                enText: 'Which language do you want to practice?',
              ),
              maxLines: 2,
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
                ruText: 'Сможете изменить позднее',
                enText: 'You can change it later',
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
            child: RepaintBoundary(
              child: LangWidget(
                key: const ValueKey<String>(
                    'student_onboarding_language_picker'),
                selected: selectedLanguage,
                allowedCodes: allowedCodes,
                action: (lang) async {
                  await onChanged(lang);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
