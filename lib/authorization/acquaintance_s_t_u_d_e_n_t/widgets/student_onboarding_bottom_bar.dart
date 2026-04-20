import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';

class StudentOnboardingBottomBar extends StatelessWidget {
  const StudentOnboardingBottomBar({
    super.key,
    required this.canGoBack,
    required this.currentStep,
    required this.isLastPage,
    required this.isSubmitting,
    required this.totalSteps,
    this.isInteractionLocked = false,
    this.onBack,
    this.onNext,
    this.onComplete,
  });

  final bool canGoBack;
  final int currentStep;
  final bool isLastPage;
  final bool isSubmitting;
  final int totalSteps;
  final bool isInteractionLocked;
  final VoidCallback? onBack;
  final VoidCallback? onNext;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final backButtonEnabled =
        canGoBack && !isSubmitting && !isInteractionLocked;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      padding: EdgeInsetsDirectional.fromSTEB(
        0.0,
        0.0,
        0.0,
        keyboardVisible ? 8.0 : 35.0,
      ),
      child: Container(
        key: const ValueKey<String>('student_onboarding_bottom_bar'),
        height: 60.0,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(100.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AnimatedBottomBarSegment(
                visible: canGoBack,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StudentOnboardingCircleButton(
                      key: const ValueKey<String>(
                          'student_onboarding_back_button'),
                      fillColor: const Color(0xFF2E2E2E),
                      onTap: backButtonEnabled ? onBack : null,
                      child: const Icon(
                        FFIcons.karrowLeft,
                        color: Colors.white,
                        size: 24.0,
                      ),
                    ),
                    const SizedBox(width: 2.0),
                  ],
                ),
              ),
              _AnimatedBottomBarSegment(
                visible: !isLastPage,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _StudentOnboardingProgressBadge(
                      currentStep: currentStep,
                      totalSteps: totalSteps,
                    ),
                    const SizedBox(width: 2.0),
                  ],
                ),
              ),
              _StudentOnboardingCircleButton(
                key: ValueKey<String>(isLastPage
                    ? 'student_onboarding_finish_button'
                    : 'student_onboarding_next_button'),
                fillColor: isLastPage
                    ? FlutterFlowTheme.of(context).success
                    : FlutterFlowTheme.of(context).primaryBackground,
                onTap: isSubmitting || isInteractionLocked
                    ? null
                    : isLastPage
                        ? onComplete
                        : onNext,
                child: isSubmitting
                    ? const SizedBox(
                        width: 20.0,
                        height: 20.0,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      )
                    : Icon(
                        isLastPage ? Icons.check : FFIcons.karrowRight,
                        color: Colors.black,
                        size: 24.0,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedBottomBarSegment extends StatelessWidget {
  const _AnimatedBottomBarSegment({
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.centerLeft,
        widthFactor: visible ? 1.0 : 0.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          opacity: visible ? 1.0 : 0.0,
          child: child,
        ),
      ),
    );
  }
}

class _StudentOnboardingProgressBadge extends StatelessWidget {
  const _StudentOnboardingProgressBadge({
    required this.currentStep,
    required this.totalSteps,
  });

  final int currentStep;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('student_onboarding_progress_badge'),
      width: 56.0,
      height: 56.0,
      decoration: const BoxDecoration(
        color: Colors.black,
        shape: BoxShape.circle,
      ),
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(2.0),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: custom_widgets.ProggresBar(
                width: double.infinity,
                height: double.infinity,
                currentStep: currentStep,
                totalSteps: totalSteps,
              ),
            ),
          ),
          Text(
            '$currentStep/$totalSteps',
            key: const ValueKey<String>('student_onboarding_progress_text'),
            textAlign: TextAlign.center,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: Colors.white,
                  fontSize: 13.0,
                  letterSpacing: 0.0,
                ),
          ),
        ],
      ),
    );
  }
}

class _StudentOnboardingCircleButton extends StatelessWidget {
  const _StudentOnboardingCircleButton({
    super.key,
    required this.fillColor,
    required this.child,
    this.onTap,
  });

  final Color fillColor;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: fillColor,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: SizedBox(
          width: 56.0,
          height: 56.0,
          child: Center(child: child),
        ),
      ),
    );
  }
}
