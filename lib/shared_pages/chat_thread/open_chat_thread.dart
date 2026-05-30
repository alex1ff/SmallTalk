import 'package:flutter/material.dart';

import '/backend/backend.dart';
import 'chat_thread_widget.dart';

Future<void> openChatThread(
  BuildContext context, {
  required DocumentReference? conversationRef,
  ConversationsRecord? initialConversation,
}) {
  return Navigator.of(context, rootNavigator: true).push(
    MaterialPageRoute<void>(
      builder: (context) => ChatThreadWidget(
        conversationRef: conversationRef,
        initialConversation: initialConversation,
      ),
    ),
  );
}
