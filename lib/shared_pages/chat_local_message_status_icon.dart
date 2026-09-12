import 'package:flutter/material.dart';

import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/chat_local_message_status.dart';
import '/shared_pages/chat_message_bubble_style.dart';
import '/shared_pages/design/expatlio_design.dart';

class ChatLocalMessageStatusIcon extends StatelessWidget {
  const ChatLocalMessageStatusIcon({
    super.key,
    required this.status,
    this.size = 14,
  });

  final ChatLocalMessageStatus status;
  final double size;

  @override
  Widget build(BuildContext context) {
    final label = labelFor(context, status);
    return Tooltip(
      message: label,
      child: Semantics(
        label: label,
        child: Icon(
          iconFor(status),
          color: colorFor(status),
          size: size,
        ),
      ),
    );
  }

  @visibleForTesting
  static IconData iconFor(ChatLocalMessageStatus status) => switch (status) {
        ChatLocalMessageStatus.sending => Icons.schedule_rounded,
        ChatLocalMessageStatus.sent => Icons.done_rounded,
        ChatLocalMessageStatus.failed => Icons.error_outline_rounded,
      };

  @visibleForTesting
  static Color colorFor(ChatLocalMessageStatus status) => switch (status) {
        ChatLocalMessageStatus.sending => ExpatlioDesign.muted,
        ChatLocalMessageStatus.sent => chatMessageReadReceiptColor(
            isReadByPartner: false,
          ),
        ChatLocalMessageStatus.failed => ExpatlioDesign.danger,
      };

  @visibleForTesting
  static String labelFor(BuildContext context, ChatLocalMessageStatus status) {
    final localizations = FFLocalizations.of(context);
    return switch (status) {
      ChatLocalMessageStatus.sending => localizations.getVariableText(
          ruText: 'Отправляется',
          enText: 'Sending',
        ),
      ChatLocalMessageStatus.sent => localizations.getVariableText(
          ruText: 'Отправлено',
          enText: 'Sent',
        ),
      ChatLocalMessageStatus.failed => localizations.getVariableText(
          ruText: 'Не отправлено',
          enText: 'Not sent',
        ),
    };
  }
}
