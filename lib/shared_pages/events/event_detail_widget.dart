import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:timezone/timezone.dart' as timezone;

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
const ValueKey<String> eventDetailReportButtonKey =
    ValueKey<String>('event_detail_report_button');
const ValueKey<String> eventDetailLevelRangeBadgeKey =
    ValueKey<String>('event_detail_level_range_badge');
const ValueKey<String> eventDetailLanguageBadgeKey =
    ValueKey<String>('event_detail_language_badge');
const ValueKey<String> eventDetailCanceledBannerKey =
    ValueKey<String>('event_detail_canceled_banner');
const ValueKey<String> eventDetailIntroCardKey =
    ValueKey<String>('event_detail_intro_card');
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
const ValueKey<String> eventDetailOrganizerControlsKey =
    ValueKey<String>('event_detail_organizer_controls');
const ValueKey<String> eventDetailOrganizerEditButtonKey =
    ValueKey<String>('event_detail_organizer_edit_button');
const ValueKey<String> eventDetailOrganizerCancelButtonKey =
    ValueKey<String>('event_detail_organizer_cancel_button');
const ValueKey<String> eventDetailCancelDialogKey =
    ValueKey<String>('event_detail_cancel_dialog');
const ValueKey<String> eventDetailCancelDialogDismissButtonKey =
    ValueKey<String>('event_detail_cancel_dialog_dismiss_button');
const ValueKey<String> eventDetailCancelDialogConfirmButtonKey =
    ValueKey<String>('event_detail_cancel_dialog_confirm_button');
const ValueKey<String> eventDetailLeaveDialogKey =
    ValueKey<String>('event_detail_leave_dialog');
const ValueKey<String> eventDetailLeaveDialogDismissButtonKey =
    ValueKey<String>('event_detail_leave_dialog_dismiss_button');
const ValueKey<String> eventDetailLeaveDialogConfirmButtonKey =
    ValueKey<String>('event_detail_leave_dialog_confirm_button');
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
const String _eventDetailFallbackRoutePath = '/events';

const Color _eventDetailDestructiveCtaBackground = Color(0xFFB42318);
const Color _eventDetailPageBackground = ExpatlioDesign.background;
const Color _eventDetailCardBorder = Color(0xFFEBEBEB);
const Color _eventDetailControlFill = Color(0xFFF2F2F3);
const Color _eventDetailNeutralBadgeFill = Color(0xFFF1F1F2);
const Color _eventDetailPrimaryBadgeFill = Color(0xFFEFE7FF);
const Color _eventDetailMutedText = Color(0xFF8E8E93);
const Color _eventDetailFreeSlotBorder = ExpatlioDesign.border;
const double _eventDetailCardRadius = 18;
const double _eventDetailContentHorizontalPadding = 18;
const double _eventDetailSectionGap = 16;
const double _eventDetailActionHeight = 48;
const double _eventDetailButtonRadius = 16;
const double _eventDetailCompactButtonRadius = 12;
const double _eventDetailContentBottomPadding = _eventDetailActionHeight +
    ExpatlioDesign.space16 * 2 +
    ExpatlioDesign.space16;

BoxDecoration _eventDetailCardDecoration() {
  return BoxDecoration(
    color: ExpatlioDesign.card,
    borderRadius: BorderRadius.circular(_eventDetailCardRadius),
    border: Border.all(color: _eventDetailCardBorder),
  );
}

ValueKey<String> eventDetailParticipantTileKey(int index) =>
    ValueKey<String>('event_detail_participant_tile_$index');

class EventDetailParticipantViewModel {
  const EventDetailParticipantViewModel({
    this.userId = '',
    required this.displayName,
    this.photoUrl,
  });

  final String userId;
  final String displayName;
  final String? photoUrl;
}

enum EventDetailJoinCtaState {
  join,
  joining,
  joined,
  joinedLocked,
  full,
  canceled,
  past,
}

class EventDetailWidget extends StatelessWidget {
  const EventDetailWidget({
    super.key,
    required this.eventId,
    this.onSharePressed,
    this.showReportAction = false,
    this.onReportPressed,
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
    this.showOrganizerControls = false,
    this.onOrganizerEditPressed,
    this.onOrganizerCancelPressed,
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
  final bool showReportAction;
  final VoidCallback? onReportPressed;
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
  final bool showOrganizerControls;
  final VoidCallback? onOrganizerEditPressed;
  final VoidCallback? onOrganizerCancelPressed;
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
    final isCanceled = joinCtaState == EventDetailJoinCtaState.canceled;

    return Scaffold(
      backgroundColor: _eventDetailPageBackground,
      bottomNavigationBar: _EventDetailBottomActionBar(
        eventId: eventId,
        joinCtaState: joinCtaState,
        onPrimaryPressed: onPrimaryCtaPressed,
        onChatPressed: onChatPressed,
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _EventDetailTopBar(
              onSharePressed: onSharePressed,
              showReportAction: showReportAction,
              onReportPressed: onReportPressed,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  _eventDetailContentHorizontalPadding,
                  ExpatlioDesign.space8,
                  _eventDetailContentHorizontalPadding,
                  _eventDetailContentBottomPadding,
                ),
                children: [
                  Align(
                    alignment: AlignmentDirectional.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _EventDetailIntroCard(
                            levelRangeLabel: levelRangeLabel,
                            languageLabel: languageLabel,
                            isCanceled: isCanceled,
                            titleLabel: titleLabel,
                            descriptionText: descriptionText,
                            fallbackText: showEventIdFallback ? eventId : null,
                            showOrganizerControls: showOrganizerControls,
                            onOrganizerEditPressed: onOrganizerEditPressed,
                            onOrganizerCancelPressed: onOrganizerCancelPressed,
                          ),
                          if (organizerName.isNotEmpty) ...[
                            const SizedBox(height: _eventDetailSectionGap),
                            _EventDetailOrganizerCard(
                              displayName: organizerName,
                              photoUrl: organizerPhotoUrl,
                              onMessagePressed: onOrganizerMessagePressed,
                            ),
                          ],
                          if (shouldShowDetails) ...[
                            const SizedBox(height: _eventDetailSectionGap),
                            _EventDetailDetailsBlock(
                              startsAt: startsAt,
                              timeZoneId: timeZoneId,
                              locationName: locationLabel,
                            ),
                          ],
                          if (participants.isNotEmpty || hasOccupancy) ...[
                            const SizedBox(height: _eventDetailSectionGap),
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

class _EventDetailIntroCard extends StatelessWidget {
  const _EventDetailIntroCard({
    required this.levelRangeLabel,
    required this.languageLabel,
    required this.isCanceled,
    required this.titleLabel,
    required this.descriptionText,
    required this.fallbackText,
    required this.showOrganizerControls,
    required this.onOrganizerEditPressed,
    required this.onOrganizerCancelPressed,
  });

  final String levelRangeLabel;
  final String languageLabel;
  final bool isCanceled;
  final String titleLabel;
  final String descriptionText;
  final String? fallbackText;
  final bool showOrganizerControls;
  final VoidCallback? onOrganizerEditPressed;
  final VoidCallback? onOrganizerCancelPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: eventDetailIntroCardKey,
      width: double.infinity,
      padding: const EdgeInsetsDirectional.fromSTEB(
        14,
        14,
        14,
        18,
      ),
      decoration: _eventDetailCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showOrganizerControls) ...[
            _EventDetailOrganizerControls(
              onEditPressed: onOrganizerEditPressed,
              onCancelPressed: onOrganizerCancelPressed,
            ),
            const SizedBox(height: ExpatlioDesign.space12),
          ],
          if (levelRangeLabel.isNotEmpty || languageLabel.isNotEmpty) ...[
            Wrap(
              spacing: ExpatlioDesign.space8,
              runSpacing: ExpatlioDesign.space8,
              children: [
                if (levelRangeLabel.isNotEmpty)
                  _EventDetailLevelRangeBadge(label: levelRangeLabel),
                if (languageLabel.isNotEmpty)
                  _EventDetailLanguageBadge(label: languageLabel),
              ],
            ),
            const SizedBox(height: 18),
          ],
          if (isCanceled) ...[
            const _EventDetailCanceledBanner(),
            const SizedBox(height: ExpatlioDesign.space20),
          ],
          Text(
            key: eventDetailTitleKey,
            titleLabel,
            softWrap: true,
            style: ExpatlioDesign.textStyle(
              context,
              size: 21,
              height: 1.24,
              weight: FontWeight.w700,
            ),
          ),
          if (descriptionText.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              key: eventDetailDescriptionKey,
              descriptionText,
              softWrap: true,
              style: ExpatlioDesign.textStyle(
                context,
                color: _eventDetailMutedText,
                size: 14,
                height: 1.42,
                weight: FontWeight.w400,
              ),
            ),
          ] else if (fallbackText != null) ...[
            const SizedBox(height: ExpatlioDesign.space8),
            Text(
              fallbackText!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.textStyle(
                context,
                color: _eventDetailMutedText,
                size: 13,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ],
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
          isPrimary: true,
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
          isPrimary: false,
        ),
      ),
    );
  }
}

class _EventDetailInfoBadge extends StatelessWidget {
  const _EventDetailInfoBadge({
    required this.icon,
    required this.label,
    required this.isPrimary,
  });

  final IconData icon;
  final String label;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: isPrimary
            ? _eventDetailPrimaryBadgeFill
            : _eventDetailNeutralBadgeFill,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isPrimary ? ExpatlioDesign.primary : ExpatlioDesign.text,
            size: 14,
          ),
          const SizedBox(width: ExpatlioDesign.space4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: isPrimary ? ExpatlioDesign.primary : ExpatlioDesign.text,
              size: 12,
              weight: FontWeight.w700,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventDetailCanceledBanner extends StatelessWidget {
  const _EventDetailCanceledBanner();

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Событие отменено',
      enText: 'Event canceled',
    );
    final description = FFLocalizations.of(context).getVariableText(
      ruText: 'Присоединение и новые действия недоступны.',
      enText: 'Joining and new actions are unavailable.',
    );

    return Semantics(
      key: eventDetailCanceledBannerKey,
      container: true,
      label: '$title. $description',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsetsDirectional.all(ExpatlioDesign.space16),
          decoration: BoxDecoration(
            color: _eventDetailDestructiveCtaBackground.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
            border: Border.all(color: ExpatlioDesign.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.event_busy_outlined,
                color: _eventDetailDestructiveCtaBackground,
                size: 24,
              ),
              const SizedBox(width: ExpatlioDesign.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: _eventDetailDestructiveCtaBackground,
                        size: 18,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space4),
                    Text(
                      description,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.muted,
                        size: 15,
                        height: 1.32,
                        weight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        const SizedBox(height: 14),
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
        if (localStartsAt != null) const SizedBox(height: 14),
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
      padding: const EdgeInsetsDirectional.fromSTEB(
        14,
        16,
        14,
        16,
      ),
      decoration: _eventDetailCardDecoration(),
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
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _eventDetailPrimaryBadgeFill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: ExpatlioDesign.primary,
                size: 17,
              ),
            ),
            const SizedBox(width: 14),
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
                      color: _eventDetailMutedText,
                      size: 13,
                      weight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    softWrap: true,
                    style: ExpatlioDesign.textStyle(
                      context,
                      size: 14,
                      weight: FontWeight.w600,
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
          subtitle: subtitle,
        ),
      ),
    );
    final action = onMessagePressed == null
        ? null
        : _EventDetailOrganizerMessageButton(
            displayName: displayName,
            onPressed: onMessagePressed,
          );

    return Container(
      key: eventDetailOrganizerCardKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        14,
        14,
        14,
        14,
      ),
      decoration: _eventDetailCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: _eventDetailMutedText,
              size: 13,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 340) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    info,
                    if (action != null) ...[
                      const SizedBox(height: ExpatlioDesign.space12),
                      action,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: info),
                  if (action != null) ...[
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 118,
                      child: action,
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EventDetailOrganizerInfo extends StatelessWidget {
  const _EventDetailOrganizerInfo({
    required this.displayName,
    required this.photoUrl,
    required this.subtitle,
  });

  final String displayName;
  final String? photoUrl;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _EventDetailOrganizerAvatar(
          displayName: displayName,
          photoUrl: photoUrl,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                key: eventDetailOrganizerNameKey,
                displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  size: 14,
                  weight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: ExpatlioDesign.space4),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: _eventDetailMutedText,
                  size: 12,
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
        child: SizedBox(
          height: 34,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: SvgPicture.asset(
              ExpatlioDesign.chatIconAsset,
              width: 16,
              height: 16,
              colorFilter: const ColorFilter.mode(
                ExpatlioDesign.text,
                BlendMode.srcIn,
              ),
            ),
            label: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: ExpatlioDesign.space12,
              ),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(_eventDetailCompactButtonRadius),
              ),
              side: BorderSide.none,
              backgroundColor: _eventDetailControlFill,
              foregroundColor: ExpatlioDesign.text,
              disabledForegroundColor: ExpatlioDesign.disabled,
              disabledBackgroundColor: ExpatlioDesign.tertiarySystemFill,
              textStyle: ExpatlioDesign.textStyle(
                context,
                size: 13,
                weight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EventDetailOrganizerControls extends StatelessWidget {
  const _EventDetailOrganizerControls({
    required this.onEditPressed,
    required this.onCancelPressed,
  });

  final VoidCallback? onEditPressed;
  final VoidCallback? onCancelPressed;

  Future<void> _confirmCancel(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: eventDetailCancelDialogKey,
          title: Text(
            FFLocalizations.of(dialogContext).getVariableText(
              ruText: 'Отменить событие?',
              enText: 'Cancel event?',
            ),
          ),
          content: Text(
            FFLocalizations.of(dialogContext).getVariableText(
              ruText:
                  'Участники больше не смогут присоединиться. Событие останется доступно по прямой ссылке.',
              enText:
                  'Participants will no longer be able to join. The event will remain available by direct link.',
            ),
          ),
          actions: [
            TextButton(
              key: eventDetailCancelDialogDismissButtonKey,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                FFLocalizations.of(dialogContext).getVariableText(
                  ruText: 'Не отменять',
                  enText: 'Keep event',
                ),
              ),
            ),
            TextButton(
              key: eventDetailCancelDialogConfirmButtonKey,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                FFLocalizations.of(dialogContext).getVariableText(
                  ruText: 'Отменить событие',
                  enText: 'Cancel event',
                ),
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      onCancelPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final editButton = _EventDetailOrganizerControlButton(
      key: eventDetailOrganizerEditButtonKey,
      icon: Icons.edit_outlined,
      label: FFLocalizations.of(context).getVariableText(
        ruText: 'Редактировать',
        enText: 'Edit',
      ),
      semanticsLabel: FFLocalizations.of(context).getVariableText(
        ruText: 'Редактировать событие',
        enText: 'Edit event',
      ),
      onPressed: onEditPressed,
    );
    final cancelButton = _EventDetailOrganizerControlButton(
      key: eventDetailOrganizerCancelButtonKey,
      icon: Icons.event_busy_outlined,
      label: FFLocalizations.of(context).getVariableText(
        ruText: 'Отменить',
        enText: 'Cancel',
      ),
      semanticsLabel: FFLocalizations.of(context).getVariableText(
        ruText: 'Отменить событие',
        enText: 'Cancel event',
      ),
      onPressed: onCancelPressed == null
          ? null
          : () {
              unawaited(_confirmCancel(context));
            },
      isDestructive: true,
    );

    return LayoutBuilder(
      key: eventDetailOrganizerControlsKey,
      builder: (context, constraints) {
        return Row(
          children: [
            Expanded(child: editButton),
            const SizedBox(width: ExpatlioDesign.space8),
            Expanded(child: cancelButton),
          ],
        );
      },
    );
  }
}

class _EventDetailOrganizerControlButton extends StatelessWidget {
  const _EventDetailOrganizerControlButton({
    super.key,
    required this.icon,
    required this.label,
    required this.semanticsLabel,
    required this.onPressed,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final String semanticsLabel;
  final VoidCallback? onPressed;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foregroundColor = enabled
        ? isDestructive
            ? _eventDetailDestructiveCtaBackground
            : ExpatlioDesign.text
        : ExpatlioDesign.disabled;
    final backgroundColor = isDestructive && enabled
        ? _eventDetailDestructiveCtaBackground.withValues(alpha: 0.10)
        : _eventDetailControlFill;

    return Semantics(
      container: true,
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: TextButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 17),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, 36),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ExpatlioDesign.space8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_eventDetailButtonRadius),
            ),
            backgroundColor: backgroundColor,
            disabledBackgroundColor: _eventDetailControlFill,
            foregroundColor: foregroundColor,
            disabledForegroundColor: ExpatlioDesign.disabled,
            textStyle: ExpatlioDesign.textStyle(
              context,
              size: 12,
              weight: FontWeight.w600,
            ),
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
    final visibleOccupiedPlaceholderCount =
        _eventDetailVisibleOccupiedPlaceholderCount(
      participantsCount: participantsCount,
      participantTileCount: participants.length,
    );
    final visibleFreeSlotCount = _eventDetailVisibleFreeSlotCount(
      capacity: capacity,
      occupiedTileCount: participants.length + visibleOccupiedPlaceholderCount,
    );
    final hasParticipantTiles = participants.isNotEmpty ||
        visibleOccupiedPlaceholderCount > 0 ||
        visibleFreeSlotCount > 0;
    final freeSlotLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Свободно',
      enText: 'Free',
    );

    return Container(
      key: eventDetailParticipantsSectionKey,
      padding: const EdgeInsetsDirectional.fromSTEB(
        14,
        16,
        14,
        18,
      ),
      decoration: _eventDetailCardDecoration(),
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
                      size: 15,
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
          if (hasParticipantTiles) ...[
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                const maxColumns = 5;
                const spacing = 8.0;
                final availableWidth = constraints.maxWidth;
                final columns = maxColumns;
                final rawTileWidth =
                    (availableWidth - (spacing * (columns - 1))) / columns;
                final tileWidth = rawTileWidth < 52 ? 52.0 : rawTileWidth;
                return Wrap(
                  spacing: spacing,
                  runSpacing: ExpatlioDesign.space16,
                  children: [
                    for (var index = 0; index < participants.length; index += 1)
                      _EventDetailParticipantTile(
                        key: eventDetailParticipantTileKey(index),
                        participant: participants[index],
                        width: tileWidth,
                      ),
                    for (var index = 0;
                        index < visibleOccupiedPlaceholderCount;
                        index += 1)
                      _EventDetailOccupiedParticipantTile(
                        width: tileWidth,
                      ),
                    for (var index = 0;
                        index < visibleFreeSlotCount;
                        index += 1)
                      _EventDetailFreeParticipantTile(
                        label: freeSlotLabel,
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
            color: _eventDetailMutedText,
            size: 12,
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
    final displayName = participant.displayName.trim();
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: displayName.isEmpty ? 'Участник' : 'Участник: $displayName',
      enText: displayName.isEmpty ? 'Participant' : 'Participant: $displayName',
    );

    return Semantics(
      container: true,
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
              if (displayName.isNotEmpty) ...[
                const SizedBox(height: ExpatlioDesign.space8),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: _eventDetailMutedText,
                    size: 13,
                    weight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDetailFreeParticipantTile extends StatelessWidget {
  const _EventDetailFreeParticipantTile({
    required this.label,
    required this.width,
  });

  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Свободное место',
      enText: 'Free spot',
    );

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _EventDetailFreeSlotAvatar(),
              const SizedBox(height: ExpatlioDesign.space8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ExpatlioDesign.textStyle(
                  context,
                  color: _eventDetailMutedText,
                  size: 12,
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

class _EventDetailOccupiedParticipantTile extends StatelessWidget {
  const _EventDetailOccupiedParticipantTile({
    required this.width,
  });

  final double width;

  @override
  Widget build(BuildContext context) {
    final semanticsLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Участник',
      enText: 'Participant',
    );

    return Semantics(
      label: semanticsLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const _EventDetailOccupiedSlotAvatar(),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDetailOccupiedSlotAvatar extends StatelessWidget {
  const _EventDetailOccupiedSlotAvatar();

  static const double _dimension = 52;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _dimension,
      height: _dimension,
      decoration: const BoxDecoration(
        color: ExpatlioDesign.avatarFallbackBackground,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_outline,
        color: ExpatlioDesign.avatarFallbackText,
        size: 18,
      ),
    );
  }
}

class _EventDetailFreeSlotAvatar extends StatelessWidget {
  const _EventDetailFreeSlotAvatar();

  static const double _dimension = 52;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _dimension,
      child: CustomPaint(
        painter: const _EventDetailDashedCirclePainter(),
        child: Icon(
          Icons.person_outline,
          color: ExpatlioDesign.systemGray3,
          size: 20,
        ),
      ),
    );
  }
}

class _EventDetailDashedCirclePainter extends CustomPainter {
  const _EventDetailDashedCirclePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _eventDetailFreeSlotBorder
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2;
    final path = Path()
      ..addOval(
        Rect.fromLTWH(
          1,
          1,
          size.width - 2,
          size.height - 2,
        ),
      );

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + 5),
          paint,
        );
        distance += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EventDetailDashedCirclePainter oldDelegate) {
    return false;
  }
}

class _EventDetailParticipantAvatar extends StatelessWidget {
  const _EventDetailParticipantAvatar({
    required this.participant,
    required this.displayName,
  });

  static const double _dimension = 52;

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
    if (displayName.trim().isEmpty) {
      return const ColoredBox(
        color: ExpatlioDesign.avatarFallbackBackground,
        child: Icon(
          Icons.person_outline,
          color: ExpatlioDesign.avatarFallbackText,
          size: 18,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(ExpatlioDesign.space12),
      color: ExpatlioDesign.avatarFallbackBackground,
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          ExpatlioDesign.avatarInitial(displayName),
          maxLines: 1,
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.avatarFallbackText,
            size: 16,
            weight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _EventDetailBottomActionBar extends StatelessWidget {
  const _EventDetailBottomActionBar({
    required this.eventId,
    required this.joinCtaState,
    required this.onPrimaryPressed,
    required this.onChatPressed,
  });

  final String eventId;
  final EventDetailJoinCtaState joinCtaState;
  final VoidCallback? onPrimaryPressed;
  final VoidCallback? onChatPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: eventDetailBottomActionBarKey,
      decoration: const BoxDecoration(
        color: ExpatlioDesign.background,
        border: Border(
          top: BorderSide(color: _eventDetailCardBorder),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            _eventDetailContentHorizontalPadding,
            ExpatlioDesign.space12,
            _eventDetailContentHorizontalPadding,
            ExpatlioDesign.space12,
          ),
          child: Align(
            alignment: AlignmentDirectional.center,
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final primaryCta = _EventDetailPrimaryCta(
                    eventId: eventId,
                    state: joinCtaState,
                    onPressed: onPrimaryPressed,
                  );
                  final chatCta = onChatPressed == null
                      ? null
                      : _EventDetailChatCta(
                          onPressed: onChatPressed,
                        );

                  if (constraints.maxWidth < 320) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        primaryCta,
                        if (chatCta != null) ...[
                          const SizedBox(height: ExpatlioDesign.space12),
                          chatCta,
                        ],
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: primaryCta),
                      if (chatCta != null) ...[
                        const SizedBox(width: ExpatlioDesign.space12),
                        SizedBox(
                          width: 78,
                          child: chatCta,
                        ),
                      ],
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

class _EventDetailPrimaryCta extends StatefulWidget {
  const _EventDetailPrimaryCta({
    required this.eventId,
    required this.state,
    required this.onPressed,
  });

  final String eventId;
  final EventDetailJoinCtaState state;
  final VoidCallback? onPressed;

  @override
  State<_EventDetailPrimaryCta> createState() => _EventDetailPrimaryCtaState();
}

class _EventDetailPrimaryCtaState extends State<_EventDetailPrimaryCta> {
  int _confirmationGeneration = 0;

  @override
  void didUpdateWidget(covariant _EventDetailPrimaryCta oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.state != widget.state ||
        (oldWidget.onPressed == null) != (widget.onPressed == null)) {
      _confirmationGeneration += 1;
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final generation = _confirmationGeneration;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          key: eventDetailLeaveDialogKey,
          title: Text(
            FFLocalizations.of(dialogContext).getVariableText(
              ruText: 'Покинуть событие?',
              enText: 'Leave event?',
            ),
          ),
          content: Text(
            FFLocalizations.of(dialogContext).getVariableText(
              ruText:
                  'Вы потеряете место в списке участников. Вернуться можно будет, если останутся свободные места.',
              enText:
                  'You will lose your participant spot. You can join again if there are still open spots.',
            ),
          ),
          actions: [
            TextButton(
              key: eventDetailLeaveDialogDismissButtonKey,
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                FFLocalizations.of(dialogContext).getVariableText(
                  ruText: 'Остаться',
                  enText: 'Stay',
                ),
              ),
            ),
            TextButton(
              key: eventDetailLeaveDialogConfirmButtonKey,
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(
                FFLocalizations.of(dialogContext).getVariableText(
                  ruText: 'Покинуть событие',
                  enText: 'Leave event',
                ),
              ),
            ),
          ],
        );
      },
    );
    if (!mounted || generation != _confirmationGeneration) {
      return;
    }
    if (confirmed == true && widget.state == EventDetailJoinCtaState.joined) {
      widget.onPressed?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final label = _eventDetailJoinCtaLabel(context, state);
    final semanticsLabel = _eventDetailJoinCtaSemanticsLabel(context, state);
    final enabled = switch (state) {
      EventDetailJoinCtaState.join ||
      EventDetailJoinCtaState.joined =>
        widget.onPressed != null,
      EventDetailJoinCtaState.joinedLocked ||
      EventDetailJoinCtaState.joining ||
      EventDetailJoinCtaState.full ||
      EventDetailJoinCtaState.canceled ||
      EventDetailJoinCtaState.past =>
        false,
    };
    final backgroundColor = enabled
        ? switch (state) {
            EventDetailJoinCtaState.join => ExpatlioDesign.primary,
            EventDetailJoinCtaState.joining =>
              ExpatlioDesign.secondarySystemBackground,
            EventDetailJoinCtaState.joined =>
              _eventDetailDestructiveCtaBackground,
            EventDetailJoinCtaState.joinedLocked =>
              ExpatlioDesign.secondarySystemBackground,
            EventDetailJoinCtaState.full ||
            EventDetailJoinCtaState.canceled ||
            EventDetailJoinCtaState.past =>
              ExpatlioDesign.secondarySystemBackground,
          }
        : ExpatlioDesign.secondarySystemBackground;
    final textColor = enabled
        ? switch (state) {
            EventDetailJoinCtaState.join => Colors.white,
            EventDetailJoinCtaState.joining => ExpatlioDesign.muted,
            EventDetailJoinCtaState.joined => Colors.white,
            EventDetailJoinCtaState.joinedLocked => ExpatlioDesign.muted,
            EventDetailJoinCtaState.full ||
            EventDetailJoinCtaState.canceled ||
            EventDetailJoinCtaState.past =>
              ExpatlioDesign.muted,
          }
        : ExpatlioDesign.muted;
    final effectiveOnPressed = enabled
        ? state == EventDetailJoinCtaState.joined
            ? () {
                unawaited(_confirmLeave(context));
              }
            : widget.onPressed
        : null;

    return Semantics(
      key: eventDetailPrimaryCtaKey,
      container: true,
      button: true,
      enabled: enabled,
      label: semanticsLabel,
      onTap: effectiveOnPressed,
      child: ExcludeSemantics(
        child: TextButton(
          onPressed: effectiveOnPressed,
          style: TextButton.styleFrom(
            minimumSize: const Size(0, _eventDetailActionHeight),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ExpatlioDesign.space16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_eventDetailButtonRadius),
            ),
            backgroundColor: backgroundColor,
            disabledBackgroundColor: _eventDetailControlFill,
            foregroundColor: Colors.white,
            disabledForegroundColor: ExpatlioDesign.muted,
          ),
          child: state == EventDetailJoinCtaState.joining
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        valueColor: AlwaysStoppedAnimation<Color>(textColor),
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: textColor,
                          size: 15,
                          weight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: ExpatlioDesign.textStyle(
                    context,
                    color: textColor,
                    size: 15,
                    weight: FontWeight.w600,
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
    final foregroundColor = ExpatlioDesign.text;
    const backgroundColor = _eventDetailControlFill;
    final label = FFLocalizations.of(context).getVariableText(
      ruText: 'Чат',
      enText: 'Chat',
    );
    final semanticsLabel = label;

    return Semantics(
      key: eventDetailChatCtaKey,
      container: true,
      button: true,
      enabled: true,
      label: semanticsLabel,
      onTap: onPressed,
      child: ExcludeSemantics(
        child: TextButton.icon(
          onPressed: onPressed,
          icon: SvgPicture.asset(
            ExpatlioDesign.chatIconAsset,
            width: 20,
            height: 20,
            colorFilter: const ColorFilter.mode(
              ExpatlioDesign.text,
              BlendMode.srcIn,
            ),
          ),
          label: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, _eventDetailActionHeight),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(_eventDetailButtonRadius),
            ),
            backgroundColor: backgroundColor,
            disabledBackgroundColor: backgroundColor,
            foregroundColor: foregroundColor,
            disabledForegroundColor: foregroundColor,
            textStyle: ExpatlioDesign.textStyle(
              context,
              size: 15,
              weight: FontWeight.w600,
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

  static const double _dimension = 44;

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
      color: ExpatlioDesign.avatarFallbackBackground,
      alignment: Alignment.center,
      child: Text(
        ExpatlioDesign.avatarInitial(displayName),
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.avatarFallbackText,
          size: 16,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventDetailTopBar extends StatelessWidget {
  const _EventDetailTopBar({
    required this.onSharePressed,
    required this.showReportAction,
    required this.onReportPressed,
  });

  final VoidCallback? onSharePressed;
  final bool showReportAction;
  final VoidCallback? onReportPressed;

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
    final reportLabel = FFLocalizations.of(context).getVariableText(
      ruText: 'Пожаловаться на событие',
      enText: 'Report event',
    );
    void handleBackPressed() {
      if (context.canPop()) {
        context.pop();
        return;
      }

      context.go(_eventDetailFallbackRoutePath);
    }

    return SizedBox(
      key: eventDetailTopBarKey,
      height: 52,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: _eventDetailContentHorizontalPadding,
        ),
        child: Stack(
          alignment: AlignmentDirectional.center,
          children: [
            PositionedDirectional(
              start: 0,
              child: Tooltip(
                message: backLabel,
                child: Semantics(
                  key: eventDetailBackButtonKey,
                  button: true,
                  label: backLabel,
                  onTap: handleBackPressed,
                  child: ExcludeSemantics(
                    child: _EventDetailTopBarIconButton(
                      icon: Icons.arrow_back,
                      onPressed: handleBackPressed,
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(horizontal: 96),
              child: Center(
                child: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Событие',
                    enText: 'Event',
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ExpatlioDesign.textStyle(
                    context,
                    size: 17,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            PositionedDirectional(
              end: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Tooltip(
                    message: shareLabel,
                    child: Semantics(
                      key: eventDetailShareButtonKey,
                      button: true,
                      enabled: onSharePressed != null,
                      label: shareLabel,
                      onTap: onSharePressed,
                      child: ExcludeSemantics(
                        child: _EventDetailTopBarIconButton(
                          icon: Icons.share_outlined,
                          onPressed: onSharePressed,
                        ),
                      ),
                    ),
                  ),
                  if (showReportAction) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: reportLabel,
                      child: Semantics(
                        key: eventDetailReportButtonKey,
                        button: true,
                        enabled: onReportPressed != null,
                        label: reportLabel,
                        onTap: onReportPressed,
                        child: ExcludeSemantics(
                          child: _EventDetailTopBarIconButton(
                            icon: Icons.flag_outlined,
                            onPressed: onReportPressed,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventDetailTopBarIconButton extends StatelessWidget {
  const _EventDetailTopBarIconButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;

    return Material(
      color: _eventDetailControlFill,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: SizedBox.square(
        dimension: 36,
        child: InkResponse(
          onTap: onPressed,
          radius: 18,
          child: Center(
            child: Icon(
              icon,
              color: enabled ? ExpatlioDesign.text : ExpatlioDesign.disabled,
              size: 20,
            ),
          ),
        ),
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

int _eventDetailVisibleOccupiedPlaceholderCount({
  required int participantsCount,
  required int participantTileCount,
}) {
  final normalizedParticipantsCount =
      participantsCount < 0 ? 0 : participantsCount;
  final missingParticipants =
      normalizedParticipantsCount - participantTileCount;
  if (missingParticipants <= 0) {
    return 0;
  }
  return missingParticipants > 10 ? 10 : missingParticipants;
}

int _eventDetailVisibleFreeSlotCount({
  required int? capacity,
  required int occupiedTileCount,
}) {
  if (capacity == null || occupiedTileCount <= 0) {
    return 0;
  }
  final openSlots = capacity - occupiedTileCount;
  if (openSlots <= 0) {
    return 0;
  }
  final visibleCapacityLeft = 10 - occupiedTileCount;
  if (visibleCapacityLeft <= 0) {
    return 0;
  }
  final visibleOpenSlots =
      openSlots < visibleCapacityLeft ? openSlots : visibleCapacityLeft;
  return visibleOpenSlots > 10 ? 10 : visibleOpenSlots;
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
    EventDetailJoinCtaState.joining =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Присоединяемся...',
        enText: 'Joining...',
      ),
    EventDetailJoinCtaState.joined =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Покинуть',
        enText: 'Leave',
      ),
    EventDetailJoinCtaState.joinedLocked =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Вы участвуете',
        enText: 'Joined',
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
    EventDetailJoinCtaState.joining =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Присоединяемся к событию',
        enText: 'Joining event',
      ),
    EventDetailJoinCtaState.joined =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Вы участвуете. Покинуть событие',
        enText: 'Joined. Leave event',
      ),
    EventDetailJoinCtaState.joinedLocked =>
      FFLocalizations.of(context).getVariableText(
        ruText: 'Вы участвуете',
        enText: 'Joined',
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
