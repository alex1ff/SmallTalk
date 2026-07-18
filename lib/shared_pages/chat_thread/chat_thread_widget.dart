import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/chat_composer.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/call_details/call_details_widget.dart';
import '/shared_pages/chat_call_event_presentation.dart';
import '/shared_pages/chat_local_message_status.dart';
import '/shared_pages/chat_local_message_status_icon.dart';
import '/shared_pages/chat_message_bubble_style.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/components/chat_call_event_card.dart';
import '/services/ux_loading_state.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';
import 'chat_thread_formatters.dart';
import 'chat_thread_model.dart';
export 'chat_thread_model.dart';

const ValueKey<String> chatThreadConversationInlineErrorKey =
    ValueKey<String>('chat_thread_conversation_inline_error');
const ValueKey<String> chatThreadConversationRetryButtonKey =
    ValueKey<String>('chat_thread_conversation_retry_button');
const ValueKey<String> chatThreadMessagesInlineErrorKey =
    ValueKey<String>('chat_thread_messages_inline_error');
const ValueKey<String> chatThreadMessagesRetryButtonKey =
    ValueKey<String>('chat_thread_messages_retry_button');
const ValueKey<String> chatThreadMessageInputKey =
    ValueKey<String>('chat_thread_message_input');
const ValueKey<String> chatThreadSendButtonKey =
    ValueKey<String>('chat_thread_send_button');
const ValueKey<String> chatThreadSendErrorSnackBarKey =
    ValueKey<String>('chat_thread_send_error_snack_bar');

final class ChatThreadConversationLoadState {
  const ChatThreadConversationLoadState({
    required this.ownerUid,
    required this.conversation,
    required this.isFromCache,
    required this.hasPendingWrites,
  });

  final String ownerUid;
  final ConversationsRecord? conversation;
  final bool isFromCache;
  final bool hasPendingWrites;

  bool get isAuthoritative => !isFromCache && !hasPendingWrites;
  bool get canResolveMissing => conversation != null || isAuthoritative;
}

final class ChatThreadMessagesLoadState {
  ChatThreadMessagesLoadState({
    required this.ownerUid,
    required Iterable<MessagesRecord> messages,
    required this.isFromCache,
    required this.hasPendingWrites,
    Iterable<String> pendingWriteMessagePaths = const <String>[],
    DateTime? pendingWritesObservedAt,
  })  : messages = List<MessagesRecord>.unmodifiable(messages),
        pendingWriteMessagePaths = Set<String>.unmodifiable(
          pendingWriteMessagePaths,
        ),
        pendingWritesObservedAt = pendingWritesObservedAt ?? DateTime.now();

  final String ownerUid;
  final List<MessagesRecord> messages;
  final bool isFromCache;
  final bool hasPendingWrites;
  final Set<String> pendingWriteMessagePaths;
  final DateTime pendingWritesObservedAt;

  bool get isAuthoritative => !isFromCache && !hasPendingWrites;
  bool get canResolveEmpty => messages.isNotEmpty || isAuthoritative;
}

final class _ChatThreadMessagesCacheEntry {
  _ChatThreadMessagesCacheEntry({
    required Iterable<MessagesRecord> messages,
    required this.limit,
  }) : messages = List<MessagesRecord>.unmodifiable(messages);

  final List<MessagesRecord> messages;
  final int limit;
}

typedef ChatThreadConversationStream = Stream<ChatThreadConversationLoadState>
    Function(
  DocumentReference conversationRef,
  String ownerUid,
);
typedef ChatThreadMessagesStream = Stream<ChatThreadMessagesLoadState> Function(
  DocumentReference conversationRef,
  int limit,
  String ownerUid,
);
typedef ChatThreadPublicProfileStream = Stream<UserPublicProfilesRecord?>
    Function(
  DocumentReference userRef,
);
typedef ChatThreadMessageWrite = Future<void> Function(
  DocumentReference messageRef,
  Map<String, dynamic> data,
);

ValueKey<String> chatThreadMessageItemKey(String messageKey) =>
    ValueKey<String>('chat_thread_message_item_$messageKey');

ValueKey<String> chatThreadMessageBubbleKey(String messageKey) =>
    ValueKey<String>('chat_thread_message_bubble_$messageKey');

ValueKey<String> chatThreadMessageTimestampSlotKey(String messageKey) =>
    ValueKey<String>('chat_thread_message_timestamp_slot_$messageKey');

ValueKey<String> chatThreadMessageTimestampTextKey(String messageKey) =>
    ValueKey<String>('chat_thread_message_timestamp_text_$messageKey');

ValueKey<String> chatThreadMessageStatusSlotKey(String messageKey) =>
    ValueKey<String>('chat_thread_message_status_slot_$messageKey');

ValueKey<String> chatThreadMessageRetrySlotKey(String messageKey) =>
    ValueKey<String>('chat_thread_message_retry_slot_$messageKey');

ValueKey<String> chatThreadMessageRetryButtonKey(String messageKey) =>
    ValueKey<String>('chat_thread_message_retry_button_$messageKey');

class ChatThreadMessageBubble extends StatelessWidget {
  const ChatThreadMessageBubble({
    super.key,
    required this.messageKey,
    required this.text,
    required this.timestampText,
    required this.isCurrentUser,
    required this.isReadByPartner,
    this.localStatus,
    this.onRetry,
  });

  static const double _shortTimestampSlotWidth = 60.0;
  static const double _twelveHourTimestampSlotWidth = 92.0;
  static const double _metadataHeight = 24.0;
  static const double _statusSlotSize = 14.0;

  final String messageKey;
  final String text;
  final String? timestampText;
  final bool isCurrentUser;
  final bool isReadByPartner;
  final ChatLocalMessageStatus? localStatus;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
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
            key: chatThreadMessageBubbleKey(messageKey),
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
              ExpatlioDesign.space8,
            ),
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
                if (isCurrentUser || timestampText != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(
                      top: ExpatlioDesign.space4,
                    ),
                    child: isCurrentUser
                        ? _buildOutgoingMetadata(context, textColor)
                        : _buildIncomingTimestamp(context, textColor),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutgoingMetadata(BuildContext context, Color textColor) {
    final canRetry =
        localStatus == ChatLocalMessageStatus.failed && onRetry != null;
    final timestampSlotWidth = FFLocalizations.of(context).languageCode == 'en'
        ? _twelveHourTimestampSlotWidth
        : _shortTimestampSlotWidth;

    return SizedBox(
      height: _metadataHeight,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            key: chatThreadMessageTimestampSlotKey(messageKey),
            width: timestampSlotWidth,
            child: Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                timestampText ?? '',
                key: chatThreadMessageTimestampTextKey(messageKey),
                maxLines: 1,
                overflow: TextOverflow.clip,
                textScaler: TextScaler.noScaling,
                style: _timestampStyle(context, textColor),
              ),
            ),
          ),
          const SizedBox(width: ExpatlioDesign.space4),
          SizedBox.square(
            key: chatThreadMessageStatusSlotKey(messageKey),
            dimension: _statusSlotSize,
            child: localStatus == null
                ? Icon(
                    isReadByPartner
                        ? Icons.done_all_rounded
                        : Icons.done_rounded,
                    color: chatMessageReadReceiptColor(
                      isReadByPartner: isReadByPartner,
                    ),
                    size: _statusSlotSize,
                  )
                : ChatLocalMessageStatusIcon(
                    status: localStatus!,
                    size: _statusSlotSize,
                  ),
          ),
          const SizedBox(width: ExpatlioDesign.space4),
          SizedBox(
            key: chatThreadMessageRetrySlotKey(messageKey),
            child: Visibility(
              visible: canRetry,
              maintainState: true,
              maintainAnimation: true,
              maintainSize: true,
              child: _buildRetryMessageButton(
                context,
                canRetry ? onRetry : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingTimestamp(BuildContext context, Color textColor) {
    return KeyedSubtree(
      key: chatThreadMessageTimestampSlotKey(messageKey),
      child: Text(
        timestampText!,
        key: chatThreadMessageTimestampTextKey(messageKey),
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: _timestampStyle(context, textColor),
      ),
    );
  }

  TextStyle _timestampStyle(BuildContext context, Color textColor) {
    return FlutterFlowTheme.of(context).bodyMedium.override(
          fontFamily: 'sf pro display',
          color: textColor.withValues(alpha: 0.58),
          fontSize: 11.0,
          letterSpacing: 0.0,
        );
  }

  Widget _buildRetryMessageButton(
    BuildContext context,
    VoidCallback? onRetry,
  ) {
    return TextButton(
      key: chatThreadMessageRetryButtonKey(messageKey),
      onPressed: onRetry,
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ExpatlioDesign.space4,
          vertical: 2.0,
        ),
      ),
      child: Text(
        FFLocalizations.of(context).getVariableText(
          ruText: 'Повторить',
          enText: 'Retry',
        ),
        maxLines: 1,
        textScaler: TextScaler.noScaling,
        style: FlutterFlowTheme.of(context).bodyMedium.override(
              fontFamily: 'sf pro display',
              color: ExpatlioDesign.danger,
              fontSize: 11.0,
              letterSpacing: 0.0,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class ChatThreadWidget extends StatefulWidget {
  const ChatThreadWidget({
    super.key,
    required this.conversationRef,
    this.initialConversation,
    this.debugConversationStream,
    this.debugMessagesStream,
    this.debugPublicProfileStream,
    this.debugAuthenticatedOwnerUidStream,
    this.debugMessageWrite,
  });

  final DocumentReference? conversationRef;
  final ConversationsRecord? initialConversation;
  final ChatThreadConversationStream? debugConversationStream;
  final ChatThreadMessagesStream? debugMessagesStream;
  final ChatThreadPublicProfileStream? debugPublicProfileStream;
  final Stream<String>? debugAuthenticatedOwnerUidStream;
  @visibleForTesting
  final ChatThreadMessageWrite? debugMessageWrite;

  static String routeName = 'chatThread';
  static String routePath = '/chatThread';

  @override
  State<ChatThreadWidget> createState() => _ChatThreadWidgetState();

  @visibleForTesting
  static void debugResetMessageCacheForTesting() {
    _ChatThreadWidgetState._clearMessagesCache();
  }
}

class _PendingChatMessage {
  const _PendingChatMessage({
    required this.localId,
    required this.messageRef,
    required this.senderId,
    required this.text,
    required this.createdAt,
    required this.status,
  });

  final String localId;
  final DocumentReference messageRef;
  final String senderId;
  final String text;
  final DateTime createdAt;
  final ChatLocalMessageStatus status;

  _PendingChatMessage copyWith({
    ChatLocalMessageStatus? status,
  }) =>
      _PendingChatMessage(
        localId: localId,
        messageRef: messageRef,
        senderId: senderId,
        text: text,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}

class _ChatThreadSendErrorSnackBarHandle {
  _ChatThreadSendErrorSnackBarHandle({
    required this.controller,
    required this.messenger,
    required this.messagePath,
  });

  final ScaffoldFeatureController<SnackBar, SnackBarClosedReason> controller;
  final ScaffoldMessengerState messenger;
  final String messagePath;
  bool isClosed = false;
}

class _ChatThreadDisplayMessage {
  const _ChatThreadDisplayMessage._({
    this.record,
    this.pending,
    this.sortCreatedAt,
  });

  factory _ChatThreadDisplayMessage.record(
    MessagesRecord record, {
    DateTime? sortCreatedAt,
  }) =>
      _ChatThreadDisplayMessage._(
        record: record,
        sortCreatedAt: sortCreatedAt,
      );

  factory _ChatThreadDisplayMessage.pending(_PendingChatMessage pending) =>
      _ChatThreadDisplayMessage._(pending: pending);

  final MessagesRecord? record;
  final _PendingChatMessage? pending;
  final DateTime? sortCreatedAt;

  String get itemKey => record?.reference.path ?? pending!.messageRef.path;

  DateTime? get createdAt =>
      record?.createdAt ?? pending?.createdAt ?? sortCreatedAt;
}

@visibleForTesting
class ChatThreadMessageMergeItem {
  const ChatThreadMessageMergeItem({
    required this.key,
    required this.createdAt,
    required this.isPending,
    this.sortCreatedAt,
  });

  final String key;
  final DateTime? createdAt;
  final bool isPending;
  final DateTime? sortCreatedAt;
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
    final orderComparison = _compareChatThreadMessageOrder(
      leftCreatedAt: left.item.sortCreatedAt ?? left.item.createdAt,
      leftKey: left.item.key,
      rightCreatedAt: right.item.sortCreatedAt ?? right.item.createdAt,
      rightKey: right.item.key,
    );
    if (orderComparison != 0) {
      return orderComparison;
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

int _compareChatThreadMessageOrder({
  required DateTime? leftCreatedAt,
  required String leftKey,
  required DateTime? rightCreatedAt,
  required String rightKey,
}) {
  final dateComparison = _compareChatThreadMessageDates(
    leftCreatedAt,
    rightCreatedAt,
  );
  if (dateComparison != 0) {
    return dateComparison;
  }
  return rightKey.compareTo(leftKey);
}

class _ChatThreadWidgetState extends State<ChatThreadWidget> {
  static const int _messagePageSize = 60;
  static final UxSessionLoadedResultCache<_ChatThreadMessagesCacheEntry>
      _messagesCacheByConversationPath =
      UxSessionLoadedResultCache<_ChatThreadMessagesCacheEntry>();

  late ChatThreadModel _model;
  late Stream<String> _authenticatedOwnerUidStream;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _messagesScrollController = ScrollController();
  Stream<ChatThreadConversationLoadState>? _conversationStream;
  String? _conversationStreamPath;
  String? _conversationStreamOwnerUid;
  ChatThreadConversationStream? _conversationStreamLoader;
  ConversationsRecord? _retainedConversation;
  List<MessagesRecord>? _retainedMessages;
  Set<String> _retainedPendingWriteMessagePaths = const <String>{};
  Map<String, DateTime> _retainedPendingWriteObservedAtByPath =
      const <String, DateTime>{};
  String? _retainedMessagesOwnerUid;
  String? _retainedMessagesConversationPath;
  String _activeOwnerUid = '';
  int _dataGeneration = 0;
  int _conversationStreamRevision = 0;
  int _messageStreamRevision = 0;
  final _publicProfileStreams = <String, Stream<UserPublicProfilesRecord?>>{};
  final _messageStreams = <String, Stream<ChatThreadMessagesLoadState>>{};
  final List<_PendingChatMessage> _pendingMessages = <_PendingChatMessage>[];
  _ChatThreadSendErrorSnackBarHandle? _sendErrorSnackBarHandle;
  DateTime? _lastReadMarkerTarget;
  DateTime? _scheduledReadMarkerTarget;
  int _pendingMessageSerial = 0;
  int _messageLimit = _messagePageSize;
  bool _canLoadOlderMessages = true;
  bool _messageLimitIncreaseScheduled = false;
  bool _isSending = false;
  bool _conversationActionsBlocked = false;
  bool _messageActionsBlocked = false;
  bool _hasConfirmedUnavailableConversation = false;
  bool _hasConfirmedConversationAccessDenied = false;
  bool _chatBoundaryRebuildScheduled = false;
  bool _clearComposerOnBoundaryRebuild = false;

  bool get _chatActionsBlocked =>
      _conversationActionsBlocked || _messageActionsBlocked;

  static void _clearMessagesCache() {
    _messagesCacheByConversationPath.clear();
  }

  String _readAuthenticatedOwnerUid() =>
      (FirebaseAuth.instance.currentUser?.uid ?? currentUser?.uid ?? '').trim();

  Stream<String> _createAuthenticatedOwnerUidStream() =>
      widget.debugAuthenticatedOwnerUidStream ??
      FirebaseAuth.instance
          .authStateChanges()
          .map((user) => (user?.uid ?? '').trim())
          .distinct();

  void _synchronizeAuthenticatedOwner(String ownerUid) {
    final normalizedOwnerUid = ownerUid.trim();
    if (_activeOwnerUid == normalizedOwnerUid) {
      return;
    }
    UxSessionCacheLifecycle.updateAuthenticatedUser(
      normalizedOwnerUid.isEmpty ? null : normalizedOwnerUid,
    );
    _activeOwnerUid = normalizedOwnerUid;
    _bindConversationRef();
  }

  void _bindConversationRef() {
    final conversationRef = widget.conversationRef;
    final path = conversationRef?.path;
    final ownerUid = _activeOwnerUid;
    final loader = widget.debugConversationStream;
    if (_conversationStreamPath == path &&
        _conversationStreamOwnerUid == ownerUid &&
        identical(_conversationStreamLoader, loader)) {
      return;
    }

    final previousOwnerUid = _conversationStreamOwnerUid;
    final dataKeyChanged =
        _conversationStreamPath != path || previousOwnerUid != ownerUid;
    final ownerChanged =
        previousOwnerUid != null && previousOwnerUid != ownerUid;
    _conversationStreamPath = path;
    _conversationStreamOwnerUid = ownerUid;
    _conversationStreamLoader = loader;
    _conversationStream = conversationRef == null || ownerUid.isEmpty
        ? null
        : _createConversationStream(conversationRef);
    _conversationStreamRevision += 1;

    if (!dataKeyChanged) {
      return;
    }

    _scheduleDismissSendErrorSnackBar();
    _dataGeneration += 1;
    final initialConversation = widget.initialConversation;
    _retainedConversation = !ownerChanged &&
            initialConversation != null &&
            conversationRef != null &&
            initialConversation.reference.path == conversationRef.path &&
            ownerUid.isNotEmpty &&
            initialConversation.participantIds.contains(ownerUid)
        ? initialConversation
        : null;
    _retainedMessages = null;
    _retainedPendingWriteMessagePaths = const <String>{};
    _retainedPendingWriteObservedAtByPath = const <String, DateTime>{};
    _retainedMessagesOwnerUid = null;
    _retainedMessagesConversationPath = null;
    _lastReadMarkerTarget = null;
    _scheduledReadMarkerTarget = null;
    final cachedMessagesEntry = conversationRef != null && ownerUid.isNotEmpty
        ? _cachedMessagesEntry(conversationRef)
        : null;
    _messageLimit = math.max(
      _messagePageSize,
      cachedMessagesEntry?.limit ?? _messagePageSize,
    );
    _messageStreamRevision = 0;
    _canLoadOlderMessages = cachedMessagesEntry == null ||
        cachedMessagesEntry.messages.length >= _messageLimit;
    _messageLimitIncreaseScheduled = false;
    _isSending = false;
    _conversationActionsBlocked = false;
    _messageActionsBlocked = false;
    _hasConfirmedUnavailableConversation = false;
    _hasConfirmedConversationAccessDenied = false;
    _clearComposerOnBoundaryRebuild = false;
    _pendingMessages.clear();
    _messageStreams.clear();
    _publicProfileStreams.clear();
    _model.messageTextController?.clear();
    _model.messageFocusNode?.unfocus();
  }

  Stream<ChatThreadConversationLoadState> _createConversationStream(
    DocumentReference conversationRef,
  ) {
    final ownerUid = _activeOwnerUid;
    final debugStream = widget.debugConversationStream;
    final stream = debugStream != null
        ? debugStream(conversationRef, ownerUid)
        : conversationRef
            .snapshots(includeMetadataChanges: true)
            .map((snapshot) {
            final conversation = !snapshot.exists || snapshot.data() == null
                ? null
                : ConversationsRecord.fromSnapshot(snapshot);
            return ChatThreadConversationLoadState(
              ownerUid: ownerUid,
              conversation: conversation,
              isFromCache: snapshot.metadata.isFromCache,
              hasPendingWrites: snapshot.metadata.hasPendingWrites,
            );
          });

    return stream.map((state) {
      final conversation = state.conversation;
      if (state.ownerUid != ownerUid) {
        throw StateError('Conversation belongs to another owner.');
      }
      if (conversation != null &&
          conversation.reference.path != conversationRef.path) {
        throw StateError(
          'Conversation stream returned ${conversation.reference.path} '
          'for ${conversationRef.path}.',
        );
      }
      return state;
    }).where((state) => state.canResolveMissing);
  }

  Stream<UserPublicProfilesRecord?> _watchPublicProfile(DocumentReference ref) {
    return _publicProfileStreams.putIfAbsent(
      ref.path,
      () =>
          widget.debugPublicProfileStream?.call(ref) ??
          UserPublicProfilesRecord.maybeGetDocument(
            UserPublicProfilesRecord.collection.doc(ref.id),
          ),
    );
  }

  String _messageStreamKey(DocumentReference conversation) =>
      '$_activeOwnerUid:${conversation.path}:$_messageLimit';

  PageStorageKey<String> _messagesListKey(
    DocumentReference conversation,
  ) =>
      PageStorageKey<String>(
        'chat_thread_messages:${_activeOwnerUid}:${conversation.path}',
      );

  Stream<ChatThreadMessagesLoadState> _watchMessages(
    DocumentReference conversation,
  ) {
    final streamKey = _messageStreamKey(conversation);
    return _messageStreams.putIfAbsent(
      streamKey,
      () => _createMessagesStream(conversation),
    );
  }

  Stream<ChatThreadMessagesLoadState> _createMessagesStream(
    DocumentReference conversation,
  ) {
    final ownerUid = _activeOwnerUid;
    final debugStream = widget.debugMessagesStream;
    final stream = debugStream != null
        ? debugStream(conversation, _messageLimit, ownerUid)
        : MessagesRecord.collection(conversation)
            .orderBy('createdAt', descending: true)
            .orderBy(FieldPath.documentId, descending: true)
            .limit(_messageLimit)
            .snapshots(includeMetadataChanges: true)
            .map((snapshot) {
            return ChatThreadMessagesLoadState(
              ownerUid: ownerUid,
              messages: snapshot.docs.map(MessagesRecord.fromSnapshot),
              isFromCache: snapshot.metadata.isFromCache,
              hasPendingWrites: snapshot.metadata.hasPendingWrites,
              pendingWriteMessagePaths: snapshot.docs
                  .where((document) => document.metadata.hasPendingWrites)
                  .map((document) => document.reference.path),
            );
          });

    return stream.map((state) {
      if (state.ownerUid != ownerUid) {
        throw StateError('Chat messages belong to another owner.');
      }
      for (final message in state.messages) {
        if (message.parentReference.path != conversation.path) {
          throw StateError(
            'Message stream returned ${message.reference.path} '
            'for ${conversation.path}.',
          );
        }
      }
      return state;
    }).where((state) => state.canResolveEmpty);
  }

  Object _messagesCacheKey(DocumentReference conversation) => [
        'chatThreadMessages',
        _activeOwnerUid,
        conversation.path,
      ];

  _ChatThreadMessagesCacheEntry? _cachedMessagesEntry(
    DocumentReference conversation,
  ) {
    return _messagesCacheByConversationPath
        .read(_messagesCacheKey(conversation))
        ?.data;
  }

  List<MessagesRecord>? _cachedMessages(DocumentReference conversation) {
    return _cachedMessagesEntry(conversation)?.messages;
  }

  ChatThreadMessagesLoadState? _cachedMessagesState(
    DocumentReference conversation,
  ) {
    final messages = _cachedMessages(conversation);
    if (messages == null) {
      return null;
    }
    return ChatThreadMessagesLoadState(
      ownerUid: _activeOwnerUid,
      messages: messages,
      isFromCache: true,
      hasPendingWrites: false,
    );
  }

  List<MessagesRecord>? _retainedMessagesFor(
    DocumentReference conversation,
  ) {
    if (_retainedMessagesOwnerUid == _activeOwnerUid &&
        _retainedMessagesConversationPath == conversation.path) {
      return _retainedMessages;
    }

    final cachedMessages = _cachedMessages(conversation);
    if (cachedMessages == null) {
      return null;
    }
    _retainMessages(conversation, cachedMessages);
    return _retainedMessages;
  }

  void _retainMessages(
    DocumentReference conversation,
    Iterable<MessagesRecord> messages, {
    Iterable<String> pendingWriteMessagePaths = const <String>[],
    Map<String, DateTime> pendingWriteObservedAtByPath =
        const <String, DateTime>{},
  }) {
    _retainedMessages = List<MessagesRecord>.unmodifiable(messages);
    _retainedPendingWriteMessagePaths = Set<String>.unmodifiable(
      pendingWriteMessagePaths,
    );
    _retainedPendingWriteObservedAtByPath =
        Map<String, DateTime>.unmodifiable(<String, DateTime>{
      for (final path in _retainedPendingWriteMessagePaths)
        if (pendingWriteObservedAtByPath[path] case final observedAt?)
          path: observedAt,
    });
    _retainedMessagesOwnerUid = _activeOwnerUid;
    _retainedMessagesConversationPath = conversation.path;
  }

  Set<String> _retainedPendingWriteMessagePathsFor(
    DocumentReference conversation,
  ) {
    if (_retainedMessagesOwnerUid == _activeOwnerUid &&
        _retainedMessagesConversationPath == conversation.path) {
      return _retainedPendingWriteMessagePaths;
    }
    return const <String>{};
  }

  Map<String, DateTime> _retainedPendingWriteObservedAtByPathFor(
    DocumentReference conversation,
  ) {
    if (_retainedMessagesOwnerUid == _activeOwnerUid &&
        _retainedMessagesConversationPath == conversation.path) {
      return _retainedPendingWriteObservedAtByPath;
    }
    return const <String, DateTime>{};
  }

  List<MessagesRecord> _mergeNonAuthoritativeMessages(
    Iterable<MessagesRecord> previousMessages,
    Iterable<MessagesRecord> incomingMessages,
  ) {
    final messagesByPath = <String, MessagesRecord>{
      for (final message in previousMessages) message.reference.path: message,
      for (final message in incomingMessages) message.reference.path: message,
    };
    final mergedMessages = messagesByPath.values.toList(growable: false)
      ..sort((left, right) {
        return _compareChatThreadMessageOrder(
          leftCreatedAt: left.createdAt,
          leftKey: left.reference.path,
          rightCreatedAt: right.createdAt,
          rightKey: right.reference.path,
        );
      });
    return List<MessagesRecord>.unmodifiable(mergedMessages);
  }

  Set<String> _mergeNonAuthoritativePendingWriteMessagePaths({
    required Iterable<String> previousPaths,
    required Iterable<MessagesRecord> incomingMessages,
    required Set<String> incomingPaths,
  }) {
    final incomingMessagePaths =
        incomingMessages.map((message) => message.reference.path).toSet();
    return Set<String>.unmodifiable(<String>{
      for (final path in previousPaths)
        if (!incomingMessagePaths.contains(path) ||
            incomingPaths.contains(path))
          path,
      ...incomingPaths,
    });
  }

  void _rememberMessages(
    DocumentReference conversation,
    List<MessagesRecord> messages,
  ) {
    final dataKey = _messagesCacheKey(conversation);
    _messagesCacheByConversationPath.write(
      UxLoadedResult<_ChatThreadMessagesCacheEntry>.data(
        dataKey: dataKey,
        data: _ChatThreadMessagesCacheEntry(
          messages: messages,
          limit: _messageLimit,
        ),
      ),
    );
  }

  ConversationsRecord? _retainedConversationFor(
    DocumentReference conversationRef,
  ) {
    final conversation = _retainedConversation;
    if (conversation == null ||
        conversation.reference.path != conversationRef.path ||
        _activeOwnerUid.isEmpty ||
        !conversation.participantIds.contains(_activeOwnerUid)) {
      return null;
    }
    return conversation;
  }

  ChatThreadConversationLoadState? _retainedConversationState(
    DocumentReference conversationRef,
  ) {
    final conversation = _retainedConversationFor(conversationRef);
    if (conversation == null) {
      return null;
    }
    return ChatThreadConversationLoadState(
      ownerUid: _activeOwnerUid,
      conversation: conversation,
      isFromCache: true,
      hasPendingWrites: false,
    );
  }

  void _rememberConversation(
    DocumentReference conversationRef,
    ConversationsRecord conversation,
  ) {
    if (conversation.reference.path == conversationRef.path &&
        _activeOwnerUid.isNotEmpty &&
        conversation.participantIds.contains(_activeOwnerUid)) {
      _retainedConversation = conversation;
    } else {
      _retainedConversation = null;
    }
  }

  void _discardRetainedMessages(DocumentReference conversationRef) {
    _scheduleDismissSendErrorSnackBar();
    _messagesCacheByConversationPath.remove(_messagesCacheKey(conversationRef));
    _retainedMessages = null;
    _retainedPendingWriteMessagePaths = const <String>{};
    _retainedPendingWriteObservedAtByPath = const <String, DateTime>{};
    _retainedMessagesOwnerUid = null;
    _retainedMessagesConversationPath = null;
    _pendingMessages.clear();
  }

  void _discardRetainedConversation(
    DocumentReference conversationRef, {
    required bool confirmedUnavailable,
    bool accessDenied = false,
  }) {
    if (!_conversationActionsBlocked) {
      _messageStreams.clear();
      _publicProfileStreams.clear();
      _messageStreamRevision += 1;
    }
    _retainedConversation = null;
    _hasConfirmedUnavailableConversation = confirmedUnavailable;
    _hasConfirmedConversationAccessDenied = accessDenied;
    _discardRetainedMessages(conversationRef);
    _blockChatActions(conversation: true);
  }

  void _blockChatActions({
    bool conversation = false,
    bool messages = false,
  }) {
    final wasBlocked = _chatActionsBlocked;
    if (conversation) {
      _conversationActionsBlocked = true;
    }
    if (messages) {
      _messageActionsBlocked = true;
    }
    if (wasBlocked || !_chatActionsBlocked) {
      return;
    }

    _dataGeneration += 1;
    _lastReadMarkerTarget = null;
    _scheduledReadMarkerTarget = null;
    _isSending = false;
    _pendingMessages.clear();
    _clearComposerOnBoundaryRebuild = true;
    _scheduleChatBoundaryRebuild();
  }

  void _allowConversationActions() {
    final wasBlocked = _chatActionsBlocked;
    _conversationActionsBlocked = false;
    if (wasBlocked != _chatActionsBlocked) {
      _scheduleChatBoundaryRebuild();
    }
  }

  void _allowMessageActions() {
    final wasBlocked = _chatActionsBlocked;
    _messageActionsBlocked = false;
    if (wasBlocked != _chatActionsBlocked) {
      _scheduleChatBoundaryRebuild();
    }
  }

  void _scheduleChatBoundaryRebuild() {
    if (_chatBoundaryRebuildScheduled) {
      return;
    }
    _chatBoundaryRebuildScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chatBoundaryRebuildScheduled = false;
      if (mounted) {
        if (_clearComposerOnBoundaryRebuild) {
          _clearComposerOnBoundaryRebuild = false;
          _model.messageTextController?.clear();
          _model.messageFocusNode?.unfocus();
        }
        setState(() {});
      }
    });
  }

  void _retryConversation() {
    final conversationRef = widget.conversationRef;
    if (conversationRef == null || _activeOwnerUid.isEmpty) {
      return;
    }
    setState(() {
      _conversationStream = _createConversationStream(conversationRef);
      _conversationStreamRevision += 1;
    });
  }

  void _retryMessages(DocumentReference conversationRef) {
    if (_activeOwnerUid.isEmpty ||
        widget.conversationRef?.path != conversationRef.path) {
      return;
    }
    setState(() {
      _messageStreams.remove(_messageStreamKey(conversationRef));
      _messageStreamRevision += 1;
    });
  }

  DocumentReference? _otherParticipantRef(ConversationsRecord conversation) {
    if (_activeOwnerUid.isEmpty) {
      return null;
    }
    final currentRef = UsersRecord.collection.doc(_activeOwnerUid);

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

  bool _isCurrentDataGeneration({
    required String ownerUid,
    required String conversationPath,
    required int generation,
  }) =>
      mounted &&
      !_chatActionsBlocked &&
      _activeOwnerUid == ownerUid &&
      widget.conversationRef?.path == conversationPath &&
      _dataGeneration == generation;

  Future<void> _markConversationRead(
    ConversationsRecord conversation, {
    required String ownerUid,
    required int generation,
  }) async {
    if (!_isCurrentDataGeneration(
          ownerUid: ownerUid,
          conversationPath: conversation.reference.path,
          generation: generation,
        ) ||
        ownerUid.isEmpty) {
      return;
    }

    if (!conversationIsUnreadForUser(conversation, ownerUid)) {
      return;
    }

    final target = conversation.lastMessageAt ?? conversation.unlockedAt;
    if (target == null) {
      return;
    }

    final currentReadAt = conversation.lastReadAtByUserId[ownerUid];
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
        'lastReadAtByUserId.$ownerUid': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint(
        'Failed to advance chat read marker for ${conversation.reference.path}: $error',
      );
    }
  }

  void _scheduleMarkConversationRead(ConversationsRecord conversation) {
    final ownerUid = _activeOwnerUid;
    final generation = _dataGeneration;
    if (_chatActionsBlocked ||
        !conversationIsUnreadForUser(conversation, ownerUid)) {
      return;
    }

    final target = conversation.lastMessageAt ?? conversation.unlockedAt;
    if (target == null) {
      return;
    }

    final currentReadAt = conversation.lastReadAtByUserId[ownerUid];
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
      if (!_isCurrentDataGeneration(
        ownerUid: ownerUid,
        conversationPath: conversation.reference.path,
        generation: generation,
      )) {
        return;
      }
      _scheduledReadMarkerTarget = null;
      _markConversationRead(
        conversation,
        ownerUid: ownerUid,
        generation: generation,
      );
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

  Map<String, dynamic> _textMessageData({
    required String senderId,
    required DocumentReference senderRef,
    required String text,
  }) =>
      mapToFirestore(
        <String, dynamic>{
          'senderId': senderId,
          'senderRef': senderRef,
          'type': kConversationMessageTypeText,
          'text': text,
          'createdAt': FieldValue.serverTimestamp(),
        },
      );

  Future<void> _writeMessage(
    DocumentReference messageRef,
    Map<String, dynamic> data,
  ) {
    final debugWrite = widget.debugMessageWrite;
    if (debugWrite != null) {
      return debugWrite(messageRef, data);
    }
    return messageRef.set(data);
  }

  void _showSendErrorSnackBar(String messagePath) {
    _dismissSendErrorSnackBar();
    final messenger = ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    final controller = messenger.showSnackBar(
      SnackBar(
        key: chatThreadSendErrorSnackBarKey,
        content: Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Не удалось отправить сообщение.',
            enText: 'Unable to send message.',
          ),
        ),
      ),
    );
    final handle = _ChatThreadSendErrorSnackBarHandle(
      controller: controller,
      messenger: messenger,
      messagePath: messagePath,
    );
    _sendErrorSnackBarHandle = handle;
    controller.closed.then((_) {
      handle.isClosed = true;
      if (identical(_sendErrorSnackBarHandle, handle)) {
        _sendErrorSnackBarHandle = null;
      }
    });
  }

  void _dismissSendErrorSnackBar({String? messagePath}) {
    final handle = _sendErrorSnackBarHandle;
    if (handle == null ||
        (messagePath != null && handle.messagePath != messagePath)) {
      return;
    }
    _sendErrorSnackBarHandle = null;
    if (!handle.isClosed && handle.messenger.mounted) {
      handle.messenger.removeCurrentSnackBar();
    }
  }

  void _scheduleDismissSendErrorSnackBar() {
    final handle = _sendErrorSnackBarHandle;
    if (handle == null) {
      return;
    }
    _sendErrorSnackBarHandle = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!handle.isClosed && handle.messenger.mounted) {
        handle.messenger.removeCurrentSnackBar();
      }
    });
  }

  Future<void> _sendMessage(ConversationsRecord conversation) async {
    final currentUid = _activeOwnerUid;
    if (currentUid.isEmpty || _isSending || _chatActionsBlocked) {
      return;
    }
    final currentRef = UsersRecord.collection.doc(currentUid);

    final text = _model.messageTextController?.text.trim() ?? '';
    if (text.isEmpty) {
      return;
    }

    final conversationPath = conversation.reference.path;
    final generation = _dataGeneration;
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
      await _writeMessage(
        messageRef,
        _textMessageData(
          senderId: currentUid,
          senderRef: currentRef,
          text: text,
        ),
      );
      if (!_isCurrentDataGeneration(
        ownerUid: currentUid,
        conversationPath: conversationPath,
        generation: generation,
      )) {
        return;
      }
      setState(() {
        final pendingIndex = _pendingMessages.indexWhere(
          (message) => message.localId == pendingMessage.localId,
        );
        if (pendingIndex == -1) {
          return;
        }
        _pendingMessages[pendingIndex] = pendingMessage.copyWith(
          status: ChatLocalMessageStatus.sent,
        );
      });
    } catch (error) {
      if (!_isCurrentDataGeneration(
        ownerUid: currentUid,
        conversationPath: conversationPath,
        generation: generation,
      )) {
        return;
      }
      final pendingIndex = _pendingMessages.indexWhere(
        (message) => message.localId == pendingMessage.localId,
      );
      if (pendingIndex == -1) {
        return;
      }
      setState(() {
        _pendingMessages[pendingIndex] = pendingMessage.copyWith(
          status: ChatLocalMessageStatus.failed,
        );
      });
      _showSendErrorSnackBar(pendingMessage.messageRef.path);
      debugPrint(
        'Failed to send chat message for ${conversation.reference.path}: $error',
      );
    } finally {
      if (_isCurrentDataGeneration(
        ownerUid: currentUid,
        conversationPath: conversationPath,
        generation: generation,
      )) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _retryPendingMessage(
    ConversationsRecord conversation,
    _PendingChatMessage pendingMessage,
  ) async {
    final currentUid = _activeOwnerUid;
    if (currentUid.isEmpty ||
        _isSending ||
        _chatActionsBlocked ||
        pendingMessage.status != ChatLocalMessageStatus.failed ||
        pendingMessage.senderId != currentUid ||
        pendingMessage.messageRef.parent.parent?.path !=
            conversation.reference.path) {
      return;
    }
    final currentRef = UsersRecord.collection.doc(currentUid);

    final conversationPath = conversation.reference.path;
    final generation = _dataGeneration;
    _dismissSendErrorSnackBar(
      messagePath: pendingMessage.messageRef.path,
    );
    setState(() {
      _isSending = true;
      _updatePendingMessageStatus(
        pendingMessage.localId,
        ChatLocalMessageStatus.sending,
      );
    });

    try {
      await _writeMessage(
        pendingMessage.messageRef,
        _textMessageData(
          senderId: currentUid,
          senderRef: currentRef,
          text: pendingMessage.text,
        ),
      );
      if (!_isCurrentDataGeneration(
        ownerUid: currentUid,
        conversationPath: conversationPath,
        generation: generation,
      )) {
        return;
      }
      final pendingIndex = _pendingMessages.indexWhere(
        (message) => message.localId == pendingMessage.localId,
      );
      if (pendingIndex == -1) {
        return;
      }
      setState(() {
        _updatePendingMessageStatus(
          pendingMessage.localId,
          ChatLocalMessageStatus.sent,
        );
      });
    } catch (error) {
      if (!_isCurrentDataGeneration(
        ownerUid: currentUid,
        conversationPath: conversationPath,
        generation: generation,
      )) {
        return;
      }
      final pendingIndex = _pendingMessages.indexWhere(
        (message) => message.localId == pendingMessage.localId,
      );
      if (pendingIndex == -1) {
        return;
      }
      setState(() {
        _updatePendingMessageStatus(
          pendingMessage.localId,
          ChatLocalMessageStatus.failed,
        );
      });
      _showSendErrorSnackBar(pendingMessage.messageRef.path);
      debugPrint(
        'Failed to retry chat message for ${conversation.reference.path}: '
        '$error',
      );
    } finally {
      if (_isCurrentDataGeneration(
        ownerUid: currentUid,
        conversationPath: conversationPath,
        generation: generation,
      )) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _updatePendingMessageStatus(
    String localId,
    ChatLocalMessageStatus status,
  ) {
    final pendingIndex = _pendingMessages.indexWhere(
      (message) => message.localId == localId,
    );
    if (pendingIndex == -1) {
      return;
    }
    _pendingMessages[pendingIndex] = _pendingMessages[pendingIndex].copyWith(
      status: status,
    );
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
      status: ChatLocalMessageStatus.sending,
    );
  }

  List<_ChatThreadDisplayMessage> _displayMessages(
    List<MessagesRecord> records, {
    required Map<String, DateTime> pendingWriteObservedAtByPath,
  }) {
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
          sortCreatedAt: record.createdAt ??
              pendingWriteObservedAtByPath[record.reference.path],
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
          _ChatThreadDisplayMessage.record(
            recordsByPath[item.key]!,
            sortCreatedAt: item.sortCreatedAt ?? item.createdAt,
          ),
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
    final ownerUid = _activeOwnerUid;
    final conversationPath = _conversationStreamPath;
    final generation = _dataGeneration;
    if (conversationPath == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isCurrentDataGeneration(
        ownerUid: ownerUid,
        conversationPath: conversationPath,
        generation: generation,
      )) {
        return;
      }
      setState(() {
        _pendingMessages.removeWhere(
          (message) => confirmedPaths.contains(message.messageRef.path),
        );
      });
      final errorMessagePath = _sendErrorSnackBarHandle?.messagePath;
      if (errorMessagePath != null &&
          confirmedPaths.contains(errorMessagePath)) {
        _dismissSendErrorSnackBar(messagePath: errorMessagePath);
      }
    });
  }

  Future<void> _toggleFriend(
      DocumentReference partnerRef, bool isFriend) async {
    final ownerUid = _activeOwnerUid;
    final conversationPath = widget.conversationRef?.path;
    final generation = _dataGeneration;
    if (ownerUid.isEmpty ||
        conversationPath == null ||
        _chatActionsBlocked ||
        !hasCurrentUserDocumentForUid(ownerUid)) {
      return;
    }
    final currentRef = UsersRecord.collection.doc(ownerUid);

    try {
      await currentRef.update(
        isFriend
            ? buildRemoveFriendUpdateData(partnerRef)
            : buildAddFriendUpdateData(partnerRef),
      );
    } catch (error) {
      debugPrint(
          'Failed to update friend state for ${partnerRef.path}: $error');
      if (!_isCurrentDataGeneration(
        ownerUid: ownerUid,
        conversationPath: conversationPath,
        generation: generation,
      )) {
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

  Widget _buildEmptyState(
    BuildContext context, {
    bool showRefreshError = false,
  }) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: ExpatlioDesign.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
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
          if (showRefreshError)
            PositionedDirectional(
              start: ExpatlioDesign.pagePadding,
              end: ExpatlioDesign.pagePadding,
              top: ExpatlioDesign.space112,
              child: _buildRefreshErrorBanner(
                context,
                stateKey: chatThreadConversationInlineErrorKey,
                retryKey: chatThreadConversationRetryButtonKey,
                ruText: 'Не удалось обновить чат.',
                enText: 'Could not refresh chat.',
                onRetry: _retryConversation,
              ),
            ),
        ],
      ),
    );
  }

  bool _isPermissionDenied(Object? error) =>
      error is FirebaseException && error.code == 'permission-denied';

  Widget _buildChatUnavailableState(
    BuildContext context, {
    required Object? error,
    bool preservePermissionDenied = false,
  }) {
    final permissionDenied =
        preservePermissionDenied || _isPermissionDenied(error);
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: ExpatlioDesign.background,
      body: Center(
        child: SizedBox(
          height: 500.0,
          child: Column(
            children: [
              Expanded(
                child: EmptyWidget(
                  txt: permissionDenied
                      ? FFLocalizations.of(context).getVariableText(
                          ruText: 'У вас нет доступа к этому чату.',
                          enText: 'You do not have access to this chat.',
                        )
                      : FFLocalizations.of(context).getVariableText(
                          ruText: 'Не удалось загрузить чат. Попробуйте позже.',
                          enText:
                              'Could not load this chat. Please try again later.',
                        ),
                ),
              ),
              if (!permissionDenied)
                _buildContextualRetryButton(
                  context,
                  key: chatThreadConversationRetryButtonKey,
                  ruLabel: 'Повторить загрузку чата',
                  enLabel: 'Retry loading chat',
                  onRetry: _retryConversation,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessagesUnavailableState(
    BuildContext context, {
    required Object? error,
    bool preservePermissionDenied = false,
  }) {
    final permissionDenied =
        preservePermissionDenied || _isPermissionDenied(error);
    return Center(
      child: SizedBox(
        height: 340.0,
        child: Column(
          children: [
            Expanded(
              child: EmptyWidget(
                txt: permissionDenied
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
            if (!permissionDenied)
              _buildContextualRetryButton(
                context,
                key: chatThreadMessagesRetryButtonKey,
                ruLabel: 'Повторить загрузку сообщений',
                enLabel: 'Retry loading messages',
                onRetry: () {
                  final conversationRef = widget.conversationRef;
                  if (conversationRef != null) {
                    _retryMessages(conversationRef);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContextualRetryButton(
    BuildContext context, {
    required Key key,
    required String ruLabel,
    required String enLabel,
    required VoidCallback onRetry,
  }) {
    final semanticLabel = FFLocalizations.of(context).getVariableText(
      ruText: ruLabel,
      enText: enLabel,
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: TextButton(
          key: key,
          onPressed: onRetry,
          child: Text(
            FFLocalizations.of(context).getVariableText(
              ruText: 'Повторить',
              enText: 'Retry',
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRefreshErrorBanner(
    BuildContext context, {
    required Key stateKey,
    required Key retryKey,
    required String ruText,
    required String enText,
    required VoidCallback onRetry,
  }) {
    final message = FFLocalizations.of(context).getVariableText(
      ruText: ruText,
      enText: enText,
    );
    return Material(
      elevation: 4.0,
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
      child: Semantics(
        key: stateKey,
        container: true,
        liveRegion: true,
        label: message,
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space12,
            ExpatlioDesign.space8,
            ExpatlioDesign.space8,
            ExpatlioDesign.space8,
          ),
          decoration: BoxDecoration(
            color: ExpatlioDesign.card,
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
            border: Border.all(color: ExpatlioDesign.danger),
          ),
          child: Row(
            children: [
              Expanded(child: Text(message)),
              _buildContextualRetryButton(
                context,
                key: retryKey,
                ruLabel: '$ruText Повторить обновление.',
                enLabel: '$enText Retry refresh.',
                onRetry: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withMessagesRefreshError(
    BuildContext context, {
    required DocumentReference conversationRef,
    required bool showError,
    required Widget child,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (showError)
          PositionedDirectional(
            start: ExpatlioDesign.pagePadding,
            end: ExpatlioDesign.pagePadding,
            bottom: ExpatlioDesign.space112,
            child: _buildRefreshErrorBanner(
              context,
              stateKey: chatThreadMessagesInlineErrorKey,
              retryKey: chatThreadMessagesRetryButtonKey,
              ruText: 'Не удалось обновить сообщения.',
              enText: 'Could not refresh messages.',
              onRetry: () => _retryMessages(conversationRef),
            ),
          ),
      ],
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
      currentUserUid: _activeOwnerUid,
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
    ChatLocalMessageStatus? localStatus,
    DateTime? displayCreatedAt,
  }) {
    return ChatThreadMessageBubble(
      messageKey: message.reference.path,
      text: message.text,
      timestampText: _formatMessageTimestamp(
        displayCreatedAt ?? message.createdAt,
      ),
      isCurrentUser: isCurrentUser,
      isReadByPartner: isReadByPartner,
      localStatus: localStatus,
    );
  }

  Widget _buildPendingMessageBubble(
    BuildContext context, {
    required ConversationsRecord conversation,
    required _PendingChatMessage message,
  }) {
    return ChatThreadMessageBubble(
      messageKey: message.messageRef.path,
      text: message.text,
      timestampText: _formatMessageTimestamp(message.createdAt),
      isCurrentUser: true,
      isReadByPartner: false,
      localStatus: message.status,
      onRetry: message.status == ChatLocalMessageStatus.failed
          ? () => _retryPendingMessage(conversation, message)
          : null,
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required ConversationsRecord conversation,
    required UserPublicProfilesRecord? partnerProfile,
    required DocumentReference partnerRef,
    required bool isFriend,
    required bool canUpdateFriend,
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
                  enabled: canUpdateFriend,
                  label: friendButtonLabel,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: canUpdateFriend
                        ? () => _toggleFriend(partnerRef, isFriend)
                        : null,
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
    UxSessionCacheLifecycle.register(_clearMessagesCache);
    _activeOwnerUid = _readAuthenticatedOwnerUid();
    UxSessionCacheLifecycle.updateAuthenticatedUser(
      _activeOwnerUid.isEmpty ? null : _activeOwnerUid,
    );
    _authenticatedOwnerUidStream = _createAuthenticatedOwnerUidStream();
    _messagesScrollController.addListener(_handleMessagesScroll);
    _bindConversationRef();
  }

  @override
  void didUpdateWidget(ChatThreadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(
      oldWidget.debugAuthenticatedOwnerUidStream,
      widget.debugAuthenticatedOwnerUidStream,
    )) {
      _authenticatedOwnerUidStream = _createAuthenticatedOwnerUidStream();
    }
    if (!identical(
      oldWidget.debugMessagesStream,
      widget.debugMessagesStream,
    )) {
      _messageStreams.clear();
      _messageStreamRevision += 1;
    }
    if (!identical(
      oldWidget.debugPublicProfileStream,
      widget.debugPublicProfileStream,
    )) {
      _publicProfileStreams.clear();
    }
    _bindConversationRef();
  }

  @override
  void dispose() {
    _scheduleDismissSendErrorSnackBar();
    _messagesScrollController.removeListener(_handleMessagesScroll);
    _messagesScrollController.dispose();
    _model.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
      stream: _authenticatedOwnerUidStream,
      initialData: _activeOwnerUid,
      builder: (context, ownerSnapshot) {
        final ownerUid = ownerSnapshot.data ?? '';
        _synchronizeAuthenticatedOwner(ownerUid);
        return _buildAuthenticatedChat(context);
      },
    );
  }

  Widget _buildAuthenticatedChat(BuildContext context) {
    _bindConversationRef();
    final conversationRef = widget.conversationRef;
    if (conversationRef == null || _activeOwnerUid.isEmpty) {
      return _buildEmptyState(context);
    }

    return StreamBuilder<ChatThreadConversationLoadState>(
      key: ValueKey<(String, String, int)>((
        conversationRef.path,
        _activeOwnerUid,
        _conversationStreamRevision,
      )),
      stream: _conversationStream,
      initialData: _retainedConversationState(conversationRef),
      builder: (context, snapshot) {
        var showConversationRefreshError = false;
        ConversationsRecord? conversation;
        if (snapshot.hasError) {
          debugPrint(
            'ChatThreadWidget: conversation stream error for ${conversationRef.path}: ${snapshot.error}',
          );
          if (_isPermissionDenied(snapshot.error)) {
            _discardRetainedConversation(
              conversationRef,
              confirmedUnavailable: false,
              accessDenied: true,
            );
            return _buildChatUnavailableState(
              context,
              error: snapshot.error,
            );
          }
          conversation = _retainedConversationFor(conversationRef);
          if (conversation == null) {
            if (_hasConfirmedUnavailableConversation) {
              return _buildEmptyState(
                context,
                showRefreshError: true,
              );
            }
            if (_hasConfirmedConversationAccessDenied) {
              return _buildChatUnavailableState(
                context,
                error: snapshot.error,
                preservePermissionDenied: true,
              );
            }
            return _buildChatUnavailableState(
              context,
              error: snapshot.error,
            );
          }
          showConversationRefreshError = true;
        } else if (snapshot.hasData) {
          final conversationState = snapshot.data!;
          conversation = conversationState.conversation;
          if (conversation == null) {
            _discardRetainedConversation(
              conversationRef,
              confirmedUnavailable: true,
            );
            return _buildEmptyState(context);
          }
          if (_conversationActionsBlocked &&
              !conversationState.isAuthoritative) {
            if (_hasConfirmedUnavailableConversation) {
              return _buildEmptyState(context);
            }
            if (_hasConfirmedConversationAccessDenied) {
              return _buildChatUnavailableState(
                context,
                error: null,
                preservePermissionDenied: true,
              );
            }
          }
          _rememberConversation(conversationRef, conversation);
        } else {
          if (snapshot.connectionState == ConnectionState.waiting) {
            conversation = _retainedConversationFor(conversationRef);
            if (conversation == null) {
              if (_hasConfirmedUnavailableConversation) {
                return _buildEmptyState(context);
              }
              if (_hasConfirmedConversationAccessDenied) {
                return _buildChatUnavailableState(
                  context,
                  error: null,
                  preservePermissionDenied: true,
                );
              }
              return _buildLoadingState(context);
            }
          } else {
            _discardRetainedConversation(
              conversationRef,
              confirmedUnavailable: true,
            );
            return _buildEmptyState(context);
          }
        }

        final resolvedConversation = conversation;
        if (_activeOwnerUid.isEmpty ||
            !resolvedConversation.participantIds.contains(_activeOwnerUid) ||
            !resolvedConversation.isUnlocked) {
          _discardRetainedConversation(
            conversationRef,
            confirmedUnavailable: true,
          );
          return _buildEmptyState(context);
        }

        final partnerRef = _otherParticipantRef(resolvedConversation);
        if (partnerRef == null) {
          _discardRetainedConversation(
            conversationRef,
            confirmedUnavailable: true,
          );
          return _buildEmptyState(context);
        }

        _hasConfirmedUnavailableConversation = false;
        _hasConfirmedConversationAccessDenied = false;
        _allowConversationActions();
        _scheduleMarkConversationRead(resolvedConversation);

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
                          final hasOwnerDocument = !_chatActionsBlocked &&
                              hasCurrentUserDocumentForUid(_activeOwnerUid);
                          final isFriend = hasOwnerDocument &&
                              userHasFriend(
                                currentUserDocument,
                                partnerRef,
                              );

                          return _buildHeader(
                            context,
                            conversation: resolvedConversation,
                            partnerProfile: partnerSnapshot.hasError
                                ? null
                                : partnerSnapshot.data,
                            partnerRef: partnerRef,
                            isFriend: isFriend,
                            canUpdateFriend: hasOwnerDocument,
                          );
                        },
                      );
                    },
                  ),
                  Expanded(
                    child: StreamBuilder<ChatThreadMessagesLoadState>(
                      key: ValueKey<(String, String, int)>((
                        _activeOwnerUid,
                        resolvedConversation.reference.path,
                        _messageStreamRevision,
                      )),
                      stream: _watchMessages(resolvedConversation.reference),
                      initialData: _cachedMessagesState(
                        resolvedConversation.reference,
                      ),
                      builder: (context, messagesSnapshot) {
                        if (messagesSnapshot.hasError) {
                          debugPrint(
                            'ChatThreadWidget: messages stream error for ${resolvedConversation.reference.path}: ${messagesSnapshot.error}',
                          );
                        }

                        if (messagesSnapshot.hasError &&
                            _isPermissionDenied(messagesSnapshot.error)) {
                          _discardRetainedMessages(
                            resolvedConversation.reference,
                          );
                          _blockChatActions(messages: true);
                          return _buildMessagesUnavailableState(
                            context,
                            error: messagesSnapshot.error,
                          );
                        }

                        final incomingMessagesState = messagesSnapshot.data;
                        if (_messageActionsBlocked &&
                            (incomingMessagesState == null ||
                                !incomingMessagesState.isAuthoritative)) {
                          return _buildMessagesUnavailableState(
                            context,
                            error: messagesSnapshot.error,
                            preservePermissionDenied: true,
                          );
                        }
                        final retainedMessages = _retainedMessagesFor(
                          resolvedConversation.reference,
                        );
                        final previousMessages =
                            retainedMessages ?? const <MessagesRecord>[];
                        final previousPendingWriteMessagePaths =
                            _retainedPendingWriteMessagePathsFor(
                          resolvedConversation.reference,
                        );
                        final previousPendingWriteObservedAtByPath =
                            _retainedPendingWriteObservedAtByPathFor(
                          resolvedConversation.reference,
                        );
                        List<MessagesRecord>? messages = retainedMessages;
                        if (!messagesSnapshot.hasError &&
                            incomingMessagesState != null) {
                          if (incomingMessagesState.isAuthoritative) {
                            _allowMessageActions();
                            messages = incomingMessagesState.messages;
                            _retainMessages(
                              resolvedConversation.reference,
                              messages,
                              pendingWriteMessagePaths: incomingMessagesState
                                  .pendingWriteMessagePaths,
                              pendingWriteObservedAtByPath: {
                                for (final path in incomingMessagesState
                                    .pendingWriteMessagePaths)
                                  path: incomingMessagesState
                                      .pendingWritesObservedAt,
                              },
                            );
                            final confirmedMessages = messages
                                .where((message) => message.createdAt != null)
                                .toList(growable: false);
                            _rememberMessages(
                              resolvedConversation.reference,
                              confirmedMessages,
                            );
                            _schedulePruneConfirmedPendingMessages(messages);
                          } else {
                            messages = _mergeNonAuthoritativeMessages(
                              previousMessages,
                              incomingMessagesState.messages,
                            );
                            final mergedPendingWriteMessagePaths =
                                _mergeNonAuthoritativePendingWriteMessagePaths(
                              previousPaths: previousPendingWriteMessagePaths,
                              incomingMessages: incomingMessagesState.messages,
                              incomingPaths: incomingMessagesState
                                  .pendingWriteMessagePaths,
                            );
                            _retainMessages(
                              resolvedConversation.reference,
                              messages,
                              pendingWriteMessagePaths:
                                  mergedPendingWriteMessagePaths,
                              pendingWriteObservedAtByPath: {
                                for (final path
                                    in mergedPendingWriteMessagePaths)
                                  path: previousPendingWriteObservedAtByPath[
                                          path] ??
                                      incomingMessagesState
                                          .pendingWritesObservedAt,
                              },
                            );
                          }
                        }
                        if (messagesSnapshot.hasError &&
                            messages == null &&
                            _pendingMessages.isEmpty) {
                          return _buildMessagesUnavailableState(
                            context,
                            error: messagesSnapshot.error,
                          );
                        }
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
                        final serverMessages =
                            messages ?? const <MessagesRecord>[];
                        final pendingWriteMessagePaths =
                            _retainedPendingWriteMessagePathsFor(
                          resolvedConversation.reference,
                        );
                        final pendingWriteObservedAtByPath =
                            _retainedPendingWriteObservedAtByPathFor(
                          resolvedConversation.reference,
                        );
                        _canLoadOlderMessages =
                            serverMessages.length >= _messageLimit;
                        final displayMessages = _displayMessages(
                          serverMessages,
                          pendingWriteObservedAtByPath:
                              pendingWriteObservedAtByPath,
                        );

                        if (displayMessages.isEmpty) {
                          return _withMessagesRefreshError(
                            context,
                            conversationRef: resolvedConversation.reference,
                            showError: messagesSnapshot.hasError,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(
                                  ExpatlioDesign.space24,
                                ),
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
                            ),
                          );
                        }

                        return _withMessagesRefreshError(
                          context,
                          conversationRef: resolvedConversation.reference,
                          showError: messagesSnapshot.hasError,
                          child: ListView.builder(
                            key: _messagesListKey(
                              resolvedConversation.reference,
                            ),
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
                              if (record != null &&
                                  messageIsCallEvent(record)) {
                                itemChildren.add(
                                  _buildCallEventMessageCard(
                                    context,
                                    message: record,
                                  ),
                                );
                                return Column(
                                  key: chatThreadMessageItemKey(
                                    displayMessage.itemKey,
                                  ),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: itemChildren,
                                );
                              }

                              if (pendingMessage != null) {
                                itemChildren.add(
                                  _buildPendingMessageBubble(
                                    context,
                                    conversation: resolvedConversation,
                                    message: pendingMessage,
                                  ),
                                );
                              } else if (record != null) {
                                final isCurrentUser =
                                    record.senderId == _activeOwnerUid;
                                final partnerReadAt = resolvedConversation
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
                                    displayCreatedAt: displayMessage.createdAt,
                                    localStatus: isCurrentUser &&
                                            pendingWriteMessagePaths.contains(
                                              record.reference.path,
                                            )
                                        ? ChatLocalMessageStatus.sending
                                        : null,
                                  ),
                                );
                              }

                              return Column(
                                key: chatThreadMessageItemKey(
                                  displayMessage.itemKey,
                                ),
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: itemChildren,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.bottomCenter,
                child: ChatComposer(
                  controller: _model.messageTextController!,
                  focusNode: _model.messageFocusNode!,
                  onSendPressed: () => _sendMessage(resolvedConversation),
                  hintText: FFLocalizations.of(context).getVariableText(
                    ruText: 'Написать сообщение',
                    enText: 'Write a message',
                  ),
                  sendButtonSemanticLabel:
                      FFLocalizations.of(context).getVariableText(
                    ruText: 'Отправить сообщение',
                    enText: 'Send message',
                  ),
                  enabled: !_chatActionsBlocked,
                  isSending: _isSending,
                  inputKey: chatThreadMessageInputKey,
                  sendButtonKey: chatThreadSendButtonKey,
                ),
              ),
              if (showConversationRefreshError)
                PositionedDirectional(
                  start: ExpatlioDesign.pagePadding,
                  end: ExpatlioDesign.pagePadding,
                  top: ExpatlioDesign.space112,
                  child: _buildRefreshErrorBanner(
                    context,
                    stateKey: chatThreadConversationInlineErrorKey,
                    retryKey: chatThreadConversationRetryButtonKey,
                    ruText: 'Не удалось обновить чат.',
                    enText: 'Could not refresh chat.',
                    onRetry: _retryConversation,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
