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
const ValueKey<String> eventGroupChatMessageInputKey =
    ValueKey<String>('event_group_chat_message_input');
const ValueKey<String> eventGroupChatSendButtonKey =
    ValueKey<String>('event_group_chat_send_button');
const ValueKey<String> eventGroupChatSendErrorSnackBarKey =
    ValueKey<String>('event_group_chat_send_error_snack_bar');

ValueKey<String> eventGroupChatMessageBubbleKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_bubble_$messageId');

ValueKey<String> eventGroupChatMessageSenderNameKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_sender_name_$messageId');

ValueKey<String> eventGroupChatMessageSenderAvatarKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_sender_avatar_$messageId');

ValueKey<String> eventGroupChatMessageTombstoneKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_tombstone_$messageId');

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
    this.messagesStream,
    this.sendMessageInvoker,
    this.messageLimit = EventGroupChatRepository.defaultMessageLimit,
  });

  final String eventId;
  final EventChatMessagesStream? messagesStream;
  final EventCallableInvoker? sendMessageInvoker;
  final int messageLimit;

  static String routeName = 'eventGroupChat';
  static String routePath = '/events/:eventId/chat';

  @override
  State<EventGroupChatWidget> createState() => _EventGroupChatWidgetState();
}

class _EventGroupChatWidgetState extends State<EventGroupChatWidget> {
  final TextEditingController _messageTextController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late Stream<List<EventChatMessagesRecord>> _messagesStream;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _messagesStream = _watchMessages();
  }

  @override
  void didUpdateWidget(covariant EventGroupChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.eventId != widget.eventId ||
        oldWidget.messagesStream != widget.messagesStream ||
        oldWidget.messageLimit != widget.messageLimit) {
      _messagesStream = _watchMessages();
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

  Future<void> _sendMessage() async {
    if (_isSending) {
      return;
    }
    final text = _messageTextController.text.trim();
    if (text.isEmpty) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _EventGroupChatTopBar(),
            Expanded(
              child: StreamBuilder<List<EventChatMessagesRecord>>(
                stream: _messagesStream,
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
                      return _EventGroupChatMessageBubble(
                        message: messages[index],
                      );
                    },
                  );
                },
              ),
            ),
            _EventGroupChatComposer(
              controller: _messageTextController,
              focusNode: _messageFocusNode,
              isSending: _isSending,
              onSendPressed: _sendMessage,
            ),
          ],
        ),
      ),
    );
  }
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
  });

  final EventChatMessagesRecord message;

  @override
  Widget build(BuildContext context) {
    final messageId = message.reference.id;
    final isCurrentUser = message.senderId.trim() == currentUserUid.trim() &&
        currentUserUid.trim().isNotEmpty;
    final isDeleted = message.deletedAt != null;
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
    final bubble = Flexible(
      child: Align(
        alignment: isCurrentUser
            ? AlignmentDirectional.centerEnd
            : AlignmentDirectional.centerStart,
        child: Container(
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
              color: isCurrentUser
                  ? ExpatlioDesign.primary
                  : ExpatlioDesign.separator,
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
                key: isDeleted
                    ? eventGroupChatMessageTombstoneKey(messageId)
                    : null,
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
