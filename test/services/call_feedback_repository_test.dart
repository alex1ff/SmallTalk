import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/call_feedback_repository.dart';

Map<String, dynamic> feedbackResult() => <String, dynamic>{
      'summary': 'Good control.',
      'score': 82,
      'strengths': <String>['Clear structure.'],
      'corrections': <Map<String, dynamic>>[
        <String, dynamic>{
          'original': 'I go yesterday.',
          'better': 'I went yesterday.',
          'explanation': 'Use the past form.',
        },
      ],
      'vocabulary': <Map<String, dynamic>>[
        <String, dynamic>{
          'term': 'confident',
          'translation': 'уверенный',
          'example': 'She sounded confident.',
        },
      ],
      'nextPractice': 'Retell yesterday using past tense.',
    };

void main() {
  test('generate sends the session and locale and decodes ready feedback',
      () async {
    String? calledFunction;
    Map<String, dynamic>? calledPayload;
    final repository = CallFeedbackRepository(
      invoker: (functionName, payload) async {
        calledFunction = functionName;
        calledPayload = payload;
        return <String, dynamic>{
          'status': 'ready',
          'feedback': feedbackResult(),
        };
      },
    );

    final response = await repository.generate(
      sessionId: 'session-a',
      outputLocale: 'ru',
    );

    expect(calledFunction, 'generateCallFeedback');
    expect(calledPayload, <String, dynamic>{
      'sessionId': 'session-a',
      'outputLocale': 'ru',
    });
    expect(response.status, CallFeedbackStatus.ready);
    expect(response.feedback?.score, 82);
    expect(response.feedback?.corrections.single.better, 'I went yesterday.');
  });

  test('pending, insufficient and terminal callable states are decoded', () {
    expect(
      parseCallFeedbackResponse(<String, dynamic>{
        'status': 'pending',
        'retryAfterMs': 1234,
      }).retryAfterMs,
      1234,
    );
    expect(
      parseCallFeedbackResponse(<String, dynamic>{
        'status': 'insufficient_text',
      }).status,
      CallFeedbackStatus.insufficientText,
    );
    expect(
      parseCallFeedbackResponse(<String, dynamic>{
        'status': 'failed_terminal',
        'errorCode': 'feedback_generation_failed',
      }).status,
      CallFeedbackStatus.terminalFailure,
    );
  });

  test('stored ready, failed and pending documents are decoded', () {
    final ready = parseStoredCallFeedback(<String, dynamic>{
      'status': 'ready',
      'result': feedbackResult(),
    });
    final failed = parseStoredCallFeedback(<String, dynamic>{
      'status': 'failed',
      'errorCode': 'feedback_generation_failed',
      'retryAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: 2)),
      ),
    });
    final pending = parseStoredCallFeedback(<String, dynamic>{
      'status': 'pending',
      'leaseExpiresAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(seconds: 2)),
      ),
    });

    expect(ready.feedback?.summary, 'Good control.');
    expect(failed.status, CallFeedbackStatus.retryableFailure);
    expect(failed.retryAfterMs, greaterThanOrEqualTo(1000));
    expect(pending.status, CallFeedbackStatus.pending);
    expect(pending.retryAfterMs, greaterThanOrEqualTo(1000));
  });

  test('malformed structured feedback is rejected', () {
    expect(
      () => parseCallFeedbackResponse(<String, dynamic>{
        'status': 'ready',
        'feedback': <String, dynamic>{'score': 82},
      }),
      throwsFormatException,
    );
  });
}
