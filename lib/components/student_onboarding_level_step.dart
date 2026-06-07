import '/backend/schema/enums/enums.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';

class StudentOnboardingLevelStep extends StatelessWidget {
  const StudentOnboardingLevelStep({
    super.key,
    required this.level,
    required this.onChanged,
    this.title,
    this.showTitle = true,
  });

  final Level level;
  final ValueChanged<Level> onChanged;
  final String? title;
  final bool showTitle;

  static const List<Level> _levels = <Level>[
    Level.Beginner,
    Level.Basic,
    Level.Intermediate,
    Level.Fluent,
  ];

  @override
  Widget build(BuildContext context) {
    final presentation = _LevelPresentation.fromLevel(context, level);

    return SingleChildScrollView(
      key: const ValueKey<String>('student_onboarding_step_level'),
      padding: EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.pagePadding,
        showTitle ? ExpatlioDesign.space32 : ExpatlioDesign.space0,
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.space112,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showTitle)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0,
                  ExpatlioDesign.space0),
              child: AutoSizeText(
                title ??
                    FFLocalizations.of(context).getVariableText(
                      ruText: 'Ваш текущий уровень',
                      enText: 'Your current level',
                    ),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'Cool',
                      color: ExpatlioDesign.text,
                      fontSize: 34.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                      lineHeight: 1.1,
                    ),
              ),
            ),
          Padding(
            padding: EdgeInsetsDirectional.only(
                top:
                    showTitle ? ExpatlioDesign.space32 : ExpatlioDesign.space0),
            child: Stack(
              alignment: const AlignmentDirectional(0.0, 1.0),
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 350.0,
                  child: custom_widgets.SemiCircleSlider(
                    width: double.infinity,
                    height: 350.0,
                    initialLevel: level,
                    onChanged: (nextLevel) async {
                      onChanged(nextLevel);
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            bottom: ExpatlioDesign.space32),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.only(
                                  bottom: ExpatlioDesign.space12),
                              child: Image.asset(
                                presentation.assetPath,
                                width: 100.0,
                                height: 70.0,
                                fit: BoxFit.contain,
                              ),
                            ),
                            Text(
                              presentation.title,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    fontSize: 22.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                            Text(
                              presentation.description,
                              textAlign: TextAlign.center,
                              style: FlutterFlowTheme.of(context)
                                  .bodyMedium
                                  .override(
                                    fontFamily: 'sf pro display',
                                    color: FlutterFlowTheme.of(context)
                                        .secondaryText,
                                    fontSize: 13.0,
                                    letterSpacing: 0.0,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Stack(
                        alignment: AlignmentDirectional.center,
                        children: [
                          Container(
                            width: double.infinity,
                            height: 22.0,
                            decoration: BoxDecoration(
                              color: FlutterFlowTheme.of(context)
                                  .primaryBackground,
                              borderRadius: BorderRadius.circular(
                                  ExpatlioDesign.radiusSmall),
                            ),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.all(ExpatlioDesign.space4),
                            child: Row(
                              children: _levels
                                  .map(
                                    (item) => Expanded(
                                      child: _LevelTick(
                                        level: item,
                                        selectedLevel: level,
                                        onTap: () => onChanged(item),
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                            top: ExpatlioDesign.space4),
                        child: Row(
                          children: _levels
                              .map(
                                (item) => Expanded(
                                  child: Padding(
                                    padding: EdgeInsetsDirectional.only(
                                      start: item == Level.Intermediate
                                          ? ExpatlioDesign.space8
                                          : ExpatlioDesign.space0,
                                      end: item == Level.Basic
                                          ? ExpatlioDesign.space8
                                          : ExpatlioDesign.space0,
                                    ),
                                    child: _LevelLabel(
                                      level: item,
                                      selectedLevel: level,
                                      onTap: () => onChanged(item),
                                    ),
                                  ),
                                ),
                              )
                              .toList(growable: false),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelLabel extends StatelessWidget {
  const _LevelLabel({
    required this.level,
    required this.selectedLevel,
    required this.onTap,
  });

  final Level level;
  final Level selectedLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedLevel == level;
    final titleColor = isSelected ? ExpatlioDesign.text : ExpatlioDesign.muted;

    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(
              top: ExpatlioDesign.space4, bottom: ExpatlioDesign.space4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: level == Level.Beginner
                ? CrossAxisAlignment.start
                : level == Level.Fluent
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.center,
            children: [
              Text(
                _LevelPresentation.shortTitle(
                  context,
                  level,
                ),
                textAlign: level == Level.Beginner
                    ? TextAlign.start
                    : level == Level.Fluent
                        ? TextAlign.end
                        : TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: titleColor,
                      fontSize: 13.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                _LevelPresentation.cefrLabel(level),
                textAlign: level == Level.Beginner
                    ? TextAlign.start
                    : level == Level.Fluent
                        ? TextAlign.end
                        : TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: titleColor,
                      fontSize: 11.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w400,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelTick extends StatelessWidget {
  const _LevelTick({
    required this.level,
    required this.selectedLevel,
    required this.onTap,
  });

  final Level level;
  final Level selectedLevel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedLevel == level;
    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: level == Level.Beginner
            ? CrossAxisAlignment.start
            : level == Level.Fluent
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: isSelected ? 32.0 : 18.0,
            height: isSelected ? 32.0 : 18.0,
            decoration: BoxDecoration(
              color: isSelected
                  ? FlutterFlowTheme.of(context).primaryBackground
                  : FlutterFlowTheme.of(context).secondaryBackground,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? ExpatlioDesign.primary : Colors.transparent,
                width: 6.0,
              ),
            ),
            child: Visibility(
              visible: !isSelected,
              child: Align(
                alignment: AlignmentDirectional.center,
                child: Container(
                  width: 2.0,
                  height: 2.0,
                  decoration: BoxDecoration(
                    color: ExpatlioDesign.text,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelPresentation {
  const _LevelPresentation({
    required this.assetPath,
    required this.title,
    required this.description,
  });

  final String assetPath;
  final String title;
  final String description;

  static _LevelPresentation fromLevel(BuildContext context, Level level) {
    switch (level) {
      case Level.Beginner:
        return _LevelPresentation(
          assetPath: 'assets/images/34kgr_.png',
          title: FFLocalizations.of(context)
              .getVariableText(ruText: 'Начальный', enText: 'Beginner'),
          description: FFLocalizations.of(context).getVariableText(
            ruText: 'Знаю базовые фразы и слова',
            enText: 'I know basic words and phrases',
          ),
        );
      case Level.Basic:
        return _LevelPresentation(
          assetPath: 'assets/images/iom0u_.png',
          title: FFLocalizations.of(context)
              .getVariableText(ruText: 'Базовый', enText: 'Basic'),
          description: FFLocalizations.of(context).getVariableText(
            ruText: 'Могу поддержать простой разговор',
            enText: 'I can keep a simple conversation',
          ),
        );
      case Level.Intermediate:
        return _LevelPresentation(
          assetPath: 'assets/images/g08g4_.png',
          title: FFLocalizations.of(context)
              .getVariableText(ruText: 'Уверенный', enText: 'Intermediate'),
          description: FFLocalizations.of(context).getVariableText(
            ruText: 'Говорю свободно на большинство тем',
            enText: 'I speak freely on most topics',
          ),
        );
      case Level.Fluent:
        return _LevelPresentation(
          assetPath: 'assets/images/e1xjd_.png',
          title: FFLocalizations.of(context)
              .getVariableText(ruText: 'Свободно', enText: 'Fluent'),
          description: FFLocalizations.of(context).getVariableText(
            ruText: 'Владею как родным',
            enText: 'I use it like a native speaker',
          ),
        );
    }
  }

  static String cefrLabel(Level level) {
    switch (level) {
      case Level.Beginner:
        return 'A1-A2';
      case Level.Basic:
        return 'A2-B1';
      case Level.Intermediate:
        return 'B1-B2';
      case Level.Fluent:
        return 'C1-C2';
    }
  }

  static String shortTitle(BuildContext context, Level level) {
    switch (level) {
      case Level.Beginner:
        return FFLocalizations.of(context)
            .getVariableText(ruText: 'Начальный', enText: 'Beginner');
      case Level.Basic:
        return FFLocalizations.of(context)
            .getVariableText(ruText: 'Базовый', enText: 'Basic');
      case Level.Intermediate:
        return FFLocalizations.of(context)
            .getVariableText(ruText: 'Уверенный', enText: 'Intermediate');
      case Level.Fluent:
        return FFLocalizations.of(context)
            .getVariableText(ruText: 'Свободно', enText: 'Fluent');
    }
  }
}
