import '/shared_pages/design/expatlio_design.dart';
import 'package:flutter/material.dart';

enum ParticipantAvatarSize { hero }

class ParticipantAvatar extends StatelessWidget {
  const ParticipantAvatar({
    super.key,
    required this.photoUrl,
    required this.displayName,
    this.size = ParticipantAvatarSize.hero,
  });

  final String photoUrl;
  final String displayName;
  final ParticipantAvatarSize size;

  double get _dimension {
    return switch (size) {
      ParticipantAvatarSize.hero => 82.0,
    };
  }

  double get _borderWidth {
    return switch (size) {
      ParticipantAvatarSize.hero => 0.0,
    };
  }

  double get _fallbackFontSize {
    return switch (size) {
      ParticipantAvatarSize.hero => 24.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final dimension = _dimension;
    final borderRadius = BorderRadius.circular(dimension / 2.0);

    return Container(
      width: dimension,
      height: dimension,
      decoration: BoxDecoration(
        color: ExpatlioDesign.avatarFallbackBackground,
        shape: BoxShape.circle,
        border: Border.all(
          color: ExpatlioDesign.border,
          width: _borderWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: photoUrl.trim().isNotEmpty
            ? Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _ParticipantAvatarFallback(
                  displayName: displayName,
                  fontSize: _fallbackFontSize,
                ),
              )
            : _ParticipantAvatarFallback(
                displayName: displayName,
                fontSize: _fallbackFontSize,
              ),
      ),
    );
  }
}

class _ParticipantAvatarFallback extends StatelessWidget {
  const _ParticipantAvatarFallback({
    required this.displayName,
    required this.fontSize,
  });

  final String displayName;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ExpatlioDesign.avatarFallbackBackground,
      alignment: Alignment.center,
      child: Text(
        ExpatlioDesign.avatarInitial(displayName),
        maxLines: 1,
        textAlign: TextAlign.center,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.avatarFallbackText,
          size: fontSize,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}
