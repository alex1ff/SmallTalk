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

    final userData = userDoc.data();
    final rawRole = userData?['role'];
    String? roleValue;
    if (rawRole is String) {
      roleValue = rawRole;
    } else if (rawRole is Map) {
      final name = rawRole['name'] ?? rawRole['value'] ?? rawRole['role'];
      if (name is String) {
        roleValue = name;
      }
    }
    roleValue ??= rawRole?.toString();
    final normalizedRole = (roleValue ?? '')
        .trim()
        .split('.')
        .last
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');

    final isStudent = normalizedRole == 'student';
    final isTutor = normalizedRole == 'native_speaker' ||
        normalizedRole == 'nativespeaker' ||
        normalizedRole == 'tutor' ||
        normalizedRole == 'teacher';

    if (!isStudent && !isTutor) {
      return false;
    }

    Query<Map<String, dynamic>> query =
        FirebaseFirestore.instance.collection('videoSessions');
    if (isStudent) {
      query = query
          .where('studentId', isEqualTo: userId)
          .where('studentNavigationTriggered', isEqualTo: true);
    } else {
      query = query
          .where('tutorId', isEqualTo: userId)
          .where('tutorNavigationTriggered', isEqualTo: true);
    }

    final activeSessions = await query.limit(5).get();
    if (activeSessions.docs.isEmpty) {
      return false;
    }

    QueryDocumentSnapshot<Map<String, dynamic>>? sessionDoc;
    for (final doc in activeSessions.docs) {
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
    if (isStudent) {
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
      }.withoutNulls,
    );
    return true;
  } catch (_) {
    return false;
  }
}
