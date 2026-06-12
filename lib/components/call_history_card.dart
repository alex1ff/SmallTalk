import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/call_details/call_details_widget.dart';
import '/shared_pages/call_history/call_history_utils.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/review_flow/review_submission_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class CallHistoryCard extends StatelessWidget {
  const CallHistoryCard({
    super.key,
    required this.session,
    required this.isTeacher,
  });

  final VideoSessionsRecord session;
  final bool isTeacher;

  String _formatStartedAtForCard(BuildContext context) {
    return formatSessionStartedAtForCard(context, session);
  }

  SessionReviewParticipantResolution get _participantResolution =>
      resolveSessionReviewParticipant(
        sessionData: session.snapshotData,
        currentUserId: currentUserUid,
      );

  bool _counterpartUsesStudentInfo(String? counterpartId) {
    return counterpartId != null &&
        counterpartId.isNotEmpty &&
        counterpartId == session.studentId.trim();
  }

  bool _counterpartUsesTutorInfo(String? counterpartId) {
    final responderIds = <String>{
      session.tutorId.trim(),
      resolveSessionResponderId(session.snapshotData) ?? '',
    }..remove('');

    return counterpartId != null &&
        counterpartId.isNotEmpty &&
        responderIds.contains(counterpartId);
  }

  String _fallbackName() {
    if (isTeacher) {
      return session.studentInfo.name.trim();
    }
    return session.tutorInfo.name.trim();
  }

  String _fallbackPhotoUrl() {
    if (isTeacher) {
      return session.studentInfo.photo.trim();
    }
    return session.tutorInfo.photo.trim();
  }

  String _rawCounterpartName() {
    final counterpartId = _participantResolution.counterpartUserId;
    if (_counterpartUsesStudentInfo(counterpartId)) {
      return session.studentInfo.name.trim();
    }
    if (_counterpartUsesTutorInfo(counterpartId)) {
      return session.tutorInfo.name.trim();
    }
    return _fallbackName();
  }

  String _rawCounterpartPhotoUrl() {
    final counterpartId = _participantResolution.counterpartUserId;
    if (_counterpartUsesStudentInfo(counterpartId)) {
      return session.studentInfo.photo.trim();
    }
    if (_counterpartUsesTutorInfo(counterpartId)) {
      return session.tutorInfo.photo.trim();
    }
    return _fallbackPhotoUrl();
  }

  String _displayName(BuildContext context) {
    final rawName = _rawCounterpartName();
    if (rawName.isNotEmpty) {
      return rawName;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: isTeacher ? 'Студент' : 'Преподаватель',
      enText: isTeacher ? 'Student' : 'Tutor',
    );
  }

  String _photoUrl() => _rawCounterpartPhotoUrl();

  bool get _currentUserWasCaller {
    final requesterId = resolveSessionRequesterId(session.snapshotData);
    if (requesterId != null && requesterId.isNotEmpty) {
      return requesterId == currentUserUid;
    }

    return session.studentId.trim() == currentUserUid;
  }

  String _callDirectionLabel(BuildContext context) {
    final currentUserWasCaller = _currentUserWasCaller;
    return FFLocalizations.of(context).getVariableText(
      ruText: currentUserWasCaller ? 'Исходящий' : 'Входящий',
      enText: currentUserWasCaller ? 'Outgoing' : 'Incoming',
    );
  }

  IconData get _callDirectionIcon => _currentUserWasCaller
      ? Icons.call_made_rounded
      : Icons.call_received_rounded;

  Color get _callDirectionColor =>
      _currentUserWasCaller ? ExpatlioDesign.muted : ExpatlioDesign.success;

  Widget _buildAvatar(BuildContext context) {
    final photoUrl = _photoUrl();
    final displayName = _displayName(context);

    return Container(
      width: 48.0,
      height: 48.0,
      decoration: const BoxDecoration(
        color: ExpatlioDesign.mutedSurface,
        shape: BoxShape.circle,
      ),
      child: photoUrl.isNotEmpty
          ? ClipOval(
              child: CachedNetworkImage(
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                imageUrl: photoUrl,
                width: 48.0,
                height: 48.0,
                fit: BoxFit.cover,
                memCacheWidth: 96,
                memCacheHeight: 96,
              ),
            )
          : Center(
              child: Text(
                displayName.characters.first.toUpperCase(),
                style: ExpatlioDesign.textStyle(
                  context,
                  color: ExpatlioDesign.muted,
                  size: 14.0,
                  weight: FontWeight.w600,
                ),
              ),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final durationLabel = formatDurationLabel(
      context,
      resolveSessionDurationSeconds(session),
    );
    final startedAtLabel = _formatStartedAtForCard(context);
    final callDirectionColor = _callDirectionColor;

    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        context.pushNamed(
          CallDetailsWidget.routeName,
          queryParameters: {
            'videoDocRef': serializeParam(
              session.reference,
              ParamType.DocumentReference,
            ),
          }.withoutNulls,
        );
      },
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 72.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsetsDirectional.only(top: ExpatlioDesign.space16),
              child: _buildAvatar(context),
            ),
            const SizedBox(width: ExpatlioDesign.space16),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 72.0),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ExpatlioDesign.border),
                  ),
                ),
                padding: const EdgeInsetsDirectional.fromSTEB(
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space16,
                    ExpatlioDesign.space0,
                    ExpatlioDesign.space16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _displayName(context),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ExpatlioDesign.textStyle(
                              context,
                              size: 16.0,
                              weight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: ExpatlioDesign.space4),
                          Row(
                            children: [
                              Icon(
                                _callDirectionIcon,
                                color: callDirectionColor,
                                size: 15.0,
                              ),
                              const SizedBox(width: ExpatlioDesign.space4),
                              Flexible(
                                child: Text(
                                  '${_callDirectionLabel(context)} · $durationLabel',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: ExpatlioDesign.textStyle(
                                    context,
                                    color: ExpatlioDesign.muted,
                                    size: 14.0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: ExpatlioDesign.space8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 112.0),
                      child: Text(
                        startedAtLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: ExpatlioDesign.textStyle(
                          context,
                          color: ExpatlioDesign.muted,
                          size: 13.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
