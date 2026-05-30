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
        color: ExpatlioDesign.primary.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: ExpatlioDesign.background,
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

  String _initials() {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      return '?';
    }

    final words = normalizedName
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.length >= 2) {
      return '${words[0].characters.first}${words[1].characters.first}'
          .toUpperCase();
    }

    final chars = normalizedName.characters;
    return chars.take(2).toString().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ExpatlioDesign.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Text(
        _initials(),
        maxLines: 1,
        textAlign: TextAlign.center,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.primary,
          size: fontSize,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}
