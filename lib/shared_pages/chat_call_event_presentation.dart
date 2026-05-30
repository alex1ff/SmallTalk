import 'package:flutter/material.dart';

import '/backend/backend.dart';
import '/components/chat_call_event_card.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/call_history/call_history_utils.dart';

class ChatCallEventPresentation {
  const ChatCallEventPresentation({
    required this.title,
    required this.details,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String details;
  final IconData icon;
  final ChatCallEventTone tone;
}

ChatCallEventPresentation buildChatCallEventPresentation(
  BuildContext context, {
  required MessagesRecord message,
  required String currentUserUid,
  DateTime? now,
}) {
  return ChatCallEventPresentation(
    title: formatChatCallEventTitle(
      context,
      outcome: message.callOutcome,
      callerId: message.callerId,
      currentUserUid: currentUserUid,
    ),
    details: formatChatCallEventDetails(context, message, now: now),
    icon: chatCallEventIcon(
      outcome: message.callOutcome,
      callerId: message.callerId,
      currentUserUid: currentUserUid,
    ),
    tone: chatCallEventTone(message.callOutcome),
  );
}

String formatChatCallEventTitle(
  BuildContext context, {
  required String? outcome,
  required String? callerId,
  required String currentUserUid,
}) {
  if (outcome == kConversationCallOutcomeCancelled) {
    return FFLocalizations.of(context).getVariableText(
      ruText: 'Отменённый звонок',
      enText: 'Cancelled call',
    );
  }

  final currentUserWasCaller = callerId == currentUserUid;
  if (outcome == kConversationCallOutcomeMissed) {
    return FFLocalizations.of(context).getVariableText(
      ruText: currentUserWasCaller ? 'Без ответа' : 'Пропущенный звонок',
      enText: currentUserWasCaller ? 'No answer' : 'Missed call',
    );
  }

  return FFLocalizations.of(context).getVariableText(
    ruText: currentUserWasCaller ? 'Исходящий звонок' : 'Входящий звонок',
    enText: currentUserWasCaller ? 'Outgoing call' : 'Incoming call',
  );
}

String formatChatCallEventDetails(
  BuildContext context,
  MessagesRecord message, {
  DateTime? now,
}) {
  final eventAt = message.callEndedAt ?? message.createdAt;
  final startedAtLabel = formatSessionStartedAtFromDateTime(
    context,
    eventAt ?? message.callStartedAt,
    now: now,
  );
  final outcome = message.callOutcome;
  final durationLabel = outcome == kConversationCallOutcomeMissed
      ? '—'
      : outcome == kConversationCallOutcomeCancelled &&
              message.callDurationSeconds <= 0
          ? FFLocalizations.of(context).getVariableText(
              ruText: '0 сек.',
              enText: '0 sec.',
            )
          : formatDurationLabel(context, message.callDurationSeconds);

  return '$startedAtLabel • $durationLabel';
}

IconData chatCallEventIcon({
  required String? outcome,
  required String? callerId,
  required String currentUserUid,
}) {
  if (outcome == kConversationCallOutcomeCancelled) {
    return Icons.phone_callback_rounded;
  }
  if (outcome == kConversationCallOutcomeMissed) {
    return Icons.phone_missed_rounded;
  }
  return callerId == currentUserUid
      ? Icons.call_made_rounded
      : Icons.call_received_rounded;
}

ChatCallEventTone chatCallEventTone(String? outcome) {
  if (outcome == kConversationCallOutcomeCancelled ||
      outcome == kConversationCallOutcomeMissed) {
    return ChatCallEventTone.alert;
  }
  return ChatCallEventTone.normal;
}
