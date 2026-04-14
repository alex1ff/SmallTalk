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

import '/auth/firebase_auth/auth_util.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/index.dart' as app;

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
      final status = doc.data()['status'] as String?;
      if (status == null || status == 'active' || status == 'connected') {
        sessionDoc = doc;
        break;
      }
    }

    if (sessionDoc == null) {
      return false;
    }

    final sessionRef = sessionDoc.reference;
    final data = sessionDoc.data();
    final isRequester = (data['studentId'] as String?) == userId;
    if (isRequester) {
      await sessionRef.update({
        'studentNavigationTriggered': false,
        'navigationCompletedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await sessionRef.update({
        'tutorNavigationTriggered': false,
        'navigationCompletedAt': FieldValue.serverTimestamp(),
      });
    }

    if (!context.mounted) {
      return false;
    }

    context.goNamed(
      app.VideoCallPageWidget.routeName,
      queryParameters: {
        'videoDocRef': serializeParam(
          sessionRef,
          ParamType.DocumentReference,
        ),
        'roomUrl': serializeParam(
          sessionDoc.data()['dailyRoomUrl'] as String?,
          ParamType.String,
        ),
        'roomName': serializeParam(
          sessionDoc.data()['dailyRoomName'] as String?,
          ParamType.String,
        ),
      }.withoutNulls,
    );
    return true;
  } catch (_) {
    return false;
  }
}
