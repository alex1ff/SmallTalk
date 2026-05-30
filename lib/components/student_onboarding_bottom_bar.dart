import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
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
        height: ExpatlioDesign.buttonHeight + 4.0,
        decoration: BoxDecoration(
          color: ExpatlioDesign.text,
          borderRadius: BorderRadius.circular(18.0),
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
                    _StudentOnboardingActionButton(
                      key: const ValueKey<String>(
                          'student_onboarding_back_button'),
                      role: _StudentOnboardingActionRole.back,
                      text: FFLocalizations.of(context).getVariableText(
                        ruText: 'Назад',
                        enText: 'Back',
                      ),
                      onTap: backButtonEnabled ? onBack : null,
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
              _StudentOnboardingActionButton(
                key: ValueKey<String>(isLastPage
                    ? 'student_onboarding_finish_button'
                    : 'student_onboarding_next_button'),
                role: isLastPage
                    ? _StudentOnboardingActionRole.complete
                    : _StudentOnboardingActionRole.next,
                text: isLastPage
                    ? FFLocalizations.of(context).getVariableText(
                        ruText: 'Готово',
                        enText: 'Done',
                      )
                    : FFLocalizations.of(context).getVariableText(
                        ruText: 'Далее',
                        enText: 'Next',
                      ),
                isLoading: isSubmitting,
                onTap: isSubmitting || isInteractionLocked
                    ? null
                    : isLastPage
                        ? onComplete
                        : onNext,
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
      width: ExpatlioDesign.buttonHeight,
      height: ExpatlioDesign.buttonHeight,
      decoration: const BoxDecoration(
        color: ExpatlioDesign.text,
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

enum _StudentOnboardingActionRole {
  back,
  next,
  complete,
}

class _StudentOnboardingActionButton extends StatelessWidget {
  const _StudentOnboardingActionButton({
    super.key,
    required this.role,
    required this.text,
    this.isLoading = false,
    this.onTap,
  });

  final _StudentOnboardingActionRole role;
  final String text;
  final bool isLoading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _StudentOnboardingActionPalette.resolve(context, role);

    return Material(
      color: palette.surface,
      borderRadius: BorderRadius.circular(16.0),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.0),
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: 94.0,
            minHeight: ExpatlioDesign.buttonHeight,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18.0, 0.0, 18.0, 0.0),
            child: Center(
              child: isLoading
                  ? SizedBox(
                      width: 20.0,
                      height: 20.0,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          palette.content,
                        ),
                      ),
                    )
                  : Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: palette.content,
                            fontSize: 15.0,
                            letterSpacing: 0.0,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentOnboardingActionPalette {
  const _StudentOnboardingActionPalette({
    required this.surface,
    required this.content,
  });

  final Color surface;
  final Color content;

  static _StudentOnboardingActionPalette resolve(
    BuildContext context,
    _StudentOnboardingActionRole role,
  ) {
    return switch (role) {
      _StudentOnboardingActionRole.back =>
        const _StudentOnboardingActionPalette(
          surface: Color(0xFF2E2E2E),
          content: Colors.white,
        ),
      _StudentOnboardingActionRole.next => _StudentOnboardingActionPalette(
          surface: FlutterFlowTheme.of(context).primaryBackground,
          content: ExpatlioDesign.text,
        ),
      _StudentOnboardingActionRole.complete => _StudentOnboardingActionPalette(
          surface: FlutterFlowTheme.of(context).success,
          content: Colors.white,
        ),
    };
  }
}
