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
const ValueKey<String> eventDetailParticipantsSectionKey =
    ValueKey<String>('event_detail_participants_section');
const ValueKey<String> eventDetailParticipantsTitleKey =
    ValueKey<String>('event_detail_participants_title');
const ValueKey<String> eventDetailOccupancyKey =
    ValueKey<String>('event_detail_occupancy');
const ValueKey<String> eventDetailBottomActionBarKey =
    ValueKey<String>('event_detail_bottom_action_bar');
const ValueKey<String> eventDetailPrimaryCtaKey =
    ValueKey<String>('event_detail_primary_cta');
const ValueKey<String> eventDetailChatCtaKey =
    ValueKey<String>('event_detail_chat_cta');

const Color _eventDetailDestructiveCtaBackground = Color(0xFFB42318);

ValueKey<String> eventDetailParticipantTileKey(int index) =>
    ValueKey<String>('event_detail_participant_tile_$index');

class EventDetailParticipantViewModel {
  const EventDetailParticipantViewModel({
    required this.displayName,
    this.photoUrl,
  });

  final String displayName;
  final String? photoUrl;
}

enum EventDetailJoinCtaState {
  join,
  joined,
  full,
  canceled,
  past,
}

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
    this.participants = const <EventDetailParticipantViewModel>[],
    this.participantsCount,
    this.capacity,
    this.joinCtaState = EventDetailJoinCtaState.join,
    this.onPrimaryCtaPressed,
    this.onChatPressed,
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
  final List<EventDetailParticipantViewModel> participants;
  final int? participantsCount;
  final int? capacity;
  final EventDetailJoinCtaState joinCtaState;
  final VoidCallback? onPrimaryCtaPressed;
  final VoidCallback? onChatPressed;

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
    final hasOccupancy = _eventDetailHasOccupancy(capacity);
    final resolvedParticipantsCount = _eventDetailResolvedParticipantsCount(
      participants: participants,
      participantsCount: participantsCount,
    );

    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      bottomNavigationBar: _EventDetailBottomActionBar(
        joinCtaState: joinCtaState,
        onPrimaryPressed: onPrimaryCtaPressed,
        onChatPressed: onChatPressed,
      ),
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
                          if (participants.isNotEmpty || hasOccupancy) ...[
                            const SizedBox(height: ExpatlioDesign.space24),
                            _EventDetailParticipantsSection(
                              participants: participants,
                              participantsCount: resolvedParticipantsCount,
                              capacity: hasOccupancy ? capacity : null,
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

class _EventDetailParticipantsSection extends StatelessWidget {
  const _EventDetailParticipantsSection({
    required this.participants,
    required this.participantsCount,
    required this.capacity,
  });

  final List<EventDetailParticipantViewModel> participants;
  final int participantsCount;
  final int? capacity;

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Участники',
      enText: 'Participants',
    );
    final occupancyLabel = capacity == null
        ? null
        : _eventDetailOccupancyLabel(
            context,
            participantsCount: participantsCount,
            capacity: capacity!,
          );

    return Container(
      key: eventDetailParticipantsSectionKey,
      padding: ExpatlioDesign.cardPaddingDirectional,
      decoration: ExpatlioDesign.cardDecoration(
        borderColor: ExpatlioDesign.separator,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    key: eventDetailParticipantsTitleKey,
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 20,
                      weight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              if (occupancyLabel != null) ...[
                const SizedBox(width: ExpatlioDesign.space12),
                Flexible(
                  child: _EventDetailOccupancyLabel(label: occupancyLabel),
                ),
              ],
            ],
          ),
          if (participants.isNotEmpty) ...[
            const SizedBox(height: ExpatlioDesign.space20),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileWidth = constraints.maxWidth < 360 ? 88.0 : 104.0;
                return Wrap(
                  spacing: ExpatlioDesign.space16,
                  runSpacing: ExpatlioDesign.space20,
                  children: [
                    for (var index = 0; index < participants.length; index += 1)
                      _EventDetailParticipantTile(
                        key: eventDetailParticipantTileKey(index),
                        participant: participants[index],
                        width: tileWidth,
                      ),
                  ],
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _EventDetailOccupancyLabel extends StatelessWidget {
  const _EventDetailOccupancyLabel({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Заполненность: $label',
      enText: 'Occupancy: $label',
    );

    return Semantics(
      key: eventDetailOccupancyKey,
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: Text(
          label,
          textAlign: TextAlign.end,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.muted,
            size: 16,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EventDetailParticipantTile extends StatelessWidget {
  const _EventDetailParticipantTile({
    super.key,
    required this.participant,
    required this.width,
  });

  final EventDetailParticipantViewModel participant;
  final double width;

  @override
  Widget build(BuildContext context) {
    final fallbackName = FFLocalizations.of(context).getVariableText(
      ruText: 'Участник',
      enText: 'Participant',
    );
    final displayName = participant.displayName.trim().isEmpty
        ? fallbackName
        : participant.displayName.trim();
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Участник: $displayName',
      enText: 'Participant: $displayName',
    );

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EventDetailParticipantAvatar(
                participant: participant,
                displayName: displayName,
              ),
              const SizedBox(height: ExpatlioDesign.space8),
              Text(
                displayName,
                textAlign: TextAlign.center,
                maxLines: 2,
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
      ),
    );
  }
}

class _EventDetailParticipantAvatar extends StatelessWidget {
  const _EventDetailParticipantAvatar({
    required this.participant,
    required this.displayName,
  });

  static const double _dimension = 64;

  final EventDetailParticipantViewModel participant;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    final normalizedPhotoUrl = participant.photoUrl?.trim() ?? '';

    return Container(
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
      padding: const EdgeInsets.all(ExpatlioDesign.space12),
      color: ExpatlioDesign.primary.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _initials(),
          maxLines: 1,
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.primary,
            size: 18,
            weight: FontWeight.w700,
          ),
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

class _EventDetailBottomActionBar extends StatelessWidget {
  const _EventDetailBottomActionBar({
    required this.joinCtaState,
    required this.onPrimaryPressed,
    required this.onChatPressed,
  });

  final EventDetailJoinCtaState joinCtaState;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onChatPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: eventDetailBottomActionBarKey,
      decoration: const BoxDecoration(
        color: ExpatlioDesign.card,
        border: Border(
          top: BorderSide(color: ExpatlioDesign.separator),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space24,
            ExpatlioDesign.space16,
            ExpatlioDesign.space24,
            ExpatlioDesign.space16,
          ),
          child: Align(
            alignment: AlignmentDirectional.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final primaryCta = _EventDetailPrimaryCta(
                    state: joinCtaState,
                    onPressed: onPrimaryPressed,
                  );
                  final chatCta = _EventDetailChatCta(
                    onPressed: onChatPressed,
                  );

                  if (constraints.maxWidth < 360) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        primaryCta,
                        const SizedBox(height: ExpatlioDesign.space12),
                        chatCta,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: primaryCta),
                      const SizedBox(width: ExpatlioDesign.space12),
                      SizedBox(
                        width: 120,
                        child: chatCta,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDetailPrimaryCta extends StatelessWidget {
  const _EventDetailPrimaryCta({
    required this.state,
    required this.onPressed,
  });

  final EventDetailJoinCtaState state;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = _eventDetailJoinCtaLabel(context, state);
    final semanticsLabel = _eventDetailJoinCtaSemanticsLabel(context, state);
    final enabled = switch (state) {
      EventDetailJoinCtaState.join ||
      EventDetailJoinCtaState.joined =>
        onPressed != null,
      EventDetailJoinCtaState.full ||
      EventDetailJoinCtaState.canceled ||
      EventDetailJoinCtaState.past =>
        false,
    };
    final backgroundColor = enabled
        ? switch (state) {
            EventDetailJoinCtaState.join => ExpatlioDesign.primary,
            EventDetailJoinCtaState.joined =>
              _eventDetailDestructiveCtaBackground,
            EventDetailJoinCtaState.full ||
            EventDetailJoinCtaState.canceled ||
            EventDetailJoinCtaState.past =>
              ExpatlioDesign.secondarySystemBackground,
          }
        : ExpatlioDesign.secondarySystemBackground;
    final textColor = enabled
        ? switch (state) {
            EventDetailJoinCtaState.join => Colors.white,
            EventDetailJoinCtaState.joined => Colors.white,
            EventDetailJoinCtaState.full ||
            EventDetailJoinCtaState.canceled ||
            EventDetailJoinCtaState.past =>
              ExpatlioDesign.muted,
          }
        : ExpatlioDesign.muted;

    return Semantics(
      key: eventDetailPrimaryCtaKey,
      container: true,
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      onTap: enabled ? onPressed : null,
      child: ExcludeSemantics(
        child: TextButton(
          onPressed: enabled ? onPressed : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, ExpatlioDesign.buttonHeight),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ExpatlioDesign.space16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
            ),
            backgroundColor: backgroundColor,
            disabledBackgroundColor: ExpatlioDesign.secondarySystemBackground,
            foregroundColor: Colors.white,
            disabledForegroundColor: ExpatlioDesign.muted,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: ExpatlioDesign.textStyle(
              context,
              color: textColor,
              size: 16,
              weight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDetailChatCta extends StatelessWidget {
  const _EventDetailChatCta({
    required this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Чат',
      enText: 'Chat',
    );
    final semanticsLabel = enabled
        ? label
        : FFLocalizations.of(context).getVariableText(
            ruText: 'Чат доступен только участникам',
            enText: 'Chat is available to participants only',
          );

    return Semantics(
      key: eventDetailChatCtaKey,
      container: true,
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(
            enabled ? Icons.chat_bubble_outline : Icons.lock_outline,
            size: 20,
          ),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, ExpatlioDesign.buttonHeight),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ExpatlioDesign.space12,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ExpatlioDesign.buttonRadius),
            ),
            backgroundColor: ExpatlioDesign.secondarySystemBackground,
            disabledBackgroundColor:
                ExpatlioDesign.secondarySystemBackground.withValues(
              alpha: 0.62,
            ),
            foregroundColor: ExpatlioDesign.text,
            disabledForegroundColor: ExpatlioDesign.disabled,
            textStyle: ExpatlioDesign.textStyle(
              context,
              size: 16,
              weight: FontWeight.w700,
            ),
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

bool _eventDetailHasOccupancy(int? capacity) {
  return capacity != null && capacity > 0;
}

int _eventDetailResolvedParticipantsCount({
  required List<EventDetailParticipantViewModel> participants,
  required int? participantsCount,
}) {
  final count = participantsCount;
  if (count == null) {
    return participants.length;
  }
  return count < participants.length ? participants.length : count;
}

String _eventDetailOccupancyLabel(
  BuildContext context, {
  required int participantsCount,
  required int capacity,
}) {
  final normalizedParticipantsCount =
      participantsCount < 0 ? 0 : participantsCount;
  final suffix = FFLocalizations.of(context).getVariableText(
    ruText: 'мест',
    enText: capacity == 1 ? 'spot' : 'spots',
  );
  return '$normalizedParticipantsCount/$capacity $suffix';
}

String _eventDetailJoinCtaLabel(
  BuildContext context,
  EventDetailJoinCtaState state,
) {
  return switch (state) {
    EventDetailJoinCtaState.join => FFLocalizations.of(context).getVariableText(
        ruText: 'Присоединиться',
        enText: 'Join',
      ),
    EventDetailJoinCtaState.joined =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Покинуть',
        enText: 'Leave',
      ),
    EventDetailJoinCtaState.full => FFLocalizations.of(context)
        .getVariableText(ruText: 'Мест нет', enText: 'Full'),
    EventDetailJoinCtaState.canceled => FFLocalizations.of(context)
        .getVariableText(ruText: 'Отменено', enText: 'Canceled'),
    EventDetailJoinCtaState.past => FFLocalizations.of(context)
        .getVariableText(ruText: 'Уже началось', enText: 'Already started'),
  };
}

String _eventDetailJoinCtaSemanticsLabel(
  BuildContext context,
  EventDetailJoinCtaState state,
) {
  return switch (state) {
    EventDetailJoinCtaState.join => _eventDetailJoinCtaLabel(context, state),
    EventDetailJoinCtaState.joined =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Вы участвуете. Покинуть событие',
        enText: 'Joined. Leave event',
      ),
    EventDetailJoinCtaState.full => FFLocalizations.of(context)
        .getVariableText(ruText: 'Мест нет', enText: 'Event is full'),
    EventDetailJoinCtaState.canceled => FFLocalizations.of(context)
        .getVariableText(ruText: 'Событие отменено', enText: 'Event canceled'),
    EventDetailJoinCtaState.past => FFLocalizations.of(context).getVariableText(
        ruText: 'Событие уже началось',
        enText: 'Event already started',
      ),
  };
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
