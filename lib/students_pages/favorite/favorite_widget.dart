import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/components/segmented_tab_bar.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/chat_call_event_presentation.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/chat_thread/open_chat_thread.dart';
import '/shared_pages/events/event_group_chat_widget.dart';
import '/services/event_group_chat_repository.dart';

import 'favorite_model.dart';
export 'favorite_model.dart';

const double _favoriteChatAvatarSize = 52.0;
const Color _favoriteChatDividerColor = Color(0xFFEBEBEB);
const Color _favoriteChatDeleteBackground = Color(0xFFFF3B30);

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
  static final Map<String, _EventChatsLoadState> _eventChatStateCacheByUid = {};
  static final Map<String, List<DocumentReference>> _friendsCacheByUid = {};
  static final Map<String, Future<UserPublicProfilesRecord?>>
      _userFutureCacheByUid = {};
  static final Map<String, UserPublicProfilesRecord> _userProfileCacheByUid =
      {};
  static final Map<String, Future<EventsRecord?>> _eventFutureCacheByEventId =
      {};
  static final Map<String, EventsRecord> _eventCacheByEventId = {};
  static final Map<String, Set<String>> _hiddenChatKeyOverridesByUid = {};
  String? _conversationsStreamUid;
  Stream<_ConversationsLoadState>? _conversationsStream;
  String? _eventChatsStreamUid;
  Stream<_EventChatsLoadState>? _eventChatsStream;
  final Map<String, Stream<List<EventChatMessagesRecord>>>
      _latestEventChatMessageStreams = {};
  int _selectedChatTabIndex = 0;

  Future<UserPublicProfilesRecord?> _getUserFuture(DocumentReference ref) {
    return _userFutureCacheByUid.putIfAbsent(
      ref.id,
      () => UserPublicProfilesRecord.maybeGetDocumentOnce(
        UserPublicProfilesRecord.collection.doc(ref.id),
      ).then((profile) {
        if (profile != null) {
          _userProfileCacheByUid[ref.id] = profile;
        }
        return profile;
      }).catchError((Object error, StackTrace stackTrace) {
        _userFutureCacheByUid.remove(ref.id);
        throw error;
      }),
    );
  }

  UserPublicProfilesRecord? _cachedUserProfile(DocumentReference ref) =>
      _userProfileCacheByUid[ref.id];

  Future<EventsRecord?> _getEventFuture(String eventId) {
    return _eventFutureCacheByEventId.putIfAbsent(
      eventId,
      () => (() async {
        final snapshot = await EventsRecord.collection.doc(eventId).get();
        if (!snapshot.exists) {
          return null;
        }

        final event = EventsRecord.fromSnapshot(snapshot);
        _eventCacheByEventId[eventId] = event;
        return event;
      })()
          .catchError((Object error, StackTrace stackTrace) {
        _eventFutureCacheByEventId.remove(eventId);
        throw error;
      }),
    );
  }

  EventsRecord? _cachedEvent(String eventId) => _eventCacheByEventId[eventId];

  List<DocumentReference> _friendsForCurrentUser(String currentUid) {
    final userDocument = currentUserDocument;
    if (userDocument == null) {
      return _friendsCacheByUid[currentUid] ?? const <DocumentReference>[];
    }

    final friends = resolveFriendsForUser(userDocument).toList(
      growable: false,
    );
    _friendsCacheByUid[currentUid] = friends;
    return friends;
  }

  Set<String> _hiddenChatKeysForCurrentUser(String currentUid) {
    final keys = <String>{};
    final rawKeys = currentUserDocument?.snapshotData['hiddenChatKeys'];
    if (rawKeys is Iterable) {
      for (final rawKey in rawKeys) {
        if (rawKey is! String) {
          continue;
        }
        final key = rawKey.trim();
        if (key.isNotEmpty) {
          keys.add(key);
        }
      }
    }
    keys.addAll(_hiddenChatKeyOverridesByUid[currentUid] ?? const <String>{});
    for (final eventId in EventGroupChatRepository.rememberedInboxEventIds) {
      keys.remove('event:$eventId');
    }
    return keys;
  }

  String _conversationHiddenKey(ConversationsRecord conversation) =>
      'conversation:${conversation.reference.id}';

  String _eventChatHiddenKey(EventChatsRecord chat) =>
      'event:${EventGroupChatRepository.eventIdForChat(chat)}';

  Future<void> _hideChat(BuildContext context, String hiddenKey) async {
    final normalizedKey = hiddenKey.trim();
    final uid = currentUserUid;
    final userRef = currentUserReference;
    if (uid.isEmpty || userRef == null || normalizedKey.isEmpty) {
      return;
    }

    setState(() {
      _hiddenChatKeyOverridesByUid
          .putIfAbsent(uid, () => <String>{})
          .add(normalizedKey);
    });

    try {
      await userRef.update({
        'hiddenChatKeys': FieldValue.arrayUnion([normalizedKey]),
      });
    } catch (error) {
      _hiddenChatKeyOverridesByUid[uid]?.remove(normalizedKey);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Не удалось удалить чат',
                enText: 'Could not delete chat',
              ),
            ),
          ),
        );
      }
    }
  }

  String _fallbackPartnerDisplayName(BuildContext context) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Собеседник',
      enText: 'Conversation partner',
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

    return '';
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

  Stream<_EventChatsLoadState> _watchEventChatsForUser(String currentUid) {
    if (currentUid.isEmpty) {
      return Stream.value(const _EventChatsLoadState());
    }

    if (_eventChatsStreamUid == currentUid && _eventChatsStream != null) {
      return _eventChatsStream!;
    }

    _eventChatsStreamUid = currentUid;
    _eventChatsStream = EventGroupChatRepository.watchInboxChats(
      currentUid: currentUid,
      rememberedEventIdsStream: () =>
          _watchSavedEventChatInboxEventIds(currentUid),
    ).map((eventChats) {
      final loadedState = _EventChatsLoadState(
        eventChats: List<EventChatsRecord>.unmodifiable(eventChats),
      );
      _eventChatStateCacheByUid[currentUid] = loadedState;
      return loadedState;
    });
    return _eventChatsStream!;
  }

  _EventChatsLoadState? _cachedEventChatsStateForUser(String currentUid) =>
      _eventChatStateCacheByUid[currentUid];

  Stream<List<String>> _watchSavedEventChatInboxEventIds(String currentUid) {
    final userRef = currentUserReference;
    if (currentUid.isEmpty || userRef == null) {
      return Stream.value(const <String>[]);
    }

    return userRef.snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return const <String>[];
      }
      return _eventChatInboxEventIdsFromData(snapshot.data());
    });
  }

  List<String> _eventChatInboxEventIdsFromData(Object? data) {
    if (data is! Map) {
      return const <String>[];
    }

    final ids = <String>[];
    final seen = <String>{};
    final rawIds = data['eventChatInboxEventIds'];
    if (rawIds is Iterable) {
      for (final rawId in rawIds) {
        if (rawId is! String) {
          continue;
        }
        final id = rawId.trim();
        if (id.isNotEmpty && seen.add(id)) {
          ids.add(id);
        }
      }
    }
    return List<String>.unmodifiable(ids);
  }

  Stream<List<EventChatMessagesRecord>> _watchLatestEventChatMessage(
    EventChatsRecord chat,
  ) {
    final eventId = EventGroupChatRepository.eventIdForChat(chat);
    return _latestEventChatMessageStreams.putIfAbsent(
      chat.reference.path,
      () => EventGroupChatRepository.watchLatestMessage(eventId: eventId),
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

  void _openEventChat(EventChatsRecord chat) {
    final eventId = EventGroupChatRepository.eventIdForChat(chat);
    if (eventId.isEmpty) {
      return;
    }

    context.pushNamed(
      EventGroupChatWidget.routeName,
      pathParameters: <String, String>{'eventId': eventId},
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

  String _eventChatTitle(BuildContext context, EventsRecord? event) {
    final title = event?.title.trim() ?? '';
    if (title.isNotEmpty) {
      return title;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Чат события',
      enText: 'Event chat',
    );
  }

  String _eventChatSubtitle(
    BuildContext context,
    EventChatMessagesRecord? latestMessage,
  ) {
    if (latestMessage?.deletedAt != null) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Сообщение удалено',
        enText: 'Message deleted',
      );
    }

    final text = latestMessage?.text.trim() ?? '';
    if (text.isNotEmpty) {
      return text;
    }

    return FFLocalizations.of(context).getVariableText(
      ruText: 'Чат события',
      enText: 'Event chat',
    );
  }

  DateTime? _eventChatTimestamp(
    EventChatsRecord chat,
    EventChatMessagesRecord? latestMessage,
  ) =>
      latestMessage?.createdAt ?? chat.updatedAt ?? chat.createdAt;

  List<_InboxChatItem> _buildInboxItems({
    required List<ConversationsRecord> conversations,
    required List<EventChatsRecord> eventChats,
    required Set<String> hiddenChatKeys,
  }) {
    final items = <_InboxChatItem>[
      for (final conversation in conversations)
        if (!hiddenChatKeys.contains(_conversationHiddenKey(conversation)))
          _InboxChatItem.conversation(conversation),
      for (final eventChat in eventChats) _InboxChatItem.eventChat(eventChat),
    ];
    items.removeWhere((item) {
      final eventChat = item.eventChat;
      return eventChat != null &&
          hiddenChatKeys.contains(_eventChatHiddenKey(eventChat));
    });
    items.sort(_compareInboxChatItems);
    return items;
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
    required VoidCallback onDelete,
  }) {
    final partnerRef = _otherParticipantRef(conversation);
    if (partnerRef == null) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<UserPublicProfilesRecord?>(
      future: _getUserFuture(partnerRef),
      initialData: _cachedUserProfile(partnerRef),
      builder: (context, partnerSnapshot) {
        if (partnerSnapshot.hasError) {
          debugPrint(
            'FavoriteWidget: failed to load partner ${partnerRef.path}: ${partnerSnapshot.error}',
          );
        }

        final partner = partnerSnapshot.hasError
            ? _cachedUserProfile(partnerRef)
            : partnerSnapshot.data;
        final partnerDisplayName = _partnerDisplayName(
          conversation,
          partnerRef,
          partner,
        );
        final partnerPhotoUrl = _partnerPhotoUrl(
          conversation,
          partnerRef,
          partner,
        );
        final visiblePartnerDisplayName = partnerDisplayName.isNotEmpty
            ? partnerDisplayName
            : _fallbackPartnerDisplayName(context);
        final unread =
            conversationIsUnreadForUser(conversation, currentUserUid);
        final subtitle = _conversationSubtitle(context, conversation);

        return _dismissibleChatCard(
          keyValue: _conversationHiddenKey(conversation),
          onDelete: onDelete,
          child: InkWell(
            splashColor: Colors.transparent,
            focusColor: Colors.transparent,
            hoverColor: Colors.transparent,
            highlightColor: Colors.transparent,
            onTap: () => _openConversation(conversation),
            child: Container(
              width: double.infinity,
              margin: EdgeInsets.zero,
              color: Colors.transparent,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.itemSpacing,
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.itemSpacing,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: _favoriteChatAvatarSize,
                          height: _favoriteChatAvatarSize,
                          decoration: BoxDecoration(
                            color: partnerPhotoUrl.isEmpty
                                ? ExpatlioDesign.avatarFallbackBackground
                                : ExpatlioDesign.card,
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
                                    ExpatlioDesign.avatarInitial(
                                        visiblePartnerDisplayName),
                                    style: ExpatlioDesign.textStyle(
                                      context,
                                      color: ExpatlioDesign.avatarFallbackText,
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
                                              visiblePartnerDisplayName,
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
                                              padding:
                                                  EdgeInsetsDirectional.only(
                                                      start: ExpatlioDesign
                                                          .space8),
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
                                          color: FlutterFlowTheme.of(context)
                                              .primary,
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
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  _chatDivider(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _dismissibleChatCard({
    required String keyValue,
    required VoidCallback onDelete,
    required Widget child,
  }) {
    return Dismissible(
      key: ValueKey<String>('favorite_chat_$keyValue'),
      direction: DismissDirection.endToStart,
      dismissThresholds: const {
        DismissDirection.endToStart: 0.34,
      },
      background: const SizedBox.shrink(),
      secondaryBackground: Container(
        color: _favoriteChatDeleteBackground,
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(
          end: ExpatlioDesign.pagePadding,
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: Colors.white,
          size: 24.0,
        ),
      ),
      onDismissed: (_) => onDelete(),
      child: child,
    );
  }

  Widget _chatDivider() {
    return const Padding(
      padding: EdgeInsetsDirectional.only(
        start: ExpatlioDesign.pagePadding +
            _favoriteChatAvatarSize +
            ExpatlioDesign.itemSpacing,
        end: ExpatlioDesign.pagePadding,
      ),
      child: Divider(
        height: 1.0,
        thickness: 1.0,
        color: _favoriteChatDividerColor,
      ),
    );
  }

  Widget _eventChatCard(
    BuildContext context, {
    required EventChatsRecord chat,
    required VoidCallback onDelete,
  }) {
    final eventId = EventGroupChatRepository.eventIdForChat(chat);
    if (eventId.isEmpty) {
      return const SizedBox.shrink();
    }

    return FutureBuilder<EventsRecord?>(
      future: _getEventFuture(eventId),
      initialData: _cachedEvent(eventId),
      builder: (context, eventSnapshot) {
        if (eventSnapshot.hasError) {
          debugPrint(
            'FavoriteWidget: failed to load event $eventId: ${eventSnapshot.error}',
          );
        }

        final event =
            eventSnapshot.hasError ? _cachedEvent(eventId) : eventSnapshot.data;
        final title = _eventChatTitle(context, event);

        return StreamBuilder<List<EventChatMessagesRecord>>(
          stream: _watchLatestEventChatMessage(chat),
          builder: (context, messageSnapshot) {
            if (messageSnapshot.hasError) {
              debugPrint(
                'FavoriteWidget: failed to load latest event chat message '
                'for $eventId: ${messageSnapshot.error}',
              );
            }

            final latestMessages = messageSnapshot.hasError
                ? const <EventChatMessagesRecord>[]
                : messageSnapshot.data ?? const <EventChatMessagesRecord>[];
            final latestMessage =
                latestMessages.isEmpty ? null : latestMessages.first;
            final subtitle = _eventChatSubtitle(context, latestMessage);
            final timestamp = _eventChatTimestamp(chat, latestMessage);

            return _dismissibleChatCard(
              keyValue: _eventChatHiddenKey(chat),
              onDelete: onDelete,
              child: InkWell(
                splashColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                highlightColor: Colors.transparent,
                onTap: () => _openEventChat(chat),
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.zero,
                  color: Colors.transparent,
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          ExpatlioDesign.pagePadding,
                          ExpatlioDesign.itemSpacing,
                          ExpatlioDesign.pagePadding,
                          ExpatlioDesign.itemSpacing,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: _favoriteChatAvatarSize,
                              height: _favoriteChatAvatarSize,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: ExpatlioDesign.avatarFallbackBackground,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: FlutterFlowTheme.of(context).primary,
                                size: 20.0,
                              ),
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
                                          child: Text(
                                            title,
                                            overflow: TextOverflow.ellipsis,
                                            style: ExpatlioDesign.textStyle(
                                              context,
                                              size: 16.0,
                                              weight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(
                                        height: ExpatlioDesign.space4),
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
                                    _formatInboxTimestamp(timestamp),
                                    style: ExpatlioDesign.textStyle(
                                      context,
                                      color: ExpatlioDesign.inactive,
                                      size: 12.0,
                                      weight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      _chatDivider(),
                    ],
                  ),
                ),
              ),
            );
          },
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
    required bool eventChatsLoadFailed,
    required List<EventChatsRecord> eventChats,
    required List<DocumentReference> friends,
    required Set<String> hiddenChatKeys,
  }) {
    final friendPaths = friends.map((reference) => reference.path).toSet();
    final inboxItems = _buildInboxItems(
      conversations: conversations,
      eventChats: eventChats,
      hiddenChatKeys: hiddenChatKeys,
    );

    if (conversationsLoading && inboxItems.isEmpty) {
      return const SizedBox.shrink();
    }

    if ((conversationsLoadFailed || eventChatsLoadFailed) &&
        inboxItems.isEmpty) {
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

    if (inboxItems.isEmpty) {
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
      itemCount: inboxItems.length,
      itemBuilder: (context, index) {
        final item = inboxItems[index];
        final conversation = item.conversation;
        if (conversation == null) {
          final eventChat = item.eventChat;
          if (eventChat == null) {
            return const SizedBox.shrink();
          }

          return _eventChatCard(
            context,
            chat: eventChat,
            onDelete: () => _hideChat(context, _eventChatHiddenKey(eventChat)),
          );
        }

        return _conversationCard(
          context,
          conversation: conversation,
          isFriend: _conversationPartnerIsFriendPathSet(
            conversation,
            friendPaths,
          ),
          onDelete: () =>
              _hideChat(context, _conversationHiddenKey(conversation)),
        );
      },
    );
  }

  Widget _buildFriendsTabContent(
    BuildContext context, {
    required bool conversationsLoading,
    required bool friendsLoading,
    required List<DocumentReference> friends,
    required List<ConversationsRecord> conversations,
    required Set<String> hiddenChatKeys,
  }) {
    final friendPaths = friends.map((reference) => reference.path).toSet();
    final friendConversations = conversations
        .where(
          (conversation) =>
              _conversationPartnerIsFriendPathSet(
                conversation,
                friendPaths,
              ) &&
              !hiddenChatKeys.contains(_conversationHiddenKey(conversation)),
        )
        .toList();

    if (conversationsLoading || friendsLoading) {
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
        onDelete: () => _hideChat(
          context,
          _conversationHiddenKey(friendConversations[index]),
        ),
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
                final currentUid = currentUserUid;
                final hasCurrentUserDocument = currentUserDocument != null;
                final hasCachedFriends =
                    _friendsCacheByUid.containsKey(currentUid);

                if (currentUid.isEmpty) {
                  return Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: MediaQuery.paddingOf(context).top + 56,
                          ),
                          _buildChatsTabBar(context),
                          const Expanded(child: SizedBox.shrink()),
                        ],
                      ),
                      _buildHeader(context),
                    ],
                  );
                }

                final friends = _friendsForCurrentUser(currentUid);

                return StreamBuilder<_ConversationsLoadState>(
                  stream: _watchConversationsForUser(currentUid),
                  initialData: _cachedConversationsStateForUser(currentUid),
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

                    return StreamBuilder<_EventChatsLoadState>(
                      stream: _watchEventChatsForUser(currentUid),
                      initialData: _cachedEventChatsStateForUser(currentUid),
                      builder: (context, eventChatsSnapshot) {
                        if (eventChatsSnapshot.hasError) {
                          debugPrint(
                            'FavoriteWidget: event chats stream error: ${eventChatsSnapshot.error}',
                          );
                        }

                        final eventChatsState = eventChatsSnapshot.data;
                        final eventChatsLoadFailed =
                            eventChatsSnapshot.hasError;
                        final eventChats =
                            eventChatsState?.eventChats ?? <EventChatsRecord>[];
                        final hiddenChatKeys =
                            _hiddenChatKeysForCurrentUser(currentUid);

                        final showFriendsTab = _selectedChatTabIndex == 1;

                        return Stack(
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(
                                  height:
                                      MediaQuery.paddingOf(context).top + 56,
                                ),
                                _buildChatsTabBar(context),
                                Expanded(
                                  child: showFriendsTab
                                      ? _buildFriendsTabContent(
                                          context,
                                          conversationsLoading:
                                              conversationsLoading,
                                          friendsLoading:
                                              !hasCurrentUserDocument &&
                                                  !hasCachedFriends,
                                          friends: friends,
                                          conversations: conversations,
                                          hiddenChatKeys: hiddenChatKeys,
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
                                          eventChatsLoadFailed:
                                              eventChatsLoadFailed,
                                          eventChats: eventChats,
                                          friends: friends,
                                          hiddenChatKeys: hiddenChatKeys,
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

class _EventChatsLoadState {
  const _EventChatsLoadState({
    this.eventChats = const <EventChatsRecord>[],
  });

  final List<EventChatsRecord> eventChats;
}

class _InboxChatItem {
  const _InboxChatItem._({
    required this.sortAt,
    required this.sortId,
    this.conversation,
    this.eventChat,
  });

  factory _InboxChatItem.conversation(ConversationsRecord conversation) {
    return _InboxChatItem._(
      conversation: conversation,
      sortAt: conversation.lastMessageAt ?? conversation.unlockedAt,
      sortId: conversation.lastMessageId ?? conversation.pairId,
    );
  }

  factory _InboxChatItem.eventChat(EventChatsRecord eventChat) {
    return _InboxChatItem._(
      eventChat: eventChat,
      sortAt: EventGroupChatRepository.inboxSortAt(eventChat),
      sortId: EventGroupChatRepository.eventIdForChat(eventChat),
    );
  }

  final ConversationsRecord? conversation;
  final EventChatsRecord? eventChat;
  final DateTime? sortAt;
  final String sortId;
}

int _compareInboxChatItems(_InboxChatItem a, _InboxChatItem b) {
  final sortAtCmp = _compareNullableDateTimesDescending(a.sortAt, b.sortAt);
  if (sortAtCmp != 0) {
    return sortAtCmp;
  }

  return b.sortId.compareTo(a.sortId);
}

int _compareNullableDateTimesDescending(DateTime? a, DateTime? b) {
  if (a == null && b == null) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  return b.compareTo(a);
}
