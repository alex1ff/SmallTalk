import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_group_chat_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('EventGroupChatRepository', () {
    test('normalizes event id and subscribes to chat metadata', () async {
      DocumentReference? capturedChatRef;
      final chat = EventChatsRecord.getDocumentFromData(
        {
          'eventId': 'event-1',
          'readAccessUserIds': <String>['uid-1'],
          'createdAt': DateTime.parse('2026-06-14T10:00:00Z'),
          'updatedAt': DateTime.parse('2026-06-14T10:00:00Z'),
        },
        EventChatsRecord.collection.doc('event-1'),
      );

      final chats = await EventGroupChatRepository.watchChatAccess(
        eventId: ' event-1 ',
        chatStream: (chatRef) {
          capturedChatRef = chatRef;
          return Stream<EventChatsRecord?>.value(chat);
        },
      ).toList();

      expect(capturedChatRef?.path, 'eventChats/event-1');
      expect(chats, hasLength(1));
      expect(chats.single?.reference.path, 'eventChats/event-1');
      expect(chats.single?.eventId, 'event-1');
    });

    test('rejects invalid chat event ids before subscribing', () {
      for (final eventId in <String>[
        '',
        ' ',
        '.',
        '..',
        'events/event-1',
        '__reserved__',
        'a' * 1501,
      ]) {
        var streamCalls = 0;

        expect(
          () => EventGroupChatRepository.watchChatAccess(
            eventId: eventId,
            chatStream: (_) {
              streamCalls += 1;
              return const Stream<EventChatsRecord?>.empty();
            },
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'Expected "$eventId" to be rejected.',
        );
        expect(streamCalls, 0);
      }
    });
  });
}
