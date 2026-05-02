import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('Chat message contract', () {
    test('conversationIsUnreadForUser ignores backend-authored call events',
        () {
      final conversation = ConversationsRecord.getDocumentFromData(
        {
          'pairId': 'student_teacher',
          'participantIds': <String>['student', 'teacher'],
          'participantRefs': <DocumentReference>[
            UsersRecord.collection.doc('student'),
            UsersRecord.collection.doc('teacher'),
          ],
          'isUnlocked': true,
          'lastMessageAt': DateTime.parse('2026-04-19T10:00:00Z'),
          'lastMessageType': kConversationMessageTypeCallEvent,
          'lastMessageText': 'Video call',
          'lastMessageSenderId': null,
          'lastMessageId': 'call_session-1',
          'lastCallOutcome': kConversationCallOutcomeCompleted,
          'lastCallCallerId': 'student',
          'lastCallRecipientId': 'teacher',
          'lastReadAtByUserId': <String, DateTime?>{
            'student': DateTime.parse('2026-04-19T09:00:00Z'),
          },
        },
        ConversationsRecord.collection.doc('student_teacher'),
      );

      expect(conversationIsUnreadForUser(conversation, 'student'), isFalse);
      expect(conversationIsUnreadForUser(conversation, 'teacher'), isFalse);
    });

    test(
        'conversationIsUnreadForUser preserves older unread text under call events',
        () {
      final conversation = ConversationsRecord.getDocumentFromData(
        {
          'pairId': 'student_teacher',
          'participantIds': <String>['student', 'teacher'],
          'participantRefs': <DocumentReference>[
            UsersRecord.collection.doc('student'),
            UsersRecord.collection.doc('teacher'),
          ],
          'isUnlocked': true,
          'lastMessageAt': DateTime.parse('2026-04-19T10:00:00Z'),
          'lastMessageType': kConversationMessageTypeCallEvent,
          'lastMessageText': 'Video call',
          'lastMessageSenderId': null,
          'lastMessageId': 'call_session-1',
          'lastCallOutcome': kConversationCallOutcomeCompleted,
          'lastCallCallerId': 'student',
          'lastCallRecipientId': 'teacher',
          'lastUnreadMessageAt': DateTime.parse('2026-04-19T09:59:00Z'),
          'lastUnreadMessageSenderId': 'teacher',
          'lastReadAtByUserId': <String, DateTime?>{
            'student': DateTime.parse('2026-04-19T09:58:00Z'),
            'teacher': DateTime.parse('2026-04-19T09:58:00Z'),
          },
        },
        ConversationsRecord.collection.doc('student_teacher'),
      );

      expect(conversationIsUnreadForUser(conversation, 'student'), isTrue);
      expect(conversationIsUnreadForUser(conversation, 'teacher'), isFalse);
    });

    test('conversationIsUnreadForUser still tracks text messages normally', () {
      final conversation = ConversationsRecord.getDocumentFromData(
        {
          'pairId': 'student_teacher',
          'participantIds': <String>['student', 'teacher'],
          'participantRefs': <DocumentReference>[
            UsersRecord.collection.doc('student'),
            UsersRecord.collection.doc('teacher'),
          ],
          'isUnlocked': true,
          'lastMessageAt': DateTime.parse('2026-04-19T10:00:00Z'),
          'lastMessageType': kConversationMessageTypeText,
          'lastMessageText': 'Hi there',
          'lastMessageSenderId': 'teacher',
          'lastMessageId': 'message-1',
          'lastReadAtByUserId': <String, DateTime?>{
            'student': DateTime.parse('2026-04-19T09:59:00Z'),
          },
        },
        ConversationsRecord.collection.doc('student_teacher'),
      );

      expect(conversationIsUnreadForUser(conversation, 'student'), isTrue);
      expect(conversationIsUnreadForUser(conversation, 'teacher'), isFalse);
    });

    test('MessagesRecord parses call-event optional payload fields', () {
      final conversationRef =
          ConversationsRecord.collection.doc('student_teacher');
      final messageRef =
          MessagesRecord.createDoc(conversationRef, id: 'call_session-1');
      final sessionRef = VideoSessionsRecord.collection.doc('session-1');

      final message = MessagesRecord.getDocumentFromData(
        {
          'type': kConversationMessageTypeCallEvent,
          'text': 'Video call',
          'sessionRef': sessionRef,
          'callKind': kConversationCallKindVideo,
          'callOutcome': kConversationCallOutcomeCompleted,
          'callerId': 'student',
          'recipientId': 'teacher',
          'callStartedAt': DateTime.parse('2026-04-19T09:00:00Z'),
          'callEndedAt': DateTime.parse('2026-04-19T09:12:30Z'),
          'callDurationSeconds': 750,
          'createdAt': DateTime.parse('2026-04-19T09:12:30Z'),
        },
        messageRef,
      );

      expect(messageIsCallEvent(message), isTrue);
      expect(message.sessionRef?.path, sessionRef.path);
      expect(message.callKind, kConversationCallKindVideo);
      expect(message.callOutcome, kConversationCallOutcomeCompleted);
      expect(message.callerId, 'student');
      expect(message.recipientId, 'teacher');
      expect(message.callDurationSeconds, 750);
      expect(message.callStartedAt, DateTime.parse('2026-04-19T09:00:00Z'));
      expect(message.callEndedAt, DateTime.parse('2026-04-19T09:12:30Z'));
    });
  });
}
