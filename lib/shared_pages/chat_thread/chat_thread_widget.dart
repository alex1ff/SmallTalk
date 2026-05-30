import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/empty/empty_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/shared_pages/call_details/call_details_widget.dart';
import '/shared_pages/call_history/call_history_utils.dart';
import '/components/chat_call_event_card.dart';
import 'chat_thread_formatters.dart';
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
  DateTime? _lastReadMarkerTarget;
  int _lastRenderedMessageCount = -1;
  bool _isSending = false;

  Stream<UserPublicProfilesRecord?> _watchPublicProfile(
          DocumentReference ref) =>
      UserPublicProfilesRecord.maybeGetDocument(
        UserPublicProfilesRecord.collection.doc(ref.id),
      );

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

  bool _shouldShowDateDivider(List<MessagesRecord> messages, int index) {
    final messageTimestamp = messages[index].createdAt;
    if (messageTimestamp == null) {
      return false;
    }

    if (index == 0) {
      return true;
    }

    return !_isSameMessageDay(messageTimestamp, messages[index - 1].createdAt);
  }

  Widget _buildDateDivider(BuildContext context, DateTime timestamp) {
    final locale = FFLocalizations.of(context).languageCode;
    return Center(
      child: Container(
        margin: const EdgeInsetsDirectional.only(bottom: 12.0),
        padding: const EdgeInsetsDirectional.fromSTEB(12.0, 6.0, 12.0, 6.0),
        decoration: BoxDecoration(
          color: ExpatlioDesign.card.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(14.0),
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

  ChatCallEventTone _callEventTone(MessagesRecord message) {
    if (message.callOutcome == kConversationCallOutcomeCancelled ||
        message.callOutcome == kConversationCallOutcomeMissed) {
      return ChatCallEventTone.alert;
    }
    return ChatCallEventTone.normal;
  }

  Widget _buildCallEventMessageCard(
    BuildContext context, {
    required MessagesRecord message,
  }) {
    return ChatCallEventCard(
      title: _callEventTitle(message),
      details: _formatCallEventDetails(message),
      icon: _callEventIcon(message),
      tone: _callEventTone(message),
      onTap: () => _openCallEvent(message),
    );
  }

  Widget _buildMessageBubble(
    BuildContext context, {
    required MessagesRecord message,
    required bool isCurrentUser,
    required bool isReadByPartner,
  }) {
    final bubbleColor =
        isCurrentUser ? const Color(0xFFEDE3FF) : ExpatlioDesign.card;
    const textColor = ExpatlioDesign.text;

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
            margin: const EdgeInsetsDirectional.only(bottom: 8.0),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16.0),
                topRight: const Radius.circular(16.0),
                bottomLeft: Radius.circular(isCurrentUser ? 16.0 : 4.0),
                bottomRight: Radius.circular(isCurrentUser ? 4.0 : 16.0),
              ),
            ),
            padding:
                const EdgeInsetsDirectional.fromSTEB(14.0, 10.0, 14.0, 8.0),
            child: Column(
              crossAxisAlignment: isCurrentUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatMessageTimestamp(message.createdAt),
                          style:
                              FlutterFlowTheme.of(context).bodyMedium.override(
                                    fontFamily: 'sf pro display',
                                    color: textColor.withValues(alpha: 0.58),
                                    fontSize: 11.0,
                                    letterSpacing: 0.0,
                                  ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 4.0),
                          Icon(
                            isReadByPartner
                                ? Icons.done_all_rounded
                                : Icons.done_rounded,
                            color: isReadByPartner
                                ? ExpatlioDesign.primary
                                : textColor.withValues(alpha: 0.45),
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

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: ExpatlioDesign.background,
        border: Border(
          bottom: BorderSide(color: ExpatlioDesign.border, width: 1.0),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 58.0,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(2.0, 6.0, 8.0, 6.0),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.safePop(),
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
                const SizedBox(width: 10.0),
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
                              padding: EdgeInsetsDirectional.only(start: 4.0),
                              child: Icon(
                                Icons.star_rounded,
                                color: Color(0xFFFFC107),
                                size: 17.0,
                              ),
                            ),
                        ],
                      ),
                      if (presenceLabel.isNotEmpty) ...[
                        const SizedBox(height: 2.0),
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
                const SizedBox(width: 8.0),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: isFriend ? 142.0 : 98.0,
                    maxWidth: isFriend ? 164.0 : 112.0,
                    minHeight: 36.0,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: () => _toggleFriend(partnerRef, isFriend),
                    icon: Icon(
                      isFriend
                          ? Icons.person_remove_alt_1_rounded
                          : Icons.person_add_alt_1_rounded,
                      size: 16.0,
                    ),
                    label: Text(
                      isFriend
                          ? FFLocalizations.of(context).getVariableText(
                              ruText: 'Убрать из друзей',
                              enText: 'Remove',
                            )
                          : FFLocalizations.of(context).getVariableText(
                              ruText: 'В друзья',
                              enText: 'Add',
                            ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: ExpatlioDesign.primary,
                      side: const BorderSide(color: ExpatlioDesign.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.0),
                      ),
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 10.0,
                      ),
                      textStyle: ExpatlioDesign.textStyle(
                        context,
                        size: 13.0,
                        weight: FontWeight.w600,
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
    final normalizedName = displayName.trim();
    final fallbackText = normalizedName.isEmpty
        ? '?'
        : normalizedName.characters.take(2).toString().toUpperCase();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: ExpatlioDesign.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: normalizedPhotoUrl.isNotEmpty
          ? Image.network(
              normalizedPhotoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _buildAvatarFallback(
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
          color: ExpatlioDesign.primary,
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

          return StreamBuilder<UserPublicProfilesRecord?>(
            stream: _watchPublicProfile(partnerRef),
            builder: (context, partnerSnapshot) {
              if (partnerSnapshot.hasError) {
                debugPrint(
                  'ChatThreadWidget: partner public profile stream failed for ${partnerRef.path}: ${partnerSnapshot.error}',
                );
              }

              if (!partnerSnapshot.hasData &&
                  partnerSnapshot.connectionState == ConnectionState.waiting &&
                  !partnerSnapshot.hasError) {
                return _buildLoadingState(context);
              }

              final isFriend = userHasFriend(
                currentUserDocument,
                partnerRef,
              );

              return Scaffold(
                key: scaffoldKey,
                backgroundColor: ExpatlioDesign.background,
                body: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                          6.0, 0.0, 6.0, 0.0),
                      child: Column(
                        children: [
                          _buildHeader(
                            context,
                            conversation: conversation,
                            partnerProfile: partnerSnapshot.hasError
                                ? null
                                : partnerSnapshot.data,
                            partnerRef: partnerRef,
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
                                    final itemChildren = <Widget>[];
                                    if (_shouldShowDateDivider(
                                      messages,
                                      index,
                                    )) {
                                      itemChildren.add(
                                        _buildDateDivider(
                                          context,
                                          message.createdAt!,
                                        ),
                                      );
                                    }

                                    if (messageIsCallEvent(message)) {
                                      itemChildren.add(
                                        _buildCallEventMessageCard(
                                          context,
                                          message: message,
                                        ),
                                      );
                                      return Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: itemChildren,
                                      );
                                    }

                                    final isCurrentUser =
                                        message.senderId == currentUserUid;
                                    final partnerReadAt = conversation
                                        .lastReadAtByUserId[partnerRef.id];
                                    final isReadByPartner = isCurrentUser &&
                                        message.createdAt != null &&
                                        partnerReadAt != null &&
                                        !partnerReadAt
                                            .isBefore(message.createdAt!);
                                    itemChildren.add(
                                      _buildMessageBubble(
                                        context,
                                        message: message,
                                        isCurrentUser: isCurrentUser,
                                        isReadByPartner: isReadByPartner,
                                      ),
                                    );

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: itemChildren,
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
                                  textAlignVertical: TextAlignVertical.center,
                                  maxLines: 4,
                                  minLines: 1,
                                  decoration:
                                      ExpatlioDesign.formFieldDecoration(
                                    context,
                                    hintText: FFLocalizations.of(context)
                                        .getVariableText(
                                      ruText: 'Написать сообщение',
                                      enText: 'Write a message',
                                    ),
                                  ),
                                  style: ExpatlioDesign.formTextStyle(context),
                                  onFieldSubmitted: (_) =>
                                      _sendMessage(conversation),
                                ),
                              ),
                              const SizedBox(width: 8.0),
                              SizedBox(
                                width: ExpatlioDesign.buttonHeight,
                                height: ExpatlioDesign.buttonHeight,
                                child: Material(
                                  color: ExpatlioDesign.primary,
                                  borderRadius: BorderRadius.circular(14.0),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14.0),
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
