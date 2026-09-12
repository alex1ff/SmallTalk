import 'package:flutter/material.dart';

import '/shared_pages/design/expatlio_design.dart';

const ValueKey<String> socialAuthProgressOverlayKey =
    ValueKey<String>('social_auth_progress_overlay');

class SocialAuthProgressOverlay extends StatelessWidget {
  const SocialAuthProgressOverlay({
    super.key,
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: socialAuthProgressOverlayKey,
      container: true,
      liveRegion: true,
      label: '$title. $message',
      child: Stack(
        fit: StackFit.expand,
        children: [
          ModalBarrier(
            dismissible: false,
            color: ExpatlioDesign.background.withValues(alpha: 0.88),
          ),
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 300.0),
              margin: const EdgeInsets.all(ExpatlioDesign.space24),
              padding: const EdgeInsets.all(ExpatlioDesign.space20),
              decoration: ExpatlioDesign.cardDecoration(),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 28.0,
                      height: 28.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: ExpatlioDesign.primary,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: ExpatlioDesign.textStyle(
                        context,
                        size: 16.0,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.muted,
                        size: 14.0,
                        weight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
