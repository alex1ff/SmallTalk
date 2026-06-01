import '/components/country_widget.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class NativeSpeakerOnboardingCountryStep extends StatelessWidget {
  const NativeSpeakerOnboardingCountryStep({
    super.key,
    required this.selectedCountry,
    required this.onChanged,
  });

  final CountryStruct? selectedCountry;
  final Future<void> Function(CountryStruct country) onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey<String>('native_speaker_onboarding_step_country'),
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
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Где вы сейчас находитесь?',
                enText: 'Where are you now?',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
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
                ruText: 'Находите новых друзей в интернете и рядом с вами.',
                enText: 'Meet new friends online and near you.',
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
            child: RepaintBoundary(
              child: CountryWidget(
                selected: selectedCountry,
                action: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
