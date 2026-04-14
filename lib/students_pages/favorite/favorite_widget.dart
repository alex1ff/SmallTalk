import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import '/services/user_match_profile.dart';
import '/shared_pages/call_history/call_history_utils.dart';

import 'favorite_model.dart';
export 'favorite_model.dart';

class FavoriteWidget extends StatefulWidget {
  const FavoriteWidget({super.key});

  static String routeName = 'favorite';
  static String routePath = '/favorite';

  @override
  State<FavoriteWidget> createState() => _FavoriteWidgetState();
}

class _FavoriteWidgetState extends State<FavoriteWidget> {
  late FavoriteModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final _userFutureCache = <String, Future<UsersRecord>>{};
  final _recentCallsFutureCache = <String, Future<List<VideoSessionsRecord>>>{};

  Future<UsersRecord> _getUserFuture(DocumentReference ref) {
    return _userFutureCache.putIfAbsent(
      ref.path,
      () => UsersRecord.getDocumentOnce(ref),
    );
  }

  Future<List<VideoSessionsRecord>> _getRecentCallsFuture(String currentUid) {
    return _recentCallsFutureCache.putIfAbsent(
      '$currentUid:5',
      () => fetchRecentHubCallSessions(
        currentUid,
        limit: 5,
      ),
    );
  }

  bool _isTeacher(BuildContext context) =>
      canAccessTeacherSurfaces(currentUserDocument);

  DocumentReference? _otherParticipantRef(ConversationsRecord conversation) {
    final currentRef = currentUserReference;
    if (currentRef == null) {
      return null;
    }

    for (final participantRef in conversation.participantRefs) {
      if (participantRef.path != currentRef.path) {
        return participantRef;
      }
    }

    return null;
  }

  String _formatInboxTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return '';
    }

    final locale = FFLocalizations.of(context).languageCode;
    final localTime = timestamp.toLocal();
    final today = DateTime.now();
    final sameDay = DateTime(
          today.year,
          today.month,
          today.day,
        ) ==
        DateTime(
          localTime.year,
          localTime.month,
          localTime.day,
        );

    if (sameDay) {
      return DateFormat.jm(locale).format(localTime);
    }

    return DateFormat('d MMM, HH:mm', locale).format(localTime);
  }

  Future<void> _openConversation(ConversationsRecord conversation) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) =>
            ChatThreadWidget(conversationRef: conversation.reference),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 50.0,
        height: 50.0,
        child: SpinKitCircle(
          color: FlutterFlowTheme.of(context).secondary,
          size: 50.0,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            FlutterFlowTheme.of(context).secondaryBackground,
            const Color(0xEFF2F2F7),
            const Color(0x00F2F2F7),
          ],
          stops: const [0.0, 0.8, 1.0],
          begin: const AlignmentDirectional(0.0, -1.0),
          end: const AlignmentDirectional(0.0, 1.0),
        ),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12.0, 55.0, 12.0, 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 45.0,
              height: 45.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
            ),
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Чаты',
                enText: 'Chats',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'Cool',
                    fontSize: 18.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.normal,
                  ),
            ),
            Container(
              width: 45.0,
              height: 45.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(
    BuildContext context, {
    required String title,
    String? subtitle,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(10.0, 18.0, 10.0, 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Cool',
                  fontSize: 24.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.normal,
                ),
          ),
          if (subtitle != null)
            Text(
              subtitle,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: FlutterFlowTheme.of(context).secondaryText,
                    fontSize: 13.0,
                    letterSpacing: 0.0,
                  ),
            ),
        ],
      ),
    );
  }

  Widget _conversationCard(
    BuildContext context, {
    required ConversationsRecord conversation,
  }) {
    final partnerRef = _otherParticipantRef(conversation);
    if (partnerRef == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<UsersRecord>(
      future: _getUserFuture(partnerRef),
      builder: (context, partnerSnapshot) {
        if (!partnerSnapshot.hasData) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            child: _buildLoadingState(context),
          );
        }

        final partner = partnerSnapshot.data!;
        final unread =
            conversationIsUnreadForUser(conversation, currentUserUid);
        final lastMessageText = (conversation.lastMessageText ?? '').trim();
        final subtitle = lastMessageText.isNotEmpty
            ? lastMessageText
            : FFLocalizations.of(context).getVariableText(
                ruText: 'Чат открыт',
                enText: 'Chat unlocked',
              );

        return InkWell(
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: () => _openConversation(conversation),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 6.0),
            decoration: BoxDecoration(
              color: FlutterFlowTheme.of(context).primaryBackground,
              borderRadius: BorderRadius.circular(26.0),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Row(
                children: [
                  Container(
                    width: 54.0,
                    height: 54.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).secondaryBackground,
                      borderRadius: BorderRadius.circular(20.0),
                      image: partner.photoUrl.isNotEmpty
                          ? DecorationImage(
                              fit: BoxFit.cover,
                              image: CachedNetworkImageProvider(
                                partner.photoUrl,
                                maxWidth: 108,
                                maxHeight: 108,
                              ),
                            )
                          : null,
                    ),
                    child: partner.photoUrl.isEmpty
                        ? Icon(
                            Icons.person_rounded,
                            color: FlutterFlowTheme.of(context).secondaryText,
                          )
                        : null,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          12.0, 0.0, 0.0, 0.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  partner.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        fontSize: 16.0,
                                        fontWeight: unread
                                            ? FontWeight.w600
                                            : FontWeight.w500,
                                        letterSpacing: 0.0,
                                      ),
                                ),
                              ),
                              if (unread)
                                Container(
                                  width: 8.0,
                                  height: 8.0,
                                  decoration: BoxDecoration(
                                    color: FlutterFlowTheme.of(context).primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4.0),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: FlutterFlowTheme.of(context)
                                      .secondaryText,
                                  fontSize: 14.0,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 10.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatInboxTimestamp(
                            conversation.lastMessageAt ??
                                conversation.unlockedAt,
                          ),
                          style: FlutterFlowTheme.of(context)
                              .bodyMedium
                              .override(
                                fontFamily: 'sf pro display',
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                fontSize: 12.0,
                                letterSpacing: 0.0,
                              ),
                        ),
                        const SizedBox(height: 8.0),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: FlutterFlowTheme.of(context).secondaryText,
                          size: 18.0,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _friendCard(
    BuildContext context, {
    required UsersRecord friend,
    required ConversationsRecord? conversation,
  }) {
    final hasOpenChat = conversation != null && conversation.isUnlocked;

    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => NativeSpeakerPageWidget(
              nsUserDocRef: friend.reference,
              hideDirectCallAction: true,
            ),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(26.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              Container(
                width: 54.0,
                height: 54.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(20.0),
                  image: friend.photoUrl.isNotEmpty
                      ? DecorationImage(
                          fit: BoxFit.cover,
                          image: CachedNetworkImageProvider(
                            friend.photoUrl,
                            maxWidth: 108,
                            maxHeight: 108,
                          ),
                        )
                      : null,
                ),
                child: friend.photoUrl.isEmpty
                    ? Icon(
                        Icons.person_rounded,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      )
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
                  child: Text(
                    friend.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'sf pro display',
                          fontSize: 16.0,
                          letterSpacing: 0.0,
                        ),
                  ),
                ),
              ),
              if (hasOpenChat)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 10.0),
                  child: OutlinedButton(
                    onPressed: () => _openConversation(conversation),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: FlutterFlowTheme.of(context).primary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12.0,
                        vertical: 10.0,
                      ),
                    ),
                    child: Text(
                      FFLocalizations.of(context).getVariableText(
                        ruText: 'Открыть чат',
                        enText: 'Open chat',
                      ),
                      style: FlutterFlowTheme.of(context).bodyMedium.override(
                            fontFamily: 'sf pro display',
                            color: FlutterFlowTheme.of(context).primary,
                            fontSize: 13.0,
                            letterSpacing: 0.0,
                          ),
                    ),
                  ),
                ),
              const SizedBox(width: 6.0),
              FlutterFlowIconButton(
                borderRadius: 14.0,
                buttonSize: 42.0,
                fillColor: FlutterFlowTheme.of(context).secondaryBackground,
                icon: Icon(
                  FFIcons.kchevronRight,
                  color: FlutterFlowTheme.of(context).secondaryText,
                  size: 18.0,
                ),
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (context) => NativeSpeakerPageWidget(
                        nsUserDocRef: friend.reference,
                        hideDirectCallAction: true,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _callCard(
    BuildContext context, {
    required VideoSessionsRecord session,
  }) {
    final teacher = _isTeacher(context);
    final peerName =
        (teacher ? session.studentInfo.name : session.tutorInfo.name).trim();
    final peerPhoto =
        (teacher ? session.studentInfo.photo : session.tutorInfo.photo).trim();

    return InkWell(
      splashColor: Colors.transparent,
      focusColor: Colors.transparent,
      hoverColor: Colors.transparent,
      highlightColor: Colors.transparent,
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) =>
                CallDetailsWidget(videoDocRef: session.reference),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 6.0),
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(26.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              Container(
                width: 54.0,
                height: 54.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(20.0),
                  image: peerPhoto.isNotEmpty
                      ? DecorationImage(
                          fit: BoxFit.cover,
                          image: CachedNetworkImageProvider(
                            peerPhoto,
                            maxWidth: 108,
                            maxHeight: 108,
                          ),
                        )
                      : null,
                ),
                child: peerPhoto.isEmpty
                    ? Icon(
                        Icons.call_rounded,
                        color: FlutterFlowTheme.of(context).secondaryText,
                      )
                    : null,
              ),
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(12.0, 0.0, 0.0, 0.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        peerName.isNotEmpty
                            ? peerName
                            : FFLocalizations.of(context).getVariableText(
                                ruText: 'Собеседник',
                                enText: 'Partner',
                              ),
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                            ),
                      ),
                      const SizedBox(height: 4.0),
                      Text(
                        formatSessionStartedAtForCard(context, session),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: FlutterFlowTheme.of(context).secondaryText,
                              fontSize: 14.0,
                              letterSpacing: 0.0,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Text(
                formatDurationLabel(
                    context, resolveSessionDurationSeconds(session)),
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: FlutterFlowTheme.of(context).secondaryText,
                      fontSize: 12.0,
                      letterSpacing: 0.0,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyHubState(BuildContext context) {
    return Center(
      child: SizedBox(
        height: 500.0,
        child: EmptyWidget(
          txt: FFLocalizations.of(context).getVariableText(
            ruText: 'Пусто. У вас пока нет звонков и сообщений',
            enText: 'Empty. You do not have calls or messages yet',
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => FavoriteModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        FocusManager.instance.primaryFocus?.unfocus();
      },
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
        body: Stack(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
              child: AuthUserStreamWidget(
                builder: (context) {
                  if (currentUserUid.isEmpty || currentUserDocument == null) {
                    return _buildLoadingState(context);
                  }

                  return StreamBuilder<List<ConversationsRecord>>(
                    stream: queryConversationsRecord(
                      queryBuilder: (conversationsRecord) =>
                          conversationsRecord.where(
                        'participantIds',
                        arrayContains: currentUserUid,
                      ),
                    ),
                    builder: (context, conversationsSnapshot) {
                      if (!conversationsSnapshot.hasData) {
                        return _buildLoadingState(context);
                      }

                      final conversations = conversationsSnapshot.data!
                          .where((conversation) => conversation.isUnlocked)
                          .toList()
                        ..sort(compareConversationsForInbox);

                      final unlockedByPairId = {
                        for (final conversation in conversations)
                          conversation.pairId: conversation,
                      };
                      final friends =
                          resolveFriendsForUser(currentUserDocument).toList();
                      final showHubEmptyState = conversations.isEmpty;

                      return FutureBuilder<List<VideoSessionsRecord>>(
                        future: _getRecentCallsFuture(currentUserUid),
                        builder: (context, callsSnapshot) {
                          if (!callsSnapshot.hasData) {
                            return _buildLoadingState(context);
                          }

                          final calls = callsSnapshot.data!;
                          final showCalls = calls.isNotEmpty;
                          final showEmptyState =
                              showHubEmptyState && !showCalls;

                          return Stack(
                            children: [
                              SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 115.0),
                                    if (showEmptyState)
                                      _buildEmptyHubState(context),
                                    if (conversations.isNotEmpty) ...[
                                      _sectionHeader(
                                        context,
                                        title: FFLocalizations.of(context)
                                            .getVariableText(
                                          ruText: 'Сообщения',
                                          enText: 'Messages',
                                        ),
                                        subtitle:
                                            conversations.length.toString(),
                                      ),
                                      ...conversations.map(
                                        (conversation) => _conversationCard(
                                          context,
                                          conversation: conversation,
                                        ),
                                      ),
                                    ],
                                    _sectionHeader(
                                      context,
                                      title: FFLocalizations.of(context)
                                          .getVariableText(
                                        ruText: 'Друзья',
                                        enText: 'Friends',
                                      ),
                                      subtitle: friends.length.toString(),
                                    ),
                                    if (friends.isEmpty)
                                      Padding(
                                        padding: const EdgeInsetsDirectional
                                            .fromSTEB(
                                          10.0,
                                          0.0,
                                          10.0,
                                          10.0,
                                        ),
                                        child: Text(
                                          FFLocalizations.of(context)
                                              .getVariableText(
                                            ruText: 'Пока нет друзей.',
                                            enText:
                                                'You do not have friends yet.',
                                          ),
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .secondaryText,
                                                fontSize: 14.0,
                                                letterSpacing: 0.0,
                                              ),
                                        ),
                                      )
                                    else
                                      ...friends.map((friendRef) {
                                        final pairId =
                                            canonicalConversationPairId(
                                          currentUserUid,
                                          friendRef.id,
                                        );
                                        final conversation =
                                            unlockedByPairId[pairId];
                                        return FutureBuilder<UsersRecord>(
                                          future: _getUserFuture(friendRef),
                                          builder: (context, friendSnapshot) {
                                            if (!friendSnapshot.hasData) {
                                              return Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  vertical: 6.0,
                                                ),
                                                child:
                                                    _buildLoadingState(context),
                                              );
                                            }
                                            return _friendCard(
                                              context,
                                              friend: friendSnapshot.data!,
                                              conversation: conversation,
                                            );
                                          },
                                        );
                                      }),
                                    if (showCalls) ...[
                                      _sectionHeader(
                                        context,
                                        title: FFLocalizations.of(context)
                                            .getVariableText(
                                          ruText: 'Звонки',
                                          enText: 'Calls',
                                        ),
                                        subtitle: calls.length.toString(),
                                      ),
                                      ...calls.map(
                                        (session) => _callCard(
                                          context,
                                          session: session,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 120.0),
                                  ],
                                ),
                              ),
                              _buildHeader(context),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
