typedef OutgoingCaptionBufferItem<T> = ({T value, String signature});

/// Stores the latest unsent caption and the last successfully sent signature.
///
/// Sending, throttling and overlap policy intentionally remain with the caller.
class OutgoingCaptionBuffer<T> {
  OutgoingCaptionBufferItem<T>? _pending;
  String? _lastSentSignature;

  void enqueue(T value, String signature) {
    _pending = (value: value, signature: signature);
  }

  OutgoingCaptionBufferItem<T>? takePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  bool isDuplicate(String signature) => signature == _lastSentSignature;

  void markSent(String signature) {
    _lastSentSignature = signature;
  }

  void clear() {
    _pending = null;
    _lastSentSignature = null;
  }
}
