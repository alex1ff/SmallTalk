import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'translation_repository.dart' show callIntegrationsRegion;

typedef CallFeedbackCallableInvoker = Future<Object?> Function(
  String functionName,
  Map<String, dynamic> payload,
);

enum CallFeedbackStatus {
  pending,
  ready,
  insufficientText,
  retryableFailure,
  terminalFailure,
}

class CallFeedbackCorrection {
  const CallFeedbackCorrection({
    required this.original,
    required this.better,
    required this.explanation,
  });

  final String original;
  final String better;
  final String explanation;
}

class CallFeedbackVocabularyItem {
  const CallFeedbackVocabularyItem({
    required this.term,
    required this.translation,
    required this.example,
  });

  final String term;
  final String translation;
  final String example;
}

class CallFeedbackResult {
  const CallFeedbackResult({
    required this.summary,
    required this.score,
    required this.strengths,
    required this.corrections,
    required this.vocabulary,
    required this.nextPractice,
  });

  final String summary;
  final int score;
  final List<String> strengths;
  final List<CallFeedbackCorrection> corrections;
  final List<CallFeedbackVocabularyItem> vocabulary;
  final String nextPractice;
}

class CallFeedbackResponse {
  const CallFeedbackResponse({
    required this.status,
    this.feedback,
    this.retryAfterMs,
    this.errorCode,
  });

  final CallFeedbackStatus status;
  final CallFeedbackResult? feedback;
  final int? retryAfterMs;
  final String? errorCode;

  bool get isFinal =>
      status == CallFeedbackStatus.ready ||
      status == CallFeedbackStatus.insufficientText ||
      status == CallFeedbackStatus.terminalFailure;
}

class CallFeedbackFailure implements Exception {
  const CallFeedbackFailure({required this.code, this.retryAfterMs});

  final String code;
  final int? retryAfterMs;

  bool get isRetryable => const <String>{
        'feedback_retry_later',
        'feedback_generation_failed',
      }.contains(code);

  @override
  String toString() => 'CallFeedbackFailure($code)';
}

class CallFeedbackRepository {
  const CallFeedbackRepository({this.invoker});

  final CallFeedbackCallableInvoker? invoker;

  Future<CallFeedbackResponse> generate({
    required String sessionId,
    required String outputLocale,
  }) async {
    try {
      final response = await _invoke('generateCallFeedback', <String, dynamic>{
        'sessionId': sessionId,
        'outputLocale': outputLocale,
      });
      return parseCallFeedbackResponse(response);
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      final detailsMap = details is Map ? details : const <Object?, Object?>{};
      final domainCode = detailsMap['domainCode'];
      final retryAfterMs = detailsMap['retryAfterMs'];
      throw CallFeedbackFailure(
        code: domainCode is String && domainCode.trim().isNotEmpty
            ? domainCode
            : error.code,
        retryAfterMs: retryAfterMs is num ? retryAfterMs.toInt() : null,
      );
    }
  }

  Stream<CallFeedbackResponse?> watch({
    required DocumentReference sessionRef,
    required String userId,
  }) {
    return sessionRef
        .collection('aiFeedback')
        .doc(userId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;
      return parseStoredCallFeedback(snapshot.data());
    });
  }

  Future<Object?> _invoke(
    String functionName,
    Map<String, dynamic> payload,
  ) async {
    final customInvoker = invoker;
    if (customInvoker != null) return customInvoker(functionName, payload);
    final callable =
        FirebaseFunctions.instanceFor(region: callIntegrationsRegion)
            .httpsCallable(functionName);
    final response = await callable.call<Object?>(payload);
    return response.data;
  }
}

CallFeedbackResponse parseCallFeedbackResponse(Object? rawValue) {
  final data = _map(rawValue, 'feedback response');
  final status = _string(data, 'status');
  switch (status) {
    case 'pending':
      return CallFeedbackResponse(
        status: CallFeedbackStatus.pending,
        retryAfterMs: _optionalInt(data, 'retryAfterMs') ?? 15000,
      );
    case 'ready':
      return CallFeedbackResponse(
        status: CallFeedbackStatus.ready,
        feedback: _feedbackResult(data['feedback']),
      );
    case 'insufficient_text':
      return const CallFeedbackResponse(
        status: CallFeedbackStatus.insufficientText,
      );
    case 'failed_terminal':
      return CallFeedbackResponse(
        status: CallFeedbackStatus.terminalFailure,
        errorCode: _optionalString(data, 'errorCode'),
      );
    default:
      throw FormatException('Unsupported feedback status "$status".');
  }
}

CallFeedbackResponse parseStoredCallFeedback(Object? rawValue) {
  final data = _map(rawValue, 'stored feedback');
  final status = _string(data, 'status');
  switch (status) {
    case 'ready':
      return CallFeedbackResponse(
        status: CallFeedbackStatus.ready,
        feedback: _feedbackResult(data['result']),
      );
    case 'insufficient_text':
      return const CallFeedbackResponse(
        status: CallFeedbackStatus.insufficientText,
      );
    case 'failed_terminal':
      return CallFeedbackResponse(
        status: CallFeedbackStatus.terminalFailure,
        errorCode: _optionalString(data, 'errorCode'),
      );
    case 'failed':
      return CallFeedbackResponse(
        status: CallFeedbackStatus.retryableFailure,
        retryAfterMs: _remainingMilliseconds(data['retryAt']),
        errorCode: _optionalString(data, 'errorCode'),
      );
    case 'pending':
      return CallFeedbackResponse(
        status: CallFeedbackStatus.pending,
        retryAfterMs: _remainingMilliseconds(data['leaseExpiresAt']),
      );
    default:
      throw FormatException('Unsupported stored feedback status "$status".');
  }
}

CallFeedbackResult _feedbackResult(Object? rawValue) {
  final data = _map(rawValue, 'feedback result');
  return CallFeedbackResult(
    summary: _string(data, 'summary'),
    score: _int(data, 'score'),
    strengths: _list(data, 'strengths')
        .map((value) => _nonEmptyString(value, 'strength'))
        .toList(growable: false),
    corrections: _list(data, 'corrections').map((value) {
      final correction = _map(value, 'correction');
      return CallFeedbackCorrection(
        original: _string(correction, 'original'),
        better: _string(correction, 'better'),
        explanation: _string(correction, 'explanation'),
      );
    }).toList(growable: false),
    vocabulary: _list(data, 'vocabulary').map((value) {
      final vocabulary = _map(value, 'vocabulary');
      return CallFeedbackVocabularyItem(
        term: _string(vocabulary, 'term'),
        translation: _string(vocabulary, 'translation'),
        example: _string(vocabulary, 'example'),
      );
    }).toList(growable: false),
    nextPractice: _string(data, 'nextPractice'),
  );
}

Map<String, dynamic> _map(Object? value, String field) {
  if (value is! Map) throw FormatException('Expected $field map.');
  return Map<String, dynamic>.from(value);
}

List<Object?> _list(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is List) return value.cast<Object?>();
  throw FormatException('Expected list field "$field".');
}

String _string(Map<String, dynamic> data, String field) =>
    _nonEmptyString(data[field], field);

String _nonEmptyString(Object? value, String field) {
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Expected non-empty string field "$field".');
}

String? _optionalString(Map<String, dynamic> data, String field) {
  final value = data[field];
  return value is String && value.trim().isNotEmpty ? value : null;
}

int _int(Map<String, dynamic> data, String field) {
  final value = data[field];
  if (value is int) return value;
  throw FormatException('Expected int field "$field".');
}

int? _optionalInt(Map<String, dynamic> data, String field) {
  final value = data[field];
  return value is num ? value.toInt() : null;
}

int _remainingMilliseconds(Object? value) {
  final DateTime? instant;
  if (value is Timestamp) {
    instant = value.toDate();
  } else if (value is DateTime) {
    instant = value;
  } else {
    instant = null;
  }
  if (instant == null) return 15000;
  final remaining = instant.difference(DateTime.now()).inMilliseconds;
  return remaining < 1000 ? 1000 : remaining;
}
