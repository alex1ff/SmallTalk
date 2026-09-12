import 'dart:convert' as dart_convert;

import 'caption_message_policy.dart' as caption_policy;

enum DeepgramMessageKind {
  ignored,
  invalidEnvelope,
  serviceError,
  utteranceEnd,
  finalizeCurrent,
  transcript,
}

class DeepgramMessage {
  const DeepgramMessage({
    required this.kind,
    this.transcript,
    this.isFinalSegment = false,
    this.speechFinal = false,
    this.confidence,
  });

  final DeepgramMessageKind kind;
  final String? transcript;
  final bool isFinalSegment;
  final bool speechFinal;
  final double? confidence;
}

/// Interprets one Deepgram frame without handling widget or stream lifecycle.
///
/// Malformed JSON and wrong raw input types intentionally propagate to the
/// widget's outer catch. Successfully decoded non-object envelopes are returned
/// as [DeepgramMessageKind.invalidEnvelope].
DeepgramMessage parseDeepgramMessage(dynamic rawMessage) {
  final decoded = dart_convert.jsonDecode(rawMessage);
  if (decoded is! Map<String, dynamic>) {
    return const DeepgramMessage(kind: DeepgramMessageKind.invalidEnvelope);
  }

  final type = decoded['type']?.toString();
  final normalizedType = type?.trim().toLowerCase();
  if (normalizedType == 'error' || decoded.containsKey('error')) {
    return const DeepgramMessage(kind: DeepgramMessageKind.serviceError);
  }
  if (type == 'UtteranceEnd') {
    return const DeepgramMessage(kind: DeepgramMessageKind.utteranceEnd);
  }

  final channel = decoded['channel'];
  final alternatives =
      channel is Map<String, dynamic> ? channel['alternatives'] : null;
  if (alternatives is! List || alternatives.isEmpty) {
    return const DeepgramMessage(kind: DeepgramMessageKind.ignored);
  }

  final firstAlternative = alternatives.first;
  if (firstAlternative is! Map) {
    return const DeepgramMessage(kind: DeepgramMessageKind.ignored);
  }

  final transcript = caption_policy.normalizeCaptionText(
    firstAlternative['transcript']?.toString() ?? '',
  );
  final isFinalSegment = decoded['is_final'] == true;
  final speechFinal =
      decoded['speech_final'] == true || decoded['speech_finalized'] == true;
  final confidence = _readDouble(firstAlternative['confidence']);

  if (transcript.isEmpty) {
    return DeepgramMessage(
      kind: speechFinal
          ? DeepgramMessageKind.finalizeCurrent
          : DeepgramMessageKind.ignored,
      transcript: transcript,
      isFinalSegment: isFinalSegment,
      speechFinal: speechFinal,
      confidence: confidence,
    );
  }

  return DeepgramMessage(
    kind: DeepgramMessageKind.transcript,
    transcript: transcript,
    isFinalSegment: isFinalSegment,
    speechFinal: speechFinal,
    confidence: confidence,
  );
}

double? _readDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}
