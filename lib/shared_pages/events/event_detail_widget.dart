import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_level_helper.dart';
import '/services/event_language_catalog.dart';

const ValueKey<String> eventDetailTopBarKey =
    ValueKey<String>('event_detail_top_bar');
const ValueKey<String> eventDetailBackButtonKey =
    ValueKey<String>('event_detail_back_button');
const ValueKey<String> eventDetailShareButtonKey =
    ValueKey<String>('event_detail_share_button');
const ValueKey<String> eventDetailLevelRangeBadgeKey =
    ValueKey<String>('event_detail_level_range_badge');
const ValueKey<String> eventDetailLanguageBadgeKey =
    ValueKey<String>('event_detail_language_badge');

class EventDetailWidget extends StatelessWidget {
  const EventDetailWidget({
    super.key,
    required this.eventId,
    this.onSharePressed,
    this.levelMin,
    this.levelMax,
    this.languageCode,
    this.languageNameEn,
    this.languageNameRu,
    this.languageCatalog,
  });

  final String eventId;
  final VoidCallback? onSharePressed;
  final String? levelMin;
  final String? levelMax;
  final String? languageCode;
  final String? languageNameEn;
  final String? languageNameRu;
  final EventLanguageCatalog? languageCatalog;

  static String routeName = 'eventDetail';
  static String routePath = '/events/:eventId';

  @override
  Widget build(BuildContext context) {
    final levelRangeLabel = _eventDetailLevelRangeLabel(
      levelMin: levelMin,
      levelMax: levelMax,
    );
    final languageLabel = _eventDetailLanguageLabel(
      languageCode: languageCode,
      languageNameEn: languageNameEn,
      languageNameRu: languageNameRu,
      languageCatalog: languageCatalog,
      localeCode: FFLocalizations.of(context).languageCode,
    );

    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventDetailTopBar(onSharePressed: onSharePressed),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(ExpatlioDesign.space24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (levelRangeLabel.isNotEmpty ||
                          languageLabel.isNotEmpty) ...[
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: ExpatlioDesign.space8,
                          runSpacing: ExpatlioDesign.space8,
                          children: [
                            if (levelRangeLabel.isNotEmpty)
                              _EventDetailLevelRangeBadge(
                                label: levelRangeLabel,
                              ),
                            if (languageLabel.isNotEmpty)
                              _EventDetailLanguageBadge(label: languageLabel),
                          ],
                        ),
                        const SizedBox(height: ExpatlioDesign.space12),
                      ],
                      Text(
                        FFLocalizations.of(context).getVariableText(
                          ruText: 'Событие',
                          enText: 'Event',
                        ),
                        textAlign: TextAlign.center,
                        style: ExpatlioDesign.textStyle(
                          context,
                          size: 28,
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: ExpatlioDesign.space8),
                      Text(
                        eventId,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: ExpatlioDesign.muted,
                          size: 14,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailLevelRangeBadge extends StatelessWidget {
  const _EventDetailLevelRangeBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Уровень $label',
      enText: 'Level $label',
    );

    return Semantics(
      key: eventDetailLevelRangeBadgeKey,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: _EventDetailInfoBadge(
          icon: Icons.school_outlined,
          label: label,
        ),
      ),
    );
  }
}

class _EventDetailLanguageBadge extends StatelessWidget {
  const _EventDetailLanguageBadge({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Язык $label',
      enText: 'Language $label',
    );

    return Semantics(
      key: eventDetailLanguageBadgeKey,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: _EventDetailInfoBadge(
          icon: Icons.translate,
          label: label,
        ),
      ),
    );
  }
}

class _EventDetailInfoBadge extends StatelessWidget {
  const _EventDetailInfoBadge({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ExpatlioDesign.space12,
        vertical: ExpatlioDesign.space8,
      ),
      decoration: ExpatlioDesign.softPrimaryDecoration(
        radius: ExpatlioDesign.radiusCapsule,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: ExpatlioDesign.primary,
            size: 16,
          ),
          const SizedBox(width: ExpatlioDesign.space4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: ExpatlioDesign.primary,
              size: 14,
              weight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailTopBar extends StatelessWidget {
  const _EventDetailTopBar({
    required this.onSharePressed,
  });

  final VoidCallback? onSharePressed;

  @override
  Widget build(BuildContext context) {
    final backLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Назад',
      enText: 'Back',
    );
    final shareLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Поделиться событием',
      enText: 'Share event',
    );
    void handleBackPressed() => context.safePop();

    return SizedBox(
      key: eventDetailTopBarKey,
      height: ExpatlioDesign.pageHeaderHeight,
      child: Row(
        children: [
          Tooltip(
            message: backLabel,
            child: Semantics(
              key: eventDetailBackButtonKey,
              button: true,
              label: backLabel,
              onTap: handleBackPressed,
              child: ExcludeSemantics(
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 24,
                  buttonSize: 48,
                  icon: Icon(
                    FFIcons.kchevronLeft,
                    color: ExpatlioDesign.text,
                    size: 24,
                  ),
                  onPressed: handleBackPressed,
                ),
              ),
            ),
          ),
          Expanded(
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Событие',
                enText: 'Event',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.pageHeaderTitleStyle(context),
            ),
          ),
          Tooltip(
            message: shareLabel,
            child: Semantics(
              key: eventDetailShareButtonKey,
              button: true,
              enabled: onSharePressed != null,
              label: shareLabel,
              onTap: onSharePressed,
              child: ExcludeSemantics(
                child: FlutterFlowIconButton(
                  borderColor: Colors.transparent,
                  borderRadius: 24,
                  buttonSize: 48,
                  disabledIconColor: ExpatlioDesign.disabled,
                  icon: Icon(
                    Icons.ios_share,
                    color: ExpatlioDesign.text,
                    size: 24,
                  ),
                  onPressed: onSharePressed,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _eventDetailLevelRangeLabel({
  required String? levelMin,
  required String? levelMax,
}) {
  final normalizedMin = levelMin?.trim() ?? '';
  final normalizedMax = levelMax?.trim() ?? '';
  if (normalizedMin.isEmpty || normalizedMax.isEmpty) {
    return '';
  }

  final range = tryEventLevelRange(
    levelMin: normalizedMin,
    levelMax: normalizedMax,
  );
  if (range == null) {
    return '';
  }

  return range.levelMin == range.levelMax
      ? range.levelMin
      : '${range.levelMin}-${range.levelMax}';
}

String _eventDetailLanguageLabel({
  required String? languageCode,
  required String? languageNameEn,
  required String? languageNameRu,
  required EventLanguageCatalog? languageCatalog,
  required String? localeCode,
}) {
  final languageCatalogLabel = languageCatalog?.localizedDisplayName(
    languageCode: languageCode,
    localeCode: localeCode,
    languageNameEn: languageNameEn,
    languageNameRu: languageNameRu,
  );
  final normalizedCatalogLabel = languageCatalogLabel?.trim();
  if (normalizedCatalogLabel != null && normalizedCatalogLabel.isNotEmpty) {
    return normalizedCatalogLabel;
  }

  final isRussianLocale = _isRussianLocaleCode(localeCode);
  final preferredFallback = (isRussianLocale
          ? languageNameRu ?? languageNameEn
          : languageNameEn ?? languageNameRu)
      ?.trim();
  if (preferredFallback != null && preferredFallback.isNotEmpty) {
    return preferredFallback;
  }

  return languageCode?.trim() ?? '';
}

bool _isRussianLocaleCode(String? localeCode) {
  final normalized = localeCode?.trim().toLowerCase();
  return normalized == 'ru' ||
      normalized?.startsWith('ru-') == true ||
      normalized?.startsWith('ru_') == true;
}
