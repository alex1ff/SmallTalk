import 'dart:math' as math;

/// Current visible remote caption; media/UI timestamps are intentionally absent.
typedef RemoteCaptionSnapshot = ({
  int utteranceId,
  int revision,
  String text,
  bool isFinal,
  bool isFadingOut,
});

/// Accepted text update plus the existing legacy-only persistence decision.
typedef RemoteCaptionUpdate = ({
  int utteranceId,
  int revision,
  String text,
  bool isFinal,
  bool shouldLogLegacyFinal,
});

/// A counter patch can exist even when the visible update is rejected.
typedef RemoteCaptionDecision = ({
  int? legacyCounterUpdate,
  RemoteCaptionUpdate? update,
});

String normalizeCaptionText(String rawText) {
  return rawText.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Resolves one peer message without owning participant state, timers or I/O.
///
/// Apply the `legacyCounterUpdate` patch before checking whether
/// there is an accepted update: rejected numeric messages can advance the counter.
RemoteCaptionDecision resolveRemoteCaptionMessage(
  Map<String, dynamic> payload, {
  RemoteCaptionSnapshot? current,
  int legacyCounter = 0,
}) {
  final text = normalizeCaptionText(payload['text']?.toString() ?? '');
  final rawUtteranceId = _readInt(payload['utteranceId']);
  final rawRevision = _readInt(payload['revision']);
  // Old clients and unknown phases default to final; only interim opts out.
  final isFinal =
      (payload['phase']?.toString() ?? '').trim().toLowerCase() != 'interim';
  if (text.isEmpty) return (legacyCounterUpdate: null, update: null);

  int utteranceId;
  int revision;
  int? counterUpdate;
  if (rawUtteranceId == null || rawRevision == null) {
    if (current != null &&
        current.isFinal &&
        current.text == text &&
        !current.isFadingOut) {
      return (legacyCounterUpdate: null, update: null);
    }
    utteranceId = math.max(legacyCounter + 1, (current?.utteranceId ?? 0) + 1);
    revision = 1;
    counterUpdate = utteranceId;
  } else {
    utteranceId = rawUtteranceId;
    revision = rawRevision;
    if (utteranceId > legacyCounter) counterUpdate = utteranceId;
  }

  if (current != null) {
    if (utteranceId < current.utteranceId ||
        (utteranceId == current.utteranceId && revision <= current.revision)) {
      return (legacyCounterUpdate: counterUpdate, update: null);
    }
    if (utteranceId == current.utteranceId && current.isFinal && !isFinal) {
      return (legacyCounterUpdate: counterUpdate, update: null);
    }
  }

  return (
    legacyCounterUpdate: counterUpdate,
    update: (
      utteranceId: utteranceId,
      revision: revision,
      text: text,
      isFinal: isFinal,
      // A partially populated numeric pair uses legacy numbering, but only
      // fully legacy final messages are logged on behalf of the remote peer.
      shouldLogLegacyFinal:
          rawUtteranceId == null && rawRevision == null && isFinal,
    ),
  );
}

int? _readInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim());
  return null;
}
