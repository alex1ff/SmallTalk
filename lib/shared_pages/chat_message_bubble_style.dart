import 'package:flutter/material.dart';

import '/shared_pages/design/expatlio_design.dart';

Color chatMessageBubbleColor({
  required bool isCurrentUser,
  bool isDeleted = false,
}) {
  if (isDeleted) {
    return ExpatlioDesign.secondarySystemBackground;
  }
  return isCurrentUser ? ExpatlioDesign.ownMessageBubble : ExpatlioDesign.card;
}

Color chatMessageTextColor({bool isDeleted = false}) {
  return isDeleted ? ExpatlioDesign.muted : ExpatlioDesign.text;
}

Color chatMessageSenderNameColor() => ExpatlioDesign.primary;

Color chatMessageReadReceiptColor({required bool isReadByPartner}) {
  return ExpatlioDesign.primary.withValues(
    alpha: isReadByPartner ? 0.88 : 0.72,
  );
}
