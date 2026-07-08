import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/call_details/call_details_widget.dart';
import '/shared_pages/chat_call_event_presentation.dart';
import '/shared_pages/chat_message_bubble_style.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/chat_call_event_card.dart';
import '/services/ux_session_loaded_result_cache.dart';
import 'chat_thread_formatters.dart';
import 'chat_thread_model.dart';
export 'chat_thread_model.dart';

class ChatThreadWidget extends StatefulWidget {
  const ChatThreadWidget({
    super.key,
    required this.conversationRef,
    this.initialConversation,
  });

  final DocumentReference? conversationRef;
  final ConversationsRecord? initialConversation;

  static String routeName = 'chatThread';
  static String routePath = '/chatThread';

  @override
  State<ChatThreadWidget> createState() => _ChatThreadWidgetState();

  @visibleForTesting
  static void debugResetMessageCacheForTesting() {
    _ChatThreadWidgetState._messagesCacheByConversationPath.clear();
  }
}

class _PendingChatMessage {
  const _PendingChatMessage({
    required this.localId,
    required this.messageRef,
    required this.senderId,
    required this.text,
    required this.createdAt,
  });

  final String localId;
  final DocumentReference messageRef;
  final String senderId;
  final String text;
  final DateTime createdAt;
}

class _ChatThreadDisplayMessage {
  const _ChatThreadDisplayMessage._({
    this.record,
    this.pending,
  });

  factory _ChatThreadDisplayMessage.record(MessagesRecord record) =>
      _ChatThreadDisplayMessage._(record: record);

  factory _ChatThreadDisplayMessage.pending(_PendingChatMessage pending) =>
      _ChatThreadDisplayMessage._(pending: pending);

  final MessagesRecord? record;
  final _PendingChatMessage? pending;

  DateTime? get createdAt => record?.createdAt ?? pending?.createdAt;
}

@visibleForTesting
class ChatThreadMessageMergeItem {
  const ChatThreadMessageMergeItem({
    required this.key,
    required this.createdAt,
    required this.isPending,
  });

  final String key;
  final DateTime? createdAt;
  final bool isPending;
}

class _IndexedChatThreadMessageMergeItem {
  const _IndexedChatThreadMessageMergeItem(this.item, this.index);

  final ChatThreadMessageMergeItem item;
  final int index;
}

@visibleForTesting
List<ChatThreadMessageMergeItem> mergeChatThreadMessageItemsForTesting({
  required Iterable<ChatThreadMessageMergeItem> records,
  required Iterable<ChatThreadMessageMergeItem> pending,
}) {
  final recordItems = records.toList(growable: false);
  final pendingItems = pending.toList(growable: false);
  final pendingKeys = pendingItems.map((message) => message.key).toSet();
  final confirmedRecordKeys = recordItems
      .where((record) => record.createdAt != null)
      .map((record) => record.key)
      .toSet();
  final items = <ChatThreadMessageMergeItem>[
    for (final record in recordItems)
      if (record.createdAt != null || !pendingKeys.contains(record.key)) record,
    for (final message in pendingItems)
      if (!confirmedRecordKeys.contains(message.key)) message,
  ];
  final indexedItems = <_IndexedChatThreadMessageMergeItem>[
    for (var index = 0; index < items.length; index += 1)
      _IndexedChatThreadMessageMergeItem(items[index], index),
  ];
  indexedItems.sort((left, right) {
    final dateComparison = _compareChatThreadMessageDates(
      left.item.createdAt,
      right.item.createdAt,
    );
    if (dateComparison != 0) {
      return dateComparison;
    }
    return left.index.compareTo(right.index);
  });
  return List<ChatThreadMessageMergeItem>.unmodifiable(
    indexedItems.map((item) => item.item),
  );
}

int _compareChatThreadMessageDates(DateTime? left, DateTime? right) {
  if (left == null && right == null) {
    return 0;
  }
  if (left == null) {
    return 1;
  }
  if (right == null) {
    return -1;
  }
  return right.compareTo(left);
}

class _ChatThreadWidgetState extends State<ChatThreadWidget> {
  static const int _messagePageSize = 60;
  static final UxSessionLoadedResultCache<List<MessagesRecord>>
      _messagesCacheByConversationPath =
      UxSessionLoadedResultCache<List<MessagesRecord>>();

  late ChatThreadModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _messagesScrollController = ScrollController();
  Stream<ConversationsRecord?>? _conversationStream;
  String? _conversationStreamPath;
  final _publicProfileStreams = <String, Stream<UserPublicProfilesRecord?>>{};
  final _messageStreams = <String, Stream<List<MessagesRecord>>>{};
  final List<_PendingChatMessage> _pendingMessages = <_PendingChatMessage>[];
  DateTime? _lastReadMarkerTarget;
  DateTime? _scheduledReadMarkerTarget;
  int _pendingMessageSerial = 0;
  int _messageLimit = _messagePageSize;
  bool _canLoadOlderMessages = true;
  bool _messageLimitIncreaseScheduled = false;
  bool _isSending = false;

  void _bindConversationRef() {
    final conversationRef = widget.conversationRef;
    final path = conversationRef?.path;
    if (_conversationStreamPath == path) {
      return;
    }

    _conversationStreamPath = path;
    _conversationStream = conversationRef?.snapshots().map(
      (snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          return null;
        }
        return ConversationsRecord.fromSnapshot(snapshot);
      },
    );
    _lastReadMarkerTarget = null;
    _scheduledReadMarkerTarget = null;
    _messageLimit = _messagePageSize;
    _canLoadOlderMessages = true;
    _messageLimitIncreaseScheduled = false;
    _pendingMessages.clear();
  }

  Stream<UserPublicProfilesRecord?> _watchPublicProfile(DocumentReference ref) {
    return _publicProfileStreams.putIfAbsent(
      ref.path,
      () => UserPublicProfilesRecord.maybeGetDocument(
        UserPublicProfilesRecord.collection.doc(ref.id),
      ),
    );
  }

  Stream<List<MessagesRecord>> _watchMessages(DocumentReference conversation) {
    final streamKey = '${conversation.path}:$_messageLimit';
    return _messageStreams.putIfAbsent(
      streamKey,
      () => queryMessagesRecord(
        parent: conversation,
        queryBuilder: (messagesRecord) => messagesRecord.orderBy(
          'createdAt',
          descending: true,
        ),
        limit: _messageLimit,
      ),
    );
  }

  Object _messagesCacheKey(DocumentReference conversation) => [
        'chatThreadMessages',
        currentUserUid,
        conversation.path,
      ];

  List<MessagesRecord>? _cachedMessages(DocumentReference conversation) {
    final messages = _messagesCacheByConversationPath.readItems(
      _messagesCacheKey(conversation),
    );
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages;
  }

  void _rememberMessages(
    DocumentReference conversation,
    List<MessagesRecord> messages,
  ) {
    _messagesCacheByConversationPath.writeItems(
      dataKey: _messagesCacheKey(conversation),
      items: List<MessagesRecord>.unmodifiable(messages),
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

  Future<void> _markConversationRead(ConversationsRecord conversation) async {
    if (currentUserReference == null || currentUserUid.isEmpty) {
      return;
    }

    if (!conversationIsUnreadForUser(conversation, currentUserUid)) {
      return;
    }

    final target = conversation.lastMessageAt ?? conversation.unlockedAt;
    if (target == null) {
      return;
    }

    final currentReadAt = conversation.lastReadAtByUserId[currentUserUid];
    if (currentReadAt != null && !currentReadAt.isBefore(target)) {
      return;
    }

    if (_lastReadMarkerTarget != null &&
        _lastReadMarkerTarget!.isAtSameMomentAs(target)) {
      return;
    }

    _lastReadMarkerTarget = target;
    try {
      await conversation.reference.update({
        'lastReadAtByUserId.$currentUserUid': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint(
        'Failed to advance chat read marker for ${conversation.reference.path}: $error',
      );
    }
  }

  void _scheduleMarkConversationRead(ConversationsRecord conversation) {
    if (!conversationIsUnreadForUser(conversation, currentUserUid)) {
      return;
    }

    final target = conversation.lastMessageAt ?? conversation.unlockedAt;
    if (target == null) {
      return;
    }

    final currentReadAt = conversation.lastReadAtByUserId[currentUserUid];
    if (currentReadAt != null && !currentReadAt.isBefore(target)) {
      return;
    }

    if (_lastReadMarkerTarget != null &&
        _lastReadMarkerTarget!.isAtSameMomentAs(target)) {
      return;
    }

    if (_scheduledReadMarkerTarget != null &&
        _scheduledReadMarkerTarget!.isAtSameMomentAs(target)) {
      return;
    }

    _scheduledReadMarkerTarget = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _scheduledReadMarkerTarget = null;
      _markConversationRead(conversation);
    });
  }

  void _handleMessagesScroll() {
    if (!_messagesScrollController.hasClients ||
        !_canLoadOlderMessages ||
        _messageLimitIncreaseScheduled) {
      return;
    }

    final position = _messagesScrollController.position;
    final distanceToOldest = position.maxScrollExtent - position.pixels;
    if (distanceToOldest > 260.0) {
      return;
    }

    _messageLimitIncreaseScheduled = true;
    setState(() {
      _messageLimit += _messagePageSize;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _messageLimitIncreaseScheduled = false;
    });
  }

  Future<void> _sendMessage(ConversationsRecord conversation) async {
    final currentRef = currentUserReference;
    final currentUid = currentUserUid;
    if (currentRef == null || currentUid.isEmpty || _isSending) {
      return;
    }

    final text = _model.messageTextController?.text.trim() ?? '';
    if (text.isEmpty) {
      return;
    }

    final messageRef = MessagesRecord.createDoc(conversation.reference);
    final pendingMessage = _createPendingMessage(
      messageRef: messageRef,
      senderId: currentUid,
      text: text,
    );
    setState(() {
      _isSending = true;
      _pendingMessages.add(pendingMessage);
    });
    _model.messageTextController?.clear();
    FocusScope.of(context).unfocus();

    try {
      await messageRef.set(
        mapToFirestore(
          <String, dynamic>{
            'senderId': currentUid,
            'senderRef': currentRef,
            'type': kConversationMessageTypeText,
            'text': text,
            'createdAt': FieldValue.serverTimestamp(),
          },
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingMessages.removeWhere(
          (message) => message.localId == pendingMessage.localId,
        );
      });
      final controller = _model.messageTextController;
      if (controller != null && controller.text.trim().isEmpty) {
        controller.text = text;
        controller.selection = TextSelection.collapsed(
          offset: controller.text.length,
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Не удалось отправить сообщение.',
              enText: 'Unable to send message.',
            ),
          ),
        ),
      );
      debugPrint(
        'Failed to send chat message for ${conversation.reference.path}: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  _PendingChatMessage _createPendingMessage({
    required DocumentReference messageRef,
    required String senderId,
    required String text,
  }) {
    final createdAt = DateTime.now();
    final serial = _pendingMessageSerial++;
    return _PendingChatMessage(
      localId: 'pending-${createdAt.microsecondsSinceEpoch}-$serial',
      messageRef: messageRef,
      senderId: senderId,
      text: text,
      createdAt: createdAt,
    );
  }

  List<_ChatThreadDisplayMessage> _displayMessages(
    List<MessagesRecord> records,
  ) {
    final recordsByPath = <String, MessagesRecord>{
      for (final record in records) record.reference.path: record,
    };
    final pendingByPath = <String, _PendingChatMessage>{
      for (final message in _pendingMessages) message.messageRef.path: message,
    };
    final mergedItems = mergeChatThreadMessageItemsForTesting(
      records: records.map(
        (record) => ChatThreadMessageMergeItem(
          key: record.reference.path,
          createdAt: record.createdAt,
          isPending: false,
        ),
      ),
      pending: _pendingMessages.map(
        (message) => ChatThreadMessageMergeItem(
          key: message.messageRef.path,
          createdAt: message.createdAt,
          isPending: true,
        ),
      ),
    );

    return <_ChatThreadDisplayMessage>[
      for (final item in mergedItems)
        if (item.isPending)
          _ChatThreadDisplayMessage.pending(pendingByPath[item.key]!)
        else
          _ChatThreadDisplayMessage.record(recordsByPath[item.key]!),
    ];
  }

  void _schedulePruneConfirmedPendingMessages(List<MessagesRecord> records) {
    if (_pendingMessages.isEmpty || records.isEmpty) {
      return;
    }
    final confirmedPaths = records
        .where((record) => record.createdAt != null)
        .map((record) => record.reference.path)
        .toSet();
    if (confirmedPaths.isEmpty) {
      return;
    }
    final hasConfirmedPending = _pendingMessages.any(
      (message) => confirmedPaths.contains(message.messageRef.path),
    );
    if (!hasConfirmedPending) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingMessages.removeWhere(
          (message) => confirmedPaths.contains(message.messageRef.path),
        );
      });
    });
  }

  Future<void> _toggleFriend(
      DocumentReference partnerRef, bool isFriend) async {
    final currentRef = currentUserReference;
    if (currentRef == null) {
      return;
    }

    try {
      await currentRef.update(
        isFriend
            ? buildRemoveFriendUpdateData(partnerRef)
            : buildAddFriendUpdateData(partnerRef),
      );
    } catch (error) {
      debugPrint(
          'Failed to update friend state for ${partnerRef.path}: $error');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Не удалось обновить список друзей.',
              enText: 'Unable to update friends.',
            ),
          ),
        ),
      );
    }
  }

  String _formatMessageTimestamp(DateTime? timestamp) {
    if (timestamp == null) {
      return '';
    }
    final locale = FFLocalizations.of(context).languageCode;
    return DateFormat.jm(locale).format(timestamp.toLocal());
  }

  bool _isSameMessageDay(DateTime? left, DateTime? right) {
    if (left == null || right == null) {
      return false;
    }

    final leftLocal = left.toLocal();
    final rightLocal = right.toLocal();
    return leftLocal.year == rightLocal.year &&
        leftLocal.month == rightLocal.month &&
        leftLocal.day == rightLocal.day;
  }

  bool _shouldShowDateDivider(
    List<_ChatThreadDisplayMessage> messages,
    int index,
  ) {
    final messageTimestamp = messages[index].createdAt;
    if (messageTimestamp == null) {
      return false;
    }

    if (index == messages.length - 1) {
      return true;
    }

    return !_isSameMessageDay(messageTimestamp, messages[index + 1].createdAt);
  }

  Widget _buildDateDivider(BuildContext context, DateTime timestamp) {
    final locale = FFLocalizations.of(context).languageCode;
    return Center(
      child: Container(
        margin:
            const EdgeInsetsDirectional.only(bottom: ExpatlioDesign.space12),
        padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space12,
            ExpatlioDesign.space8,
            ExpatlioDesign.space12,
            ExpatlioDesign.space8),
        decoration: BoxDecoration(
          color: ExpatlioDesign.card.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        ),
        child: Text(
          formatChatDateDividerLabel(timestamp, locale: locale),
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.muted,
            size: 12.0,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: ExpatlioDesign.background,
      body: Center(
        child: SizedBox(
          width: 50.0,
          height: 50.0,
          child: SpinKitCircle(
            color: FlutterFlowTheme.of(context).secondary,
            size: 50.0,
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: ExpatlioDesign.background,
      body: Center(
        child: SizedBox(
          height: 500.0,
          child: EmptyWidget(
            txt: FFLocalizations.of(context).getVariableText(
              ruText: 'Чат пока недоступен.',
              enText: 'This chat is not available yet.',
            ),
          ),
        ),
      ),
    );
  }

  bool _isPermissionDenied(Object? error) =>
      error is FirebaseException && error.code == 'permission-denied';

  Widget _buildChatUnavailableState(
    BuildContext context, {
    required Object? error,
  }) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: ExpatlioDesign.background,
      body: Center(
        child: SizedBox(
          height: 500.0,
          child: EmptyWidget(
            txt: _isPermissionDenied(error)
                ? FFLocalizations.of(context).getVariableText(
                    ruText: 'У вас нет доступа к этому чату.',
                    enText: 'You do not have access to this chat.',
                  )
                : FFLocalizations.of(context).getVariableText(
                    ruText: 'Не удалось загрузить чат. Попробуйте позже.',
                    enText: 'Could not load this chat. Please try again later.',
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesUnavailableState(
    BuildContext context, {
    required Object? error,
  }) {
    return Center(
      child: SizedBox(
        height: 260.0,
        child: EmptyWidget(
          txt: _isPermissionDenied(error)
              ? FFLocalizations.of(context).getVariableText(
                  ruText: 'У вас нет доступа к сообщениям этого чата.',
                  enText: 'You do not have access to this chat history.',
                )
              : FFLocalizations.of(context).getVariableText(
                  ruText: 'Не удалось загрузить сообщения.',
                  enText: 'Could not load messages.',
                ),
        ),
      ),
    );
  }

  Future<void> _openCallEvent(MessagesRecord message) async {
    final sessionRef = message.sessionRef;
    if (sessionRef == null) {
      _showUnavailableCallDetailsSnackBar();
      return;
    }

    if (!mounted) {
      return;
    }

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) => CallDetailsWidget(videoDocRef: sessionRef),
      ),
    );
  }

  void _showUnavailableCallDetailsSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Не удалось открыть детали звонка.',
            enText: 'Unable to open call details.',
          ),
        ),
      ),
    );
  }

  Widget _buildCallEventMessageCard(
    BuildContext context, {
    required MessagesRecord message,
  }) {
    final presentation = buildChatCallEventPresentation(
      context,
      message: message,
      currentUserUid: currentUserUid,
    );

    return ChatCallEventCard(
      title: presentation.title,
      details: presentation.details,
      icon: presentation.icon,
      tone: presentation.tone,
      onTap: () => _openCallEvent(message),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context, {
    required MessagesRecord message,
    required bool isCurrentUser,
    required bool isReadByPartner,
  }) {
    return _buildTextMessageBubble(
      context,
      text: message.text,
      timestamp: message.createdAt,
      isCurrentUser: isCurrentUser,
      isReadByPartner: isReadByPartner,
    );
  }

  Widget _buildPendingMessageBubble(
    BuildContext context, {
    required _PendingChatMessage message,
  }) {
    return _buildTextMessageBubble(
      context,
      text: message.text,
      timestamp: message.createdAt,
      isCurrentUser: true,
      isReadByPartner: false,
    );
  }

  Widget _buildTextMessageBubble(
    BuildContext context, {
    required String text,
    required DateTime? timestamp,
    required bool isCurrentUser,
    required bool isReadByPartner,
  }) {
    final bubbleColor = chatMessageBubbleColor(isCurrentUser: isCurrentUser);
    final textColor = chatMessageTextColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = math.min(
          320.0,
          constraints.maxWidth * 0.76,
        );

        return Align(
          alignment: isCurrentUser
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: Container(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            margin:
                const EdgeInsetsDirectional.only(bottom: ExpatlioDesign.space8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(ExpatlioDesign.radiusLarge),
                topRight: const Radius.circular(ExpatlioDesign.radiusLarge),
                bottomLeft: Radius.circular(
                  isCurrentUser
                      ? ExpatlioDesign.radiusLarge
                      : ExpatlioDesign.radiusSmall,
                ),
                bottomRight: Radius.circular(
                  isCurrentUser
                      ? ExpatlioDesign.radiusSmall
                      : ExpatlioDesign.radiusLarge,
                ),
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space16,
                ExpatlioDesign.space12,
                ExpatlioDesign.space16,
                ExpatlioDesign.space8),
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        color: textColor,
                        fontSize: 15.0,
                        letterSpacing: 0.0,
                      ),
                ),
                if (timestamp != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                        top: ExpatlioDesign.space4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTimestamp(timestamp),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'sf pro display',
                                    color: textColor.withValues(alpha: 0.58),
                                    fontSize: 11.0,
                                    letterSpacing: 0.0,
                                  ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: ExpatlioDesign.space4),
                          Icon(
                            isReadByPartner
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            color: chatMessageReadReceiptColor(
                              isReadByPartner: isReadByPartner,
                            ),
                            size: 14.0,
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required ConversationsRecord conversation,
    required UserPublicProfilesRecord? partnerProfile,
    required DocumentReference partnerRef,
    required bool isFriend,
  }) {
    final partnerName = _partnerDisplayName(
      context,
      conversation: conversation,
      partnerProfile: partnerProfile,
      partnerRef: partnerRef,
    );
    final partnerPhotoUrl = _partnerPhotoUrl(
      conversation: conversation,
      partnerProfile: partnerProfile,
      partnerRef: partnerRef,
    );
    final locale = FFLocalizations.of(context).languageCode;
    final presenceLabel = formatChatPresenceLabel(
      partnerProfile?.lastSeenAt,
      locale: locale,
    );
    final isOnline = chatPartnerIsOnline(partnerProfile?.lastSeenAt);
    final friendButtonLabel = isFriend
        ? FFLocalizations.of(context).getVariableText(
            ruText: 'Убрать из друзей',
            enText: 'Remove',
          )
        : FFLocalizations.of(context).getVariableText(
            ruText: 'В друзья',
            enText: 'Add',
          );
    final friendButtonWidth = isFriend ? 148.0 : 104.0;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ExpatlioDesign.card,
        border: Border(
          bottom: BorderSide(color: ExpatlioDesign.separator, width: 1.0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58.0,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                ExpatlioDesign.space4,
                ExpatlioDesign.space8,
                ExpatlioDesign.space8,
                ExpatlioDesign.space8),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(
                    Icons.arrow_back,
                    color: ExpatlioDesign.text,
                    size: 24.0,
                  ),
                  splashRadius: 22.0,
                ),
                _buildPartnerAvatar(
                  context,
                  displayName: partnerName,
                  photoUrl: partnerPhotoUrl,
                  size: 40.0,
                ),
                const SizedBox(width: ExpatlioDesign.space12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              partnerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: ExpatlioDesign.textStyle(
                                context,
                                size: 16.0,
                                weight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (isFriend)
                            const Padding(
                              padding: EdgeInsetsDirectional.only(
                                  start: ExpatlioDesign.space4),
                              child: Icon(
                                Icons.star_rounded,
                                color: ExpatlioDesign.warning,
                                size: 17.0,
                              ),
                            ),
                        ],
                      ),
                      if (presenceLabel.isNotEmpty) ...[
                        const SizedBox(height: ExpatlioDesign.space4),
                        Text(
                          presenceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: ExpatlioDesign.textStyle(
                            context,
                            color: isOnline
                                ? ExpatlioDesign.primary
                                : ExpatlioDesign.muted,
                            size: 12.0,
                            weight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: ExpatlioDesign.space8),
                Semantics(
                  button: true,
                  label: friendButtonLabel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _toggleFriend(partnerRef, isFriend),
                    child: SizedBox(
                      width: friendButtonWidth,
                      height: 44.0,
                      child: Center(
                        child: SizedBox(
                          width: friendButtonWidth,
                          height: 35.0,
                          child: ExcludeSemantics(
                            child: IgnorePointer(
                              child: OutlinedButton.icon(
                                onPressed: () {},
                                icon: Icon(
                                  isFriend
                                      ? Icons.person_remove_alt_1_rounded
                                      : Icons.person_add_alt_1_rounded,
                                  size: 16.0,
                                ),
                                label: Text(
                                  friendButtonLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: ExpatlioDesign.primary,
                                  side: const BorderSide(
                                    color: ExpatlioDesign.border,
                                  ),
                                  minimumSize: Size.zero,
                                  fixedSize: Size.fromHeight(35.0),
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        ExpatlioDesign.radiusMedium),
                                  ),
                                  padding:
                                      const EdgeInsetsDirectional.symmetric(
                                    horizontal: ExpatlioDesign.space8,
                                  ),
                                  textStyle: ExpatlioDesign.textStyle(
                                    context,
                                    size: 12.0,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _partnerDisplayName(
    BuildContext context, {
    required ConversationsRecord conversation,
    required UserPublicProfilesRecord? partnerProfile,
    required DocumentReference partnerRef,
  }) {
    var partnerName = partnerProfile?.displayName.trim() ?? '';
    if (partnerName.isEmpty) {
      partnerName = _conversationParticipantDisplayName(
        conversation,
        partnerRef,
      );
    }

    return partnerName.isNotEmpty
        ? partnerName
        : FFLocalizations.of(context).getVariableText(
            ruText: 'Собеседник',
            enText: 'Conversation partner',
          );
  }

  String _partnerPhotoUrl({
    required ConversationsRecord conversation,
    required UserPublicProfilesRecord? partnerProfile,
    required DocumentReference partnerRef,
  }) {
    final profilePhotoUrl = partnerProfile?.photoUrl.trim() ?? '';
    if (profilePhotoUrl.isNotEmpty) {
      return profilePhotoUrl;
    }

    return _conversationParticipantPhotoUrl(conversation, partnerRef);
  }

  Widget _buildPartnerAvatar(
    BuildContext context, {
    required String displayName,
    required String photoUrl,
    required double size,
  }) {
    final normalizedPhotoUrl = photoUrl.trim();
    final fallbackText = ExpatlioDesign.avatarInitial(displayName);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ExpatlioDesign.avatarFallbackBackground,
        shape: BoxShape.circle,
        border: Border.all(color: ExpatlioDesign.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: normalizedPhotoUrl.isNotEmpty
          ? CachedNetworkImage(
              imageUrl: normalizedPhotoUrl,
              fit: BoxFit.cover,
              memCacheWidth:
                  (size * MediaQuery.devicePixelRatioOf(context)).round(),
              memCacheHeight:
                  (size * MediaQuery.devicePixelRatioOf(context)).round(),
              fadeInDuration: Duration.zero,
              fadeOutDuration: Duration.zero,
              errorWidget: (_, __, ___) => _buildAvatarFallback(
                context,
                fallbackText,
              ),
              placeholder: (_, __) => _buildAvatarFallback(
                context,
                fallbackText,
              ),
            )
          : _buildAvatarFallback(context, fallbackText),
    );
  }

  Widget _buildAvatarFallback(BuildContext context, String fallbackText) {
    return Center(
      child: Text(
        fallbackText,
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.avatarFallbackText,
          size: 13.0,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatThreadModel());
    _messagesScrollController.addListener(_handleMessagesScroll);
    _bindConversationRef();
  }

  @override
  void didUpdateWidget(ChatThreadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindConversationRef();
  }

  @override
  void dispose() {
    _messagesScrollController.removeListener(_handleMessagesScroll);
    _messagesScrollController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversationRef = widget.conversationRef;
    if (conversationRef == null) {
      return _buildEmptyState(context);
    }

    return StreamBuilder<ConversationsRecord?>(
      stream: _conversationStream,
      initialData: widget.initialConversation,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            'ChatThreadWidget: conversation stream error for ${conversationRef.path}: ${snapshot.error}',
          );
          return _buildChatUnavailableState(
            context,
            error: snapshot.error,
          );
        }

        if (!snapshot.hasData &&
            snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(context);
        }

        final conversation = snapshot.data;
        if (conversation == null) {
          return _buildEmptyState(context);
        }

        final currentRef = currentUserReference;
        if (currentRef == null ||
            !conversation.participantIds.contains(currentUserUid) ||
            !conversation.isUnlocked) {
          return _buildEmptyState(context);
        }

        final partnerRef = _otherParticipantRef(conversation);
        if (partnerRef == null) {
          return _buildEmptyState(context);
        }

        _scheduleMarkConversationRead(conversation);

        return Scaffold(
          key: scaffoldKey,
          backgroundColor: ExpatlioDesign.background,
          body: Stack(
            children: [
              Column(
                children: [
                  StreamBuilder<UserPublicProfilesRecord?>(
                    stream: _watchPublicProfile(partnerRef),
                    builder: (context, partnerSnapshot) {
                      if (partnerSnapshot.hasError) {
                        debugPrint(
                          'ChatThreadWidget: partner public profile stream failed for ${partnerRef.path}: ${partnerSnapshot.error}',
                        );
                      }

                      return AuthUserStreamWidget(
                        builder: (context) {
                          final isFriend = userHasFriend(
                            currentUserDocument,
                            partnerRef,
                          );

                          return _buildHeader(
                            context,
                            conversation: conversation,
                            partnerProfile: partnerSnapshot.hasError
                                ? null
                                : partnerSnapshot.data,
                            partnerRef: partnerRef,
                            isFriend: isFriend,
                          );
                        },
                      );
                    },
                  ),
                  Expanded(
                    child: StreamBuilder<List<MessagesRecord>>(
                      stream: _watchMessages(conversation.reference),
                      initialData: _cachedMessages(conversation.reference),
                      builder: (context, messagesSnapshot) {
                        if (messagesSnapshot.hasError) {
                          debugPrint(
                            'ChatThreadWidget: messages stream error for ${conversation.reference.path}: ${messagesSnapshot.error}',
                          );
                          return _buildMessagesUnavailableState(
                            context,
                            error: messagesSnapshot.error,
                          );
                        }

                        final messages = messagesSnapshot.data ??
                            _cachedMessages(conversation.reference);
                        if (messages == null && _pendingMessages.isEmpty) {
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

                        if (messagesSnapshot.connectionState !=
                                ConnectionState.waiting &&
                            messagesSnapshot.hasData &&
                            messages != null) {
                          final confirmedMessages = messages
                              .where((message) => message.createdAt != null)
                              .toList(growable: false);
                          _rememberMessages(
                            conversation.reference,
                            confirmedMessages,
                          );
                          _schedulePruneConfirmedPendingMessages(messages);
                        }
                        final serverMessages =
                            messages ?? const <MessagesRecord>[];
                        _canLoadOlderMessages =
                            serverMessages.length >= _messageLimit;
                        final displayMessages =
                            _displayMessages(serverMessages);

                        if (displayMessages.isEmpty) {
                          return Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.all(ExpatlioDesign.space24),
                              child: Text(
                                FFLocalizations.of(context).getVariableText(
                                  ruText:
                                      'Чат открыт. Напишите первое сообщение.',
                                  enText:
                                      'The chat is open. Send the first message.',
                                ),
                                textAlign: TextAlign.center,
                                style: FlutterFlowTheme.of(context)
                                    .bodyMedium
                                    .override(
                                      fontFamily: 'sf pro display',
                                      color: FlutterFlowTheme.of(context)
                                          .secondaryText,
                                      fontSize: 15.0,
                                      letterSpacing: 0.0,
                                    ),
                              ),
                            ),
                          );
                        }

                        return ListView.builder(
                          controller: _messagesScrollController,
                          reverse: true,
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            ExpatlioDesign.pagePadding,
                            ExpatlioDesign.space12,
                            ExpatlioDesign.pagePadding,
                            ExpatlioDesign.space112,
                          ),
                          itemCount: displayMessages.length,
                          itemBuilder: (context, index) {
                            final displayMessage = displayMessages[index];
                            final itemChildren = <Widget>[];
                            if (_shouldShowDateDivider(
                              displayMessages,
                              index,
                            )) {
                              itemChildren.add(
                                _buildDateDivider(
                                  context,
                                  displayMessage.createdAt!,
                                ),
                              );
                            }

                            final record = displayMessage.record;
                            final pendingMessage = displayMessage.pending;
                            if (record != null && messageIsCallEvent(record)) {
                              itemChildren.add(
                                _buildCallEventMessageCard(
                                  context,
                                  message: record,
                                ),
                              );
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: itemChildren,
                              );
                            }

                            if (pendingMessage != null) {
                              itemChildren.add(
                                _buildPendingMessageBubble(
                                  context,
                                  message: pendingMessage,
                                ),
                              );
                            } else if (record != null) {
                              final isCurrentUser =
                                  record.senderId == currentUserUid;
                              final partnerReadAt = conversation
                                  .lastReadAtByUserId[partnerRef.id];
                              final isReadByPartner = isCurrentUser &&
                                  record.createdAt != null &&
                                  partnerReadAt != null &&
                                  !partnerReadAt.isBefore(record.createdAt!);
                              itemChildren.add(
                                _buildMessageBubble(
                                  context,
                                  message: record,
                                  isCurrentUser: isCurrentUser,
                                  isReadByPartner: isReadByPartner,
                                ),
                              );
                            }

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: itemChildren,
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.bottomCenter,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        ExpatlioDesign.background.withValues(alpha: 0.0),
                        ExpatlioDesign.background.withValues(alpha: 0.84),
                        ExpatlioDesign.background,
                      ],
                      stops: const [0.0, 0.2, 1.0],
                      begin: const AlignmentDirectional(0.0, -1.0),
                      end: const AlignmentDirectional(0.0, 1.0),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.space12,
                      ExpatlioDesign.pagePadding,
                      ExpatlioDesign.space32,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _model.messageTextController,
                            focusNode: _model.messageFocusNode,
                            textCapitalization: TextCapitalization.sentences,
                            textInputAction: TextInputAction.send,
                            textAlignVertical: TextAlignVertical.center,
                            maxLines: 4,
                            minLines: 1,
                            decoration: ExpatlioDesign.formFieldDecoration(
                              context,
                              hintText:
                                  FFLocalizations.of(context).getVariableText(
                                ruText: 'Написать сообщение',
                                enText: 'Write a message',
                              ),
                            ),
                            style: ExpatlioDesign.formTextStyle(context),
                            onFieldSubmitted: (_) => _sendMessage(conversation),
                          ),
                        ),
                        const SizedBox(width: ExpatlioDesign.space8),
                        SizedBox(
                          width: ExpatlioDesign.formFieldHeight,
                          height: ExpatlioDesign.formFieldHeight,
                          child: Material(
                            color: ExpatlioDesign.primary,
                            borderRadius: BorderRadius.circular(
                                ExpatlioDesign.radiusMedium),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(
                                  ExpatlioDesign.radiusMedium),
                              onTap: _isSending
                                  ? null
                                  : () => _sendMessage(conversation),
                              child: Icon(
                                _isSending
                                    ? Icons.hourglass_top_rounded
                                    : Icons.send_rounded,
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                size: 22.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
