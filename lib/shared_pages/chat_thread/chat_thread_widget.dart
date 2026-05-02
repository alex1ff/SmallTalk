import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/call_details/call_details_widget.dart';
import '/shared_pages/call_history/call_history_utils.dart';

import 'chat_call_event_card.dart';
import 'chat_thread_model.dart';
export 'chat_thread_model.dart';

class ChatThreadWidget extends StatefulWidget {
  const ChatThreadWidget({
    super.key,
    required this.conversationRef,
  });

  final DocumentReference? conversationRef;

  static String routeName = 'chatThread';
  static String routePath = '/chatThread';

  @override
  State<ChatThreadWidget> createState() => _ChatThreadWidgetState();
}

class _ChatThreadWidgetState extends State<ChatThreadWidget> {
  late ChatThreadModel _model;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _messagesScrollController = ScrollController();
  final _userFutureCache = <String, Future<UsersRecord>>{};
  DateTime? _lastReadMarkerTarget;
  int _lastRenderedMessageCount = -1;
  bool _isSending = false;

  Future<UsersRecord> _getUserFuture(DocumentReference ref) {
    return _userFutureCache.putIfAbsent(
      ref.path,
      () => UsersRecord.getDocumentOnce(ref),
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

  Future<void> _markConversationRead(ConversationsRecord conversation) async {
    if (currentUserReference == null || currentUserUid.isEmpty) {
      return;
    }

    final target = conversation.lastMessageAt ?? conversation.unlockedAt;
    if (target == null) {
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

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_messagesScrollController.hasClients) {
        return;
      }
      final position = _messagesScrollController.position;
      _messagesScrollController.jumpTo(position.maxScrollExtent);
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

    setState(() {
      _isSending = true;
    });

    try {
      final messageRef = MessagesRecord.createDoc(conversation.reference);
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
      _model.messageTextController?.clear();
      FocusScope.of(context).unfocus();
    } catch (error) {
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

  Widget _buildLoadingState(BuildContext context) {
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
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
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
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
      backgroundColor: FlutterFlowTheme.of(context).secondaryBackground,
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

    try {
      final sessionSnap = await sessionRef.get();
      if (!sessionSnap.exists) {
        _showUnavailableCallDetailsSnackBar();
        return;
      }
    } catch (error) {
      debugPrint(
        'Failed to resolve call event session ${sessionRef.path}: $error',
      );
      _showUnavailableCallDetailsSnackBar();
      return;
    }

    if (!mounted) {
      return;
    }

    context.pushNamed(
      CallDetailsWidget.routeName,
      queryParameters: {
        'videoDocRef': serializeParam(
          sessionRef,
          ParamType.DocumentReference,
        ),
      }.withoutNulls,
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

  String _formatCallEventDetails(MessagesRecord message) {
    final eventAt = message.callEndedAt ?? message.createdAt;
    final startedAtLabel = formatSessionStartedAtFromDateTime(
      context,
      eventAt ?? message.callStartedAt,
    );
    final isMissed = message.callOutcome == kConversationCallOutcomeMissed;
    final isCancelled =
        message.callOutcome == kConversationCallOutcomeCancelled;
    final durationLabel = isMissed
        ? '—'
        : isCancelled && message.callDurationSeconds <= 0
            ? FFLocalizations.of(context).getVariableText(
                ruText: '0 сек.',
                enText: '0 sec.',
              )
            : formatDurationLabel(context, message.callDurationSeconds);

    return '$startedAtLabel • $durationLabel';
  }

  String _callEventTitle(MessagesRecord message) {
    final outcome = message.callOutcome;
    if (outcome == kConversationCallOutcomeCancelled) {
      return FFLocalizations.of(context).getVariableText(
        ruText: 'Отменённый звонок',
        enText: 'Cancelled call',
      );
    }

    if (outcome == kConversationCallOutcomeMissed) {
      final currentUserWasCaller = message.callerId == currentUserUid;
      return FFLocalizations.of(context).getVariableText(
        ruText: currentUserWasCaller ? 'Без ответа' : 'Пропущенный звонок',
        enText: currentUserWasCaller ? 'No answer' : 'Missed call',
      );
    }

    final currentUserWasCaller = message.callerId == currentUserUid;
    return FFLocalizations.of(context).getVariableText(
      ruText: currentUserWasCaller ? 'Исходящий звонок' : 'Входящий звонок',
      enText: currentUserWasCaller ? 'Outgoing call' : 'Incoming call',
    );
  }

  IconData _callEventIcon(MessagesRecord message) {
    if (message.callOutcome == kConversationCallOutcomeCancelled) {
      return Icons.phone_callback_rounded;
    }
    if (message.callOutcome == kConversationCallOutcomeMissed) {
      return Icons.phone_missed_rounded;
    }
    return message.callerId == currentUserUid
        ? Icons.call_made_rounded
        : Icons.call_received_rounded;
  }

  Color _callEventIconColor(MessagesRecord message) {
    if (message.callOutcome == kConversationCallOutcomeCancelled ||
        message.callOutcome == kConversationCallOutcomeMissed) {
      return FlutterFlowTheme.of(context).error;
    }
    return FlutterFlowTheme.of(context).primary;
  }

  Widget _buildCallEventMessageCard(
    BuildContext context, {
    required MessagesRecord message,
  }) {
    return ChatCallEventCard(
      title: _callEventTitle(message),
      details: _formatCallEventDetails(message),
      icon: _callEventIcon(message),
      iconColor: _callEventIconColor(message),
      onTap: () => _openCallEvent(message),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context, {
    required MessagesRecord message,
    required bool isCurrentUser,
  }) {
    final bubbleColor = isCurrentUser
        ? FlutterFlowTheme.of(context).primary
        : FlutterFlowTheme.of(context).primaryBackground;
    final textColor = isCurrentUser
        ? FlutterFlowTheme.of(context).primaryBackground
        : FlutterFlowTheme.of(context).primaryText;

    return Align(
      alignment: isCurrentUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 300.0),
        margin: const EdgeInsetsDirectional.only(bottom: 8.0),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(22.0),
        ),
        padding: const EdgeInsetsDirectional.fromSTEB(14.0, 10.0, 14.0, 10.0),
        child: Column(
          crossAxisAlignment:
              isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.text,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: textColor,
                    fontSize: 15.0,
                    letterSpacing: 0.0,
                  ),
            ),
            if (message.createdAt != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: 4.0),
                child: Text(
                  _formatMessageTimestamp(message.createdAt),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        color: textColor.withValues(alpha: 0.72),
                        fontSize: 11.0,
                        letterSpacing: 0.0,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context, {
    required UsersRecord partner,
    required bool isFriend,
  }) {
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
          children: [
            FlutterFlowIconButton(
              borderRadius: 70.0,
              buttonSize: 45.0,
              fillColor: Colors.white,
              icon: Icon(
                FFIcons.kchevronLeft,
                color: FlutterFlowTheme.of(context).primaryText,
                size: 20.0,
              ),
              onPressed: () => context.safePop(),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 12.0),
              child: Container(
                width: 46.0,
                height: 46.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(18.0),
                  image: partner.photoUrl.isNotEmpty
                      ? DecorationImage(
                          fit: BoxFit.cover,
                          image: CachedNetworkImageProvider(
                            partner.photoUrl,
                            maxWidth: 92,
                            maxHeight: 92,
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
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsetsDirectional.only(start: 12.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        partner.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              fontSize: 18.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                    ),
                    if (isFriend)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(start: 5.0),
                        child: Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFC107),
                          size: 20.0,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 174.0),
              child: OutlinedButton.icon(
                onPressed: () => _toggleFriend(partner.reference, isFriend),
                icon: Icon(
                  isFriend
                      ? Icons.person_remove_alt_1_rounded
                      : Icons.person_add_alt_1_rounded,
                  size: 18.0,
                ),
                label: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: isFriend ? 'Убрать из друзей' : 'Добавить в друзья',
                    enText: isFriend ? 'Remove friend' : 'Add friend',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: FlutterFlowTheme.of(context).secondaryText,
                  side: BorderSide(
                    color: FlutterFlowTheme.of(context).primaryBackground,
                  ),
                  backgroundColor: FlutterFlowTheme.of(context)
                      .secondaryBackground
                      .withValues(alpha: 0.45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    10.0,
                    8.0,
                    12.0,
                    8.0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ChatThreadModel());
  }

  @override
  void dispose() {
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

    return AuthUserStreamWidget(
      builder: (context) => StreamBuilder<DocumentSnapshot<Object?>>(
        stream: conversationRef.snapshots(),
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

          if (!snapshot.hasData) {
            return _buildLoadingState(context);
          }

          final conversationDoc = snapshot.data!;
          if (!conversationDoc.exists || conversationDoc.data() == null) {
            return _buildEmptyState(context);
          }

          final conversation =
              ConversationsRecord.fromSnapshot(conversationDoc);
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

          _markConversationRead(conversation);

          return FutureBuilder<UsersRecord>(
            future: _getUserFuture(partnerRef),
            builder: (context, partnerSnapshot) {
              if (partnerSnapshot.hasError) {
                debugPrint(
                  'ChatThreadWidget: partner load failed for ${partnerRef.path}: ${partnerSnapshot.error}',
                );
                return _buildChatUnavailableState(
                  context,
                  error: partnerSnapshot.error,
                );
              }

              if (!partnerSnapshot.hasData) {
                return _buildLoadingState(context);
              }

              final partner = partnerSnapshot.data!;
              final isFriend = userHasFriend(
                currentUserDocument,
                partner.reference,
              );

              return Scaffold(
                key: scaffoldKey,
                backgroundColor:
                    FlutterFlowTheme.of(context).secondaryBackground,
                body: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          6.0, 0.0, 6.0, 0.0),
                      child: Column(
                        children: [
                          _buildHeader(
                            context,
                            partner: partner,
                            isFriend: isFriend,
                          ),
                          Expanded(
                            child: StreamBuilder<List<MessagesRecord>>(
                              stream: queryMessagesRecord(
                                parent: conversation.reference,
                                queryBuilder: (messagesRecord) =>
                                    messagesRecord.orderBy('createdAt'),
                              ),
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

                                if (!messagesSnapshot.hasData) {
                                  return Center(
                                    child: SizedBox(
                                      width: 50.0,
                                      height: 50.0,
                                      child: SpinKitCircle(
                                        color: FlutterFlowTheme.of(context)
                                            .secondary,
                                        size: 50.0,
                                      ),
                                    ),
                                  );
                                }

                                final messages = messagesSnapshot.data!.toList()
                                  ..sort(compareMessagesForThread);

                                if (_lastRenderedMessageCount !=
                                    messages.length) {
                                  _lastRenderedMessageCount = messages.length;
                                  _scheduleScrollToBottom();
                                }

                                if (messages.isEmpty) {
                                  return Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24.0),
                                      child: Text(
                                        FFLocalizations.of(context)
                                            .getVariableText(
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
                                              color:
                                                  FlutterFlowTheme.of(context)
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
                                  padding: const EdgeInsetsDirectional.fromSTEB(
                                    12.0,
                                    12.0,
                                    12.0,
                                    120.0,
                                  ),
                                  itemCount: messages.length,
                                  itemBuilder: (context, index) {
                                    final message = messages[index];
                                    if (messageIsCallEvent(message)) {
                                      return _buildCallEventMessageCard(
                                        context,
                                        message: message,
                                      );
                                    }

                                    return _buildMessageBubble(
                                      context,
                                      message: message,
                                      isCurrentUser:
                                          message.senderId == currentUserUid,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    Align(
                      alignment: AlignmentDirectional.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0x00F2F2F7),
                              const Color(0xACF2F2F7),
                              FlutterFlowTheme.of(context).secondaryBackground,
                            ],
                            stops: const [0.0, 0.2, 1.0],
                            begin: const AlignmentDirectional(0.0, -1.0),
                            end: const AlignmentDirectional(0.0, 1.0),
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            6.0,
                            12.0,
                            6.0,
                            35.0,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.max,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _model.messageTextController,
                                  focusNode: _model.messageFocusNode,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  textInputAction: TextInputAction.send,
                                  maxLines: 4,
                                  minLines: 1,
                                  decoration: InputDecoration(
                                    hintText: FFLocalizations.of(context)
                                        .getVariableText(
                                      ruText: 'Написать сообщение',
                                      enText: 'Write a message',
                                    ),
                                    filled: true,
                                    fillColor: FlutterFlowTheme.of(context)
                                        .primaryBackground,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24.0),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding:
                                        const EdgeInsetsDirectional.fromSTEB(
                                      16.0,
                                      14.0,
                                      16.0,
                                      14.0,
                                    ),
                                  ),
                                  style: FlutterFlowTheme.of(context)
                                      .bodyMedium
                                      .override(
                                        fontFamily: 'sf pro display',
                                        fontSize: 15.0,
                                        letterSpacing: 0.0,
                                      ),
                                  onFieldSubmitted: (_) =>
                                      _sendMessage(conversation),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              SizedBox(
                                width: 52.0,
                                height: 52.0,
                                child: Material(
                                  color: FlutterFlowTheme.of(context).primary,
                                  borderRadius: BorderRadius.circular(18.0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18.0),
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
        },
      ),
    );
  }
}
