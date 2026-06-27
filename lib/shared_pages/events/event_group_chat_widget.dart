import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_action_error_mapper.dart';
import '/services/event_actions_repository.dart';
import '/services/event_group_chat_repository.dart';

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
const ValueKey<String> eventGroupChatReadOnlySnackBarKey =
    ValueKey<String>('event_group_chat_read_only_snack_bar');
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
const ValueKey<String> eventGroupChatCanceledReadOnlyBannerKey =
    ValueKey<String>('event_group_chat_canceled_read_only_banner');

ValueKey<String> eventGroupChatMessageBubbleKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_bubble_$messageId');

ValueKey<String> eventGroupChatMessageSenderNameKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_sender_name_$messageId');

ValueKey<String> eventGroupChatMessageSenderAvatarKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_sender_avatar_$messageId');

ValueKey<String> eventGroupChatMessageTombstoneKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_tombstone_$messageId');

ValueKey<String> eventGroupChatMessageReportButtonKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_report_button_$messageId');

ValueKey<String> eventGroupChatReportReasonKey(String reasonCode) =>
    ValueKey<String>('event_group_chat_report_reason_$reasonCode');

/// Event chat intentionally uses an event-specific surface.
///
/// The existing one-to-one chat UI is backed by conversation documents and
/// direct message writes, while event chat is backed by event chat documents,
/// participant access rules, read-only canceled state, and a trusted send
/// callable.
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
}

class _EventGroupChatWidgetState extends State<EventGroupChatWidget> {
  final TextEditingController _messageTextController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late Stream<EventChatsRecord?> _chatAccessStream;
  Stream<List<EventChatMessagesRecord>>? _messagesStream;
  Future<EventChatAccessStateResult>? _accessStateFuture;
  String? _accessStateCacheKey;
  int _chatAccessRevision = 0;
  bool _isSending = false;
  bool _isReportingMessage = false;

  @override
  void initState() {
    super.initState();
    _chatAccessStream = _watchChatAccess();
  }

  @override
  void didUpdateWidget(covariant EventGroupChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final accessChanged = oldWidget.eventId != widget.eventId ||
        oldWidget.chatStream != widget.chatStream ||
        oldWidget.accessStateInvoker != widget.accessStateInvoker;
    final messagesChanged = oldWidget.messagesStream != widget.messagesStream ||
        oldWidget.messageLimit != widget.messageLimit;

    if (accessChanged) {
      _chatAccessRevision += 1;
      _chatAccessStream = _watchChatAccess();
      _messagesStream = null;
      _accessStateFuture = null;
      _accessStateCacheKey = null;
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

  Stream<EventChatsRecord?> _watchChatAccess() =>
      EventGroupChatRepository.watchChatAccess(
        eventId: widget.eventId,
        chatStream: widget.chatStream,
      );

  String _accessStateKeyFor(EventChatsRecord chat) {
    final updatedAtKey =
        chat.updatedAt?.microsecondsSinceEpoch.toString() ?? 'missing';
    return [
      widget.eventId.trim(),
      chat.reference.path,
      updatedAtKey,
    ].join('|');
  }

  Future<EventChatAccessStateResult> _loadAccessState(String cacheKey) {
    if (_accessStateCacheKey != cacheKey || _accessStateFuture == null) {
      _accessStateCacheKey = cacheKey;
      _messagesStream = null;
      _accessStateFuture = EventActionsRepository.getEventChatAccessState(
        eventId: widget.eventId,
        invoker: widget.accessStateInvoker,
      );
    }
    return _accessStateFuture!;
  }

  void _clearAccessStateCacheIfCurrent(String cacheKey) {
    if (_accessStateCacheKey == cacheKey) {
      _accessStateCacheKey = null;
      _accessStateFuture = null;
    }
  }

  Future<void> _sendMessage({required bool isReadOnly}) async {
    if (_isSending) {
      return;
    }
    final text = _messageTextController.text.trim();
    if (text.isEmpty) {
      return;
    }
    if (isReadOnly) {
      _showReadOnlySnackBar();
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await EventActionsRepository.sendEventChatMessage(
        eventId: widget.eventId,
        text: text,
        invoker: widget.sendMessageInvoker,
      );
      if (!mounted) {
        return;
      }
      _messageTextController.clear();
      _messageFocusNode.unfocus();
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventGroupChatSendErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
      debugPrint(
        'EventGroupChatWidget: failed to send message for '
        '${widget.eventId}: $error',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
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

  void _showReadOnlySnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        key: eventGroupChatReadOnlySnackBarKey,
        content: Text(
          FFLocalizations.of(context).getVariableText(
            ruText: 'Чат доступен только для чтения.',
            enText: 'This chat is read-only.',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
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

        final accessStateKey = _accessStateKeyFor(chat);
        return FutureBuilder<EventChatAccessStateResult>(
          key:
              ValueKey<String>('event_group_chat_access_state_$accessStateKey'),
          future: _loadAccessState(accessStateKey),
          builder: (context, accessSnapshot) {
            if (accessSnapshot.hasError) {
              _clearAccessStateCacheIfCurrent(accessStateKey);
              debugPrint(
                'EventGroupChatWidget: access state error for '
                '${widget.eventId}: ${accessSnapshot.error}',
              );
              return _accessDeniedState();
            }

            if (!accessSnapshot.hasData) {
              return const Center(
                child: SizedBox.square(
                  key: eventGroupChatAccessLoadingKey,
                  dimension: 28,
                  child: CircularProgressIndicator(strokeWidth: 2.8),
                ),
              );
            }

            final accessState = accessSnapshot.data!;
            final isCanceledReadOnly =
                accessState.status == 'canceled' && accessState.readOnly;
            return _buildMessagesContent(
              isReadOnly: accessState.readOnly,
              isCanceledReadOnly: isCanceledReadOnly,
            );
          },
        );
      },
    );
  }

  Widget _buildMessagesContent({
    required bool isReadOnly,
    required bool isCanceledReadOnly,
  }) {
    final messagesStream = _messagesStream ??= _watchMessages();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isCanceledReadOnly) const _EventGroupChatCanceledReadOnlyBanner(),
        Expanded(
          child: StreamBuilder<List<EventChatMessagesRecord>>(
            stream: messagesStream,
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

              if (!snapshot.hasData) {
                return const Center(
                  child: SizedBox.square(
                    key: eventGroupChatMessagesLoadingKey,
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.8),
                  ),
                );
              }

              final messages = snapshot.data!;
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
                    message: message,
                    onReportPressed: () => _showReportMessageDialog(message),
                  );
                },
              );
            },
          ),
        ),
        if (!isCanceledReadOnly)
          _EventGroupChatComposer(
            controller: _messageTextController,
            focusNode: _messageFocusNode,
            isSending: _isSending,
            onSendPressed: () => _sendMessage(isReadOnly: isReadOnly),
          ),
      ],
    );
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

class _EventGroupChatCanceledReadOnlyBanner extends StatelessWidget {
  const _EventGroupChatCanceledReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    final title = FFLocalizations.of(context).getVariableText(
      ruText: 'Событие отменено',
      enText: 'Event canceled',
    );
    final description = FFLocalizations.of(context).getVariableText(
      ruText: 'Чат доступен только для чтения.',
      enText: 'This chat is read-only.',
    );

    return Semantics(
      key: eventGroupChatCanceledReadOnlyBannerKey,
      container: true,
      label: '$title. $description',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsetsDirectional.fromSTEB(
            ExpatlioDesign.space16,
            ExpatlioDesign.space8,
            ExpatlioDesign.space16,
            ExpatlioDesign.space8,
          ),
          padding: const EdgeInsetsDirectional.all(ExpatlioDesign.space12),
          decoration: BoxDecoration(
            color: ExpatlioDesign.danger.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(ExpatlioDesign.radiusSmall),
            border: Border.all(
              color: ExpatlioDesign.danger.withValues(alpha: 0.24),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.event_busy_outlined,
                color: ExpatlioDesign.danger,
                size: 20,
              ),
              const SizedBox(width: ExpatlioDesign.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.text,
                        size: 14,
                        height: 1.2,
                        weight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: ExpatlioDesign.space4),
                    Text(
                      description,
                      style: ExpatlioDesign.textStyle(
                        context,
                        color: ExpatlioDesign.muted,
                        size: 13,
                        height: 1.25,
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

class _EventChatMessageReportDialogResult {
  const _EventChatMessageReportDialogResult({
    required this.reasonCode,
    this.details,
  });

  final String reasonCode;
  final String? details;
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
                border: const OutlineInputBorder(),
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
    required this.isSending,
    required this.onSendPressed,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isSending;
  final VoidCallback onSendPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ExpatlioDesign.card,
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
                  enabled: !isSending,
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
                    onTap: isSending ? null : onSendPressed,
                    child: Icon(
                      isSending
                          ? Icons.hourglass_top_rounded
                          : Icons.send_rounded,
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(ExpatlioDesign.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: titleRu,
                enText: titleEn,
              ),
              textAlign: TextAlign.center,
              style: ExpatlioDesign.textStyle(
                context,
                size: 22,
                weight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: ExpatlioDesign.space8),
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: messageRu,
                enText: messageEn,
              ),
              textAlign: TextAlign.center,
              style: ExpatlioDesign.textStyle(
                context,
                color: ExpatlioDesign.muted,
                size: 15,
                height: 1.35,
                weight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EventGroupChatMessageBubble extends StatelessWidget {
  const _EventGroupChatMessageBubble({
    required this.message,
    required this.onReportPressed,
  });

  final EventChatMessagesRecord message;
  final VoidCallback onReportPressed;

  @override
  Widget build(BuildContext context) {
    final messageId = message.reference.id;
    final normalizedCurrentUserUid = currentUserUid.trim();
    final isCurrentUser = message.senderId.trim() == normalizedCurrentUserUid &&
        normalizedCurrentUserUid.isNotEmpty;
    final isDeleted = message.deletedAt != null;
    final canReport =
        normalizedCurrentUserUid.isNotEmpty && !isCurrentUser && !isDeleted;
    final bubbleColor = isDeleted
        ? ExpatlioDesign.secondarySystemBackground
        : isCurrentUser
            ? ExpatlioDesign.primary
            : ExpatlioDesign.card;
    final textColor = isDeleted
        ? ExpatlioDesign.muted
        : isCurrentUser
            ? Colors.white
            : ExpatlioDesign.text;
    final senderNameColor =
        isDeleted || !isCurrentUser ? ExpatlioDesign.primary : Colors.white;
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
          color:
              isCurrentUser ? ExpatlioDesign.primary : ExpatlioDesign.separator,
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
      color: ExpatlioDesign.primary.withValues(alpha: 0.10),
      alignment: Alignment.center,
      child: Text(
        _initials(),
        maxLines: 1,
        style: ExpatlioDesign.textStyle(
          context,
          color: ExpatlioDesign.primary,
          size: 12,
          weight: FontWeight.w700,
        ),
      ),
    );
  }

  String _initials() {
    final normalizedName = displayName.trim();
    if (normalizedName.isEmpty) {
      return '?';
    }
    final words = normalizedName
        .split(RegExp(r'\s+'))
        .where((word) => word.trim().isNotEmpty)
        .toList(growable: false);
    if (words.length >= 2) {
      return '${words[0].characters.first}${words[1].characters.first}'
          .toUpperCase();
    }
    return normalizedName.characters.take(2).toString().toUpperCase();
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
