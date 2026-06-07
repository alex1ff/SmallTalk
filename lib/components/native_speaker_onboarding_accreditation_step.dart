import '/authorization/acquaintance_n_s/native_speaker_onboarding_logic.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class NativeSpeakerOnboardingAccreditationStep extends StatelessWidget {
  const NativeSpeakerOnboardingAccreditationStep({
    super.key,
    required this.teachingExperience,
    required this.qualificationProofs,
    required this.localQualificationFiles,
    required this.existingQualificationFiles,
    required this.isPickingFiles,
    required this.isUploadingFiles,
    required this.onTeachingExperienceChanged,
    required this.onQualificationProofsChanged,
    required this.onPickFiles,
    required this.onRemoveLocalFile,
    required this.onRemoveExistingFile,
  });

  final String? teachingExperience;
  final List<String> qualificationProofs;
  final List<FFUploadedFile> localQualificationFiles;
  final List<NativeSpeakerEvidenceFile> existingQualificationFiles;
  final bool isPickingFiles;
  final bool isUploadingFiles;
  final ValueChanged<String> onTeachingExperienceChanged;
  final ValueChanged<List<String>> onQualificationProofsChanged;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemoveLocalFile;
  final ValueChanged<int> onRemoveExistingFile;

  @override
  Widget build(BuildContext context) {
    final isRu = FFLocalizations.of(context).languageCode == 'ru';
    final experienceOptions = <String, String>{
      'none': isRu ? 'Нет опыта' : 'No experience',
      'lt_1_year': isRu ? 'До 1 года' : 'Under 1 year',
      '1_3_years': isRu ? '1-3 года' : '1-3 years',
      '3_plus_years': isRu ? '3+ года' : '3+ years',
    };
    final proofOptions = <String, String>{
      'degree': isRu ? 'Диплом' : 'Degree',
      'certificate': isRu ? 'Сертификат' : 'Certificate',
      'other_document': isRu ? 'Другой документ' : 'Other document',
      'experience_only': isRu ? 'Только опыт' : 'Experience only',
      'none': isRu ? 'Нет' : 'None',
    };
    final requiresEvidenceFiles =
        shouldRequireNativeSpeakerQualificationFiles(qualificationProofs);

    return SingleChildScrollView(
      key: const ValueKey<String>(
        'native_speaker_onboarding_step_accreditation',
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space32,
          ExpatlioDesign.pagePadding,
          ExpatlioDesign.space112),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space0,
                ExpatlioDesign.space0,
                ExpatlioDesign.space0,
                ExpatlioDesign.space0),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Подтвердите опыт учителя',
                enText: 'Confirm your teacher profile',
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
                ExpatlioDesign.space0,
                ExpatlioDesign.space4,
                ExpatlioDesign.space0,
                ExpatlioDesign.space0),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText:
                    'Администратор проверит заявку перед доступом к звонкам.',
                enText:
                    'An admin will review this before you can receive calls.',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: ExpatlioDesign.muted,
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space0,
                ExpatlioDesign.space32,
                ExpatlioDesign.space0,
                ExpatlioDesign.space0),
            child: Text(
              isRu ? 'Опыт преподавания' : 'Teaching experience',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space0,
                ExpatlioDesign.space12,
                ExpatlioDesign.space0,
                ExpatlioDesign.space0),
            child: Wrap(
              spacing: ExpatlioDesign.space8,
              runSpacing: ExpatlioDesign.space8,
              children: experienceOptions.entries
                  .map(
                    (entry) => _NativeSpeakerAccreditationChoice(
                      label: entry.value,
                      selected: teachingExperience == entry.key,
                      onTap: () => onTeachingExperienceChanged(entry.key),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space0,
                ExpatlioDesign.space24,
                ExpatlioDesign.space0,
                ExpatlioDesign.space0),
            child: Text(
              isRu ? 'Подтверждение квалификации' : 'Qualification proof',
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    fontSize: 16.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space0,
                ExpatlioDesign.space4,
                ExpatlioDesign.space0,
                ExpatlioDesign.space0),
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText:
                    'Можно выбрать несколько вариантов, если у вас есть несколько подтверждений.',
                enText:
                    'You can select multiple options if you have several proofs.',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: ExpatlioDesign.muted,
                    fontSize: 15.0,
                    letterSpacing: 0.0,
                  ),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space0,
                ExpatlioDesign.space12,
                ExpatlioDesign.space0,
                ExpatlioDesign.space0),
            child: Wrap(
              spacing: ExpatlioDesign.space8,
              runSpacing: ExpatlioDesign.space8,
              children: proofOptions.entries
                  .map(
                    (entry) => _NativeSpeakerAccreditationChoice(
                      label: entry.value,
                      selected: qualificationProofs.contains(entry.key),
                      onTap: () => onQualificationProofsChanged(
                        toggleNativeSpeakerQualificationProof(
                          qualificationProofs,
                          entry.key,
                        ),
                      ),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          if (requiresEvidenceFiles) ...[
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: Text(
                isRu ? 'Файлы подтверждения' : 'Supporting files',
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      fontSize: 16.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space4,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText:
                      'Добавьте PDF, изображения или документы. Можно загрузить несколько файлов.',
                  enText:
                      'Add PDFs, images, or documents. You can upload multiple files.',
                ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: ExpatlioDesign.muted,
                      fontSize: 15.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: InkWell(
                key: const ValueKey<String>(
                  'native_speaker_accreditation_upload_button',
                ),
                borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
                onTap: isPickingFiles || isUploadingFiles ? null : onPickFiles,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space16,
                      ExpatlioDesign.space16,
                      ExpatlioDesign.space16,
                      ExpatlioDesign.space16),
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.card,
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.cardRadius),
                    border: Border.all(
                      color: FlutterFlowTheme.of(context).alternate,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        color: ExpatlioDesign.text,
                        size: 20.0,
                      ),
                      const SizedBox(width: ExpatlioDesign.space12),
                      Expanded(
                        child: Text(
                          isUploadingFiles
                              ? FFLocalizations.of(context).getVariableText(
                                  ruText: 'Загружаем файлы...',
                                  enText: 'Uploading files...',
                                )
                              : isPickingFiles
                                  ? FFLocalizations.of(context).getVariableText(
                                      ruText: 'Открываем файлы...',
                                      enText: 'Opening files...',
                                    )
                                  : FFLocalizations.of(context).getVariableText(
                                      ruText: 'Добавить файлы',
                                      enText: 'Add files',
                                    ),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'sf pro display',
                                    fontSize: 15.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (existingQualificationFiles.isNotEmpty ||
                localQualificationFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space12,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space0),
                child: Column(
                  children: [
                    for (var index = 0;
                        index < existingQualificationFiles.length;
                        index++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            bottom: ExpatlioDesign.space8),
                        child: _NativeSpeakerEvidenceFileTile(
                          fileName: existingQualificationFiles[index].name,
                          fileReference:
                              existingQualificationFiles[index].storagePath,
                          onRemove: () => onRemoveExistingFile(index),
                        ),
                      ),
                    for (var index = 0;
                        index < localQualificationFiles.length;
                        index++)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            bottom: ExpatlioDesign.space8),
                        child: _NativeSpeakerEvidenceFileTile(
                          fileName: _displayNameForLocalFile(
                            localQualificationFiles[index],
                          ),
                          fileReference: null,
                          pending: true,
                          onRemove: () => onRemoveLocalFile(index),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _displayNameForLocalFile(FFUploadedFile file) {
    final originalFilename = file.originalFilename.trim();
    if (originalFilename.isNotEmpty) {
      return originalFilename;
    }
    return (file.name ?? '').trim();
  }
}

class _NativeSpeakerAccreditationChoice extends StatelessWidget {
  const _NativeSpeakerAccreditationChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space16,
            ExpatlioDesign.space12,
            ExpatlioDesign.space16,
            ExpatlioDesign.space12),
        decoration: BoxDecoration(
          color: selected ? theme.primaryText : theme.primaryBackground,
          borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
          border: Border.all(
            color: selected ? theme.primaryText : theme.alternate,
          ),
        ),
        child: Text(
          label,
          style: theme.bodyMedium.override(
            fontFamily: 'sf pro display',
            color: selected ? theme.primaryBackground : theme.primaryText,
            fontSize: 15.0,
            letterSpacing: 0.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NativeSpeakerEvidenceFileTile extends StatelessWidget {
  const _NativeSpeakerEvidenceFileTile({
    required this.fileName,
    required this.onRemove,
    this.fileReference,
    this.pending = false,
  });

  final String fileName;
  final String? fileReference;
  final bool pending;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = FlutterFlowTheme.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.space16,
          ExpatlioDesign.space12,
          ExpatlioDesign.space12,
          ExpatlioDesign.space12),
      decoration: BoxDecoration(
        color: theme.primaryBackground,
        borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
        border: Border.all(color: theme.alternate),
      ),
      child: Row(
        children: [
          Icon(
            Icons.description_outlined,
            color: theme.primaryText,
            size: 20.0,
          ),
          const SizedBox(width: ExpatlioDesign.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.bodyMedium.override(
                    fontFamily: 'sf pro display',
                    fontSize: 15.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (pending || (fileReference?.isNotEmpty ?? false))
                  Text(
                    pending
                        ? FFLocalizations.of(context).getVariableText(
                            ruText: 'Будет загружен при сохранении',
                            enText: 'Will upload on save',
                          )
                        : FFLocalizations.of(context).getVariableText(
                            ruText: 'Файл уже добавлен',
                            enText: 'File already attached',
                          ),
                    style: theme.bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: theme.secondaryText,
                      fontSize: 12.0,
                      letterSpacing: 0.0,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: ExpatlioDesign.space8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
            child: Container(
              width: 28.0,
              height: 28.0,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
