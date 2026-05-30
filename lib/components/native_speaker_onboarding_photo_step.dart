import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class NativeSpeakerOnboardingPhotoStep extends StatelessWidget {
  const NativeSpeakerOnboardingPhotoStep({
    super.key,
    required this.localPhoto,
    required this.existingPhotoUrl,
    required this.enabled,
    required this.onPickPhoto,
  });

  final FFUploadedFile? localPhoto;
  final String existingPhotoUrl;
  final bool enabled;
  final Future<void> Function() onPickPhoto;

  @override
  Widget build(BuildContext context) {
    final hasLocalPhoto = localPhoto?.bytes?.isNotEmpty ?? false;
    final hasRemotePhoto = existingPhotoUrl.trim().isNotEmpty;

    return SingleChildScrollView(
      key: const ValueKey<String>('native_speaker_onboarding_step_photo'),
      padding: const EdgeInsetsDirectional.fromSTEB(6.0, 32.0, 6.0, 120.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(10.0, 0.0, 10.0, 0.0),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Добавьте фото профиля',
                enText: 'Add a profile photo',
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
          const SizedBox(height: 60.0),
          InkWell(
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: enabled ? onPickPhoto : null,
            child: Container(
              width: double.infinity,
              height: 479.1,
              decoration: BoxDecoration(
                color: ExpatlioDesign.card,
                borderRadius: BorderRadius.circular(16.0),
              ),
              child: Builder(
                builder: (context) {
                  if (hasLocalPhoto) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: Image.memory(
                        localPhoto!.bytes!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    );
                  }
                  if (hasRemotePhoto) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(16.0),
                      child: Image.network(
                        existingPhotoUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    );
                  }
                  return Align(
                    alignment: AlignmentDirectional.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 45.0,
                          height: 45.0,
                          decoration: BoxDecoration(
                            color: FlutterFlowTheme.of(context)
                                .secondaryBackground,
                            borderRadius: BorderRadius.circular(20.0),
                          ),
                          child: Icon(
                            FFIcons.kcameraPlus,
                            color: ExpatlioDesign.text,
                            size: 20.0,
                          ),
                        ),
                        Padding(
                          padding:
                              const EdgeInsetsDirectional.only(start: 12.0),
                          child: AutoSizeText(
                            FFLocalizations.of(context).getVariableText(
                              ruText: 'Загрузить фото',
                              enText: 'Upload a photo',
                            ),
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  fontSize: 16.0,
                                  letterSpacing: 0.0,
                                  fontWeight: FontWeight.normal,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
