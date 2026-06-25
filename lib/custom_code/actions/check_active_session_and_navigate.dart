// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import '/backend/schema/enums/enums.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'index.dart'; // Imports other custom actions

import 'dart:async';
import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '/index.dart' as app;

const int _activeSessionTokenMaxAttempts = 2;
const Duration _activeSessionTokenRetryDelay = Duration(milliseconds: 400);

Map<String, dynamic> _activeSessionMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  return <String, dynamic>{};
}

String? _activeSessionNonEmpty(dynamic value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

Future<Map<String, dynamic>?> _requestActiveSessionTokensWithRetry(
  String sessionId,
) async {
  for (var attempt = 1; attempt <= _activeSessionTokenMaxAttempts; attempt++) {
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getSessionTokens')
          .call({'sessionId': sessionId});
      return _activeSessionMap(result.data);
    } catch (_) {
      if (attempt >= _activeSessionTokenMaxAttempts) {
        return null;
      }
      await Future.delayed(_activeSessionTokenRetryDelay);
    }
  }
  return null;
}

Future<void> _clearActiveSessionNavigationFlag({
  required DocumentReference<Map<String, dynamic>> sessionRef,
  required bool isRequester,
}) async {
  final flagField =
      isRequester ? 'studentNavigationTriggered' : 'tutorNavigationTriggered';
  try {
    await sessionRef.update({
      flagField: false,
      'navigationCompletedAt': FieldValue.serverTimestamp(),
    });
  } catch (_) {}
}

Future<bool> checkActiveSessionAndNavigate(BuildContext context) async {
  final userId = currentUserUid;
  if (userId.isEmpty) {
    return false;
  }

  try {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return false;
    }

    final studentSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('studentId', isEqualTo: userId)
        .where('studentNavigationTriggered', isEqualTo: true)
        .limit(5)
        .get();
    final tutorSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('tutorId', isEqualTo: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .limit(5)
        .get();

    final deduped = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in [...studentSessions.docs, ...tutorSessions.docs]) {
      deduped[doc.reference.path] = doc;
    }

    if (deduped.isEmpty) {
      return false;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? sessionDoc;
    for (final doc in deduped.values) {
      final data = doc.data();
      final status = data['status'] as String?;
      final roomUrl = (data['dailyRoomUrl'] as String?)?.trim();
      final isJoinable =
          status == 'active' || status == 'connected' || status == 'connecting';
      if (isJoinable && roomUrl != null && roomUrl.isNotEmpty) {
        sessionDoc = doc;
        break;
      }
    }

    if (sessionDoc == null) {
      return false;
    }

    final sessionRef = sessionDoc.reference;
    final data = sessionDoc.data();
    final tokenData = await _requestActiveSessionTokensWithRetry(sessionRef.id);
    final meetingToken = _activeSessionNonEmpty(tokenData?['meetingToken']);
    final roomUrl = _activeSessionNonEmpty(tokenData?['roomUrl']) ??
        _activeSessionNonEmpty(data['dailyRoomUrl']);
    if (meetingToken == null || roomUrl == null) {
      return false;
    }

    if (!context.mounted) {
      return false;
    }

    final isRequester = (data['studentId'] as String?) == userId;
    context.goNamed(
      app.VideoCallPageWidget.routeName,
      queryParameters: {
        'videoDocRef': serializeParam(
          sessionRef,
          ParamType.DocumentReference,
        ),
        'roomUrl': serializeParam(
          roomUrl,
          ParamType.String,
        ),
        'roomName': serializeParam(
          _activeSessionNonEmpty(tokenData?['roomName']) ??
              _activeSessionNonEmpty(data['dailyRoomName']),
          ParamType.String,
        ),
        'meetingToken': serializeParam(meetingToken, ParamType.String),
      }.withoutNulls,
    );
    unawaited(_clearActiveSessionNavigationFlag(
      sessionRef: sessionRef,
      isRequester: isRequester,
    ));
    return true;
  } catch (_) {
    return false;
  }
}
