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
import 'package:flutter/foundation.dart';
import '/index.dart' as app;

const int _activeSessionFallbackTokenMaxAttempts = 2;
const int _activeSessionCurrentTokenMaxAttempts = 5;
const int _activeSessionNavigationQueryLimit = 20;
const int _activeSessionLegacyFallbackLimit = 100;
const Duration _activeSessionFallbackTokenRetryDelay =
    Duration(milliseconds: 400);
const Duration _activeSessionCurrentTokenRetryDelay =
    Duration(milliseconds: 500);

class _ActiveSessionRecoveryCandidate {
  const _ActiveSessionRecoveryCandidate({
    required this.sessionDoc,
    required this.data,
    required this.tokenData,
    required this.meetingToken,
    required this.roomUrl,
  });

  final DocumentSnapshot<Map<String, dynamic>> sessionDoc;
  final Map<String, dynamic> data;
  final Map<String, dynamic> tokenData;
  final String meetingToken;
  final String roomUrl;
}

@visibleForTesting
Future<DocumentSnapshot<Map<String, dynamic>>> Function(String userId)?
    debugActiveSessionUserSnapshot;
@visibleForTesting
Future<List<DocumentSnapshot<Map<String, dynamic>>>> Function(String userId)?
    debugActiveNavigationSessionSnapshots;
@visibleForTesting
Future<DocumentSnapshot<Map<String, dynamic>>?> Function(String sessionId)?
    debugActiveCurrentSessionSnapshot;
@visibleForTesting
Future<dynamic> Function(String sessionId)? debugActiveSessionTokenRequest;
@visibleForTesting
void Function(
  DocumentReference<Map<String, dynamic>> videoDocRef, {
  String? roomUrl,
  String? roomName,
  String? meetingToken,
})? debugActiveSessionNavigator;

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

int _activeSessionTimestampMicros(dynamic value) {
  if (value is Timestamp) {
    return value.microsecondsSinceEpoch;
  }
  if (value is DateTime) {
    return value.microsecondsSinceEpoch;
  }
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return 0;
}

Map<String, dynamic> _activeSessionNestedMap(
  Map<String, dynamic> data,
  String key,
) {
  return _activeSessionMap(data[key]);
}

bool _activeSessionListContains(dynamic values, String userId) {
  if (values is! Iterable) {
    return false;
  }
  for (final value in values) {
    if (_activeSessionNonEmpty(value) == userId) {
      return true;
    }
  }
  return false;
}

bool _activeSessionHasParticipant(
  Map<String, dynamic> data,
  String userId,
) {
  if (_activeSessionListContains(data['participantIds'], userId)) {
    return true;
  }

  final matchContext = _activeSessionNestedMap(data, 'matchContext');
  final participantFields = <dynamic>[
    data['studentId'],
    data['requesterId'],
    data['tutorId'],
    data['currentResponderId'],
    data['currentTutorId'],
    data['responderId'],
    matchContext['requesterId'],
    matchContext['acceptedResponderId'],
    matchContext['currentResponderId'],
    matchContext['responderId'],
  ];

  return participantFields
      .any((value) => _activeSessionNonEmpty(value) == userId);
}

bool _activeSessionIsJoinableStatus(String? status) {
  return status == 'active' || status == 'connected' || status == 'connecting';
}

bool _activeSessionIsJoinableParticipant(
  Map<String, dynamic> data,
  String userId,
) {
  return _activeSessionIsJoinableStatus(data['status'] as String?) &&
      _activeSessionHasParticipant(data, userId);
}

bool _activeSessionHasRequesterNavigationRole(
  Map<String, dynamic> data,
  String userId,
) {
  final matchContext = _activeSessionNestedMap(data, 'matchContext');
  return <dynamic>[
    data['studentId'],
    data['requesterId'],
    matchContext['requesterId'],
  ].any((value) => _activeSessionNonEmpty(value) == userId);
}

bool _activeSessionCanUseTutorNavigationFlag(
  Map<String, dynamic> data,
  String userId,
) {
  if (_activeSessionHasRequesterNavigationRole(data, userId)) {
    return false;
  }

  final matchContext = _activeSessionNestedMap(data, 'matchContext');
  final responderFields = <dynamic>[
    data['tutorId'],
    data['currentTutorId'],
    data['currentResponderId'],
    data['responderId'],
    matchContext['acceptedResponderId'],
    matchContext['currentResponderId'],
    matchContext['responderId'],
  ];
  return responderFields
      .any((value) => _activeSessionNonEmpty(value) == userId);
}

bool _activeSessionNavigationTriggerMatchesUser(
  Map<String, dynamic> data,
  String userId,
) {
  return (data['studentNavigationTriggered'] == true &&
          _activeSessionNonEmpty(data['studentId']) == userId) ||
      (data['tutorNavigationTriggered'] == true &&
          _activeSessionCanUseTutorNavigationFlag(data, userId));
}

String? _activeSessionNavigationFlagForUser(
  Map<String, dynamic> data,
  String userId,
) {
  if (_activeSessionNonEmpty(data['studentId']) == userId) {
    return 'studentNavigationTriggered';
  }
  if (_activeSessionHasRequesterNavigationRole(data, userId)) {
    return null;
  }

  if (_activeSessionCanUseTutorNavigationFlag(data, userId)) {
    return 'tutorNavigationTriggered';
  }

  return null;
}

List<int> _activeSessionRecoverySortValues(
  DocumentSnapshot<Map<String, dynamic>> doc,
) {
  final data = doc.data();
  if (data == null) {
    return const [0, 0, 0, 0];
  }
  return [
    data['navigationTimestamp'],
    data['acceptedAt'],
    data['updatedAt'],
    data['createdAt'],
  ].map(_activeSessionTimestampMicros).toList();
}

int _compareActiveSessionRecoveryTime(
  DocumentSnapshot<Map<String, dynamic>> a,
  DocumentSnapshot<Map<String, dynamic>> b,
) {
  final aValues = _activeSessionRecoverySortValues(a);
  final bValues = _activeSessionRecoverySortValues(b);
  for (var i = 0; i < aValues.length; i++) {
    final byField = bValues[i].compareTo(aValues[i]);
    if (byField != 0) {
      return byField;
    }
  }
  return 0;
}

List<DocumentSnapshot<Map<String, dynamic>>> _sortActiveNavigationSessions(
  List<DocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final sorted = [...docs];
  sorted.sort((a, b) {
    final byTime = _compareActiveSessionRecoveryTime(a, b);
    if (byTime != 0) {
      return byTime;
    }
    return a.reference.path.compareTo(b.reference.path);
  });
  return sorted;
}

Future<Map<String, dynamic>?> _requestActiveSessionTokensWithRetry(
  String sessionId, {
  int maxAttempts = _activeSessionFallbackTokenMaxAttempts,
  Duration retryDelay = _activeSessionFallbackTokenRetryDelay,
  bool retryMissingMeetingToken = false,
}) async {
  Object? lastError;
  Map<String, dynamic>? lastData;
  for (var attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      final debugRequest = debugActiveSessionTokenRequest;
      if (debugRequest != null) {
        lastData = _activeSessionMap(await debugRequest(sessionId));
      } else {
        final result = await FirebaseFunctions.instance
            .httpsCallable('getSessionTokens')
            .call({'sessionId': sessionId});
        lastData = _activeSessionMap(result.data);
      }
      if (!retryMissingMeetingToken ||
          _activeSessionNonEmpty(lastData['meetingToken']) != null ||
          attempt >= maxAttempts) {
        return lastData;
      }
    } catch (error) {
      lastError = error;
      if (attempt >= maxAttempts) {
        debugPrint(
          'ActiveSessionRecovery: getSessionTokens failed for $sessionId: $lastError',
        );
        return null;
      }
    }
    await Future.delayed(retryDelay);
  }
  return lastData;
}

Future<void> _clearActiveSessionNavigationFlag({
  required DocumentReference<Map<String, dynamic>> sessionRef,
  required String? flagField,
}) async {
  try {
    final updateData = <String, dynamic>{
      'navigationCompletedAt': FieldValue.serverTimestamp(),
    };
    if (flagField != null) {
      updateData[flagField] = false;
    }
    await sessionRef.update(updateData);
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to reset navigation flag for ${sessionRef.id}: $error',
    );
  }
}

Future<DocumentSnapshot<Map<String, dynamic>>> _readActiveSessionUserSnapshot(
  String userId,
) {
  final debugReader = debugActiveSessionUserSnapshot;
  if (debugReader != null) {
    return debugReader(userId);
  }
  return FirebaseFirestore.instance.collection('users').doc(userId).get();
}

Future<List<DocumentSnapshot<Map<String, dynamic>>>>
    _readActiveNavigationSessionSnapshots(String userId) async {
  final debugReader = debugActiveNavigationSessionSnapshots;
  if (debugReader != null) {
    return debugReader(userId);
  }

  final snapshotsByPath = <String, DocumentSnapshot<Map<String, dynamic>>>{};
  try {
    final studentSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('studentId', isEqualTo: userId)
        .where('studentNavigationTriggered', isEqualTo: true)
        .orderBy('navigationTimestamp', descending: true)
        .limit(_activeSessionNavigationQueryLimit)
        .get();
    for (final doc in studentSessions.docs) {
      snapshotsByPath[doc.reference.path] = doc;
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read student navigation sessions for $userId: $error',
    );
  }
  try {
    final legacyStudentSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('studentId', isEqualTo: userId)
        .where('studentNavigationTriggered', isEqualTo: true)
        .limit(_activeSessionLegacyFallbackLimit)
        .get();
    for (final doc in legacyStudentSessions.docs) {
      snapshotsByPath.putIfAbsent(doc.reference.path, () => doc);
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read legacy student navigation sessions for $userId: $error',
    );
  }
  try {
    final tutorSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('tutorId', isEqualTo: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .orderBy('navigationTimestamp', descending: true)
        .limit(_activeSessionNavigationQueryLimit)
        .get();
    for (final doc in tutorSessions.docs) {
      snapshotsByPath[doc.reference.path] = doc;
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read tutor navigation sessions for $userId: $error',
    );
  }
  try {
    final legacyTutorSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('tutorId', isEqualTo: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .limit(_activeSessionLegacyFallbackLimit)
        .get();
    for (final doc in legacyTutorSessions.docs) {
      snapshotsByPath.putIfAbsent(doc.reference.path, () => doc);
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read legacy tutor navigation sessions for $userId: $error',
    );
  }
  try {
    final currentTutorSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('currentTutorId', isEqualTo: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .orderBy('navigationTimestamp', descending: true)
        .limit(_activeSessionNavigationQueryLimit)
        .get();
    for (final doc in currentTutorSessions.docs) {
      snapshotsByPath[doc.reference.path] = doc;
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read current tutor navigation sessions for $userId: $error',
    );
  }
  try {
    final legacyCurrentTutorSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('currentTutorId', isEqualTo: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .limit(_activeSessionLegacyFallbackLimit)
        .get();
    for (final doc in legacyCurrentTutorSessions.docs) {
      snapshotsByPath.putIfAbsent(doc.reference.path, () => doc);
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read legacy current tutor navigation sessions for $userId: $error',
    );
  }
  try {
    final currentResponderSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('currentResponderId', isEqualTo: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .orderBy('navigationTimestamp', descending: true)
        .limit(_activeSessionNavigationQueryLimit)
        .get();
    for (final doc in currentResponderSessions.docs) {
      final data = doc.data();
      if (_activeSessionCanUseTutorNavigationFlag(data, userId)) {
        snapshotsByPath[doc.reference.path] = doc;
      }
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read current responder navigation sessions for $userId: $error',
    );
  }
  try {
    final legacyCurrentResponderSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('currentResponderId', isEqualTo: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .limit(_activeSessionLegacyFallbackLimit)
        .get();
    for (final doc in legacyCurrentResponderSessions.docs) {
      final data = doc.data();
      if (_activeSessionCanUseTutorNavigationFlag(data, userId)) {
        snapshotsByPath.putIfAbsent(doc.reference.path, () => doc);
      }
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read legacy current responder navigation sessions for $userId: $error',
    );
  }
  try {
    final responderSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('responderId', isEqualTo: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .orderBy('navigationTimestamp', descending: true)
        .limit(_activeSessionNavigationQueryLimit)
        .get();
    for (final doc in responderSessions.docs) {
      final data = doc.data();
      if (_activeSessionCanUseTutorNavigationFlag(data, userId)) {
        snapshotsByPath[doc.reference.path] = doc;
      }
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read responder navigation sessions for $userId: $error',
    );
  }
  try {
    final legacyResponderSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('responderId', isEqualTo: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .limit(_activeSessionLegacyFallbackLimit)
        .get();
    for (final doc in legacyResponderSessions.docs) {
      final data = doc.data();
      if (_activeSessionCanUseTutorNavigationFlag(data, userId)) {
        snapshotsByPath.putIfAbsent(doc.reference.path, () => doc);
      }
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read responder legacy navigation sessions for $userId: $error',
    );
  }
  try {
    final participantSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('participantIds', arrayContains: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .orderBy('navigationTimestamp', descending: true)
        .limit(_activeSessionNavigationQueryLimit)
        .get();
    for (final doc in participantSessions.docs) {
      final data = doc.data();
      if (_activeSessionCanUseTutorNavigationFlag(data, userId)) {
        snapshotsByPath[doc.reference.path] = doc;
      }
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read participant navigation sessions for $userId: $error',
    );
  }
  try {
    final legacyParticipantSessions = await FirebaseFirestore.instance
        .collection('videoSessions')
        .where('participantIds', arrayContains: userId)
        .where('tutorNavigationTriggered', isEqualTo: true)
        .limit(_activeSessionLegacyFallbackLimit)
        .get();
    for (final doc in legacyParticipantSessions.docs) {
      final data = doc.data();
      if (_activeSessionCanUseTutorNavigationFlag(data, userId)) {
        snapshotsByPath.putIfAbsent(doc.reference.path, () => doc);
      }
    }
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to read legacy participant navigation sessions for $userId: $error',
    );
  }

  return snapshotsByPath.values.toList();
}

Future<DocumentSnapshot<Map<String, dynamic>>?> _readCurrentSessionSnapshot(
  String? sessionId,
) {
  final normalizedSessionId = _activeSessionNonEmpty(sessionId);
  if (normalizedSessionId == null) {
    return Future<DocumentSnapshot<Map<String, dynamic>>?>.value();
  }

  final debugReader = debugActiveCurrentSessionSnapshot;
  if (debugReader != null) {
    return debugReader(normalizedSessionId);
  }

  return FirebaseFirestore.instance
      .collection('videoSessions')
      .doc(normalizedSessionId)
      .get();
}

Future<_ActiveSessionRecoveryCandidate?> _resolveActiveSessionCandidate({
  required Iterable<DocumentSnapshot<Map<String, dynamic>>> candidates,
  required String userId,
  int tokenMaxAttempts = _activeSessionFallbackTokenMaxAttempts,
  Duration tokenRetryDelay = _activeSessionFallbackTokenRetryDelay,
  bool retryMissingMeetingToken = false,
}) async {
  for (final doc in candidates) {
    final data = doc.data();
    if (data == null) {
      continue;
    }
    if (!_activeSessionIsJoinableParticipant(data, userId)) {
      continue;
    }

    final tokenData = await _requestActiveSessionTokensWithRetry(
      doc.id,
      maxAttempts: tokenMaxAttempts,
      retryDelay: tokenRetryDelay,
      retryMissingMeetingToken: retryMissingMeetingToken,
    );
    final meetingToken = _activeSessionNonEmpty(tokenData?['meetingToken']);
    final roomUrl = _activeSessionNonEmpty(tokenData?['roomUrl']) ??
        _activeSessionNonEmpty(data['dailyRoomUrl']);
    if (meetingToken == null || roomUrl == null) {
      continue;
    }

    return _ActiveSessionRecoveryCandidate(
      sessionDoc: doc,
      data: data,
      tokenData: tokenData ?? const <String, dynamic>{},
      meetingToken: meetingToken,
      roomUrl: roomUrl,
    );
  }
  return null;
}

Future<bool> checkActiveSessionAndNavigate(BuildContext context) async {
  final userId = currentUserUid;
  if (userId.isEmpty) {
    return false;
  }

  try {
    final userDoc = await _readActiveSessionUserSnapshot(userId);
    if (!userDoc.exists) {
      return false;
    }
    final userData = userDoc.data();
    if (userData?['isInCall'] != true) {
      return false;
    }

    DocumentSnapshot<Map<String, dynamic>>? currentSession;
    var currentSessionReadFailed = false;
    try {
      currentSession = await _readCurrentSessionSnapshot(
        _activeSessionNonEmpty(userData?['currentSessionId']),
      );
    } catch (error) {
      debugPrint(
        'ActiveSessionRecovery: failed to read current session for $userId: $error',
      );
      currentSessionReadFailed =
          _activeSessionNonEmpty(userData?['currentSessionId']) != null;
      currentSession = null;
    }
    final currentData = currentSession != null && currentSession.exists
        ? currentSession.data()
        : null;
    final currentSessionIsJoinable = currentData != null &&
        _activeSessionIsJoinableParticipant(currentData, userId);
    final currentCandidate = currentSessionIsJoinable
        ? await _resolveActiveSessionCandidate(
            candidates: [currentSession!],
            userId: userId,
            tokenMaxAttempts: _activeSessionCurrentTokenMaxAttempts,
            tokenRetryDelay: _activeSessionCurrentTokenRetryDelay,
            retryMissingMeetingToken: true,
          )
        : null;

    _ActiveSessionRecoveryCandidate? selectedCandidate = currentCandidate;
    if (selectedCandidate == null && currentSessionIsJoinable) {
      return false;
    }
    if (selectedCandidate == null && currentSessionReadFailed) {
      return false;
    }
    if (selectedCandidate == null) {
      List<DocumentSnapshot<Map<String, dynamic>>> navigationSessions =
          const [];
      try {
        navigationSessions =
            await _readActiveNavigationSessionSnapshots(userId);
      } catch (error) {
        debugPrint(
          'ActiveSessionRecovery: failed to read navigation sessions for $userId: $error',
        );
        navigationSessions = const [];
      }
      final sortedNavigationSessions =
          _sortActiveNavigationSessions(navigationSessions);
      final currentPath = currentSession?.reference.path;
      selectedCandidate = await _resolveActiveSessionCandidate(
        candidates: sortedNavigationSessions.where(
          (doc) {
            final data = doc.data();
            return doc.reference.path != currentPath &&
                data != null &&
                _activeSessionNavigationTriggerMatchesUser(data, userId);
          },
        ),
        userId: userId,
      );
    }

    if (selectedCandidate == null) {
      return false;
    }

    final sessionRef = selectedCandidate.sessionDoc.reference;
    final data = selectedCandidate.data;
    final tokenData = selectedCandidate.tokenData;
    final meetingToken = selectedCandidate.meetingToken;
    final roomUrl = selectedCandidate.roomUrl;

    if (!context.mounted) {
      return false;
    }

    final flagField = _activeSessionNavigationFlagForUser(data, userId);
    final roomName = _activeSessionNonEmpty(tokenData?['roomName']) ??
        _activeSessionNonEmpty(data['dailyRoomName']);
    final debugNavigator = debugActiveSessionNavigator;
    if (debugNavigator != null) {
      debugNavigator(
        sessionRef,
        roomUrl: roomUrl,
        roomName: roomName,
        meetingToken: meetingToken,
      );
    } else {
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
            roomName,
            ParamType.String,
          ),
          'meetingToken': serializeParam(meetingToken, ParamType.String),
        }.withoutNulls,
      );
    }
    unawaited(_clearActiveSessionNavigationFlag(
      sessionRef: sessionRef,
      flagField: flagField,
    ));
    return true;
  } catch (error) {
    debugPrint(
      'ActiveSessionRecovery: failed to recover active session for $userId: $error',
    );
    return false;
  }
}
