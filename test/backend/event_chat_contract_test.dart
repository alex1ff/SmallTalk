import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('EventChatsRecord', () {
    test('parses event chat metadata contract', () {
      final createdAt = DateTime.parse('2026-06-14T10:00:00Z');
      final updatedAt = DateTime.parse('2026-06-15T11:30:00Z');
      final chat = EventChatsRecord.getDocumentFromData(
        {
          'eventId': 'event-1',
          'readAccessUserIds': <String>['organizer', 'uid-1'],
          'createdAt': createdAt,
          'updatedAt': updatedAt,
        },
        EventChatsRecord.collection.doc('event-1'),
      );

      expect(EventChatsRecord.collection.path, 'eventChats');
      expect(chat.reference.path, 'eventChats/event-1');
      expect(chat.eventId, 'event-1');
      expect(chat.readAccessUserIds, <String>['organizer', 'uid-1']);
      expect(chat.createdAt, createdAt);
      expect(chat.updatedAt, updatedAt);
    });
  });

  group('EventChatMessagesRecord', () {
    test('parses event chat message contract with nullable fields', () {
      final createdAt = DateTime.parse('2026-06-14T10:00:00Z');
      final chatRef = EventChatsRecord.collection.doc('event-1');
      final messageRef = EventChatMessagesRecord.createDoc(
        chatRef,
        id: 'message-1',
      );

      final message = EventChatMessagesRecord.getDocumentFromData(
        {
          'senderId': 'uid-1',
          'senderDisplayName': 'Marco',
          'senderPhotoUrl': null,
          'text': 'Всем привет!',
          'createdAt': createdAt,
          'deletedAt': null,
        },
        messageRef,
      );

      expect(message.reference.path, 'eventChats/event-1/messages/message-1');
      expect(message.parentReference.path, 'eventChats/event-1');
      expect(message.senderId, 'uid-1');
      expect(message.senderDisplayName, 'Marco');
      expect(message.senderPhotoUrl, '');
      expect(message.hasSenderPhotoUrl(), isFalse);
      expect(message.text, 'Всем привет!');
      expect(message.createdAt, createdAt);
      expect(message.deletedAt, isNull);
      expect(message.hasDeletedAt(), isFalse);
    });

    test('parses tombstoned event chat message', () {
      final createdAt = DateTime.parse('2026-06-14T10:00:00Z');
      final deletedAt = DateTime.parse('2026-06-15T11:30:00Z');
      final message = EventChatMessagesRecord.getDocumentFromData(
        {
          'senderId': 'uid-2',
          'senderDisplayName': 'Olga',
          'senderPhotoUrl': 'https://example.com/avatar.jpg',
          'text': 'Message removed',
          'createdAt': createdAt,
          'deletedAt': deletedAt,
        },
        EventChatMessagesRecord.createDoc(
          EventChatsRecord.collection.doc('event-1'),
          id: 'message-2',
        ),
      );

      expect(message.senderId, 'uid-2');
      expect(message.senderPhotoUrl, 'https://example.com/avatar.jpg');
      expect(message.deletedAt, deletedAt);
      expect(message.hasDeletedAt(), isTrue);
    });

    test('requires event chat parent for message collection', () {
      final chatRef = EventChatsRecord.collection.doc('event-1');
      final collection = EventChatMessagesRecord.collection(chatRef);

      expect(collection.path, 'eventChats/event-1/messages');
    });
  });
}
