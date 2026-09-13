import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '/flutter_flow/internationalization.dart';
import '/flutter_flow/nav/nav.dart';
import '/flutter_flow/permissions_util.dart';
import '/services/match_coordinator.dart';
import '/services/passive_search_service.dart';

@immutable
class PartnerAvailabilityInvitation {
  const PartnerAvailabilityInvitation({
    required this.recipientId,
    required this.requestId,
    required this.activeUserId,
    required this.activeRequestId,
    required this.expiresAt,
  });

  static PartnerAvailabilityInvitation? fromData(Map<String, dynamic> data) {
    if (data['type'] != 'partner_available') return null;
    String? id(String key) {
      final value = data[key];
      return value is String && value.trim().isNotEmpty && !value.contains('/')
          ? value.trim()
          : null;
    }

    final recipient = id('recipientId');
    final request = id('requestId');
    final activeUser = id('activeUserId');
    final activeRequest = id('activeRequestId');
    final expiry = searchDateTime(data['expiresAt']);
    if (recipient == null ||
        request == null ||
        activeUser == null ||
        activeRequest == null ||
        expiry == null ||
        recipient == activeUser) {
      return null;
    }
    return PartnerAvailabilityInvitation(
        recipientId: recipient,
        requestId: request,
        activeUserId: activeUser,
        activeRequestId: activeRequest,
        expiresAt: expiry);
  }

  final String recipientId;
  final String requestId;
  final String activeUserId;
  final String activeRequestId;
  final DateTime expiresAt;
  String get key => '$recipientId:$requestId:$activeUserId:$activeRequestId';
}

class _ForegroundAvailabilityNotice {
  const _ForegroundAvailabilityNotice(
    this.invitation, {
    this.bodyRu,
    this.bodyEn,
  });

  final PartnerAvailabilityInvitation invitation;
  final String? bodyRu;
  final String? bodyEn;
}

/// Normal notifications have their own lifecycle. Receiving one never accepts
/// a call; only a tap reaches [PassiveSearchService.connect].
class PartnerAvailabilityNotifications with WidgetsBindingObserver {
  PartnerAvailabilityNotifications({
    this.service = PassiveSearchService.instance,
    this.contextReader,
    this.mediaPermissions,
    this.onConnected,
    this.clock,
  });

  static final instance = PartnerAvailabilityNotifications();
  final PassiveSearchService service;
  final BuildContext? Function()? contextReader;
  final Future<bool> Function()? mediaPermissions;
  final Future<void> Function(String userId)? onConnected;
  final DateTime Function()? clock;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _opened;
  Timer? _readyRetry;
  String? _userId;
  PartnerAvailabilityInvitation? _pending;
  final Map<String, _ForegroundAvailabilityNotice> _foregroundNotices = {};
  final Set<String> _completed = <String>{};
  bool _started = false;
  bool _handling = false;
  int _generation = 0;

  DateTime _now() => clock?.call() ?? DateTime.now();
  BuildContext? get _context =>
      contextReader?.call() ?? appNavigatorKey.currentContext;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _foreground = FirebaseMessaging.onMessage.listen((message) =>
        handleForeground(message.data, body: message.notification?.body));
    _opened = FirebaseMessaging.onMessageOpenedApp.listen(
      (message) => handleTap(message.data),
    );
    final generation = _generation;
    try {
      final initial = await FirebaseMessaging.instance.getInitialMessage();
      if (_started && generation == _generation && initial != null) {
        handleTap(initial.data);
      }
    } catch (error) {
      debugPrint(
          'PartnerAvailability: initial notification unavailable: $error');
    }
  }

  void setUser(String? userId) {
    if (userId == null || (_userId != null && _userId != userId)) {
      _generation++;
      _pending = null;
      _completed.clear();
      _readyRetry?.cancel();
      if (userId == null) _foregroundNotices.clear();
    }
    _userId = userId;
    if (_pending != null && userId != null && _pending!.recipientId != userId) {
      _pending = null;
    }
    if (userId != null) {
      _foregroundNotices
          .removeWhere((_, notice) => notice.invitation.recipientId != userId);
      _drainForegroundNotices();
    }
    unawaited(drain());
  }

  void handleForeground(Map<String, dynamic> data, {String? body}) {
    final invitation = PartnerAvailabilityInvitation.fromData(data);
    if (invitation == null || !invitation.expiresAt.isAfter(_now())) return;
    if (_userId != null && invitation.recipientId != _userId) return;
    _foregroundNotices[invitation.key] = _ForegroundAvailabilityNotice(
      invitation,
      bodyRu: _nonEmptyNotificationText(data['bodyRu']),
      bodyEn: _nonEmptyNotificationText(data['bodyEn']),
    );
    _drainForegroundNotices();
  }

  void _drainForegroundNotices() {
    final userId = _userId;
    if (userId == null || _foregroundNotices.isEmpty) return;
    final context = _context;
    if (context == null || !context.mounted) {
      _scheduleDrain();
      return;
    }
    final notices = _foregroundNotices.values
        .where((notice) => notice.invitation.recipientId == userId)
        .toList();
    _foregroundNotices
        .removeWhere((_, notice) => notice.invitation.recipientId == userId);
    for (final notice in notices) {
      if (!notice.invitation.expiresAt.isAfter(_now())) continue;
      _show(
        (_isRussian ? notice.bodyRu : notice.bodyEn) ??
            _text(
              'Появился собеседник. Подключитесь прямо сейчас.',
              'A partner is waiting. Join now.',
            ),
        action: () => handleTap({
          'type': 'partner_available',
          'recipientId': notice.invitation.recipientId,
          'requestId': notice.invitation.requestId,
          'activeUserId': notice.invitation.activeUserId,
          'activeRequestId': notice.invitation.activeRequestId,
          'expiresAt': notice.invitation.expiresAt.toIso8601String(),
        }),
      );
    }
  }

  bool get _isRussian =>
      _context != null && FFLocalizations.of(_context!).languageCode == 'ru';

  static String? _nonEmptyNotificationText(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }

  void _scheduleDrain() {
    _readyRetry?.cancel();
    _readyRetry = Timer(const Duration(milliseconds: 250), () {
      _drainForegroundNotices();
      unawaited(drain());
    });
  }

  void handleTap(Map<String, dynamic> data) {
    final invitation = PartnerAvailabilityInvitation.fromData(data);
    if (invitation == null ||
        _completed.contains(invitation.key) ||
        (_userId != null && invitation.recipientId != _userId)) return;
    _pending = invitation;
    unawaited(drain());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(drain());
  }

  Future<void> drain() async {
    if (_handling || _pending == null || _userId == null) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed)
      return;
    final context = _context;
    if (context == null || !context.mounted) {
      _scheduleDrain();
      return;
    }
    final invitation = _pending!;
    if (invitation.recipientId != _userId) {
      _pending = null;
      return;
    }
    if (!invitation.expiresAt.isAfter(_now())) {
      _pending = null;
      _showUnavailable();
      return;
    }
    final generation = _generation;
    bool current() =>
        generation == _generation && _userId == invitation.recipientId;
    _handling = true;
    try {
      if (MatchCoordinator.instance
          .isSearchLocallyCancelled(invitation.requestId)) {
        _pending = null;
        _show(_text(
            'Завершите остановку поиска в приложении, затем начните новый поиск.',
            'Finish stopping your search in the app, then start a new search.'));
        return;
      }
      final allowed = await (mediaPermissions?.call() ??
          ensureCameraAndMicrophonePermissions());
      if (!current()) return;
      if (MatchCoordinator.instance
          .isSearchLocallyCancelled(invitation.requestId)) {
        _pending = null;
        return;
      }
      if (!allowed) {
        _pending = null;
        _show(
            _text('Разрешите камеру и микрофон, чтобы подключиться.',
                'Allow camera and microphone to join.'),
            action: () => _retry(invitation));
        return;
      }
      // Permission sheets can outlive the invitation's active search.
      if (!invitation.expiresAt.isAfter(_now())) {
        _pending = null;
        _showUnavailable();
        return;
      }
      final result = await service.connect(
        requestId: invitation.requestId,
        activeUserId: invitation.activeUserId,
        activeRequestId: invitation.activeRequestId,
      );
      if (!current()) return;
      if (_pending?.key == invitation.key) _pending = null;
      if (result['status'] == 'matched' && result['sessionId'] is String) {
        _completed.add(invitation.key);
        await (onConnected?.call(invitation.recipientId) ??
            MatchCoordinator.instance.startForUser(invitation.recipientId));
      } else {
        _showUnavailable();
      }
    } catch (error) {
      debugPrint('PartnerAvailability: connection failed: $error');
      if (current()) {
        if (_pending?.key == invitation.key) _pending = null;
        if (error is FirebaseFunctionsException &&
            const {
              'failed-precondition',
              'permission-denied',
              'not-found',
              'unauthenticated',
              'invalid-argument'
            }.contains(error.code)) {
          _showUnavailable();
          return;
        }
        _show(
            _text('Не удалось подключиться. Проверьте подключение и повторите.',
                'Could not connect. Check your connection and retry.'),
            action: () => _retry(invitation));
      }
    } finally {
      _handling = false;
      if (_pending != null) unawaited(drain());
    }
  }

  void _retry(PartnerAvailabilityInvitation invitation) {
    if (_userId != invitation.recipientId ||
        _completed.contains(invitation.key)) return;
    _pending = invitation;
    unawaited(drain());
  }

  String _text(String ru, String en) {
    final context = _context;
    if (context == null) return en;
    return FFLocalizations.of(context).getVariableText(ruText: ru, enText: en);
  }

  void _showUnavailable() => _show(_text(
        'Собеседник уже занят или завершил поиск. Если срок очереди не истек, вы продолжаете ожидание.',
        'This partner is busy or has stopped searching. You remain on the waiting list until it expires.',
      ));

  void _show(String text, {VoidCallback? action}) {
    final context = _context;
    if (context == null || !context.mounted) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
      content: Text(text),
      duration: const Duration(seconds: 8),
      action: action == null
          ? null
          : SnackBarAction(
              label: _text('Подключиться', 'Join'),
              onPressed: action,
            ),
    ));
  }

  Future<void> dispose() async {
    _generation++;
    _started = false;
    _pending = null;
    _userId = null;
    _completed.clear();
    _foregroundNotices.clear();
    _readyRetry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _foreground?.cancel();
    await _opened?.cancel();
  }
}
