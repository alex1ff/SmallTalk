import 'dart:convert' as dart_convert;

/// Decodes a Daily app-message payload, including one double-encoded layer.
///
/// Format and map-conversion errors deliberately propagate so the widget's
/// existing transport-level catch remains the single error boundary.
Map<String, dynamic>? decodeDailyAppMessagePayload(String rawMessage) {
  dynamic payload = rawMessage;

  for (var i = 0; i < 2; i++) {
    if (payload is String) {
      final trimmed = payload.trim();
      if (trimmed.isEmpty) return null;
      payload = dart_convert.jsonDecode(trimmed);
      continue;
    }
    break;
  }

  if (payload is Map) {
    return Map<String, dynamic>.from(payload);
  }

  return null;
}
