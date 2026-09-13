import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum PassiveSearchDuration {
  thirtyMinutes('30'),
  sixtyMinutes('60'),
  endOfDay('day');

  const PassiveSearchDuration(this.value);
  final String value;
}

DateTime? searchDateTime(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}

@immutable
class PassiveSearchState {
  const PassiveSearchState({
    required this.requestId,
    required this.status,
    required this.expiresAt,
    this.sourceSearchRequestId,
    this.sessionId,
  });

  factory PassiveSearchState.fromData(Map<String, dynamic> data) {
    return PassiveSearchState(
      requestId: data['requestId']?.toString() ?? '',
      status: data['status']?.toString() ?? '',
      expiresAt: searchDateTime(data['expiresAt']),
      sourceSearchRequestId: data['sourceSearchRequestId']?.toString(),
      sessionId: data['sessionId']?.toString(),
    );
  }

  final String requestId;
  final String status;
  final DateTime? expiresAt;
  final String? sourceSearchRequestId;
  final String? sessionId;

  bool isWaiting(DateTime now) =>
      requestId.isNotEmpty &&
      status == 'waiting' &&
      expiresAt != null &&
      expiresAt!.isAfter(now);
}

typedef PassiveSearchInvoker = Future<Map<String, dynamic>> Function(
  String name,
  Map<String, dynamic> data,
);
typedef PassiveSearchStream = Stream<PassiveSearchState?> Function(
    String userId);

class PassiveSearchService {
  const PassiveSearchService({
    this.invoke,
    this.watch,
    this.prepareNotifications,
    this.readTimeZone,
  });

  static const instance = PassiveSearchService();
  static const requestTimeout = Duration(seconds: 25);
  static const _timeZoneChannel = MethodChannel('smalltalk/timezone');

  final PassiveSearchInvoker? invoke;
  final PassiveSearchStream? watch;
  final Future<bool> Function()? prepareNotifications;
  final Future<String> Function()? readTimeZone;

  Stream<PassiveSearchState?> watchForUser(String userId) {
    if (watch != null) return watch!(userId);
    return FirebaseFirestore.instance
        .collection('passiveSearches')
        .doc(userId)
        .snapshots()
        .map((doc) =>
            doc.exists ? PassiveSearchState.fromData(doc.data()!) : null);
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> data,
  ) async {
    if (invoke != null) return invoke!(name, data).timeout(requestTimeout);
    final result = await FirebaseFunctions.instance
        .httpsCallable(name)
        .call<Map<String, dynamic>>(data)
        .timeout(requestTimeout);
    return result.data;
  }

  Future<bool> enableNotifications() async {
    if (prepareNotifications != null) return prepareNotifications!();
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return false;
    final messaging = FirebaseMessaging.instance;
    final settings = await messaging
        .requestPermission(
          alert: true,
          sound: true,
          badge: true,
        )
        .timeout(requestTimeout);
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return false;
    }
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        await messaging.getAPNSToken().timeout(requestTimeout) == null) {
      throw StateError('notification_token_unavailable');
    }
    final token = await messaging.getToken().timeout(requestTimeout);
    if (token == null || token.isEmpty) {
      throw StateError('notification_token_unavailable');
    }
    if (FirebaseAuth.instance.currentUser?.uid != userId) return false;
    await _call('registerVoipToken', {
      'tokenType': 'fcm',
      'token': token,
      'platform':
          defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'matchProtocolVersion': 2,
    });
    return FirebaseAuth.instance.currentUser?.uid == userId;
  }

  Future<PassiveSearchState> join({
    required String searchRequestId,
    required String requestId,
    required PassiveSearchDuration duration,
    required String locale,
  }) async {
    // A timezone is only needed for the calendar-based choice. Never substitute
    // a timezone abbreviation or current UTC offset: DST changes the deadline.
    final timeZone = duration == PassiveSearchDuration.endOfDay
        ? await (readTimeZone?.call() ??
                _timeZoneChannel
                    .invokeMethod<String>('getTimeZone')
                    .then((value) {
                  if (value == null || value.isEmpty) {
                    throw StateError('timezone_unavailable');
                  }
                  return value;
                }))
            .timeout(requestTimeout)
        : null;
    final result = await _call('joinPassiveSearch', {
      'searchRequestId': searchRequestId,
      'requestId': requestId,
      'duration': duration.value,
      'locale': locale == 'ru' ? 'ru' : 'en',
      if (timeZone != null) 'timeZone': timeZone,
    });
    return PassiveSearchState.fromData({
      ...result,
      'sourceSearchRequestId': searchRequestId,
    });
  }

  Future<Map<String, dynamic>> leave(String requestId) =>
      _call('leavePassiveSearch', {'requestId': requestId});

  Future<Map<String, dynamic>> stopActive(
          {String? requestId, String? sessionId}) =>
      _call('stopSearch', {
        if (requestId != null) 'requestId': requestId,
        if (sessionId != null) 'sessionId': sessionId,
      });

  Future<Map<String, dynamic>> connect({
    required String requestId,
    required String activeUserId,
    required String activeRequestId,
  }) =>
      _call('connectPassiveSearch', {
        'requestId': requestId,
        'activeUserId': activeUserId,
        'activeRequestId': activeRequestId,
      });
}
