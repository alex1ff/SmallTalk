import 'dart:math' as math;

import '/shared_pages/design/expatlio_design.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class OrbitingAvatarMotionSpec {
  const OrbitingAvatarMotionSpec({
    required this.radiusX,
    required this.radiusY,
    required this.phase,
    required this.speed,
    this.drift = 0.12,
    this.scalePulse = 0.14,
  });

  final double radiusX;
  final double radiusY;
  final double phase;
  final double speed;
  final double drift;
  final double scalePulse;

  Offset offsetAt(double progress) {
    final turn = progress * math.pi * 2.0;
    final cycles = math.max(1, speed.abs().round()).toDouble();
    final direction = speed.isNegative ? -1.0 : 1.0;
    final driftTurn = turn * (cycles + 1.0);
    final radiusWave = 1.0 +
        math.sin(driftTurn + phase * 0.7) * drift * 0.72 +
        math.cos(turn * 3.0 - phase * 0.4) * drift * 0.28;
    final angle = phase +
        turn * cycles * direction +
        math.sin(driftTurn + phase) * drift * 0.82;

    return Offset(
      math.cos(angle) * radiusX * radiusWave +
          math.sin(turn * 3.0 + phase) * radiusX * drift * 0.16,
      math.sin(angle) *
              radiusY *
              (1.0 - math.cos(driftTurn - phase) * drift * 0.28) +
          math.cos(turn * 2.0 + phase * 1.3) * radiusY * drift * 0.14,
    );
  }

  double scaleAt(double progress) {
    final turn = progress * math.pi * 2.0;
    final cycles = math.max(1, speed.abs().round()).toDouble();
    final pulse = math.sin(turn * (cycles + 2.0) + phase);
    return 1.0 - scalePulse * 0.5 + ((pulse + 1.0) * 0.5 * scalePulse);
  }
}

class OrbitingAvatarData {
  const OrbitingAvatarData({
    required this.initials,
    required this.motion,
    this.assetPath = '',
    this.photoUrl = '',
    this.size = 42.0,
    this.muted = false,
  });

  final String initials;
  final String assetPath;
  final String photoUrl;
  final double size;
  final bool muted;
  final OrbitingAvatarMotionSpec motion;
}

class OrbitingAvatarsCta extends StatefulWidget {
  const OrbitingAvatarsCta({
    super.key,
    required this.avatars,
    required this.action,
    this.duration = const Duration(milliseconds: 18000),
  });

  final List<OrbitingAvatarData> avatars;
  final Widget action;
  final Duration duration;

  @override
  State<OrbitingAvatarsCta> createState() => _OrbitingAvatarsCtaState();
}

class _OrbitingAvatarsCtaState extends State<OrbitingAvatarsCta>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant OrbitingAvatarsCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);

    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final progress = animationsDisabled ? 0.0 : _controller.value;

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              for (final avatar in widget.avatars)
                IgnorePointer(
                  child: Align(
                    alignment: Alignment.center,
                    child: Transform.translate(
                      offset: avatar.motion.offsetAt(progress),
                      child: Transform.scale(
                        scale: avatar.motion.scaleAt(progress),
                        child: _OrbitingAvatar(avatar: avatar),
                      ),
                    ),
                  ),
                ),
              Center(child: child),
            ],
          );
        },
        child: widget.action,
      ),
    );
  }
}

class _OrbitingAvatar extends StatelessWidget {
  const _OrbitingAvatar({
    required this.avatar,
  });

  final OrbitingAvatarData avatar;
  static const _avatarCacheDimension = 384;

  @override
  Widget build(BuildContext context) {
    final photoUrl = avatar.photoUrl.trim();
    final assetPath = avatar.assetPath.trim();

    return SizedBox(
      width: avatar.size,
      height: avatar.size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 14.0,
              offset: Offset(0.0, 6.0),
            ),
          ],
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: avatar.muted
                ? ExpatlioDesign.mutedSurface
                : ExpatlioDesign.card,
            shape: BoxShape.circle,
            border: Border.all(
              color: ExpatlioDesign.border,
              width: 2.0,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(ExpatlioDesign.space4),
            child: ClipOval(
              child: _buildAvatarContent(context, photoUrl, assetPath),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarContent(
    BuildContext context,
    String photoUrl,
    String assetPath,
  ) {
    if (photoUrl.isEmpty) {
      if (assetPath.isEmpty) {
        return _buildInitials(context);
      }

      return Image.asset(
        assetPath,
        fit: BoxFit.cover,
        cacheWidth: _avatarCacheDimension,
        cacheHeight: _avatarCacheDimension,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => _buildInitials(context),
      );
    }

    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover,
      memCacheWidth: _avatarCacheDimension,
      memCacheHeight: _avatarCacheDimension,
      useOldImageOnUrlChange: true,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (context, url) => _buildInitials(context),
      errorWidget: (context, url, error) => _buildInitials(context),
    );
  }

  Widget _buildInitials(BuildContext context) {
    return ColoredBox(
      color: ExpatlioDesign.avatarFallbackBackground,
      child: Center(
        child: Text(
          ExpatlioDesign.avatarInitial(avatar.initials),
          maxLines: 1,
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.avatarFallbackText,
            size: avatar.size < 40.0 ? 11.0 : 13.0,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
