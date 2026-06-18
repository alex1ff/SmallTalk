import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as timezone;

import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_list_date_bounds.dart';
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
const ValueKey<String> eventDetailTitleKey =
    ValueKey<String>('event_detail_title');
const ValueKey<String> eventDetailDescriptionKey =
    ValueKey<String>('event_detail_description');
const ValueKey<String> eventDetailOrganizerCardKey =
    ValueKey<String>('event_detail_organizer_card');
const ValueKey<String> eventDetailOrganizerAvatarKey =
    ValueKey<String>('event_detail_organizer_avatar');
const ValueKey<String> eventDetailOrganizerNameKey =
    ValueKey<String>('event_detail_organizer_name');
const ValueKey<String> eventDetailOrganizerMessageButtonKey =
    ValueKey<String>('event_detail_organizer_message_button');
const ValueKey<String> eventDetailDetailsBlockKey =
    ValueKey<String>('event_detail_details_block');
const ValueKey<String> eventDetailDateRowKey =
    ValueKey<String>('event_detail_date_row');
const ValueKey<String> eventDetailTimeRowKey =
    ValueKey<String>('event_detail_time_row');
const ValueKey<String> eventDetailPlaceRowKey =
    ValueKey<String>('event_detail_place_row');

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
    this.title,
    this.description,
    this.organizerDisplayName,
    this.organizerPhotoUrl,
    this.onOrganizerMessagePressed,
    this.startsAt,
    this.timeZoneId,
    this.locationName,
  });

  final String eventId;
  final VoidCallback? onSharePressed;
  final String? levelMin;
  final String? levelMax;
  final String? languageCode;
  final String? languageNameEn;
  final String? languageNameRu;
  final EventLanguageCatalog? languageCatalog;
  final String? title;
  final String? description;
  final String? organizerDisplayName;
  final String? organizerPhotoUrl;
  final VoidCallback? onOrganizerMessagePressed;
  final DateTime? startsAt;
  final String? timeZoneId;
  final String? locationName;

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
    final titleLabel = _eventDetailTitleLabel(context, title);
    final descriptionText = description?.trim() ?? '';
    final showEventIdFallback =
        (title?.trim().isEmpty ?? true) && descriptionText.isEmpty;
    final organizerName = organizerDisplayName?.trim() ?? '';
    final locationLabel = locationName?.trim() ?? '';
    final shouldShowDetails = startsAt != null || locationLabel.isNotEmpty;

    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventDetailTopBar(onSharePressed: onSharePressed),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space32,
                ),
                children: [
                  Align(
                    alignment: AlignmentDirectional.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (levelRangeLabel.isNotEmpty ||
                              languageLabel.isNotEmpty) ...[
                            Wrap(
                              spacing: ExpatlioDesign.space8,
                              runSpacing: ExpatlioDesign.space8,
                              children: [
                                if (levelRangeLabel.isNotEmpty)
                                  _EventDetailLevelRangeBadge(
                                    label: levelRangeLabel,
                                  ),
                                if (languageLabel.isNotEmpty)
                                  _EventDetailLanguageBadge(
                                    label: languageLabel,
                                  ),
                              ],
                            ),
                            const SizedBox(height: ExpatlioDesign.space20),
                          ],
                          Text(
                            key: eventDetailTitleKey,
                            titleLabel,
                            softWrap: true,
                            style: ExpatlioDesign.textStyle(
                              context,
                              size: 32,
                              height: 1.18,
                              weight: FontWeight.w700,
                            ),
                          ),
                          if (descriptionText.isNotEmpty) ...[
                            const SizedBox(height: ExpatlioDesign.space16),
                            Text(
                              key: eventDetailDescriptionKey,
                              descriptionText,
                              softWrap: true,
                              style: ExpatlioDesign.textStyle(
                                context,
                                color: ExpatlioDesign.muted,
                                size: 18,
                                height: 1.42,
                                weight: FontWeight.w500,
                              ),
                            ),
                          ] else if (showEventIdFallback) ...[
                            const SizedBox(height: ExpatlioDesign.space8),
                            Text(
                              eventId,
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
                          if (shouldShowDetails) ...[
                            const SizedBox(height: ExpatlioDesign.space24),
                            _EventDetailDetailsBlock(
                              startsAt: startsAt,
                              timeZoneId: timeZoneId,
                              locationName: locationLabel,
                            ),
                          ],
                          if (organizerName.isNotEmpty) ...[
                            const SizedBox(height: ExpatlioDesign.space24),
                            _EventDetailOrganizerCard(
                              displayName: organizerName,
                              photoUrl: organizerPhotoUrl,
                              onMessagePressed: onOrganizerMessagePressed,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
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

class _EventDetailDetailsBlock extends StatelessWidget {
  const _EventDetailDetailsBlock({
    required this.startsAt,
    required this.timeZoneId,
    required this.locationName,
  });

  final DateTime? startsAt;
  final String? timeZoneId;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final localStartsAt = startsAt == null
        ? null
        : _eventDetailLocalDateTime(
            startsAt: startsAt!,
            timeZoneId: timeZoneId,
          );
    final locale = FFLocalizations.of(context).languageCode;
    final placeValue = locationName.isEmpty
        ? FFLocalizations.of(context).getVariableText(
            ruText: 'Место не указано',
            enText: 'Place not specified',
          )
        : locationName;
    final shouldShowPlace = localStartsAt != null || locationName.isNotEmpty;
    final rows = <Widget>[
      if (localStartsAt != null) ...[
        _EventDetailDetailsRow(
          key: eventDetailDateRowKey,
          icon: Icons.calendar_month_outlined,
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Дата',
            enText: 'Date',
          ),
          value: _eventDetailDateLabel(
            context,
            eventLocalDateTime: localStartsAt,
            timeZoneId: timeZoneId,
          ),
        ),
        const SizedBox(height: ExpatlioDesign.space20),
        _EventDetailDetailsRow(
          key: eventDetailTimeRowKey,
          icon: Icons.schedule,
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Время',
            enText: 'Time',
          ),
          value: dateTimeFormat('Hm', localStartsAt, locale: locale),
        ),
      ],
      if (shouldShowPlace) ...[
        if (localStartsAt != null)
          const SizedBox(height: ExpatlioDesign.space20),
        _EventDetailDetailsRow(
          key: eventDetailPlaceRowKey,
          icon: Icons.location_on_outlined,
          label: FFLocalizations.of(context).getVariableText(
            ruText: 'Место',
            enText: 'Place',
          ),
          value: placeValue,
        ),
      ],
    ];

    return Container(
      key: eventDetailDetailsBlockKey,
      padding: ExpatlioDesign.cardPaddingDirectional,
      decoration: ExpatlioDesign.cardDecoration(
        borderColor: ExpatlioDesign.separator,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

class _EventDetailDetailsRow extends StatelessWidget {
  const _EventDetailDetailsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: ExpatlioDesign.softPrimaryDecoration(
                radius: ExpatlioDesign.radiusMedium,
              ),
              child: Icon(
                icon,
                color: ExpatlioDesign.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: ExpatlioDesign.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      color: ExpatlioDesign.muted,
                      size: 16,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: ExpatlioDesign.space4),
                  Text(
                    value,
                    softWrap: true,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 18,
                      weight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailOrganizerCard extends StatelessWidget {
  const _EventDetailOrganizerCard({
    required this.displayName,
    required this.photoUrl,
    required this.onMessagePressed,
  });

  final String displayName;
  final String? photoUrl;
  final VoidCallback? onMessagePressed;

  @override
  Widget build(BuildContext context) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Организатор',
      enText: 'Organizer',
    );
    final subtitle = FFLocalizations.of(context).getVariableText(
      ruText: 'Ведущий встречи',
      enText: 'Meeting host',
    );
    final semanticsLabel = '$label: $displayName. $subtitle';
    final info = Semantics(
      container: true,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: _EventDetailOrganizerInfo(
          displayName: displayName,
          photoUrl: photoUrl,
          label: label,
          subtitle: subtitle,
        ),
      ),
    );
    final action = _EventDetailOrganizerMessageButton(
      displayName: displayName,
      onPressed: onMessagePressed,
    );

    return Container(
      key: eventDetailOrganizerCardKey,
      padding: ExpatlioDesign.cardPaddingDirectional,
      decoration: ExpatlioDesign.cardDecoration(
        borderColor: ExpatlioDesign.separator,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 360) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                info,
                const SizedBox(height: ExpatlioDesign.space12),
                action,
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: info),
              const SizedBox(width: ExpatlioDesign.space12),
              SizedBox(
                width: 144,
                child: action,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EventDetailOrganizerInfo extends StatelessWidget {
  const _EventDetailOrganizerInfo({
    required this.displayName,
    required this.photoUrl,
    required this.label,
    required this.subtitle,
  });

  final String displayName;
  final String? photoUrl;
  final String label;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _EventDetailOrganizerAvatar(
          displayName: displayName,
          photoUrl: photoUrl,
        ),
        const SizedBox(width: ExpatlioDesign.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 15,
                  weight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: ExpatlioDesign.space8),
              Text(
                key: eventDetailOrganizerNameKey,
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 19,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: ExpatlioDesign.space4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 15,
                  weight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EventDetailOrganizerMessageButton extends StatelessWidget {
  const _EventDetailOrganizerMessageButton({
    required this.displayName,
    required this.onPressed,
  });

  final String displayName;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Написать',
      enText: 'Message',
    );
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Написать организатору $displayName',
      enText: 'Message organizer $displayName',
    );

    return Semantics(
      key: eventDetailOrganizerMessageButtonKey,
      button: true,
      enabled: onPressed != null,
      label: semanticsLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(
            Icons.chat_bubble_outline,
            size: 20,
          ),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(0, 48),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ExpatlioDesign.space12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
            ),
            side: BorderSide.none,
            backgroundColor: ExpatlioDesign.secondarySystemFill,
            foregroundColor: ExpatlioDesign.text,
            disabledForegroundColor: ExpatlioDesign.disabled,
            disabledBackgroundColor: ExpatlioDesign.tertiarySystemFill,
          ),
        ),
      ),
    );
  }
}

class _EventDetailOrganizerAvatar extends StatelessWidget {
  const _EventDetailOrganizerAvatar({
    required this.displayName,
    required this.photoUrl,
  });

  static const double _dimension = 56;

  final String displayName;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedPhotoUrl = photoUrl?.trim() ?? '';

    return Container(
      key: eventDetailOrganizerAvatarKey,
      width: _dimension,
      height: _dimension,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: normalizedPhotoUrl.isEmpty
          ? _fallback(context)
          : CachedNetworkImage(
              imageUrl: normalizedPhotoUrl,
              fit: BoxFit.cover,
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              memCacheWidth: (_dimension *
                      MediaQuery.devicePixelRatioOf(
                        context,
                      ))
                  .round(),
              memCacheHeight: (_dimension *
                      MediaQuery.devicePixelRatioOf(
                        context,
                      ))
                  .round(),
              placeholder: (context, _) => _fallback(context),
              errorWidget: (context, _, __) => _fallback(context),
            ),
    );
  }

  Widget _fallback(BuildContext context) {
    return Container(
      color: ExpatlioDesign.primary.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Text(
        _initials(),
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.primary,
          size: 17,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

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
    return normalizedName.characters.take(2).toString().toUpperCase();
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

DateTime _eventDetailLocalDateTime({
  required DateTime startsAt,
  required String? timeZoneId,
}) {
  final utcStartsAt = startsAt.isUtc ? startsAt : startsAt.toUtc();
  try {
    final local = timezone.TZDateTime.from(
      utcStartsAt,
      eventListTimeZoneLocation(timeZoneId ?? ''),
    );
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  } on ArgumentError {
    return startsAt.toLocal();
  }
}

String _eventDetailDateLabel(
  BuildContext context, {
  required DateTime eventLocalDateTime,
  required String? timeZoneId,
}) {
  final locale = FFLocalizations.of(context).languageCode;
  final eventLocalDate = DateTime(
    eventLocalDateTime.year,
    eventLocalDateTime.month,
    eventLocalDateTime.day,
  );
  final nowUtc = DateTime.now().toUtc();
  final today = _safeEventDetailCityLocalDate(
    timeZoneId: timeZoneId,
    utcInstant: nowUtc,
  );
  if (today != null && _sameCalendarDate(eventLocalDate, today)) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Сегодня',
      enText: 'Today',
    );
  }

  final tomorrow =
      today == null ? null : DateTime(today.year, today.month, today.day + 1);
  if (tomorrow != null && _sameCalendarDate(eventLocalDate, tomorrow)) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Завтра',
      enText: 'Tomorrow',
    );
  }

  return dateTimeFormat('d MMM', eventLocalDateTime, locale: locale);
}

DateTime? _safeEventDetailCityLocalDate({
  required String? timeZoneId,
  required DateTime utcInstant,
}) {
  try {
    return eventListCityLocalDate(
      timeZoneId: timeZoneId ?? '',
      utcInstant: utcInstant,
    );
  } on ArgumentError {
    return null;
  }
}

bool _sameCalendarDate(DateTime left, DateTime right) =>
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _eventDetailTitleLabel(BuildContext context, String? title) {
  final normalizedTitle = title?.trim() ?? '';
  if (normalizedTitle.isNotEmpty) {
    return normalizedTitle;
  }

  return FFLocalizations.of(context).getVariableText(
    ruText: 'Без названия',
    enText: 'Untitled',
  );
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
