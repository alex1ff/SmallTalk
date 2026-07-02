import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProfileAvatarPicker extends StatelessWidget {
  const ProfileAvatarPicker({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(ExpatlioDesign.cardRadius),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 112.0,
              height: 112.0,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AuthUserStreamWidget(
                      builder: (context) {
                        if (currentUserPhoto.isEmpty) {
                          return const _ProfileAvatarPlaceholder();
                        }
                        return ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: currentUserPhoto,
                            fit: BoxFit.cover,
                            memCacheWidth: 224,
                            memCacheHeight: 224,
                            placeholder: (context, url) =>
                                const _ProfileAvatarPlaceholder(),
                            errorWidget: (context, url, error) =>
                                const _ProfileAvatarPlaceholder(),
                          ),
                        );
                      },
                    ),
                  ),
                  PositionedDirectional(
                    end: 0.0,
                    bottom: 4.0,
                    child: Container(
                      width: 40.0,
                      height: 40.0,
                      decoration: BoxDecoration(
                        color: ExpatlioDesign.primary,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: ExpatlioDesign.border, width: 2.5),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 7.0,
                            color: Color(0x26000000),
                            offset: Offset(0.0, 3.0),
                          ),
                        ],
                      ),
                      child: const Icon(
                        FFIcons.kcameraPlus,
                        color: Colors.white,
                        size: 19.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space12),
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Изменить фото',
                enText: 'Change photo',
              ),
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.primary,
                size: 15.0,
                weight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatarPlaceholder extends StatelessWidget {
  const _ProfileAvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    final displayName = currentUserDisplayName.trim();
    final firstLetter =
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

    return Container(
      decoration: BoxDecoration(
        color: ExpatlioDesign.mutedSurface,
        shape: BoxShape.circle,
        border: Border.all(color: ExpatlioDesign.border),
      ),
      alignment: Alignment.center,
      child: Text(
        firstLetter,
        textAlign: TextAlign.center,
        style: ExpatlioDesign.textStyle(
          context,
          size: 28.0,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}
