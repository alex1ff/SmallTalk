import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/ux_empty_state.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/chat_local_message_status.dart';
import '/shared_pages/chat_local_message_status_icon.dart';
import '/shared_pages/chat_message_bubble_style.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_action_error_mapper.dart';
import '/services/event_actions_repository.dart';
import '/services/event_group_chat_repository.dart';
import '/services/ux_session_loaded_result_cache.dart';

const ValueKey<String> eventGroupChatMessagesLoadingKey =
    ValueKey<String>('event_group_chat_messages_loading');
const ValueKey<String> eventGroupChatMessagesErrorKey =
    ValueKey<String>('event_group_chat_messages_error');
const ValueKey<String> eventGroupChatMessagesEmptyKey =
    ValueKey<String>('event_group_chat_messages_empty');
const ValueKey<String> eventGroupChatMessagesListKey =
    ValueKey<String>('event_group_chat_messages_list');
const ValueKey<String> eventGroupChatAccessLoadingKey =
    ValueKey<String>('event_group_chat_access_loading');
const ValueKey<String> eventGroupChatAccessDeniedKey =
    ValueKey<String>('event_group_chat_access_denied');
const ValueKey<String> eventGroupChatMessageInputKey =
    ValueKey<String>('event_group_chat_message_input');
const ValueKey<String> eventGroupChatSendButtonKey =
    ValueKey<String>('event_group_chat_send_button');
const ValueKey<String> eventGroupChatSendErrorSnackBarKey =
    ValueKey<String>('event_group_chat_send_error_snack_bar');
const ValueKey<String> eventGroupChatReportSuccessSnackBarKey =
    ValueKey<String>('event_group_chat_report_success_snack_bar');
const ValueKey<String> eventGroupChatReportErrorSnackBarKey =
    ValueKey<String>('event_group_chat_report_error_snack_bar');
const ValueKey<String> eventGroupChatReportDialogKey =
    ValueKey<String>('event_group_chat_report_dialog');
const ValueKey<String> eventGroupChatReportDetailsFieldKey =
    ValueKey<String>('event_group_chat_report_details_field');
const ValueKey<String> eventGroupChatReportDismissButtonKey =
    ValueKey<String>('event_group_chat_report_dismiss_button');
const ValueKey<String> eventGroupChatReportSubmitButtonKey =
    ValueKey<String>('event_group_chat_report_submit_button');

ValueKey<String> eventGroupChatMessageBubbleKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_bubble_$messageId');

ValueKey<String> eventGroupChatMessageItemKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_item_$messageId');

ValueKey<String> eventGroupChatMessageSenderNameKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_sender_name_$messageId');

ValueKey<String> eventGroupChatMessageSenderAvatarKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_sender_avatar_$messageId');

ValueKey<String> eventGroupChatMessageTombstoneKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_tombstone_$messageId');

ValueKey<String> eventGroupChatMessageReportButtonKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_report_button_$messageId');

ValueKey<String> eventGroupChatMessageLocalStatusKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_local_status_$messageId');

ValueKey<String> eventGroupChatMessageRetryButtonKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_retry_button_$messageId');

ValueKey<String> eventGroupChatReportReasonKey(String reasonCode) =>
    ValueKey<String>('event_group_chat_report_reason_$reasonCode');

/// Event chat intentionally uses an event-specific surface.
///
/// The existing one-to-one chat UI is backed by conversation documents and
/// direct message writes, while event chat is backed by event chat documents,
/// participant access rules, and a trusted send callable.
class EventGroupChatWidget extends StatefulWidget {
  const EventGroupChatWidget({
    super.key,
    required this.eventId,
    this.chatStream,
    this.messagesStream,
    this.accessStateInvoker,
    this.sendMessageInvoker,
    this.reportMessageInvoker,
    this.messageLimit = EventGroupChatRepository.defaultMessageLimit,
  });

  final String eventId;
  final EventChatMetadataStream? chatStream;
  final EventChatMessagesStream? messagesStream;
  final EventCallableInvoker? accessStateInvoker;
  final EventCallableInvoker? sendMessageInvoker;
  final EventCallableInvoker? reportMessageInvoker;
  final int messageLimit;

  static String routeName = 'eventGroupChat';
  static String routePath = '/events/:eventId/chat';

  @override
  State<EventGroupChatWidget> createState() => _EventGroupChatWidgetState();

  @visibleForTesting
  static void debugResetMessageCacheForTesting() {
    _EventGroupChatWidgetState._messagesCacheByEventId.clear();
  }
}

class _EventGroupChatWidgetState extends State<EventGroupChatWidget> {
  static final UxSessionLoadedResultCache<List<EventChatMessagesRecord>>
      _messagesCacheByEventId =
      UxSessionLoadedResultCache<List<EventChatMessagesRecord>>();
  final TextEditingController _messageTextController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late Stream<EventChatsRecord?> _chatAccessStream;
  Stream<List<EventChatMessagesRecord>>? _messagesStream;
  final List<_PendingEventChatMessage> _pendingMessages =
      <_PendingEventChatMessage>[];
  int _chatAccessRevision = 0;
  int _pendingMessageSerial = 0;
  bool _isReportingMessage = false;

  @override
  void initState() {
    super.initState();
    _chatAccessStream = _watchChatAccess();
    _rememberInboxEvent(persist: true);
  }

  @override
  void didUpdateWidget(covariant EventGroupChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final accessChanged = oldWidget.eventId != widget.eventId ||
        oldWidget.chatStream != widget.chatStream;
    final messagesChanged = oldWidget.messagesStream != widget.messagesStream ||
        oldWidget.messageLimit != widget.messageLimit;

    if (accessChanged) {
      _chatAccessRevision += 1;
      _chatAccessStream = _watchChatAccess();
      _messagesStream = null;
      _pendingMessages.clear();
      _rememberInboxEvent(persist: true);
    } else if (messagesChanged) {
      _messagesStream = null;
    }
  }

  @override
  void dispose() {
    _messageFocusNode.dispose();
    _messageTextController.dispose();
    super.dispose();
  }

  Stream<List<EventChatMessagesRecord>> _watchMessages() =>
      EventGroupChatRepository.watchMessages(
        eventId: widget.eventId,
        messagesStream: widget.messagesStream,
        limit: widget.messageLimit,
      );

  Object _messagesCacheKey(String eventId) => [
        'eventGroupChatMessages',
        currentUserUid,
        eventId.trim(),
      ];

  List<EventChatMessagesRecord>? _cachedMessages(String eventId) {
    final messages =
        _messagesCacheByEventId.readItems(_messagesCacheKey(eventId));
    if (messages == null || messages.isEmpty) {
      return null;
    }
    return messages;
  }

  void _rememberMessages(
    String eventId,
    List<EventChatMessagesRecord> messages,
  ) {
    _messagesCacheByEventId.writeItems(
      dataKey: _messagesCacheKey(eventId),
      items: List<EventChatMessagesRecord>.unmodifiable(messages),
    );
  }

  Stream<EventChatsRecord?> _watchChatAccess() =>
      EventGroupChatRepository.watchChatAccess(
        eventId: widget.eventId,
        chatStream: widget.chatStream,
      );

  void _rememberInboxEvent({bool persist = false}) {
    late final String eventId;
    try {
      eventId = EventGroupChatRepository.chatReferenceForEventId(
        widget.eventId,
      ).id;
    } on ArgumentError {
      return;
    }

    EventGroupChatRepository.rememberInboxEventId(eventId);
    if (persist) {
      unawaited(_persistInboxEventId(eventId));
    }
  }

  Future<void> _persistInboxEventId(String eventId) async {
    final userRef = currentUserReference;
    if (currentUserUid.trim().isEmpty || userRef == null) {
      return;
    }

    try {
      await userRef.update({
        'eventChatInboxEventIds': FieldValue.arrayUnion([eventId]),
        'hiddenChatKeys': FieldValue.arrayRemove(['event:$eventId']),
      });
    } catch (error) {
      debugPrint(
        'EventGroupChatWidget: failed to persist inbox event '
        '$eventId: $error',
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageTextController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final eventId = widget.eventId.trim();
    final pendingMessage = _createPendingMessage(text);
    setState(() {
      _pendingMessages.add(pendingMessage);
    });
    _messageTextController.clear();

    try {
      final result = await EventActionsRepository.sendEventChatMessage(
        eventId: eventId,
        text: text,
        clientMessageId: pendingMessage.localId,
        invoker: widget.sendMessageInvoker,
      );
      EventGroupChatRepository.rememberInboxEventId(eventId);
      unawaited(_persistInboxEventId(eventId));
      if (!mounted || widget.eventId.trim() != eventId) {
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
          serverMessageId: result.messageId,
          status: ChatLocalMessageStatus.sent,
        );
      });
    } catch (error) {
      if (!mounted || widget.eventId.trim() != eventId) {
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
          status: ChatLocalMessageStatus.failed,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventGroupChatSendErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
      debugPrint(
        'EventGroupChatWidget: failed to send message for '
        '$eventId: $error',
      );
    }
  }

  Future<void> _retryPendingMessage(String localId) async {
    final pendingIndex = _pendingMessages.indexWhere(
      (message) => message.localId == localId,
    );
    if (pendingIndex == -1) {
      return;
    }
    final pendingMessage = _pendingMessages[pendingIndex];
    if (pendingMessage.status != ChatLocalMessageStatus.failed) {
      return;
    }

    final eventId = widget.eventId.trim();
    setState(() {
      _updatePendingMessageStatus(localId, ChatLocalMessageStatus.sending);
    });

    try {
      final result = await EventActionsRepository.sendEventChatMessage(
        eventId: eventId,
        text: pendingMessage.text,
        clientMessageId: pendingMessage.localId,
        invoker: widget.sendMessageInvoker,
      );
      EventGroupChatRepository.rememberInboxEventId(eventId);
      unawaited(_persistInboxEventId(eventId));
      if (!mounted || widget.eventId.trim() != eventId) {
        return;
      }
      setState(() {
        _updatePendingMessageStatus(
          localId,
          ChatLocalMessageStatus.sent,
          serverMessageId: result.messageId,
        );
      });
    } catch (error) {
      if (!mounted || widget.eventId.trim() != eventId) {
        return;
      }
      setState(() {
        _updatePendingMessageStatus(localId, ChatLocalMessageStatus.failed);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventGroupChatSendErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
      debugPrint(
        'EventGroupChatWidget: failed to retry message for '
        '$eventId: $error',
      );
    }
  }

  void _updatePendingMessageStatus(
    String localId,
    ChatLocalMessageStatus status, {
    String? serverMessageId,
  }) {
    final pendingIndex = _pendingMessages.indexWhere(
      (message) => message.localId == localId,
    );
    if (pendingIndex == -1) {
      return;
    }
    _pendingMessages[pendingIndex] = _pendingMessages[pendingIndex].copyWith(
      serverMessageId: serverMessageId,
      status: status,
    );
  }

  _PendingEventChatMessage _createPendingMessage(String text) {
    final createdAt = DateTime.now();
    final serial = _pendingMessageSerial++;
    return _PendingEventChatMessage(
      localId: 'pending-${createdAt.microsecondsSinceEpoch}-$serial',
      senderId: currentUserUid.trim(),
      senderDisplayName: currentUserDisplayName.trim(),
      senderPhotoUrl: currentUserPhoto.trim(),
      text: text,
      createdAt: createdAt,
      status: ChatLocalMessageStatus.sending,
    );
  }

  Future<void> _showReportMessageDialog(
    EventChatMessagesRecord message,
  ) async {
    if (_isReportingMessage || message.deletedAt != null) {
      return;
    }

    final eventId = widget.eventId.trim();
    final messageId = message.reference.id;
    final reportRequest = await showDialog<_EventChatMessageReportDialogResult>(
      context: context,
      builder: (context) => const _EventChatMessageReportDialog(),
    );
    if (reportRequest == null ||
        !mounted ||
        widget.eventId.trim() != eventId ||
        message.reference.id != messageId) {
      return;
    }
    await _handleReportMessage(
      eventId: eventId,
      messageId: messageId,
      reportRequest: reportRequest,
    );
  }

  Future<void> _handleReportMessage({
    required String eventId,
    required String messageId,
    required _EventChatMessageReportDialogResult reportRequest,
  }) async {
    if (_isReportingMessage) {
      return;
    }

    setState(() {
      _isReportingMessage = true;
    });
    try {
      final result = await EventActionsRepository.reportEventChatMessage(
        eventId: eventId,
        messageId: messageId,
        reasonCode: reportRequest.reasonCode,
        details: reportRequest.details,
        invoker: widget.reportMessageInvoker,
      );
      if (!mounted || widget.eventId.trim() != eventId) {
        return;
      }
      final message = result.alreadySubmitted
          ? FFLocalizations.of(context).getVariableText(
              ruText: 'Жалоба уже отправлена.',
              enText: 'Report already submitted.',
            )
          : FFLocalizations.of(context).getVariableText(
              ruText: 'Жалоба отправлена.',
              enText: 'Report submitted.',
            );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventGroupChatReportSuccessSnackBarKey,
          content: Text(message),
        ),
      );
    } catch (error) {
      if (!mounted || widget.eventId.trim() != eventId) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventGroupChatReportErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isReportingMessage = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _EventGroupChatTopBar(),
            Expanded(child: _buildChatContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildChatContent() {
    return StreamBuilder<EventChatsRecord?>(
      key: ValueKey<int>(_chatAccessRevision),
      stream: _chatAccessStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint(
            'EventGroupChatWidget: access stream error for '
            '${widget.eventId}: ${snapshot.error}',
          );
          return _accessDeniedState();
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Center(
            child: SizedBox.square(
              key: eventGroupChatAccessLoadingKey,
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            ),
          );
        }

        final chat = snapshot.data;
        if (chat == null) {
          return _accessDeniedState();
        }

        return _buildMessagesContent();
      },
    );
  }

  Widget _buildMessagesContent() {
    final messagesStream = _messagesStream ??= _watchMessages();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: StreamBuilder<List<EventChatMessagesRecord>>(
            stream: messagesStream,
            initialData: _cachedMessages(widget.eventId),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                debugPrint(
                  'EventGroupChatWidget: messages stream error for '
                  '${widget.eventId}: ${snapshot.error}',
                );
                return _EventGroupChatStateMessage(
                  key: eventGroupChatMessagesErrorKey,
                  titleRu: 'Не удалось загрузить чат',
                  titleEn: 'Could not load chat',
                  messageRu: 'Проверьте подключение и попробуйте снова.',
                  messageEn: 'Check your connection and try again.',
                );
              }

              final messageRecords =
                  snapshot.data ?? _cachedMessages(widget.eventId);
              if (messageRecords == null) {
                return const Center(
                  child: SizedBox.square(
                    key: eventGroupChatMessagesLoadingKey,
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.8),
                  ),
                );
              }

              if (snapshot.connectionState != ConnectionState.waiting &&
                  snapshot.hasData) {
                _rememberMessages(widget.eventId, messageRecords);
                _schedulePruneConfirmedPendingMessages(messageRecords);
              }
              final messages = _displayMessages(messageRecords);
              if (messages.isEmpty) {
                return _EventGroupChatStateMessage(
                  key: eventGroupChatMessagesEmptyKey,
                  titleRu: 'Сообщений пока нет',
                  titleEn: 'No messages yet',
                  messageRu:
                      'Когда участники напишут, сообщения появятся здесь.',
                  messageEn:
                      'Messages will appear here when participants write.',
                );
              }

              return ListView.builder(
                key: eventGroupChatMessagesListKey,
                reverse: true,
                padding: const EdgeInsetsDirectional.fromSTEB(
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space12,
                  ExpatlioDesign.space24,
                  ExpatlioDesign.space24,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  return _EventGroupChatMessageBubble(
                    key: eventGroupChatMessageItemKey(message.itemKey),
                    message: message,
                    onReportPressed: message.record == null
                        ? null
                        : () => _showReportMessageDialog(message.record!),
                    onRetryPressed:
                        message.localStatus == ChatLocalMessageStatus.failed
                            ? () => _retryPendingMessage(message.id)
                            : null,
                  );
                },
              );
            },
          ),
        ),
        _EventGroupChatComposer(
          controller: _messageTextController,
          focusNode: _messageFocusNode,
          onSendPressed: _sendMessage,
        ),
      ],
    );
  }

  List<_EventGroupChatDisplayMessage> _displayMessages(
    List<EventChatMessagesRecord> records,
  ) {
    final recordIds = records
        .map((record) => record.reference.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final visiblePendingMessages = _pendingMessages.where((message) {
      final confirmedMessageId = message.serverMessageId ?? message.localId;
      return !recordIds.contains(confirmedMessageId);
    });

    return <_EventGroupChatDisplayMessage>[
      for (final record in records)
        _EventGroupChatDisplayMessage.record(record),
      for (final message in visiblePendingMessages)
        _EventGroupChatDisplayMessage.pending(message),
    ];
  }

  void _schedulePruneConfirmedPendingMessages(
    List<EventChatMessagesRecord> records,
  ) {
    if (_pendingMessages.isEmpty || records.isEmpty) {
      return;
    }

    final recordIds = records
        .map((record) => record.reference.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    if (recordIds.isEmpty) {
      return;
    }

    final hasConfirmedPending = _pendingMessages.any((message) {
      final confirmedMessageId = message.serverMessageId ?? message.localId;
      return recordIds.contains(confirmedMessageId);
    });
    if (!hasConfirmedPending) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingMessages.removeWhere((message) {
          final confirmedMessageId = message.serverMessageId ?? message.localId;
          return recordIds.contains(confirmedMessageId);
        });
      });
    });
  }

  Widget _accessDeniedState() {
    return _EventGroupChatStateMessage(
      key: eventGroupChatAccessDeniedKey,
      titleRu: 'Сначала присоединитесь к событию',
      titleEn: 'Join the event first',
      messageRu: 'Чат доступен только участникам события.',
      messageEn: 'Only event participants can access this chat.',
    );
  }
}

class _EventChatMessageReportDialogResult {
  const _EventChatMessageReportDialogResult({
    required this.reasonCode,
    this.details,
  });

  final String reasonCode;
  final String? details;
}

class _PendingEventChatMessage {
  const _PendingEventChatMessage({
    required this.localId,
    required this.senderId,
    required this.senderDisplayName,
    required this.senderPhotoUrl,
    required this.text,
    required this.createdAt,
    required this.status,
    this.serverMessageId,
  });

  final String localId;
  final String? serverMessageId;
  final String senderId;
  final String senderDisplayName;
  final String senderPhotoUrl;
  final String text;
  final DateTime createdAt;
  final ChatLocalMessageStatus status;

  _PendingEventChatMessage copyWith({
    String? serverMessageId,
    ChatLocalMessageStatus? status,
  }) =>
      _PendingEventChatMessage(
        localId: localId,
        serverMessageId: serverMessageId ?? this.serverMessageId,
        senderId: senderId,
        senderDisplayName: senderDisplayName,
        senderPhotoUrl: senderPhotoUrl,
        text: text,
        createdAt: createdAt,
        status: status ?? this.status,
      );
}

class _EventGroupChatDisplayMessage {
  const _EventGroupChatDisplayMessage._({
    required this.id,
    required this.itemKey,
    required this.senderId,
    required this.senderDisplayName,
    required this.senderPhotoUrl,
    required this.text,
    required this.createdAt,
    required this.deletedAt,
    required this.record,
    required this.isPending,
    required this.localStatus,
  });

  factory _EventGroupChatDisplayMessage.record(
    EventChatMessagesRecord record,
  ) =>
      _EventGroupChatDisplayMessage._(
        id: record.reference.id,
        itemKey: record.reference.id,
        senderId: record.senderId,
        senderDisplayName: record.senderDisplayName,
        senderPhotoUrl: record.senderPhotoUrl,
        text: record.text,
        createdAt: record.createdAt,
        deletedAt: record.deletedAt,
        record: record,
        isPending: false,
        localStatus: null,
      );

  factory _EventGroupChatDisplayMessage.pending(
    _PendingEventChatMessage message,
  ) =>
      _EventGroupChatDisplayMessage._(
        id: message.localId,
        itemKey: message.localId,
        senderId: message.senderId,
        senderDisplayName: message.senderDisplayName,
        senderPhotoUrl: message.senderPhotoUrl,
        text: message.text,
        createdAt: message.createdAt,
        deletedAt: null,
        record: null,
        isPending: true,
        localStatus: message.status,
      );

  final String id;
  final String itemKey;
  final String senderId;
  final String senderDisplayName;
  final String senderPhotoUrl;
  final String text;
  final DateTime? createdAt;
  final DateTime? deletedAt;
  final EventChatMessagesRecord? record;
  final bool isPending;
  final ChatLocalMessageStatus? localStatus;
}

class _EventChatMessageReportReasonOption {
  const _EventChatMessageReportReasonOption({
    required this.code,
    required this.label,
  });

  final String code;
  final String label;
}

class _EventChatMessageReportDialog extends StatefulWidget {
  const _EventChatMessageReportDialog();

  @override
  State<_EventChatMessageReportDialog> createState() =>
      _EventChatMessageReportDialogState();
}

class _EventChatMessageReportDialogState
    extends State<_EventChatMessageReportDialog> {
  final TextEditingController _detailsController = TextEditingController();
  String? _selectedReasonCode;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = FFLocalizations.of(context);
    final options = _eventChatMessageReportReasonOptions(context);

    return AlertDialog(
      key: eventGroupChatReportDialogKey,
      title: Text(
        localizations.getVariableText(
          ruText: 'Пожаловаться на сообщение',
          enText: 'Report message',
        ),
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  ChoiceChip(
                    key: eventGroupChatReportReasonKey(option.code),
                    label: Text(option.label),
                    selected: _selectedReasonCode == option.code,
                    onSelected: (_) {
                      setState(() {
                        _selectedReasonCode = option.code;
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              key: eventGroupChatReportDetailsFieldKey,
              controller: _detailsController,
              maxLines: 3,
              maxLength: eventReportDetailsMaxLength,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                labelText: localizations.getVariableText(
                  ruText: 'Комментарий',
                  enText: 'Comment',
                ),
                hintText: localizations.getVariableText(
                  ruText: 'Можно оставить пустым',
                  enText: 'Optional',
                ),
                border: OutlineInputBorder(
                  borderSide: const BorderSide(color: ExpatlioDesign.border),
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.controlRadius),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: eventGroupChatReportDismissButtonKey,
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            localizations.getVariableText(
              ruText: 'Отмена',
              enText: 'Cancel',
            ),
          ),
        ),
        FilledButton(
          key: eventGroupChatReportSubmitButtonKey,
          onPressed: _selectedReasonCode == null
              ? null
              : () {
                  Navigator.of(context).pop(
                    _EventChatMessageReportDialogResult(
                      reasonCode: _selectedReasonCode!,
                      details: _detailsController.text,
                    ),
                  );
                },
          child: Text(
            localizations.getVariableText(
              ruText: 'Отправить',
              enText: 'Submit',
            ),
          ),
        ),
      ],
    );
  }
}

List<_EventChatMessageReportReasonOption> _eventChatMessageReportReasonOptions(
    BuildContext context) {
  final localizations = FFLocalizations.of(context);
  return [
    _EventChatMessageReportReasonOption(
      code: 'spam',
      label: localizations.getVariableText(
        ruText: 'Спам',
        enText: 'Spam',
      ),
    ),
    _EventChatMessageReportReasonOption(
      code: 'offensive',
      label: localizations.getVariableText(
        ruText: 'Оскорбления',
        enText: 'Offensive',
      ),
    ),
    _EventChatMessageReportReasonOption(
      code: 'unsafe',
      label: localizations.getVariableText(
        ruText: 'Небезопасно',
        enText: 'Unsafe',
      ),
    ),
    _EventChatMessageReportReasonOption(
      code: 'other',
      label: localizations.getVariableText(
        ruText: 'Другое',
        enText: 'Other',
      ),
    ),
  ];
}

class _EventGroupChatComposer extends StatelessWidget {
  const _EventGroupChatComposer({
    required this.controller,
    required this.focusNode,
    required this.onSendPressed,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSendPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ExpatlioDesign.background,
        border: Border(
          top: BorderSide(color: ExpatlioDesign.separator),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space16,
            ExpatlioDesign.space12,
            ExpatlioDesign.space16,
            ExpatlioDesign.space12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextFormField(
                  key: eventGroupChatMessageInputKey,
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.send,
                  textAlignVertical: TextAlignVertical.center,
                  minLines: 1,
                  maxLines: 4,
                  decoration: ExpatlioDesign.formFieldDecoration(
                    context,
                    hintText: FFLocalizations.of(context).getVariableText(
                      ruText: 'Написать сообщение',
                      enText: 'Write a message',
                    ),
                  ),
                  style: ExpatlioDesign.formTextStyle(context),
                  onFieldSubmitted: (_) => onSendPressed(),
                ),
              ),
              const SizedBox(width: ExpatlioDesign.space8),
              SizedBox.square(
                dimension: ExpatlioDesign.formFieldHeight,
                child: Material(
                  color: ExpatlioDesign.primary,
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusMedium),
                  child: InkWell(
                    key: eventGroupChatSendButtonKey,
                    borderRadius:
                        BorderRadius.circular(ExpatlioDesign.radiusMedium),
                    onTap: onSendPressed,
                    child: const Icon(
                      Icons.send_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventGroupChatStateMessage extends StatelessWidget {
  const _EventGroupChatStateMessage({
    super.key,
    required this.titleRu,
    required this.titleEn,
    required this.messageRu,
    required this.messageEn,
  });

  final String titleRu;
  final String titleEn;
  final String messageRu;
  final String messageEn;

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: titleRu,
      enText: titleEn,
    );
    final message = FFLocalizations.of(context).getVariableText(
      ruText: messageRu,
      enText: messageEn,
    );

    return Center(
      child: UxEmptyState(
        title: title,
        message: message,
        shrinkWrap: true,
        showImage: false,
        topPadding: ExpatlioDesign.space0,
        semanticsLabel: '$title. $message',
        liveRegion: true,
        titleStyle: ExpatlioDesign.textStyle(
          context,
          size: 22,
          weight: FontWeight.w700,
        ),
        messageStyle: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.muted,
          size: 15,
          height: 1.35,
          weight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _EventGroupChatMessageBubble extends StatelessWidget {
  const _EventGroupChatMessageBubble({
    super.key,
    required this.message,
    required this.onReportPressed,
    required this.onRetryPressed,
  });

  final _EventGroupChatDisplayMessage message;
  final VoidCallback? onReportPressed;
  final VoidCallback? onRetryPressed;

  @override
  Widget build(BuildContext context) {
    final messageId = message.id;
    final normalizedCurrentUserUid = currentUserUid.trim();
    final isCurrentUser = message.senderId.trim() == normalizedCurrentUserUid &&
        normalizedCurrentUserUid.isNotEmpty;
    final isDeleted = message.deletedAt != null;
    final canReport = normalizedCurrentUserUid.isNotEmpty &&
        !isCurrentUser &&
        !isDeleted &&
        onReportPressed != null;
    final bubbleColor = chatMessageBubbleColor(
      isCurrentUser: isCurrentUser,
      isDeleted: isDeleted,
    );
    final textColor = chatMessageTextColor(isDeleted: isDeleted);
    final senderNameColor = chatMessageSenderNameColor();
    final text = message.text.trim();
    final messageText = isDeleted
        ? FFLocalizations.of(context).getVariableText(
            ruText: 'Сообщение удалено',
            enText: 'Message removed',
          )
        : text.isEmpty
            ? message.text
            : text;
    final senderName = _senderDisplayName(context);
    final avatar = _EventGroupChatSenderAvatar(
      messageId: messageId,
      displayName: senderName,
      photoUrl: message.senderPhotoUrl,
    );
    final bubbleBody = Container(
      key: eventGroupChatMessageBubbleKey(messageId),
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: ExpatlioDesign.space12,
        vertical: ExpatlioDesign.space8,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: ExpatlioDesign.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            senderName,
            key: eventGroupChatMessageSenderNameKey(messageId),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ExpatlioDesign.textStyle(
              context,
              color: senderNameColor,
              size: 13,
              height: 1.2,
              weight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            messageText,
            key:
                isDeleted ? eventGroupChatMessageTombstoneKey(messageId) : null,
            style: ExpatlioDesign.textStyle(
              context,
              color: textColor,
              size: 16,
              height: 1.3,
              weight: FontWeight.w500,
            ),
          ),
          if (message.localStatus != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatLocalMessageStatusIcon(
                    key: eventGroupChatMessageLocalStatusKey(messageId),
                    status: message.localStatus!,
                  ),
                  if (message.localStatus == ChatLocalMessageStatus.failed &&
                      onRetryPressed != null) ...[
                    const SizedBox(width: ExpatlioDesign.space4),
                    _EventGroupChatRetryButton(
                      key: eventGroupChatMessageRetryButtonKey(messageId),
                      onPressed: onRetryPressed!,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
    final bubble = Flexible(
      child: Align(
        alignment: isCurrentUser
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: bubbleBody),
            if (canReport) ...[
              const SizedBox(width: ExpatlioDesign.space4),
              Tooltip(
                message: FFLocalizations.of(context).getVariableText(
                  ruText: 'Пожаловаться на сообщение',
                  enText: 'Report message',
                ),
                child: Semantics(
                  key: eventGroupChatMessageReportButtonKey(messageId),
                  button: true,
                  label: FFLocalizations.of(context).getVariableText(
                    ruText: 'Пожаловаться на сообщение',
                    enText: 'Report message',
                  ),
                  onTap: onReportPressed,
                  child: ExcludeSemantics(
                    child: IconButton(
                      onPressed: onReportPressed,
                      icon: const Icon(Icons.flag_outlined),
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 48,
                        height: 48,
                      ),
                      color: ExpatlioDesign.muted,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: ExpatlioDesign.space8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: isCurrentUser
            ? <Widget>[
                bubble,
                const SizedBox(width: ExpatlioDesign.space8),
                avatar,
              ]
            : <Widget>[
                avatar,
                const SizedBox(width: ExpatlioDesign.space8),
                bubble,
              ],
      ),
    );
  }

  String _senderDisplayName(BuildContext context) {
    final displayName = message.senderDisplayName.trim();
    if (displayName.isNotEmpty) {
      return displayName;
    }
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Участник',
      enText: 'Participant',
    );
  }
}

class _EventGroupChatRetryButton extends StatelessWidget {
  const _EventGroupChatRetryButton({
    super.key,
    required this.onPressed,
  });

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
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
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.danger,
          size: 11,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EventGroupChatSenderAvatar extends StatelessWidget {
  const _EventGroupChatSenderAvatar({
    required this.messageId,
    required this.displayName,
    required this.photoUrl,
  });

  static const double _dimension = 32;

  final String messageId;
  final String displayName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final normalizedPhotoUrl = photoUrl.trim();

    return Container(
      key: eventGroupChatMessageSenderAvatarKey(messageId),
      width: _dimension,
      height: _dimension,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      foregroundDecoration: const BoxDecoration(
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: ExpatlioDesign.border),
        ),
      ),
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
          size: 12,
          weight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EventGroupChatTopBar extends StatelessWidget {
  const _EventGroupChatTopBar();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: ExpatlioDesign.pageHeaderHeight,
      child: Row(
        children: [
          FlutterFlowIconButton(
            borderColor: Colors.transparent,
            borderRadius: 24,
            buttonSize: 48,
            icon: Icon(
              FFIcons.kchevronLeft,
              color: ExpatlioDesign.text,
              size: 24,
            ),
            onPressed: () => context.safePop(),
          ),
          Expanded(
            child: Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'Чат события',
                enText: 'Event chat',
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: ExpatlioDesign.pageHeaderTitleStyle(context),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}
