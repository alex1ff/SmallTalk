import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/chat_thread/chat_thread_widget.dart';

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
  final _userFutureCache = <String, Future<UserPublicProfilesRecord?>>{};
  int _selectedChatTabIndex = 0;

  Future<UserPublicProfilesRecord?> _getUserFuture(DocumentReference ref) {
    return _userFutureCache.putIfAbsent(
      ref.path,
      () => UserPublicProfilesRecord.maybeGetDocumentOnce(
        UserPublicProfilesRecord.collection.doc(ref.id),
      ),
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

  Stream<_ConversationsLoadState> _watchConversationsForUser(
      String currentUid) {
    if (currentUid.isEmpty) {
      return Stream.value(const _ConversationsLoadState());
    }

    return queryConversationsRecord(
      queryBuilder: (query) => query.where(
        FieldPath(['participantMap', currentUid]),
        isEqualTo: true,
      ),
    ).map(
      (conversations) => _ConversationsLoadState(conversations: conversations),
    );
  }

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

  String _conversationSubtitle(
      BuildContext context, ConversationsRecord conversation) {
    if (conversation.lastMessageType == kConversationMessageTypeCallEvent) {
      final currentUserWasCaller =
          conversation.lastCallCallerId == currentUserUid;
      if (conversation.lastCallOutcome == kConversationCallOutcomeCancelled) {
        return FFLocalizations.of(context).getVariableText(
          ruText: 'Отменённый звонок',
          enText: 'Cancelled call',
        );
      }
      if (conversation.lastCallOutcome == kConversationCallOutcomeMissed) {
        return FFLocalizations.of(context).getVariableText(
          ruText: currentUserWasCaller ? 'Без ответа' : 'Пропущенный звонок',
          enText: currentUserWasCaller ? 'No answer' : 'Missed call',
        );
      }
      return FFLocalizations.of(context).getVariableText(
        ruText: currentUserWasCaller ? 'Исходящий звонок' : 'Входящий звонок',
        enText: currentUserWasCaller ? 'Outgoing call' : 'Incoming call',
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
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          ExpatlioDesign.itemSpacing,
          MediaQuery.paddingOf(context).top,
          ExpatlioDesign.itemSpacing,
          0.0,
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
              style: ExpatlioDesign.textStyle(
                context,
                size: 17.0,
                weight: FontWeight.w700,
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

  Widget _chatTabButton(
    BuildContext context, {
    required int index,
    required String label,
  }) {
    final selected = _selectedChatTabIndex == index;

    return Expanded(
      child: InkWell(
        splashColor: Colors.transparent,
        focusColor: Colors.transparent,
        hoverColor: Colors.transparent,
        highlightColor: Colors.transparent,
        onTap: () async {
          if (_selectedChatTabIndex == index) {
            return;
          }
          setState(() => _selectedChatTabIndex = index);
        },
        child: Container(
          width: double.infinity,
          height: 36.0,
          decoration: BoxDecoration(
            color: selected ? ExpatlioDesign.card : Colors.transparent,
            borderRadius: BorderRadius.circular(10.0),
            shape: BoxShape.rectangle,
          ),
          child: Align(
            alignment: const AlignmentDirectional(0.0, 0.0),
            child: Text(
              label,
              style: ExpatlioDesign.textStyle(
                context,
                color: selected ? ExpatlioDesign.text : ExpatlioDesign.muted,
                size: 14.0,
                weight: FontWeight.w500,
              ),
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
      child: Container(
        width: double.infinity,
        height: 38.0,
        decoration: BoxDecoration(
          color: ExpatlioDesign.mutedSurface,
          borderRadius: BorderRadius.circular(12.0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              _chatTabButton(
                context,
                index: 0,
                label: FFLocalizations.of(context).getVariableText(
                  ruText: 'Все',
                  enText: 'All',
                ),
              ),
              _chatTabButton(
                context,
                index: 1,
                label: FFLocalizations.of(context).getVariableText(
                  ruText: 'Друзья',
                  enText: 'Friends',
                ),
              ),
            ],
          ),
        ),
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
          return _buildInlineNotice(
            context,
            text: FFLocalizations.of(context).getVariableText(
              ruText: 'Не удалось загрузить этот чат.',
              enText: 'Could not load this chat.',
            ),
          );
        }

        if (partnerSnapshot.connectionState == ConnectionState.waiting) {
          return _conversationLoadingCard(context);
        }

        final partner = partnerSnapshot.data;
        final partnerDisplayName = _publicProfileDisplayName(context, partner);
        final partnerPhotoUrl = _publicProfilePhotoUrl(partner);
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
                bottom: BorderSide(color: ExpatlioDesign.border),
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
                      color: ExpatlioDesign.mutedSurface,
                      shape: BoxShape.circle,
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
                        0.0,
                        0.0,
                        0.0,
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
                                            start: 5),
                                        child: Icon(
                                          Icons.star_rounded,
                                          color: Color(0xFFFFC107),
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
                          const SizedBox(height: 4.0),
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
                          style: ExpatlioDesign.textStyle(
                            context,
                            color: ExpatlioDesign.muted,
                            size: 12.0,
                            weight: FontWeight.w400,
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
    if (conversationsLoading) {
      return _buildMessagesLoadingList(context);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: conversations
          .map(
            (conversation) => _conversationCard(
              context,
              conversation: conversation,
              isFriend: conversationPartnerIsFriend(
                conversation,
                friends,
                currentUserUid,
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildMessagesLoadingList(BuildContext context) {
    return Column(
      children: List.generate(
        4,
        (_) => _conversationLoadingCard(context),
      ),
    );
  }

  Widget _conversationLoadingCard(BuildContext context) {
    const placeholderColor = ExpatlioDesign.mutedSurface;

    Widget placeholder({
      required double width,
      required double height,
      required double radius,
    }) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: placeholderColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    return Container(
      width: double.infinity,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: const Border(
          bottom: BorderSide(color: ExpatlioDesign.border),
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
            placeholder(
              width: 54.0,
              height: 54.0,
              radius: 20.0,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.itemSpacing,
                  0.0,
                  0.0,
                  0.0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    placeholder(
                      width: 140.0,
                      height: 14.0,
                      radius: 20.0,
                    ),
                    const SizedBox(height: ExpatlioDesign.compactSpacing),
                    placeholder(
                      width: 210.0,
                      height: 12.0,
                      radius: 20.0,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(
                start: ExpatlioDesign.itemSpacing,
              ),
              child: placeholder(
                width: 42.0,
                height: 12.0,
                radius: 20.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendsTabContent(
    BuildContext context, {
    required List<DocumentReference> friends,
    required List<ConversationsRecord> conversations,
  }) {
    final friendConversations = conversations
        .where(
          (conversation) => conversationPartnerIsFriend(
            conversation,
            friends,
            currentUserUid,
          ),
        )
        .toList();

    if (friendConversations.isEmpty) {
      return _buildEmptyListState(
        context,
        text: FFLocalizations.of(context).getVariableText(
          ruText: 'У вас пока нет чатов с друзьями.',
          enText: 'You do not have chats with friends yet.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: friendConversations
          .map(
            (conversation) => _conversationCard(
              context,
              conversation: conversation,
              isFriend: true,
            ),
          )
          .toList(),
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
        0.0,
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
        borderRadius: BorderRadius.circular(16.0),
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
                  initialData: const _ConversationsLoadState(),
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

                    final conversations = conversationsState != null
                        ? (() {
                            final loadedConversations = conversationsState
                                .conversations
                                .where(
                                    (conversation) => conversation.isUnlocked)
                                .toList();
                            loadedConversations.sort(
                              compareConversationsForInbox,
                            );
                            return loadedConversations;
                          })()
                        : <ConversationsRecord>[];

                    final showFriendsTab = _selectedChatTabIndex == 1;

                    return Stack(
                      children: [
                        SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: MediaQuery.paddingOf(context).top + 56,
                              ),
                              _buildChatsTabBar(context),
                              if (showFriendsTab)
                                _buildFriendsTabContent(
                                  context,
                                  friends: friends,
                                  conversations: conversations,
                                )
                              else
                                _buildMessagesTabContent(
                                  context,
                                  conversationsLoading: conversationsLoading,
                                  conversationsLoadFailed:
                                      conversationsLoadFailed,
                                  conversationsAccessDenied:
                                      conversationsAccessDenied,
                                  conversations: conversations,
                                  friends: friends,
                                ),
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
