import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/components/segmented_tab_bar.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/chat_call_event_presentation.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/chat_thread/open_chat_thread.dart';

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
  static final Map<String, _ConversationsLoadState>
      _conversationStateCacheByUid = {};
  final _userFutureCache = <String, Future<UserPublicProfilesRecord?>>{};
  String? _conversationsStreamUid;
  Stream<_ConversationsLoadState>? _conversationsStream;
  int _selectedChatTabIndex = 0;

  Future<UserPublicProfilesRecord?> _getUserFuture(DocumentReference ref) {
    return _userFutureCache.putIfAbsent(
      ref.path,
      () => UserPublicProfilesRecord.maybeGetDocumentOnce(
        UserPublicProfilesRecord.collection.doc(ref.id),
      ).catchError((Object error, StackTrace stackTrace) {
        _userFutureCache.remove(ref.path);
        throw error;
      }),
    );
  }

  String _publicProfileDisplayName(
    BuildContext context,
    UserPublicProfilesRecord? profile,
  ) {
    final displayName = profile?.displayName.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Пользователь',
      enText: 'User',
    );
  }

  String _publicProfilePhotoUrl(UserPublicProfilesRecord? profile) =>
      profile?.photoUrl.trim() ?? '';

  Map<String, dynamic> _conversationParticipantInfo(
    ConversationsRecord conversation,
    DocumentReference participantRef,
  ) {
    final rawInfoByUserId =
        conversation.snapshotData['participantInfoByUserId'];
    if (rawInfoByUserId is Map) {
      final rawInfo = rawInfoByUserId[participantRef.id] ??
          rawInfoByUserId[participantRef.path];
      if (rawInfo is Map) {
        return rawInfo.map((key, value) => MapEntry(key.toString(), value));
      }
    }

    return const <String, dynamic>{};
  }

  String _conversationParticipantDisplayName(
    ConversationsRecord conversation,
    DocumentReference participantRef,
  ) {
    final info = _conversationParticipantInfo(conversation, participantRef);
    for (final key in const ['displayName', 'display_name', 'name']) {
      final value = info[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  String _conversationParticipantPhotoUrl(
    ConversationsRecord conversation,
    DocumentReference participantRef,
  ) {
    final info = _conversationParticipantInfo(conversation, participantRef);
    for (final key in const ['photoUrl', 'photo_url', 'photo']) {
      final value = info[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return '';
  }

  String _partnerDisplayName(
    BuildContext context,
    ConversationsRecord conversation,
    DocumentReference partnerRef,
    UserPublicProfilesRecord? profile,
  ) {
    final profileDisplayName = profile?.displayName.trim();
    if (profileDisplayName != null && profileDisplayName.isNotEmpty) {
      return profileDisplayName;
    }

    final conversationDisplayName =
        _conversationParticipantDisplayName(conversation, partnerRef);
    if (conversationDisplayName.isNotEmpty) {
      return conversationDisplayName;
    }

    return _publicProfileDisplayName(context, profile);
  }

  String _partnerPhotoUrl(
    ConversationsRecord conversation,
    DocumentReference partnerRef,
    UserPublicProfilesRecord? profile,
  ) {
    final profilePhotoUrl = _publicProfilePhotoUrl(profile);
    if (profilePhotoUrl.isNotEmpty) {
      return profilePhotoUrl;
    }

    return _conversationParticipantPhotoUrl(conversation, partnerRef);
  }

  Stream<_ConversationsLoadState> _watchConversationsForUser(
      String currentUid) {
    if (currentUid.isEmpty) {
      return Stream.value(const _ConversationsLoadState());
    }

    if (_conversationsStreamUid == currentUid && _conversationsStream != null) {
      return _conversationsStream!;
    }

    _conversationsStreamUid = currentUid;
    _conversationsStream = queryConversationsRecord(
      queryBuilder: (query) => query.where(
        FieldPath(['participantMap', currentUid]),
        isEqualTo: true,
      ),
    ).map((conversations) {
      final loadedConversations = conversations
          .where((conversation) => conversation.isUnlocked)
          .toList();
      loadedConversations.sort(compareConversationsForInbox);
      final loadedState = _ConversationsLoadState(
        conversations: List<ConversationsRecord>.unmodifiable(
          loadedConversations,
        ),
      );
      _conversationStateCacheByUid[currentUid] = loadedState;
      return loadedState;
    });
    return _conversationsStream!;
  }

  _ConversationsLoadState? _cachedConversationsStateForUser(
    String currentUid,
  ) =>
      _conversationStateCacheByUid[currentUid];

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

  bool _conversationPartnerIsFriendPathSet(
    ConversationsRecord conversation,
    Set<String> friendPaths,
  ) {
    for (final participantRef in conversation.participantRefs) {
      if (participantRef.id != currentUserUid &&
          friendPaths.contains(participantRef.path)) {
        return true;
      }
    }
    return false;
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
    await openChatThread(
      context,
      conversationRef: conversation.reference,
      initialConversation: conversation,
    );
  }

  String _conversationSubtitle(
      BuildContext context, ConversationsRecord conversation) {
    if (conversation.lastMessageType == kConversationMessageTypeCallEvent) {
      return formatChatCallEventTitle(
        context,
        outcome: conversation.lastCallOutcome,
        callerId: conversation.lastCallCallerId,
        currentUserUid: currentUserUid,
      );
    }

    final lastMessageText = (conversation.lastMessageText ?? '').trim();
    if (lastMessageText.isNotEmpty) {
      return lastMessageText;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Чат открыт',
      enText: 'Chat unlocked',
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
      color: ExpatlioDesign.background,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: ExpatlioDesign.pageHeaderHeight,
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: ExpatlioDesign.pagePadding,
            ),
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
                  style: ExpatlioDesign.pageHeaderTitleStyle(context),
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
        ),
      ),
    );
  }

  Widget _buildChatsTabBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.compactSpacing,
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.itemSpacing,
      ),
      child: ExpatlioSegmentedTabBar(
        labels: [
          FFLocalizations.of(context).getVariableText(
            ruText: 'Все',
            enText: 'All',
          ),
          FFLocalizations.of(context).getVariableText(
            ruText: 'Друзья',
            enText: 'Friends',
          ),
        ],
        selectedIndex: _selectedChatTabIndex,
        onChanged: (index) => setState(() => _selectedChatTabIndex = index),
      ),
    );
  }

  Widget _conversationCard(
    BuildContext context, {
    required ConversationsRecord conversation,
    required bool isFriend,
  }) {
    final partnerRef = _otherParticipantRef(conversation);
    if (partnerRef == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<UserPublicProfilesRecord?>(
      future: _getUserFuture(partnerRef),
      builder: (context, partnerSnapshot) {
        if (partnerSnapshot.hasError) {
          debugPrint(
            'FavoriteWidget: failed to load partner ${partnerRef.path}: ${partnerSnapshot.error}',
          );
        }

        final partner = partnerSnapshot.hasError ? null : partnerSnapshot.data;
        final partnerDisplayName = _partnerDisplayName(
          context,
          conversation,
          partnerRef,
          partner,
        );
        final partnerPhotoUrl = _partnerPhotoUrl(
          conversation,
          partnerRef,
          partner,
        );
        final unread =
            conversationIsUnreadForUser(conversation, currentUserUid);
        final subtitle = _conversationSubtitle(context, conversation);

        return InkWell(
          splashColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          onTap: () => _openConversation(conversation),
          child: Container(
            width: double.infinity,
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: const Border(
                bottom: BorderSide(color: ExpatlioDesign.separator),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.pagePadding,
                ExpatlioDesign.itemSpacing,
                ExpatlioDesign.pagePadding,
                ExpatlioDesign.itemSpacing,
              ),
              child: Row(
                children: [
                  Container(
                    width: 52.0,
                    height: 52.0,
                    decoration: BoxDecoration(
                      color: ExpatlioDesign.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: ExpatlioDesign.border),
                      image: partnerPhotoUrl.isNotEmpty
                          ? DecorationImage(
                              fit: BoxFit.cover,
                              image: CachedNetworkImageProvider(
                                partnerPhotoUrl,
                                maxWidth: 108,
                                maxHeight: 108,
                              ),
                            )
                          : null,
                    ),
                    child: partnerPhotoUrl.isEmpty
                        ? Center(
                            child: Text(
                              partnerDisplayName.characters.first.toUpperCase(),
                              style: ExpatlioDesign.textStyle(
                                context,
                                color: ExpatlioDesign.muted,
                                size: 14.0,
                                weight: FontWeight.w600,
                              ),
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        ExpatlioDesign.itemSpacing,
                        ExpatlioDesign.space0,
                        ExpatlioDesign.space0,
                        ExpatlioDesign.space0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        partnerDisplayName,
                                        overflow: TextOverflow.ellipsis,
                                        style: ExpatlioDesign.textStyle(
                                          context,
                                          size: 16.0,
                                          weight: unread
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    if (isFriend)
                                      const Padding(
                                        padding: EdgeInsetsDirectional.only(
                                            start: ExpatlioDesign.space8),
                                        child: Icon(
                                          Icons.star_rounded,
                                          color: ExpatlioDesign.warning,
                                          size: 18.0,
                                        ),
                                      ),
                                  ],
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
                          const SizedBox(height: ExpatlioDesign.space4),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ExpatlioDesign.textStyle(
                              context,
                              color: ExpatlioDesign.muted,
                              size: 14.0,
                              weight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                        start: ExpatlioDesign.space12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          _formatInboxTimestamp(
                            conversation.lastMessageAt ??
                                conversation.unlockedAt,
                          ),
                          style: ExpatlioDesign.textStyle(
                            context,
                            color: ExpatlioDesign.inactive,
                            size: 12.0,
                            weight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: ExpatlioDesign.space8),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: ExpatlioDesign.inactive,
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

  Widget _buildEmptyListState(
    BuildContext context, {
    required String text,
  }) {
    return Center(
      child: SizedBox(
        height: 360.0,
        child: EmptyWidget(
          txt: text,
        ),
      ),
    );
  }

  Widget _buildMessagesTabContent(
    BuildContext context, {
    required bool conversationsLoading,
    required bool conversationsLoadFailed,
    required bool conversationsAccessDenied,
    required List<ConversationsRecord> conversations,
    required List<DocumentReference> friends,
  }) {
    final friendPaths = friends.map((reference) => reference.path).toSet();

    if (conversationsLoading) {
      return const SizedBox.shrink();
    }

    if (conversationsLoadFailed) {
      return _buildInlineNotice(
        context,
        text: conversationsAccessDenied
            ? FFLocalizations.of(context).getVariableText(
                ruText: 'Чаты пока недоступны для этого аккаунта.',
                enText: 'Chats are not available for this account yet.',
              )
            : FFLocalizations.of(context).getVariableText(
                ruText: 'Не удалось загрузить сообщения. Попробуйте позже.',
                enText: 'Could not load messages. Please try again later.',
              ),
      );
    }

    if (conversations.isEmpty) {
      return _buildEmptyListState(
        context,
        text: FFLocalizations.of(context).getVariableText(
          ruText: 'У вас пока нет сообщений.',
          enText: 'You do not have messages yet.',
        ),
      );
    }

    return ListView.builder(
      padding:
          const EdgeInsetsDirectional.only(bottom: ExpatlioDesign.space112),
      itemCount: conversations.length,
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        return _conversationCard(
          context,
          conversation: conversation,
          isFriend: _conversationPartnerIsFriendPathSet(
            conversation,
            friendPaths,
          ),
        );
      },
    );
  }

  Widget _buildFriendsTabContent(
    BuildContext context, {
    required bool conversationsLoading,
    required List<DocumentReference> friends,
    required List<ConversationsRecord> conversations,
  }) {
    final friendPaths = friends.map((reference) => reference.path).toSet();
    final friendConversations = conversations
        .where(
          (conversation) => _conversationPartnerIsFriendPathSet(
            conversation,
            friendPaths,
          ),
        )
        .toList();

    if (conversationsLoading) {
      return const SizedBox.shrink();
    }

    if (friendConversations.isEmpty) {
      return _buildEmptyListState(
        context,
        text: FFLocalizations.of(context).getVariableText(
          ruText: 'У вас пока нет чатов с друзьями.',
          enText: 'You do not have chats with friends yet.',
        ),
      );
    }

    return ListView.builder(
      padding:
          const EdgeInsetsDirectional.only(bottom: ExpatlioDesign.space112),
      itemCount: friendConversations.length,
      itemBuilder: (context, index) => _conversationCard(
        context,
        conversation: friendConversations[index],
        isFriend: true,
      ),
    );
  }

  bool _isPermissionDenied(Object? error) =>
      error is FirebaseException && error.code == 'permission-denied';

  Widget _buildInlineNotice(
    BuildContext context, {
    required String text,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.space0,
        ExpatlioDesign.pagePadding,
        ExpatlioDesign.itemSpacing,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        ExpatlioDesign.sectionSpacing,
        ExpatlioDesign.itemSpacing,
        ExpatlioDesign.sectionSpacing,
        ExpatlioDesign.itemSpacing,
      ),
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).primaryBackground,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        border: Border.all(color: ExpatlioDesign.border),
      ),
      child: Text(
        text,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.muted,
          size: 14.0,
          weight: FontWeight.w400,
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
        backgroundColor: ExpatlioDesign.background,
        body: Stack(
          children: [
            AuthUserStreamWidget(
              builder: (context) {
                if (currentUserUid.isEmpty || currentUserDocument == null) {
                  return _buildLoadingState(context);
                }

                final friends =
                    resolveFriendsForUser(currentUserDocument).toList();

                return StreamBuilder<_ConversationsLoadState>(
                  stream: _watchConversationsForUser(currentUserUid),
                  initialData: _cachedConversationsStateForUser(currentUserUid),
                  builder: (context, conversationsSnapshot) {
                    if (conversationsSnapshot.hasError) {
                      debugPrint(
                        'FavoriteWidget: conversations stream error: ${conversationsSnapshot.error}',
                      );
                    }

                    final conversationsState = conversationsSnapshot.data;
                    final conversationsError = conversationsSnapshot.error;
                    final conversationsLoading =
                        conversationsSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            conversationsState == null &&
                            !conversationsSnapshot.hasError;
                    final conversationsLoadFailed =
                        conversationsSnapshot.hasError;
                    final conversationsAccessDenied =
                        _isPermissionDenied(conversationsError);

                    final conversations = conversationsState?.conversations ??
                        <ConversationsRecord>[];

                    final showFriendsTab = _selectedChatTabIndex == 1;

                    return Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              height: MediaQuery.paddingOf(context).top + 56,
                            ),
                            _buildChatsTabBar(context),
                            Expanded(
                              child: showFriendsTab
                                  ? _buildFriendsTabContent(
                                      context,
                                      conversationsLoading:
                                          conversationsLoading,
                                      friends: friends,
                                      conversations: conversations,
                                    )
                                  : _buildMessagesTabContent(
                                      context,
                                      conversationsLoading:
                                          conversationsLoading,
                                      conversationsLoadFailed:
                                          conversationsLoadFailed,
                                      conversationsAccessDenied:
                                          conversationsAccessDenied,
                                      conversations: conversations,
                                      friends: friends,
                                    ),
                            ),
                          ],
                        ),
                        _buildHeader(context),
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationsLoadState {
  const _ConversationsLoadState({
    this.conversations = const <ConversationsRecord>[],
  });

  final List<ConversationsRecord> conversations;
}
