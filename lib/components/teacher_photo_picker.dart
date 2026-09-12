import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

class TeacherPhotoPicker extends StatelessWidget {
  const TeacherPhotoPicker({
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

    return Material(
      color: Colors.transparent,
      child: InkWell(
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
        onTap: enabled ? onPickPhoto : null,
        child: Container(
          constraints: const BoxConstraints(minHeight: 84.0),
          decoration: ExpatlioDesign.cardDecoration(
            color: ExpatlioDesign.mutedSurface,
            radius: ExpatlioDesign.controlRadius,
            borderColor: ExpatlioDesign.border,
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space12,
              ExpatlioDesign.space12,
              ExpatlioDesign.space16,
              ExpatlioDesign.space12),
          child: Row(
            children: [
              Container(
                width: 62.0,
                height: 62.0,
                decoration: BoxDecoration(
                  color: ExpatlioDesign.card,
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusLarge),
                ),
                clipBehavior: Clip.antiAlias,
                child: Builder(
                  builder: (context) {
                    if (hasLocalPhoto) {
                      return Image.memory(
                        localPhoto!.bytes!,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      );
                    }
                    if (hasRemotePhoto) {
                      return Image.network(
                        existingPhotoUrl,
                        width: double.infinity,
                        height: double.infinity,
                        fit: BoxFit.cover,
                      );
                    }
                    return const Icon(
                      Icons.camera_alt_outlined,
                      color: ExpatlioDesign.primary,
                      size: 24.0,
                    );
                  },
                ),
              ),
              const SizedBox(width: ExpatlioDesign.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      hasLocalPhoto || hasRemotePhoto
                          ? FFLocalizations.of(context).getVariableText(
                              ruText: 'Фото добавлено',
                              enText: 'Photo added',
                            )
                          : FFLocalizations.of(context).getVariableText(
                              ruText: 'Добавьте фото',
                              enText: 'Add a photo',
                            ),
                      style: ExpatlioDesign.textStyle(
                        context,
                        size: 15.0,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space4),
                    Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Нажмите, чтобы изменить',
                        enText: 'Tap to change',
                      ),
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.muted,
                        size: 13.0,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: ExpatlioDesign.muted,
                size: 22.0,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
