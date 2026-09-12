import 'dart:convert';

import 'package:crypto/crypto.dart';

String deterministicCallKitIdForTest(String sessionId) {
  final digestBytes =
      md5.convert(utf8.encode('smalltalk-call:$sessionId')).bytes.toList();
  digestBytes[6] = (digestBytes[6] & 0x0F) | 0x30;
  digestBytes[8] = (digestBytes[8] & 0x3F) | 0x80;
  final hex =
      digestBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  return '${hex.substring(0, 8)}-'
      '${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-'
      '${hex.substring(16, 20)}-'
      '${hex.substring(20, 32)}';
}
