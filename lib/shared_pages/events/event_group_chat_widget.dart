import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';

import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/components/chat_composer.dart';
import '/components/ux_empty_state.dart';
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/chat_local_message_status.dart';
import '/shared_pages/chat_local_message_status_icon.dart';
import '/shared_pages/chat_message_bubble_style.dart';
import '/shared_pages/chat_thread/chat_thread_formatters.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/event_action_error_mapper.dart';
import '/services/event_actions_repository.dart';
import '/services/event_group_chat_repository.dart';
import '/services/ux_session_cache_lifecycle.dart';
import '/services/ux_session_loaded_result_cache.dart';

const ValueKey<String> eventGroupChatMessagesLoadingKey =
    ValueKey<String>('event_group_chat_messages_loading');
const ValueKey<String> eventGroupChatMessagesErrorKey =
    ValueKey<String>('event_group_chat_messages_error');
const ValueKey<String> eventGroupChatMessagesInlineErrorKey =
    ValueKey<String>('event_group_chat_messages_inline_error');
const ValueKey<String> eventGroupChatMessagesRetryButtonKey =
    ValueKey<String>('event_group_chat_messages_retry_button');
const ValueKey<String> eventGroupChatMessagesEmptyKey =
    ValueKey<String>('event_group_chat_messages_empty');
const ValueKey<String> eventGroupChatMessagesListKey =
    ValueKey<String>('event_group_chat_messages_list');
const ValueKey<String> eventGroupChatAccessLoadingKey =
    ValueKey<String>('event_group_chat_access_loading');
const ValueKey<String> eventGroupChatAccessDeniedKey =
    ValueKey<String>('event_group_chat_access_denied');
const ValueKey<String> eventGroupChatAccessErrorKey =
    ValueKey<String>('event_group_chat_access_error');
const ValueKey<String> eventGroupChatAccessInlineErrorKey =
    ValueKey<String>('event_group_chat_access_inline_error');
const ValueKey<String> eventGroupChatAccessRetryButtonKey =
    ValueKey<String>('event_group_chat_access_retry_button');
const ValueKey<String> eventGroupChatMessageInputKey =
    ValueKey<String>('event_group_chat_message_input');
const ValueKey<String> eventGroupChatSendButtonKey =
    ValueKey<String>('event_group_chat_send_button');
const ValueKey<String> eventGroupChatComposerKey =
    ValueKey<String>('event_group_chat_composer');
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

ValueKey<String> eventGroupChatMessageTimestampKey(String messageId) =>
    ValueKey<String>('event_group_chat_message_timestamp_$messageId');

ValueKey<String> eventGroupChatDateDividerKey(String messageId) =>
    ValueKey<String>('event_group_chat_date_divider_$messageId');

ValueKey<String> eventGroupChatReportReasonKey(String reasonCode) =>
    ValueKey<String>('event_group_chat_report_reason_$reasonCode');

typedef EventGroupChatAuthenticatedUserIdProvider = String? Function();
typedef EventGroupChatInboxPersistenceInvoker = Future<void> Function({
  required String ownerUid,
  required DocumentReference userReference,
  required String eventId,
});

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
    this.debugChatAccessStateStream,
    this.messagesStream,
    this.debugMessagesStateStream,
    this.sendMessageInvoker,
    this.reportMessageInvoker,
    this.debugAuthenticatedUserIdProvider,
    this.debugAuthenticatedUserIdStream,
    this.debugInitialAuthenticatedUserId,
    this.debugInboxPersistenceInvoker,
    this.debugClientMessageIdRandom,
    this.messageLimit = EventGroupChatRepository.defaultMessageLimit,
  });

  final String eventId;
  final EventChatMetadataStream? chatStream;
  @visibleForTesting
  final EventChatAccessStateStream? debugChatAccessStateStream;
  final EventChatMessagesStream? messagesStream;
  @visibleForTesting
  final EventChatMessagesStateStream? debugMessagesStateStream;
  final EventCallableInvoker? sendMessageInvoker;
  final EventCallableInvoker? reportMessageInvoker;

  @visibleForTesting
  final EventGroupChatAuthenticatedUserIdProvider?
      debugAuthenticatedUserIdProvider;

  @visibleForTesting
  final Stream<String?>? debugAuthenticatedUserIdStream;

  @visibleForTesting
  final String? debugInitialAuthenticatedUserId;

  @visibleForTesting
  final EventGroupChatInboxPersistenceInvoker? debugInboxPersistenceInvoker;

  @visibleForTesting
  final math.Random? debugClientMessageIdRandom;

  final int messageLimit;

  static String routeName = 'eventGroupChat';
  static String routePath = '/events/:eventId/chat';

  @override
  State<EventGroupChatWidget> createState() => _EventGroupChatWidgetState();

  @visibleForTesting
  static void debugResetMessageCacheForTesting() {
    _EventGroupChatWidgetState._clearMessagesCache();
  }
}

class _EventGroupChatWidgetState extends State<EventGroupChatWidget> {
  static final UxSessionLoadedResultCache<List<EventChatMessagesRecord>>
      _messagesCacheByEventId =
      UxSessionLoadedResultCache<List<EventChatMessagesRecord>>();
  final TextEditingController _messageTextController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  late Stream<EventChatAccessLoadState> _chatAccessStream;
  Stream<EventChatMessagesLoadState>? _messagesStream;
  StreamSubscription<String?>? _authenticatedOwnerSubscription;
  final List<_PendingEventChatMessage> _pendingMessages =
      <_PendingEventChatMessage>[];
  final Set<(String, String, int)> _serverConfirmedAccessScopes = {};
  final Set<(String, String, int)> _rememberedAccessScopes = {};
  String _activeOwnerUid = '';
  int _messagesBoundaryRevision = 0;
  int _actionBoundaryRevision = 0;
  late math.Random _clientMessageIdRandom;
  EventChatMessagesLoadState? _lastDisplayedMessagesState;
  (String, String, int)? _lastDisplayedMessagesScope;
  Object? _reportOperationToken;

  bool get _isReportingMessage => _reportOperationToken != null;

  @override
  void initState() {
    super.initState();
    UxSessionCacheLifecycle.register(_clearMessagesCache);
    _activeOwnerUid = _initialAuthenticatedOwnerUid();
    UxSessionCacheLifecycle.updateAuthenticatedUser(
      _activeOwnerUid.isEmpty ? null : _activeOwnerUid,
    );
    _clientMessageIdRandom =
        widget.debugClientMessageIdRandom ?? math.Random.secure();
    _chatAccessStream = _watchChatAccess(
      ownerUid: _activeOwnerUid,
      eventId: widget.eventId,
    );
    _subscribeToAuthenticatedOwner();
  }

  @override
  void didUpdateWidget(covariant EventGroupChatWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final accessChanged = oldWidget.eventId != widget.eventId ||
        oldWidget.chatStream != widget.chatStream ||
        oldWidget.debugChatAccessStateStream !=
            widget.debugChatAccessStateStream;
    final messagesChanged = oldWidget.messagesStream != widget.messagesStream ||
        oldWidget.debugMessagesStateStream != widget.debugMessagesStateStream ||
        oldWidget.messageLimit != widget.messageLimit;
    final authenticatedOwnerSourceChanged =
        oldWidget.debugAuthenticatedUserIdProvider !=
                widget.debugAuthenticatedUserIdProvider ||
            oldWidget.debugAuthenticatedUserIdStream !=
                widget.debugAuthenticatedUserIdStream ||
            oldWidget.debugInitialAuthenticatedUserId !=
                widget.debugInitialAuthenticatedUserId;

    if (oldWidget.debugClientMessageIdRandom !=
        widget.debugClientMessageIdRandom) {
      _clientMessageIdRandom =
          widget.debugClientMessageIdRandom ?? math.Random.secure();
    }

    if (authenticatedOwnerSourceChanged) {
      _activateAuthenticatedOwner(
        _initialAuthenticatedOwnerUid(),
        rebuild: false,
      );
      _subscribeToAuthenticatedOwner();
    }

    if (accessChanged) {
      if (oldWidget.eventId != widget.eventId) {
        _actionBoundaryRevision += 1;
      }
      _serverConfirmedAccessScopes.clear();
      _rememberedAccessScopes.clear();
      _chatAccessStream = _watchChatAccess(
        ownerUid: _activeOwnerUid,
        eventId: widget.eventId,
      );
      _clearLastDisplayedMessages();
      _resetMessagesBoundary();
      _pendingMessages.clear();
      _reportOperationToken = null;
    } else if (messagesChanged) {
      _resetMessagesBoundary();
    }
  }

  @override
  void dispose() {
    unawaited(_authenticatedOwnerSubscription?.cancel());
    _messageFocusNode.dispose();
    _messageTextController.dispose();
    super.dispose();
  }

  static void _clearMessagesCache() {
    _messagesCacheByEventId.clear();
  }

  Stream<EventChatMessagesLoadState> _watchMessages({
    required String ownerUid,
    required String eventId,
    required int actionBoundaryRevision,
  }) {
    final messagesBoundaryRevision = _messagesBoundaryRevision;
    return EventGroupChatRepository.watchMessagesState(
      eventId: eventId,
      ownerUid: ownerUid,
      messagesStream: widget.messagesStream,
      messagesStateStream: widget.debugMessagesStateStream,
      limit: widget.messageLimit,
    ).where(
      (state) =>
          mounted &&
          state.ownerUid == ownerUid &&
          _activeOwnerUid == ownerUid &&
          _authenticatedOwnerUid() == ownerUid &&
          _actionBoundaryRevision == actionBoundaryRevision &&
          _messagesBoundaryRevision == messagesBoundaryRevision &&
          widget.eventId == eventId,
    );
  }

  Object _messagesCacheKey(String ownerUid, String eventId) => [
        'eventGroupChatMessages',
        ownerUid,
        eventId.trim(),
      ];

  List<EventChatMessagesRecord>? _cachedMessages(
    String ownerUid,
    String eventId,
  ) {
    if (ownerUid.isEmpty || _authenticatedOwnerUid() != ownerUid) {
      return null;
    }
    final messages = _messagesCacheByEventId.readItems(
      _messagesCacheKey(ownerUid, eventId),
    );
    if (messages == null) {
      return null;
    }
    return messages;
  }

  void _rememberMessages(
    String ownerUid,
    String eventId,
    List<EventChatMessagesRecord> messages,
    int actionBoundaryRevision,
  ) {
    if (ownerUid.isEmpty ||
        _activeOwnerUid != ownerUid ||
        _authenticatedOwnerUid() != ownerUid ||
        _actionBoundaryRevision != actionBoundaryRevision) {
      return;
    }
    _messagesCacheByEventId.writeItems(
      dataKey: _messagesCacheKey(ownerUid, eventId),
      items: List<EventChatMessagesRecord>.unmodifiable(messages),
    );
  }

  Stream<EventChatAccessLoadState> _watchChatAccess({
    required String ownerUid,
    required String eventId,
  }) {
    final actionBoundaryRevision = _actionBoundaryRevision;
    return EventGroupChatRepository.watchChatAccessState(
      eventId: eventId,
      ownerUid: ownerUid,
      chatStream: widget.chatStream,
      accessStateStream: widget.debugChatAccessStateStream,
    ).where(
      (state) =>
          mounted &&
          state.ownerUid == ownerUid &&
          _activeOwnerUid == ownerUid &&
          _authenticatedOwnerUid() == ownerUid &&
          _actionBoundaryRevision == actionBoundaryRevision &&
          widget.eventId == eventId,
    );
  }

  String _normalizeEventId(String eventId) {
    try {
      return EventGroupChatRepository.chatReferenceForEventId(eventId).id;
    } on ArgumentError {
      return '';
    }
  }

  String _normalizeOwnerUid(String? uid) => uid?.trim() ?? '';

  String _initialAuthenticatedOwnerUid() {
    final injectedInitialUid = widget.debugInitialAuthenticatedUserId;
    if (injectedInitialUid != null) {
      return _normalizeOwnerUid(injectedInitialUid);
    }
    final injectedProvider = widget.debugAuthenticatedUserIdProvider;
    if (injectedProvider != null) {
      return _normalizeOwnerUid(injectedProvider());
    }
    if (widget.chatStream != null) {
      return _trustedInjectedOwnerUid();
    }
    return _normalizeOwnerUid(FirebaseAuth.instance.currentUser?.uid);
  }

  String _trustedInjectedOwnerUid() {
    final injectedUid = currentUserUid.trim();
    return injectedUid.isEmpty ? 'test-user' : injectedUid;
  }

  Stream<String?> _watchAuthenticatedOwners() {
    final injectedStream = widget.debugAuthenticatedUserIdStream;
    if (injectedStream != null) {
      return injectedStream;
    }
    final injectedProvider = widget.debugAuthenticatedUserIdProvider;
    if (injectedProvider != null) {
      return const Stream<String?>.empty();
    }
    if (widget.chatStream != null) {
      return const Stream<String?>.empty();
    }
    return FirebaseAuth.instance.authStateChanges().map((user) => user?.uid);
  }

  void _subscribeToAuthenticatedOwner() {
    unawaited(_authenticatedOwnerSubscription?.cancel());
    _authenticatedOwnerSubscription =
        _watchAuthenticatedOwners().map(_normalizeOwnerUid).listen(
      _activateAuthenticatedOwner,
      onError: (Object error, StackTrace _) {
        if (kDebugMode) {
          debugPrint(
            'EventGroupChatWidget: auth stream failed: '
            '${error.runtimeType}',
          );
        }
      },
    );
  }

  void _activateAuthenticatedOwner(
    String ownerUid, {
    bool rebuild = true,
  }) {
    final normalizedOwnerUid = _normalizeOwnerUid(ownerUid);
    UxSessionCacheLifecycle.updateAuthenticatedUser(
      normalizedOwnerUid.isEmpty ? null : normalizedOwnerUid,
    );

    void resetOwnerBoundary() {
      _activeOwnerUid = normalizedOwnerUid;
      _actionBoundaryRevision += 1;
      _serverConfirmedAccessScopes.clear();
      _rememberedAccessScopes.clear();
      _chatAccessStream = _watchChatAccess(
        ownerUid: normalizedOwnerUid,
        eventId: widget.eventId,
      );
      _clearLastDisplayedMessages();
      _resetMessagesBoundary();
      _pendingMessages.clear();
      _messageTextController.clear();
      _reportOperationToken = null;
    }

    if (rebuild && mounted) {
      setState(resetOwnerBoundary);
    } else {
      resetOwnerBoundary();
    }
  }

  void _resetMessagesBoundary() {
    _messagesBoundaryRevision += 1;
    _messagesStream = null;
  }

  void _clearLastDisplayedMessages() {
    _lastDisplayedMessagesState = null;
    _lastDisplayedMessagesScope = null;
  }

  EventChatMessagesLoadState? _displayedMessagesState({
    required String ownerUid,
    required String eventId,
    required int actionBoundaryRevision,
    required EventChatMessagesLoadState? incomingState,
    required EventChatMessagesLoadState? cachedState,
  }) {
    if (_actionBoundaryRevision != actionBoundaryRevision) {
      return null;
    }
    final scope = (
      ownerUid,
      _normalizeEventId(eventId),
      actionBoundaryRevision,
    );
    if (incomingState != null &&
        incomingState.ownerUid == ownerUid &&
        (incomingState.messages.isNotEmpty || incomingState.isAuthoritative)) {
      final previousState = _lastDisplayedMessagesScope == scope
          ? _lastDisplayedMessagesState
          : cachedState;
      final nextState = !incomingState.isAuthoritative && previousState != null
          ? EventChatMessagesLoadState(
              ownerUid: incomingState.ownerUid,
              messages: _mergeMessagesOverlay(
                previousState.messages,
                incomingState.messages,
              ),
              isFromCache: incomingState.isFromCache,
              hasPendingWrites: incomingState.hasPendingWrites,
            )
          : incomingState;
      _lastDisplayedMessagesScope = scope;
      _lastDisplayedMessagesState = nextState;
    } else if (_lastDisplayedMessagesScope != scope && cachedState != null) {
      _lastDisplayedMessagesScope = scope;
      _lastDisplayedMessagesState = cachedState;
    }
    if (_lastDisplayedMessagesScope == scope) {
      return _lastDisplayedMessagesState;
    }
    return cachedState;
  }

  List<EventChatMessagesRecord> _mergeMessagesOverlay(
    List<EventChatMessagesRecord> previousMessages,
    List<EventChatMessagesRecord> incomingMessages,
  ) {
    final incomingByPath = <String, EventChatMessagesRecord>{};
    final incomingPaths = <String>[];
    for (final message in incomingMessages) {
      final path = message.reference.path;
      if (!incomingByPath.containsKey(path)) {
        incomingPaths.add(path);
      }
      incomingByPath[path] = message;
    }

    final mergedMessages = <EventChatMessagesRecord>[];
    final seenPaths = <String>{};
    for (final message in previousMessages) {
      final path = message.reference.path;
      if (!seenPaths.add(path)) {
        continue;
      }
      mergedMessages.add(incomingByPath[path] ?? message);
    }
    for (final path in incomingPaths) {
      if (!seenPaths.add(path)) {
        continue;
      }
      mergedMessages.add(incomingByPath[path]!);
    }
    return mergedMessages;
  }

  String _authenticatedOwnerUid() {
    final injectedProvider = widget.debugAuthenticatedUserIdProvider;
    // FlutterFlow's cached user can lag behind Firebase during account changes.
    if (injectedProvider != null) {
      return _normalizeOwnerUid(injectedProvider());
    }
    if (widget.debugAuthenticatedUserIdStream != null) {
      return _activeOwnerUid;
    }
    if (widget.chatStream != null) {
      return _trustedInjectedOwnerUid();
    }
    return _normalizeOwnerUid(FirebaseAuth.instance.currentUser?.uid);
  }

  _EventGroupChatActionScope? _captureActionScope() {
    late final String normalizedEventId;
    try {
      normalizedEventId = EventGroupChatRepository.chatReferenceForEventId(
        widget.eventId,
      ).id;
    } on ArgumentError {
      return null;
    }

    final ownerUid = _authenticatedOwnerUid();
    if (ownerUid.isEmpty ||
        ownerUid != _activeOwnerUid ||
        !_serverConfirmedAccessScopes.contains(
          (ownerUid, normalizedEventId, _actionBoundaryRevision),
        )) {
      return null;
    }
    return _EventGroupChatActionScope(
      ownerUid: ownerUid,
      userReference:
          ownerUid.isEmpty ? null : UsersRecord.collection.doc(ownerUid),
      eventId: normalizedEventId,
      actionBoundaryRevision: _actionBoundaryRevision,
    );
  }

  bool _isActionScopeCurrent(_EventGroupChatActionScope scope) {
    if (!mounted ||
        _activeOwnerUid != scope.ownerUid ||
        _authenticatedOwnerUid() != scope.ownerUid ||
        _actionBoundaryRevision != scope.actionBoundaryRevision ||
        !_serverConfirmedAccessScopes.contains(
          (
            scope.ownerUid,
            scope.eventId,
            scope.actionBoundaryRevision,
          ),
        )) {
      return false;
    }
    try {
      return EventGroupChatRepository.chatReferenceForEventId(widget.eventId)
              .id ==
          scope.eventId;
    } on ArgumentError {
      return false;
    }
  }

  void _rememberInboxEvent(_EventGroupChatActionScope scope) {
    if (!_isActionScopeCurrent(scope) ||
        scope.ownerUid.isEmpty ||
        !_rememberedAccessScopes.add((
          scope.ownerUid,
          scope.eventId,
          scope.actionBoundaryRevision,
        ))) {
      return;
    }

    EventGroupChatRepository.rememberInboxEventId(
      scope.eventId,
      ownerUid: scope.ownerUid,
    );
    if (scope.userReference != null) {
      unawaited(_persistInboxEventId(scope));
    }
  }

  Future<void> _persistInboxEventId(
    _EventGroupChatActionScope scope,
  ) async {
    final userReference = scope.userReference;
    if (scope.ownerUid.isEmpty ||
        userReference == null ||
        !_isActionScopeCurrent(scope)) {
      return;
    }

    try {
      final injectedInvoker = widget.debugInboxPersistenceInvoker;
      if (injectedInvoker != null) {
        await injectedInvoker(
          ownerUid: scope.ownerUid,
          userReference: userReference,
          eventId: scope.eventId,
        );
      } else {
        await EventGroupChatRepository.persistInboxEventId(
          ownerUid: scope.ownerUid,
          userReference: userReference,
          eventId: scope.eventId,
          isStillCurrent: () => _isActionScopeCurrent(scope),
        );
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint(
          'EventGroupChatWidget: failed to persist inbox event: '
          '${error.runtimeType}',
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageTextController.text.trim();
    if (text.isEmpty) {
      return;
    }

    final scope = _captureActionScope();
    if (scope == null || scope.ownerUid.isEmpty) {
      return;
    }
    final eventId = scope.eventId;
    final pendingMessage = _createPendingMessage(
      text,
      senderId: scope.ownerUid,
    );
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
      if (!_isActionScopeCurrent(scope)) {
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
      if (!_isActionScopeCurrent(scope)) {
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
      if (kDebugMode) {
        debugPrint(
          'EventGroupChatWidget: failed to send message: '
          '${error.runtimeType}',
        );
      }
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

    final scope = _captureActionScope();
    if (scope == null ||
        scope.ownerUid.isEmpty ||
        pendingMessage.senderId != scope.ownerUid) {
      return;
    }
    final eventId = scope.eventId;
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
      if (!_isActionScopeCurrent(scope)) {
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
      if (!_isActionScopeCurrent(scope)) {
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
      if (kDebugMode) {
        debugPrint(
          'EventGroupChatWidget: failed to retry message: '
          '${error.runtimeType}',
        );
      }
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

  String _pendingSenderDisplayName(String ownerUid) {
    if (hasCurrentUserDocumentForUid(ownerUid)) {
      final displayName = currentUserDocument?.displayName.trim() ?? '';
      if (displayName.isNotEmpty) {
        return displayName;
      }
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser?.uid == ownerUid) {
      final displayName = firebaseUser?.displayName?.trim() ?? '';
      if (displayName.isNotEmpty) {
        return displayName;
      }
    }

    if (currentUser?.uid == ownerUid) {
      return currentUser?.displayName?.trim() ?? '';
    }
    return '';
  }

  String _pendingSenderPhotoUrl(String ownerUid) {
    if (hasCurrentUserDocumentForUid(ownerUid)) {
      final photoUrl = currentUserDocument?.photoUrl.trim() ?? '';
      if (photoUrl.isNotEmpty) {
        return photoUrl;
      }
    }

    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser?.uid == ownerUid) {
      final photoUrl = firebaseUser?.photoURL?.trim() ?? '';
      if (photoUrl.isNotEmpty) {
        return photoUrl;
      }
    }

    if (currentUser?.uid == ownerUid) {
      return currentUser?.photoUrl?.trim() ?? '';
    }
    return '';
  }

  _PendingEventChatMessage _createPendingMessage(
    String text, {
    required String senderId,
  }) {
    final createdAt = DateTime.now();
    return _PendingEventChatMessage(
      localId: _createClientMessageId(),
      senderId: senderId,
      senderDisplayName: _pendingSenderDisplayName(senderId),
      senderPhotoUrl: _pendingSenderPhotoUrl(senderId),
      text: text,
      createdAt: createdAt,
      status: ChatLocalMessageStatus.sending,
    );
  }

  String _createClientMessageId() {
    final bytes = List<int>.generate(
      16,
      (_) => _clientMessageIdRandom.nextInt(256),
      growable: false,
    );
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex =
        bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<void> _showReportMessageDialog(
    EventChatMessagesRecord message,
  ) async {
    if (_isReportingMessage || message.deletedAt != null) {
      return;
    }

    final scope = _captureActionScope();
    if (scope == null) {
      return;
    }
    final messageId = message.reference.id;
    final reportRequest = await showDialog<_EventChatMessageReportDialogResult>(
      context: context,
      builder: (context) => const _EventChatMessageReportDialog(),
    );
    if (reportRequest == null ||
        !_isActionScopeCurrent(scope) ||
        message.reference.id != messageId) {
      return;
    }
    await _handleReportMessage(
      scope: scope,
      messageId: messageId,
      reportRequest: reportRequest,
    );
  }

  Future<void> _handleReportMessage({
    required _EventGroupChatActionScope scope,
    required String messageId,
    required _EventChatMessageReportDialogResult reportRequest,
  }) async {
    if (_isReportingMessage || !_isActionScopeCurrent(scope)) {
      return;
    }

    final operationToken = Object();
    setState(() {
      _reportOperationToken = operationToken;
    });
    try {
      if (!_isActionScopeCurrent(scope)) {
        return;
      }
      final result = await EventActionsRepository.reportEventChatMessage(
        eventId: scope.eventId,
        messageId: messageId,
        reasonCode: reportRequest.reasonCode,
        details: reportRequest.details,
        invoker: widget.reportMessageInvoker,
      );
      if (!_isActionScopeCurrent(scope)) {
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
      if (!_isActionScopeCurrent(scope)) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          key: eventGroupChatReportErrorSnackBarKey,
          content: Text(eventActionFailureMessage(context, error)),
        ),
      );
    } finally {
      if (mounted &&
          identical(_reportOperationToken, operationToken) &&
          _activeOwnerUid == scope.ownerUid &&
          _authenticatedOwnerUid() == scope.ownerUid) {
        setState(() {
          _reportOperationToken = null;
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
    final ownerUid = _activeOwnerUid;
    final eventId = _normalizeEventId(widget.eventId);
    final actionBoundaryRevision = _actionBoundaryRevision;
    if (ownerUid.isEmpty ||
        ownerUid != _authenticatedOwnerUid() ||
        eventId.isEmpty) {
      return _accessDeniedState();
    }
    final accessScope = (ownerUid, eventId, actionBoundaryRevision);

    return StreamBuilder<EventChatAccessLoadState>(
      key: ValueKey<(String, String, int)>(accessScope),
      stream: _chatAccessStream,
      builder: (context, snapshot) {
        final hasConfirmedAccess =
            _serverConfirmedAccessScopes.contains(accessScope);
        if (snapshot.hasError) {
          if (kDebugMode) {
            debugPrint(
              'EventGroupChatWidget: access stream failed: '
              '${snapshot.error.runtimeType}',
            );
          }
          if (_isAccessPermissionDenied(snapshot.error)) {
            _serverConfirmedAccessScopes.remove(accessScope);
            return _accessDeniedState();
          }
          if (hasConfirmedAccess) {
            return _buildAccessibleChatContent(
              actionBoundaryRevision: actionBoundaryRevision,
              showAccessRefreshError: true,
            );
          }
          return _buildAccessErrorState(context);
        }

        final accessState = snapshot.data;
        if (accessState == null) {
          if (hasConfirmedAccess) {
            return _buildAccessibleChatContent(
              actionBoundaryRevision: actionBoundaryRevision,
            );
          }
          return const Center(
            child: SizedBox.square(
              key: eventGroupChatAccessLoadingKey,
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            ),
          );
        }
        if (accessState.ownerUid != ownerUid) {
          return const Center(
            child: SizedBox.square(
              key: eventGroupChatAccessLoadingKey,
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            ),
          );
        }
        final accessChat = accessState.chat;
        if (accessState.accessGranted &&
            (accessChat == null ||
                accessChat.reference.id != eventId ||
                accessChat.eventId.trim() != eventId)) {
          return const Center(
            child: SizedBox.square(
              key: eventGroupChatAccessLoadingKey,
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            ),
          );
        }
        if (accessState.isAuthoritative) {
          if (!accessState.accessGranted) {
            _serverConfirmedAccessScopes.remove(accessScope);
            return _accessDeniedState();
          }
          _serverConfirmedAccessScopes.add(accessScope);
          final inboxScope = _captureActionScope();
          if (inboxScope != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_isActionScopeCurrent(inboxScope)) {
                _rememberInboxEvent(inboxScope);
              }
            });
          }
        } else if (!hasConfirmedAccess) {
          return const Center(
            child: SizedBox.square(
              key: eventGroupChatAccessLoadingKey,
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.8),
            ),
          );
        }

        return _buildAccessibleChatContent(
          actionBoundaryRevision: actionBoundaryRevision,
        );
      },
    );
  }

  Widget _buildAccessibleChatContent({
    required int actionBoundaryRevision,
    bool showAccessRefreshError = false,
  }) {
    return Stack(
      fit: StackFit.expand,
      children: [
        _buildMessagesContent(
          actionBoundaryRevision: actionBoundaryRevision,
        ),
        if (showAccessRefreshError)
          PositionedDirectional(
            start: ExpatlioDesign.pagePadding,
            end: ExpatlioDesign.pagePadding,
            bottom: ExpatlioDesign.space112,
            child: _buildAccessInlineError(context),
          ),
      ],
    );
  }

  Widget _buildMessagesContent({
    required int actionBoundaryRevision,
  }) {
    final ownerUid = _activeOwnerUid;
    final eventId = widget.eventId;
    final messagesStream = _messagesStream ??= _watchMessages(
      ownerUid: ownerUid,
      eventId: eventId,
      actionBoundaryRevision: actionBoundaryRevision,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: StreamBuilder<EventChatMessagesLoadState>(
            key: ValueKey<(String, String, int)>((
              ownerUid,
              _normalizeEventId(eventId),
              actionBoundaryRevision,
            )),
            stream: messagesStream,
            initialData: _cachedMessagesState(ownerUid, eventId),
            builder: (context, snapshot) {
              final cachedState = _cachedMessagesState(ownerUid, eventId);
              final messageState = _displayedMessagesState(
                ownerUid: ownerUid,
                eventId: eventId,
                actionBoundaryRevision: actionBoundaryRevision,
                incomingState: snapshot.data,
                cachedState: cachedState,
              );
              final messageRecords =
                  messageState?.messages ?? const <EventChatMessagesRecord>[];
              final displayMessages = _displayMessages(
                messageRecords,
                ownerUid: ownerUid,
              );

              if (snapshot.hasError) {
                if (kDebugMode) {
                  debugPrint(
                    'EventGroupChatWidget: messages stream failed: '
                    '${snapshot.error.runtimeType}',
                  );
                }
                if (messageState == null && displayMessages.isEmpty) {
                  return _buildMessagesErrorState(context);
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    _buildMessagesState(
                      messageState: messageState,
                      messages: displayMessages,
                    ),
                    PositionedDirectional(
                      start: ExpatlioDesign.pagePadding,
                      end: ExpatlioDesign.pagePadding,
                      top: ExpatlioDesign.space16,
                      child: _buildMessagesInlineError(context),
                    ),
                  ],
                );
              }

              if (messageState == null && displayMessages.isEmpty) {
                return const Center(
                  child: SizedBox.square(
                    key: eventGroupChatMessagesLoadingKey,
                    dimension: 28,
                    child: CircularProgressIndicator(strokeWidth: 2.8),
                  ),
                );
              }

              if (snapshot.hasData && messageState!.isAuthoritative) {
                _rememberMessages(
                  ownerUid,
                  eventId,
                  messageState.messages,
                  actionBoundaryRevision,
                );
                _schedulePruneConfirmedPendingMessages(
                  messageRecords,
                  ownerUid: ownerUid,
                  actionBoundaryRevision: actionBoundaryRevision,
                );
              }
              return _buildMessagesState(
                messageState: messageState,
                messages: displayMessages,
              );
            },
          ),
        ),
        ChatComposer(
          key: eventGroupChatComposerKey,
          controller: _messageTextController,
          focusNode: _messageFocusNode,
          onSendPressed: _sendMessage,
          hintText: FFLocalizations.of(context).getVariableText(
            ruText: 'Написать сообщение',
            enText: 'Write a message',
          ),
          sendButtonSemanticLabel: FFLocalizations.of(context).getVariableText(
            ruText: 'Отправить сообщение',
            enText: 'Send message',
          ),
          enabled: true,
          isSending: false,
          inputKey: eventGroupChatMessageInputKey,
          sendButtonKey: eventGroupChatSendButtonKey,
        ),
      ],
    );
  }

  EventChatMessagesLoadState? _cachedMessagesState(
    String ownerUid,
    String eventId,
  ) {
    final messages = _cachedMessages(ownerUid, eventId);
    if (messages == null) {
      return null;
    }
    return EventChatMessagesLoadState(
      ownerUid: ownerUid,
      messages: messages,
      isFromCache: false,
      hasPendingWrites: false,
    );
  }

  Widget _buildMessagesState({
    required EventChatMessagesLoadState? messageState,
    required List<_EventGroupChatDisplayMessage> messages,
  }) {
    if (messages.isEmpty) {
      if (messageState == null || !messageState.isAuthoritative) {
        return const Center(
          child: SizedBox.square(
            key: eventGroupChatMessagesLoadingKey,
            dimension: 28,
            child: CircularProgressIndicator(strokeWidth: 2.8),
          ),
        );
      }
      return _EventGroupChatStateMessage(
        key: eventGroupChatMessagesEmptyKey,
        titleRu: 'Сообщений пока нет',
        titleEn: 'No messages yet',
        messageRu: 'Когда участники напишут, сообщения появятся здесь.',
        messageEn: 'Messages will appear here when participants write.',
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
        final messageIndex = messages.length - 1 - index;
        final message = messages[messageIndex];
        return Column(
          key: eventGroupChatMessageItemKey(message.itemKey),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_shouldShowDateDivider(messages, messageIndex))
              _EventGroupChatDateDivider(
                key: eventGroupChatDateDividerKey(message.itemKey),
                timestamp: message.createdAt!,
              ),
            _EventGroupChatMessageBubble(
              message: message,
              onReportPressed: message.record == null
                  ? null
                  : () => _showReportMessageDialog(message.record!),
              onRetryPressed:
                  message.localStatus == ChatLocalMessageStatus.failed
                      ? () => _retryPendingMessage(message.id)
                      : null,
            ),
          ],
        );
      },
    );
  }

  bool _shouldShowDateDivider(
    List<_EventGroupChatDisplayMessage> messages,
    int messageIndex,
  ) {
    final timestamp = messages[messageIndex].createdAt;
    if (timestamp == null) {
      return false;
    }
    if (messageIndex == 0) {
      return true;
    }

    final previousTimestamp = messages[messageIndex - 1].createdAt;
    if (previousTimestamp == null) {
      return true;
    }
    final localTimestamp = timestamp.toLocal();
    final localPreviousTimestamp = previousTimestamp.toLocal();
    return localTimestamp.year != localPreviousTimestamp.year ||
        localTimestamp.month != localPreviousTimestamp.month ||
        localTimestamp.day != localPreviousTimestamp.day;
  }

  Widget _buildMessagesErrorState(BuildContext context) {
    return Semantics(
      key: eventGroupChatMessagesErrorKey,
      container: true,
      liveRegion: true,
      label: FFLocalizations.of(context).getVariableText(
        ruText: 'Не удалось загрузить чат. Повторить загрузку.',
        enText: 'Could not load chat. Retry loading.',
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _EventGroupChatStateMessage(
              titleRu: 'Не удалось загрузить чат',
              titleEn: 'Could not load chat',
              messageRu: 'Проверьте подключение и попробуйте снова.',
              messageEn: 'Check your connection and try again.',
            ),
            TextButton(
              key: eventGroupChatMessagesRetryButtonKey,
              onPressed: _retryMessages,
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Повторить',
                  enText: 'Retry',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesInlineError(BuildContext context) {
    final message = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось обновить чат.',
      enText: 'Could not refresh chat.',
    );
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
      child: Semantics(
        key: eventGroupChatMessagesInlineErrorKey,
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
              TextButton(
                key: eventGroupChatMessagesRetryButtonKey,
                onPressed: _retryMessages,
                child: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Повторить',
                    enText: 'Retry',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _retryMessages() {
    setState(_resetMessagesBoundary);
  }

  bool _isAccessPermissionDenied(Object? error) =>
      error is FirebaseException && error.code == 'permission-denied';

  void _retryChatAccess() {
    final ownerUid = _activeOwnerUid;
    if (ownerUid.isEmpty || ownerUid != _authenticatedOwnerUid()) {
      return;
    }
    setState(() {
      _chatAccessStream = _watchChatAccess(
        ownerUid: ownerUid,
        eventId: widget.eventId,
      );
    });
  }

  Widget _buildAccessErrorState(BuildContext context) {
    return Semantics(
      key: eventGroupChatAccessErrorKey,
      container: true,
      liveRegion: true,
      label: FFLocalizations.of(context).getVariableText(
        ruText: 'Не удалось проверить доступ к чату. Повторить.',
        enText: 'Could not verify chat access. Retry.',
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _EventGroupChatStateMessage(
              titleRu: 'Не удалось открыть чат',
              titleEn: 'Could not open chat',
              messageRu: 'Проверьте подключение и попробуйте снова.',
              messageEn: 'Check your connection and try again.',
            ),
            TextButton(
              key: eventGroupChatAccessRetryButtonKey,
              onPressed: _retryChatAccess,
              child: Text(
                FFLocalizations.of(context).getVariableText(
                  ruText: 'Повторить',
                  enText: 'Retry',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessInlineError(BuildContext context) {
    final message = FFLocalizations.of(context).getVariableText(
      ruText: 'Не удалось обновить доступ к чату.',
      enText: 'Could not refresh chat access.',
    );
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
      child: Semantics(
        key: eventGroupChatAccessInlineErrorKey,
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
              TextButton(
                key: eventGroupChatAccessRetryButtonKey,
                onPressed: _retryChatAccess,
                child: Text(
                  FFLocalizations.of(context).getVariableText(
                    ruText: 'Повторить',
                    enText: 'Retry',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_EventGroupChatDisplayMessage> _displayMessages(
    List<EventChatMessagesRecord> records, {
    required String ownerUid,
  }) {
    final recordIds = records
        .map((record) => record.reference.id)
        .where((id) => id.trim().isNotEmpty)
        .toSet();
    final visiblePendingMessages = _pendingMessages.where((message) {
      if (message.senderId != ownerUid ||
          _activeOwnerUid != ownerUid ||
          _authenticatedOwnerUid() != ownerUid) {
        return false;
      }
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
    List<EventChatMessagesRecord> records, {
    required String ownerUid,
    required int actionBoundaryRevision,
  }) {
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
      if (!mounted ||
          _activeOwnerUid != ownerUid ||
          _authenticatedOwnerUid() != ownerUid ||
          _actionBoundaryRevision != actionBoundaryRevision) {
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

class _EventGroupChatActionScope {
  const _EventGroupChatActionScope({
    required this.ownerUid,
    required this.userReference,
    required this.eventId,
    required this.actionBoundaryRevision,
  });

  final String ownerUid;
  final DocumentReference? userReference;
  final String eventId;
  final int actionBoundaryRevision;
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

class _EventGroupChatDateDivider extends StatelessWidget {
  const _EventGroupChatDateDivider({
    super.key,
    required this.timestamp,
  });

  final DateTime timestamp;

  @override
  Widget build(BuildContext context) {
    final locale = FFLocalizations.of(context).languageCode;
    return Center(
      child: Container(
        margin: const EdgeInsetsDirectional.only(
          bottom: ExpatlioDesign.space12,
        ),
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: ExpatlioDesign.space12,
          vertical: ExpatlioDesign.space8,
        ),
        decoration: BoxDecoration(
          color: ExpatlioDesign.card.withValues(alpha: 0.86),
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusMedium),
        ),
        child: Text(
          formatChatDateDividerLabel(timestamp, locale: locale),
          style: ExpatlioDesign.textStyle(
            context,
            color: ExpatlioDesign.muted,
            size: 12,
            weight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _EventGroupChatMessageBubble extends StatelessWidget {
  const _EventGroupChatMessageBubble({
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
    final timestampText = message.createdAt == null
        ? ''
        : MaterialLocalizations.of(context).formatTimeOfDay(
            TimeOfDay.fromDateTime(message.createdAt!.toLocal()),
            alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
          );
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
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
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
              ),
              if (timestampText.isNotEmpty || message.localStatus != null) ...[
                const SizedBox(width: ExpatlioDesign.space8),
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (timestampText.isNotEmpty)
                        Text(
                          timestampText,
                          key: eventGroupChatMessageTimestampKey(messageId),
                          maxLines: 1,
                          textScaler: TextScaler.noScaling,
                          style: ExpatlioDesign.textStyle(
                            context,
                            color: ExpatlioDesign.muted,
                            size: 11,
                            height: 1,
                            weight: FontWeight.w500,
                          ),
                        ),
                      if (message.localStatus != null) ...[
                        const SizedBox(width: ExpatlioDesign.space4),
                        ChatLocalMessageStatusIcon(
                          key: eventGroupChatMessageLocalStatusKey(messageId),
                          status: message.localStatus!,
                        ),
                      ],
                      if (message.localStatus ==
                              ChatLocalMessageStatus.failed &&
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
