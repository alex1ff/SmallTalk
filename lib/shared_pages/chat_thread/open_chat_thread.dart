import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'chat_thread_widget.dart';

Future<void> openChatThread(
  BuildContext context, {
  required DocumentReference? conversationRef,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (context) => ChatThreadWidget(conversationRef: conversationRef),
    ),
  );
}
