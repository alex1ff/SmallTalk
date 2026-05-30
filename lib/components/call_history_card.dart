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

  String _displayName(BuildContext context) {
    final rawName =
        (isTeacher ? session.studentInfo.name : session.tutorInfo.name).trim();
    if (rawName.isNotEmpty) {
      return rawName;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: isTeacher ? 'Студент' : 'Преподаватель',
      enText: isTeacher ? 'Student' : 'Tutor',
    );
  }

  String _photoUrl() =>
      (isTeacher ? session.studentInfo.photo : session.tutorInfo.photo).trim();

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
              padding: const EdgeInsetsDirectional.only(top: 14.0),
              child: _buildAvatar(context),
            ),
            const SizedBox(width: 14.0),
            Expanded(
              child: Container(
                constraints: const BoxConstraints(minHeight: 72.0),
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: ExpatlioDesign.border),
                  ),
                ),
                padding:
                    const EdgeInsetsDirectional.fromSTEB(0.0, 14.0, 0.0, 14.0),
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
                          const SizedBox(height: 3.0),
                          Row(
                            children: [
                              Icon(
                                _callDirectionIcon,
                                color: callDirectionColor,
                                size: 15.0,
                              ),
                              const SizedBox(width: 4.0),
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
                    const SizedBox(width: 8.0),
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
