// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'dart:async';
import 'package:cloud_functions/cloud_functions.dart';
import '/index.dart' as app;

StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? studentSessionSub;
bool studentNavigationHandled = false;
bool studentSessionTokenFetchInProgress = false;
int _studentSessionListenerGeneration = 0;
Stream<DocumentSnapshot<Map<String, dynamic>>> Function(String sessionId)?
    debugStudentSessionSnapshots;
Future<dynamic> Function(String sessionId)? debugStudentSessionTokenRequest;
void Function(
  DocumentReference<Map<String, dynamic>> videoDocRef, {
  String? roomUrl,
  String? roomName,
  String? meetingToken,
})? debugStudentSessionNavigator;

const int _studentSessionTokenMaxAttempts = 2;
const Duration _studentSessionTokenRetryDelay = Duration(milliseconds: 400);

Map<String, dynamic> _studentSessionMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

String? _studentSessionNonEmpty(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

Future<dynamic> _requestStudentSessionTokens(String sessionId) {
  final debugRequest = debugStudentSessionTokenRequest;
  if (debugRequest != null) {
    return debugRequest(sessionId);
  }
  return FirebaseFunctions.instance
      .httpsCallable('getSessionTokens')
      .call({'sessionId': sessionId}).then((result) => result.data);
}

Future<Map<String, dynamic>?> _requestStudentSessionTokensWithRetry(
  String sessionId,
) async {
  Object? lastError;
  for (var attempt = 1; attempt <= _studentSessionTokenMaxAttempts; attempt++) {
    try {
      return _studentSessionMap(await _requestStudentSessionTokens(sessionId));
    } catch (error) {
      lastError = error;
      if (attempt >= _studentSessionTokenMaxAttempts) {
        break;
      }
      await Future.delayed(_studentSessionTokenRetryDelay);
    }
  }
  debugPrint('WaitingForTeacher: getSessionTokens failed: $lastError');
  return null;
}

Future<void> _clearStudentNavigationFlag(
  DocumentReference<Map<String, dynamic>> sessionRef,
) async {
  try {
    await sessionRef.update({
      'studentNavigationTriggered': false,
      'navigationCompletedAt': FieldValue.serverTimestamp(),
    });
  } catch (e) {
    debugPrint('WaitingForTeacher: failed to reset navigation flag: $e');
  }
}

Future startStudentSessionListener(
  BuildContext context,
  String sessionId,
) async {
  final trimmedId = sessionId.trim();
  if (trimmedId.isEmpty) {
    debugPrint('WaitingForTeacher: sessionId is empty, listener not started');
    return;
  }

  final listenerGeneration = ++_studentSessionListenerGeneration;
  final previousSubscription = studentSessionSub;
  studentSessionSub = null;
  if (previousSubscription != null) {
    unawaited(previousSubscription.cancel());
  }
  studentNavigationHandled = false;
  studentSessionTokenFetchInProgress = false;

  final sessionRef =
      FirebaseFirestore.instance.collection('videoSessions').doc(trimmedId);
  final debugSnapshots = debugStudentSessionSnapshots;
  final sessionSnapshots = debugSnapshots != null
      ? debugSnapshots(trimmedId)
      : sessionRef.snapshots();

  studentSessionSub = sessionSnapshots.listen((snapshot) async {
    if (_studentSessionListenerGeneration != listenerGeneration ||
        !context.mounted ||
        studentNavigationHandled) {
      return;
    }
    if (!snapshot.exists) {
      return;
    }

    final data = snapshot.data();
    final status = data?['status'] as String?;
    final isJoinable = status == CallStatus.active.name ||
        status == 'active' ||
        status == 'connecting' ||
        status == 'connected';
    final studentTriggered = data?['studentNavigationTriggered'] == true;
    final hasRoomUrl = (data?['dailyRoomUrl'] as String?)?.isNotEmpty ?? false;

    if (!hasRoomUrl || !isJoinable || studentSessionTokenFetchInProgress) {
      return;
    }

    studentSessionTokenFetchInProgress = true;
    final tokenData = await _requestStudentSessionTokensWithRetry(trimmedId);
    if (_studentSessionListenerGeneration != listenerGeneration ||
        studentNavigationHandled) {
      return;
    }
    studentSessionTokenFetchInProgress = false;
    if (!context.mounted) {
      return;
    }
    final meetingToken = _studentSessionNonEmpty(tokenData?['meetingToken']);
    if (meetingToken == null) {
      return;
    }

    studentNavigationHandled = true;
    final activeSubscription = studentSessionSub;
    studentSessionSub = null;
    if (activeSubscription != null) {
      unawaited(activeSubscription.cancel());
    }

    final tokenRoomUrl = _studentSessionNonEmpty(tokenData?['roomUrl']);
    final tokenRoomName = _studentSessionNonEmpty(tokenData?['roomName']);
    final resolvedRoomUrl = tokenRoomUrl ?? data?['dailyRoomUrl'] as String?;
    final resolvedRoomName = tokenRoomName ?? data?['dailyRoomName'] as String?;
    final debugNavigator = debugStudentSessionNavigator;
    if (debugNavigator != null) {
      debugNavigator(
        sessionRef,
        roomUrl: resolvedRoomUrl,
        roomName: resolvedRoomName,
        meetingToken: meetingToken,
      );
      if (studentTriggered) {
        unawaited(_clearStudentNavigationFlag(sessionRef));
      }
      return;
    }

    if (!context.mounted) {
      return;
    }

    context.goNamed(
      app.VideoCallPageWidget.routeName,
      queryParameters: {
        'videoDocRef': serializeParam(
          sessionRef,
          ParamType.DocumentReference,
        ),
        'roomUrl': serializeParam(
          resolvedRoomUrl,
          ParamType.String,
        ),
        'roomName': serializeParam(
          resolvedRoomName,
          ParamType.String,
        ),
        'meetingToken': serializeParam(meetingToken, ParamType.String),
      }.withoutNulls,
    );
    if (studentTriggered) {
      unawaited(_clearStudentNavigationFlag(sessionRef));
    }
  });
}
