import 'dart:math' as math;

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';

class StudentOnboardingGenderStep extends StatelessWidget {
  const StudentOnboardingGenderStep({
    super.key,
    required this.genderMale,
    required this.onChanged,
  });

  final bool genderMale;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      key: const ValueKey<String>('student_onboarding_gender_page_clip'),
      child: SingleChildScrollView(
        key: const ValueKey<String>('student_onboarding_step_gender'),
        padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.pagePadding,
            ExpatlioDesign.space32,
            ExpatlioDesign.pagePadding,
            ExpatlioDesign.space112),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AutoSizeText(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Как вы себя\nидентифицируете?',
                enText: 'How do you\nidentify yourself?',
              ),
              maxLines: 2,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
                    color: ExpatlioDesign.text,
                    fontSize: 34.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                    lineHeight: 1.1,
                  ),
            ),
            const SizedBox(height: ExpatlioDesign.space32),
            _StudentGenderChoice(
              genderMale: genderMale,
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentGenderChoice extends StatefulWidget {
  const _StudentGenderChoice({
    required this.genderMale,
    required this.onChanged,
  });

  final bool genderMale;
  final ValueChanged<bool> onChanged;

  @override
  State<_StudentGenderChoice> createState() => _StudentGenderChoiceState();
}

class _StudentGenderChoiceState extends State<_StudentGenderChoice> {
  static const _maleIndex = 0;
  static const _femaleIndex = 1;
  static const _maleRotationAngle = 15.0 * math.pi / 180.0;
  static const _femaleRotationAngle = 350.0 * math.pi / 180.0;
  static const _swiperPadding = EdgeInsetsDirectional.fromSTEB(
    ExpatlioDesign.space8,
    ExpatlioDesign.space12,
    ExpatlioDesign.space32,
    ExpatlioDesign.space12,
  );
  static const _backCardOffset = Offset(84.0, 0.0);

  final CardSwiperController _controller = CardSwiperController();
  late final ValueNotifier<bool> _selectedGenderMale =
      ValueNotifier<bool>(widget.genderMale);
  late bool _currentGenderMale = widget.genderMale;
  bool _isAnimating = false;

  @override
  void didUpdateWidget(covariant _StudentGenderChoice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isAnimating && widget.genderMale != _currentGenderMale) {
      _currentGenderMale = widget.genderMale;
      _selectedGenderMale.value = widget.genderMale;
    }
  }

  @override
  void dispose() {
    _selectedGenderMale.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animateToGender(bool genderMale) {
    if (_isAnimating || genderMale == _currentGenderMale) {
      return;
    }

    _isAnimating = true;
    _selectedGenderMale.value = genderMale;

    if (genderMale) {
      _controller.swipeRight();
    } else {
      _controller.swipeLeft();
    }
  }

  bool _handleSwipe(
    int previousIndex,
    int? currentIndex,
    CardSwiperDirection direction,
  ) {
    final nextGenderMale = (currentIndex ?? previousIndex) == _maleIndex;
    _isAnimating = false;
    _currentGenderMale = nextGenderMale;
    _selectedGenderMale.value = nextGenderMale;
    widget.onChanged(nextGenderMale);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final maleAssetPath = _genderAssetPath(context, isMale: true);
    final femaleAssetPath = _genderAssetPath(context, isMale: false);
    return RepaintBoundary(
      child: Column(
        children: [
          SizedBox(
            height: 410.0,
            child: CardSwiper(
              controller: _controller,
              initialIndex: _currentGenderMale ? _maleIndex : _femaleIndex,
              cardsCount: 2,
              isLoop: true,
              numberOfCardsDisplayed: 2,
              scale: 0.88,
              maxAngle: 24.0,
              threshold: 42,
              padding: _swiperPadding,
              backCardOffset: _backCardOffset,
              allowedSwipeDirection:
                  AllowedSwipeDirection.symmetric(horizontal: true),
              onSwipe: _handleSwipe,
              cardBuilder: (
                context,
                index,
                percentThresholdX,
                percentThresholdY,
              ) {
                final isMaleCard = index == _maleIndex;
                return _StudentGenderCard(
                  key: ValueKey<String>(isMaleCard
                      ? 'student_onboarding_gender_male'
                      : 'student_onboarding_gender_female'),
                  assetPath: isMaleCard ? maleAssetPath : femaleAssetPath,
                  rotationAngle:
                      isMaleCard ? _maleRotationAngle : _femaleRotationAngle,
                  onTap: () => _animateToGender(isMaleCard),
                );
              },
            ),
          ),
          const SizedBox(height: ExpatlioDesign.space16),
          ValueListenableBuilder<bool>(
            valueListenable: _selectedGenderMale,
            builder: (context, genderMale, _) {
              return _StudentGenderSelector(
                genderMale: genderMale,
                onChanged: _animateToGender,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StudentGenderCard extends StatelessWidget {
  const _StudentGenderCard({
    super.key,
    required this.assetPath,
    required this.rotationAngle,
    required this.onTap,
  });

  final String assetPath;
  final double rotationAngle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space4,
              ExpatlioDesign.space4,
              ExpatlioDesign.space4,
              ExpatlioDesign.space4),
          child: Transform.rotate(
            angle: rotationAngle,
            child: ClipRRect(
              borderRadius:
                  BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
              child: Image.asset(
                assetPath,
                height: 340.0,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.low,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentGenderSelector extends StatelessWidget {
  const _StudentGenderSelector({
    required this.genderMale,
    required this.onChanged,
  });

  final bool genderMale;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('student_onboarding_gender_selector'),
      height: 58.0,
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
      ),
      padding: const EdgeInsets.all(ExpatlioDesign.space4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final selectedSegmentWidth = (constraints.maxWidth - 2.0) / 2.0;
          final selectedSegmentOffset =
              genderMale ? 0.0 : selectedSegmentWidth + 2.0;

          return Stack(
            children: [
              AnimatedPositionedDirectional(
                key: const ValueKey<String>(
                    'student_onboarding_gender_selector_indicator_position'),
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                top: 0.0,
                bottom: 0.0,
                start: selectedSegmentOffset,
                child: Container(
                  key: const ValueKey<String>(
                      'student_onboarding_gender_selector_indicator'),
                  width: selectedSegmentWidth,
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.background,
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.controlRadius),
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _StudentGenderSelectorItem(
                      key: const ValueKey<String>(
                          'student_onboarding_gender_selector_male'),
                      selected: genderMale,
                      label: FFLocalizations.of(context).getVariableText(
                        ruText: 'Мужчина',
                        enText: 'Male',
                      ),
                      onTap: () => onChanged(true),
                    ),
                  ),
                  const SizedBox(width: ExpatlioDesign.space4),
                  Expanded(
                    child: _StudentGenderSelectorItem(
                      key: const ValueKey<String>(
                          'student_onboarding_gender_selector_female'),
                      selected: !genderMale,
                      label: FFLocalizations.of(context).getVariableText(
                        ruText: 'Женщина',
                        enText: 'Female',
                      ),
                      onTap: () => onChanged(false),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudentGenderSelectorItem extends StatelessWidget {
  const _StudentGenderSelectorItem({
    super.key,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      borderRadius: BorderRadius.circular(ExpatlioDesign.controlRadius),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        alignment: AlignmentDirectional.center,
        child: Text(
          label,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'sf pro display',
                color: selected ? ExpatlioDesign.text : ExpatlioDesign.muted,
                letterSpacing: 0.0,
              ),
        ),
      ),
    );
  }
}

String _genderAssetPath(BuildContext context, {required bool isMale}) {
  if (isMale) {
    return FFLocalizations.of(context).languageCode == 'ru'
        ? 'assets/images/group_11712753102.webp'
        : 'assets/images/group_1171275311.webp';
  }

  return FFLocalizations.of(context).languageCode == 'ru'
      ? 'assets/images/33_2.webp'
      : 'assets/images/33_.webp';
}
