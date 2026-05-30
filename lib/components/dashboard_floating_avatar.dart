import '/shared_pages/design/expatlio_design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

enum DashboardFloatingAvatarScale {
  tiny,
  small,
  compact,
  regular,
  large,
  current,
}

enum DashboardFloatingAvatarTone { normal, muted }

class DashboardFloatingAvatar extends StatelessWidget {
  const DashboardFloatingAvatar({
    super.key,
    required this.initials,
    required this.scale,
    this.photoUrl = '',
    this.tone = DashboardFloatingAvatarTone.normal,
  });

  final String initials;
  final String photoUrl;
  final DashboardFloatingAvatarScale scale;
  final DashboardFloatingAvatarTone tone;

  double get _dimension {
    return switch (scale) {
      DashboardFloatingAvatarScale.tiny => 34.0,
      DashboardFloatingAvatarScale.small => 36.0,
      DashboardFloatingAvatarScale.compact => 38.0,
      DashboardFloatingAvatarScale.regular => 40.0,
      DashboardFloatingAvatarScale.large => 54.0,
      DashboardFloatingAvatarScale.current => 62.0,
    };
  }

  bool get _muted => tone == DashboardFloatingAvatarTone.muted;

  @override
  Widget build(BuildContext context) {
    final dimension = _dimension;
    final hasPhoto = photoUrl.trim().isNotEmpty;

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: _muted ? ExpatlioDesign.mutedSurface : ExpatlioDesign.card,
        shape: BoxShape.circle,
        border: Border.all(color: ExpatlioDesign.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x16000000),
            blurRadius: 12.0,
            offset: Offset(0.0, 5.0),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasPhoto
          ? CachedNetworkImage(
              imageUrl: photoUrl,
              fit: BoxFit.cover,
              memCacheWidth: (dimension * 2).round(),
              memCacheHeight: (dimension * 2).round(),
              placeholder: (context, url) => const SizedBox.shrink(),
              errorWidget: (context, url, error) => _buildInitials(context),
            )
          : _buildInitials(context),
    );
  }

  Widget _buildInitials(BuildContext context) {
    final dimension = _dimension;

    return Center(
      child: Text(
        initials,
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: _muted ? ExpatlioDesign.muted : ExpatlioDesign.text,
          size: dimension <= 38.0 ? 11.0 : 13.0,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}
