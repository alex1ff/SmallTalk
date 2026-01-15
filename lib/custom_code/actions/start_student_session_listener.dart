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
import 'package:cloud_firestore/cloud_firestore.dart';
import '/index.dart' as app;

StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? studentSessionSub;
bool studentNavigationHandled = false;

Future startStudentSessionListener(
  BuildContext context,
  String sessionId,
) async {
  final trimmedId = sessionId.trim();
  if (trimmedId.isEmpty) {
    debugPrint('WaitingForTeacher: sessionId is empty, listener not started');
    return;
  }

  await studentSessionSub?.cancel();
  studentSessionSub = null;
  studentNavigationHandled = false;

  final sessionRef =
      FirebaseFirestore.instance.collection('videoSessions').doc(trimmedId);

  studentSessionSub = sessionRef.snapshots().listen((snapshot) async {
    if (!context.mounted || studentNavigationHandled) {
      return;
    }
    if (!snapshot.exists) {
      return;
    }

    final data = snapshot.data();
    final status = data?['status'] as String?;
    final isActive = status == CallStatus.active.name ||
        status == 'active' ||
        status == 'connected';
    final studentTriggered = data?['studentNavigationTriggered'] == true;
    final hasRoomUrl = (data?['roomUrl'] as String?)?.isNotEmpty ?? false;
    final hasMeetingToken =
        (data?['meetingToken'] as String?)?.isNotEmpty ?? false;

    if (!(isActive || studentTriggered || hasRoomUrl || hasMeetingToken)) {
      return;
    }

    studentNavigationHandled = true;
    await studentSessionSub?.cancel();
    studentSessionSub = null;

    if (studentTriggered) {
      try {
        await sessionRef.update({
          'studentNavigationTriggered': false,
          'navigationCompletedAt': FieldValue.serverTimestamp(),
        });
      } catch (e) {
        debugPrint('WaitingForTeacher: failed to reset navigation flag: $e');
      }
    }

    if (!context.mounted) {
      return;
    }

    context.goNamed(
      app.VideoCallPageStudentWidget.routeName,
      queryParameters: {
        'videoDocRef': serializeParam(
          sessionRef,
          ParamType.DocumentReference,
        ),
      }.withoutNulls,
    );
  });
}
