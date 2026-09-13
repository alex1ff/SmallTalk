import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/shared_pages/chat_message_bubble_style.dart';
import 'package:small_talk/shared_pages/design/expatlio_design.dart';

void main() {
  double contrastRatio(Color foreground, Color background) {
    int channel(Color color, int shift) => (color.toARGB32() >> shift) & 0xFF;

    Color composite(Color foreground, Color background) {
      final alpha = channel(foreground, 24) / 255.0;
      int blend(int foregroundChannel, int backgroundChannel) {
        return (foregroundChannel * alpha + backgroundChannel * (1.0 - alpha))
            .round();
      }

      return Color.fromARGB(
        255,
        blend(channel(foreground, 16), channel(background, 16)),
        blend(channel(foreground, 8), channel(background, 8)),
        blend(channel(foreground, 0), channel(background, 0)),
      );
    }

    double linearize(int component) {
      final normalized = component / 255.0;
      if (normalized <= 0.04045) {
        return normalized / 12.92;
      }
      return math.pow((normalized + 0.055) / 1.055, 2.4).toDouble();
    }

    double luminance(Color color) {
      final r = linearize(channel(color, 16));
      final g = linearize(channel(color, 8));
      final b = linearize(channel(color, 0));
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    final foregroundLuminance = luminance(composite(foreground, background));
    final backgroundLuminance = luminance(background);
    final lighter = math.max(foregroundLuminance, backgroundLuminance);
    final darker = math.min(foregroundLuminance, backgroundLuminance);
    return (lighter + 0.05) / (darker + 0.05);
  }

  test('shared own-message bubble style is lavender and readable', () {
    final unreadReceiptColor =
        chatMessageReadReceiptColor(isReadByPartner: false);

    expect(
      chatMessageBubbleColor(isCurrentUser: true),
      const Color(0xFFEDE4FA),
    );
    expect(
      chatMessageBubbleColor(isCurrentUser: false),
      ExpatlioDesign.card,
    );
    expect(chatMessageTextColor(isDeleted: false), Colors.black);
    expect(
      unreadReceiptColor,
      ExpatlioDesign.primary.withValues(alpha: 0.72),
    );
    expect(
      contrastRatio(unreadReceiptColor, ExpatlioDesign.ownMessageBubble),
      greaterThan(3),
    );
    expect(
      chatMessageReadReceiptColor(isReadByPartner: true),
      ExpatlioDesign.primary.withValues(alpha: 0.88),
    );
  });

  test('all chat surfaces use the shared own-message bubble color', () {
    final designSource =
        File('lib/shared_pages/design/expatlio_design.dart').readAsStringSync();
    final chatThreadSource =
        File('lib/shared_pages/chat_thread/chat_thread_widget.dart')
            .readAsStringSync();
    final eventChatSource =
        File('lib/shared_pages/events/event_group_chat_widget.dart')
            .readAsStringSync();
    final inCallChatSource =
        File('lib/custom_code/widgets/minimal_daily_widget.dart')
            .readAsStringSync();

    expect(
      designSource,
      contains('static const Color ownMessageBubble = Color(0xFFEDE4FA);'),
    );
    expect(chatThreadSource, contains('chatMessageBubbleColor('));
    expect(eventChatSource, contains('chatMessageBubbleColor('));
    expect(inCallChatSource, contains('chatMessageBubbleColor('));
  });
}
