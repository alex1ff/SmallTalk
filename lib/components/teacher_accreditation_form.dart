import '/authorization/acquaintance_n_s/native_speaker_onboarding_logic.dart';
import '/components/onboarding_form_section.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class TeacherAccreditationForm extends StatelessWidget {
  const TeacherAccreditationForm({
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

    return Container(
      key: const ValueKey<String>(
          'native_speaker_onboarding_step_accreditation'),
      decoration: ExpatlioDesign.formGroupDecoration(),
      padding: ExpatlioDesign.formGroupPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OnboardingFormSection(
            title: isRu ? 'Опыт преподавания' : 'Teaching experience',
            child: Wrap(
              spacing: 8.0,
              runSpacing: 8.0,
              children: experienceOptions.entries
                  .map(
                    (entry) => _TeacherAccreditationChoice(
                      label: entry.value,
                      selected: teachingExperience == entry.key,
                      onTap: () => onTeachingExperienceChanged(entry.key),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
          const SizedBox(height: ExpatlioDesign.sectionSpacing),
          OnboardingFormSection(
            title: isRu ? 'Подтверждение квалификации' : 'Qualification proof',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText:
                        'Можно выбрать несколько вариантов, если есть несколько подтверждений.',
                    enText:
                        'You can select multiple options if you have several proofs.',
                  ),
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: ExpatlioDesign.muted,
                    size: 13.0,
                  ),
                ),
                const SizedBox(height: 10.0),
                Wrap(
                  spacing: 8.0,
                  runSpacing: 8.0,
                  children: proofOptions.entries
                      .map(
                        (entry) => _TeacherAccreditationChoice(
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
              ],
            ),
          ),
          if (requiresEvidenceFiles) ...[
            const SizedBox(height: ExpatlioDesign.sectionSpacing),
            OnboardingFormSection(
              title: isRu ? 'Файлы подтверждения' : 'Supporting files',
              child: _TeacherEvidenceUploader(
                localQualificationFiles: localQualificationFiles,
                existingQualificationFiles: existingQualificationFiles,
                isPickingFiles: isPickingFiles,
                isUploadingFiles: isUploadingFiles,
                onPickFiles: onPickFiles,
                onRemoveLocalFile: onRemoveLocalFile,
                onRemoveExistingFile: onRemoveExistingFile,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TeacherEvidenceUploader extends StatelessWidget {
  const _TeacherEvidenceUploader({
    required this.localQualificationFiles,
    required this.existingQualificationFiles,
    required this.isPickingFiles,
    required this.isUploadingFiles,
    required this.onPickFiles,
    required this.onRemoveLocalFile,
    required this.onRemoveExistingFile,
  });

  final List<FFUploadedFile> localQualificationFiles;
  final List<NativeSpeakerEvidenceFile> existingQualificationFiles;
  final bool isPickingFiles;
  final bool isUploadingFiles;
  final VoidCallback onPickFiles;
  final ValueChanged<int> onRemoveLocalFile;
  final ValueChanged<int> onRemoveExistingFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          FFLocalizations.of(context).getVariableText(
            ruText:
                'Добавьте PDF, изображения или документы. Можно загрузить несколько файлов.',
            enText:
                'Add PDFs, images, or documents. You can upload multiple files.',
          ),
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.muted,
            size: 13.0,
          ),
        ),
        const SizedBox(height: 10.0),
        InkWell(
          key: const ValueKey<String>(
            'native_speaker_accreditation_upload_button',
          ),
          borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
          onTap: isPickingFiles || isUploadingFiles ? null : onPickFiles,
          child: Container(
            height: ExpatlioDesign.formFieldHeight,
            decoration: ExpatlioDesign.cardDecoration(
              color: ExpatlioDesign.mutedSurface,
              radius: ExpatlioDesign.controlRadius,
              borderColor: ExpatlioDesign.border,
            ),
            padding: const EdgeInsetsDirectional.symmetric(horizontal: 14.0),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file_rounded,
                  color: ExpatlioDesign.primary,
                  size: 19.0,
                ),
                const SizedBox(width: 9.0),
                Expanded(
                  child: Text(
                    _uploadButtonText(context),
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 15.0,
                      weight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (existingQualificationFiles.isNotEmpty ||
            localQualificationFiles.isNotEmpty) ...[
          const SizedBox(height: 10.0),
          for (var index = 0; index < existingQualificationFiles.length; index++)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8.0),
              child: _TeacherEvidenceFileTile(
                fileName: existingQualificationFiles[index].name,
                fileReference: existingQualificationFiles[index].storagePath,
                onRemove: () => onRemoveExistingFile(index),
              ),
            ),
          for (var index = 0; index < localQualificationFiles.length; index++)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8.0),
              child: _TeacherEvidenceFileTile(
                fileName: _displayNameForLocalFile(
                  localQualificationFiles[index],
                ),
                pending: true,
                onRemove: () => onRemoveLocalFile(index),
              ),
            ),
        ],
      ],
    );
  }

  String _uploadButtonText(BuildContext context) {
    if (isUploadingFiles) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Загружаем файлы...',
        enText: 'Uploading files...',
      );
    }
    if (isPickingFiles) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Открываем файлы...',
        enText: 'Opening files...',
      );
    }
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Добавить файлы',
      enText: 'Add files',
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

class _TeacherAccreditationChoice extends StatelessWidget {
  const _TeacherAccreditationChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : ExpatlioDesign.text;
    return InkWell(
      borderRadius: BorderRadius.circular(999.0),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(13.0, 9.0, 13.0, 9.0),
        decoration: BoxDecoration(
          color:
              selected ? ExpatlioDesign.primary : ExpatlioDesign.mutedSurface,
          borderRadius: BorderRadius.circular(999.0),
          border: Border.all(
            color: selected ? ExpatlioDesign.primary : ExpatlioDesign.border,
          ),
        ),
        child: Text(
          label,
          style: ExpatlioDesign.textStyle(
            context,
            color: foreground,
            size: 14.0,
            weight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _TeacherEvidenceFileTile extends StatelessWidget {
  const _TeacherEvidenceFileTile({
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
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(12.0, 10.0, 8.0, 10.0),
      decoration: ExpatlioDesign.cardDecoration(
        color: ExpatlioDesign.mutedSurface,
        radius: ExpatlioDesign.controlRadius,
        borderColor: ExpatlioDesign.border,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_outlined,
            color: ExpatlioDesign.primary,
            size: 19.0,
          ),
          const SizedBox(width: 9.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    size: 14.0,
                    weight: FontWeight.w500,
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
                    style: ExpatlioDesign.textStyle(
                      context,
                      color: ExpatlioDesign.muted,
                      size: 12.0,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8.0),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(16.0),
            child: const SizedBox(
              width: 30.0,
              height: 30.0,
              child: Icon(
                Icons.close_rounded,
                color: ExpatlioDesign.muted,
                size: 17.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
