/// Pure normalization and selection rules for Daily join data and Deepgram auth.
/// Network refresh, cached credentials and call lifecycle remain in the widget.

bool isValidRoomUrl(String url) {
  if (url.isEmpty || url == '0' || url == 'null') return false;
  try {
    final uri = Uri.tryParse(url);
    return uri != null && uri.hasScheme && uri.hasAuthority;
  } catch (_) {
    return false;
  }
}

String? sanitizeRoomUrl(String? url) {
  if (url == null) return null;
  final trimmed = url.trim();
  return isValidRoomUrl(trimmed) ? trimmed : null;
}

String? sanitizeMeetingToken(String? token) => _sanitizeCredential(token);

String? effectiveMeetingToken({
  String? dynamicToken,
  String? configuredToken,
}) {
  // Select before normalizing: an explicitly invalid override must not silently
  // revive the configured token.
  return sanitizeMeetingToken(dynamicToken ?? configuredToken);
}

String? effectiveRoomUrl({
  String? dynamicRoomUrl,
  required String configuredRoomUrl,
}) {
  // Unlike tokens, an invalid URL override falls back to the configured URL.
  return sanitizeRoomUrl(dynamicRoomUrl) ?? sanitizeRoomUrl(configuredRoomUrl);
}

String? configuredDeepgramCredential({
  String? primaryCredential,
  String? legacyApiKey,
}) {
  // The deprecated key is a fallback for absence, not for invalid primary data.
  return sanitizeDeepgramCredential(primaryCredential ?? legacyApiKey);
}

String? sanitizeDeepgramCredential(String? value) => _sanitizeCredential(value);

String? _sanitizeCredential(String? value) {
  if (value == null) return null;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final lowered = trimmed.toLowerCase();
  if (lowered == 'null' ||
      lowered == 'undefined' ||
      lowered == 'false' ||
      lowered == '0' ||
      lowered == 'none') {
    return null;
  }
  return trimmed;
}

/// A header-selection heuristic only, not JWT parsing or signature validation.
bool looksLikeJwt(String value) {
  final parts = value.split('.');
  return parts.length == 3 &&
      parts[0].isNotEmpty &&
      parts[1].isNotEmpty &&
      parts[2].isNotEmpty;
}

/// Callers supply a credential already accepted by [sanitizeDeepgramCredential].
String buildDeepgramAuthHeader(String credential) {
  final sanitized = credential.trim();
  final lowered = sanitized.toLowerCase();
  if (lowered.startsWith('token ') || lowered.startsWith('bearer ')) {
    return sanitized;
  }
  return looksLikeJwt(sanitized) ? 'Bearer $sanitized' : 'Token $sanitized';
}
