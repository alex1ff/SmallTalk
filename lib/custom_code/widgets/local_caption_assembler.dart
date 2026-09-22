import 'dart:math' as math;

import 'caption_message_policy.dart' as caption_policy;

/// One immutable caption revision; transport, logging and closing stay external.
typedef LocalCaptionEmission = ({
  int utteranceId,
  int revision,
  String text,
  bool isFinal,
  DateTime startedAt,
  DateTime lastUpdateAt,
});

/// Builds local caption revisions without owning media, timers or persistence.
///
/// A final emission does not close the utterance. The caller dispatches and logs
/// it first, then explicitly calls [closeUtterance].
class LocalCaptionAssembler {
  LocalCaptionAssembler({DateTime Function()? now})
      : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  int _utteranceId = 0;
  int _revision = 0;
  bool _isOpen = false;
  String _committedText = '';
  String _currentText = '';
  DateTime? _startedAt;
  double? _confidence;

  int get utteranceId => _utteranceId;
  int get revision => _revision;
  bool get isOpen => _isOpen;
  String get currentText => _currentText;
  double? get confidence => _confidence;

  LocalCaptionEmission acceptTranscript({
    required String transcript,
    required bool isFinalSegment,
    required bool speechFinal,
    double? confidence,
  }) {
    _ensureUtteranceStarted();
    if (confidence != null && (isFinalSegment || speechFinal)) {
      _confidence = confidence;
    }
    if (isFinalSegment) {
      _committedText = _mergeCaptionSegments(_committedText, transcript);
    }

    final now = _now();
    final displayText = isFinalSegment
        ? _committedText
        : _mergeCaptionSegments(_committedText, transcript);
    _currentText = displayText;
    return (
      utteranceId: _utteranceId,
      revision: ++_revision,
      text: displayText,
      isFinal: speechFinal,
      startedAt: _startedAt ?? now,
      lastUpdateAt: now,
    );
  }

  /// Prepares the last interim phrase for final dispatch, leaving it open.
  /// Repeated preparation before closing intentionally creates a new revision.
  LocalCaptionEmission? prepareFinalUpdate() {
    final finalText = caption_policy.normalizeCaptionText(_currentText);
    if (!_isOpen || finalText.isEmpty) return null;

    final now = _now();
    return (
      utteranceId: _utteranceId,
      revision: ++_revision,
      text: finalText,
      isFinal: true,
      startedAt: _startedAt ?? now,
      lastUpdateAt: now,
    );
  }

  void closeUtterance(String fallbackText) {
    final finalText = caption_policy.normalizeCaptionText(fallbackText);
    if (finalText.isEmpty) return;
    _isOpen = false;
    _committedText = '';
    _currentText = finalText;
  }

  /// Clears recognition state, retaining the ID so peers can order new phrases.
  void clear() {
    _isOpen = false;
    _committedText = '';
    _currentText = '';
    _confidence = null;
    _revision = 0;
    _startedAt = null;
  }

  void _ensureUtteranceStarted() {
    if (_isOpen) return;
    _isOpen = true;
    _utteranceId += 1;
    _revision = 0;
    _committedText = '';
    _currentText = '';
    _startedAt = _now();
    _confidence = null;
  }

  String _mergeCaptionSegments(String committed, String segment) {
    final normalizedCommitted = caption_policy.normalizeCaptionText(committed);
    final normalizedSegment = caption_policy.normalizeCaptionText(segment);
    if (normalizedCommitted.isEmpty) return normalizedSegment;
    if (normalizedSegment.isEmpty) return normalizedCommitted;
    if (normalizedSegment.startsWith(normalizedCommitted)) {
      return normalizedSegment;
    }
    if (normalizedCommitted.endsWith(normalizedSegment)) {
      return normalizedCommitted;
    }

    final committedWords = normalizedCommitted.split(' ');
    final segmentWords = normalizedSegment.split(' ');
    final maxOverlap = math.min(committedWords.length, segmentWords.length);

    for (var overlap = maxOverlap; overlap > 0; overlap--) {
      final committedSuffix =
          committedWords.sublist(committedWords.length - overlap);
      final segmentPrefix = segmentWords.sublist(0, overlap);
      if (_wordListsEqual(committedSuffix, segmentPrefix)) {
        return <String>[
          ...committedWords,
          ...segmentWords.sublist(overlap),
        ].join(' ');
      }
    }

    return '$normalizedCommitted $normalizedSegment';
  }

  bool _wordListsEqual(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }

    for (var i = 0; i < left.length; i++) {
      if (left[i].toLowerCase() != right[i].toLowerCase()) {
        return false;
      }
    }
    return true;
  }
}
