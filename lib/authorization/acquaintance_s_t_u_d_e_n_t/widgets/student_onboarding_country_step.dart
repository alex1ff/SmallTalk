import '/authorization/components/country/country_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class StudentOnboardingCountryStep extends StatelessWidget {
  const StudentOnboardingCountryStep({
    super.key,
    required this.selectedCountry,
    required this.onChanged,
  });

  final CountryStruct? selectedCountry;
  final Future<void> Function(CountryStruct country) onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey<String>('student_onboarding_step_country'),
      padding: const EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(10.0, 32.0, 10.0, 0.0),
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Где вы сейчас находитесь?',
                  enText: 'Where are you now?',
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Cool',
                      fontSize: 43.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                      lineHeight: 1.1,
                    ),
              ),
            ),
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(10.0, 4.0, 10.0, 0.0),
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText:
                      'Локация помогает подбирать собеседников по выбранному фильтру.',
                  enText:
                      'Location helps match you when someone uses the location filter.',
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
                  const EdgeInsetsDirectional.fromSTEB(0.0, 60.0, 0.0, 0.0),
              child: RepaintBoundary(
                child: CountryWidget(
                  selected: selectedCountry,
                  action: onChanged,
                ),
              ),
            ),
          ].addToEnd(
            const SizedBox(height: 120.0),
          ),
        ),
      ),
    );
  }
}
