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
    setUp(() {
      EventGroupChatRepository.resetRememberedInboxEventIdsForTesting();
    });

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

    test('builds stable chronological message query with document id tie break',
        () {
      final chatRef = EventChatsRecord.collection.doc('event-1');
      final query = EventGroupChatRepository.buildMessagesQuery(
        EventChatMessagesRecord.collection(chatRef),
      );

      expect(query.parameters['orderBy'], [
        [FieldPath.fromString('createdAt'), false],
        [FieldPath.documentId, false],
      ]);
      expect(query.parameters['limit'], isNull);
      expect(query.parameters['startAfter'], isNull);
    });

    test('builds latest message query for inbox preview', () {
      final chatRef = EventChatsRecord.collection.doc('event-1');
      final query = EventGroupChatRepository.buildLatestMessageQuery(
        EventChatMessagesRecord.collection(chatRef),
      );

      expect(query.parameters['orderBy'], [
        [FieldPath.fromString('createdAt'), true],
        [FieldPath.documentId, true],
      ]);
      expect(query.parameters['limit'], isNull);
    });

    test('builds inbox query from event chat read access', () {
      final query = EventGroupChatRepository.buildInboxChatsQuery(
        EventChatsRecord.collection,
        'uid-1',
      );
      final where = query.parameters['where'] as List<dynamic>;

      expect(where.toString(), contains('readAccessUserIds'));
      expect(where.toString(), contains('uid-1'));
      expect(where.toString(), contains('array-contains'));
    });

    test('loads inbox chats sorted by recency with event id fallback',
        () async {
      final older = EventChatsRecord.getDocumentFromData(
        {
          'eventId': 'event-old',
          'readAccessUserIds': <String>['uid-1'],
          'createdAt': DateTime.parse('2026-06-14T10:00:00Z'),
          'updatedAt': DateTime.parse('2026-06-14T10:00:00Z'),
        },
        EventChatsRecord.collection.doc('event-old'),
      );
      final newer = EventChatsRecord.getDocumentFromData(
        {
          'readAccessUserIds': <String>['uid-1'],
          'createdAt': DateTime.parse('2026-06-15T10:00:00Z'),
          'updatedAt': DateTime.parse('2026-06-15T10:00:00Z'),
        },
        EventChatsRecord.collection.doc('event-new'),
      );
      final invalid = EventChatsRecord.getDocumentFromData(
        {
          'eventId': ' ',
          'readAccessUserIds': <String>['uid-1'],
        },
        EventChatsRecord.collection.doc(' '),
      );

      final chats = await EventGroupChatRepository.watchInboxChats(
        currentUid: ' uid-1 ',
        chatsStream: () => Stream.value([older, newer, invalid]),
      ).first;

      expect(chats.map(EventGroupChatRepository.eventIdForChat), [
        'event-new',
        'event-old',
      ]);
    });

    test('loads inbox chat from accessible event id without list query',
        () async {
      final chat = EventChatsRecord.getDocumentFromData(
        {
          'eventId': 'event-1',
          'readAccessUserIds': <String>[],
          'createdAt': DateTime.parse('2026-06-14T10:00:00Z'),
          'updatedAt': DateTime.parse('2026-06-14T10:00:00Z'),
        },
        EventChatsRecord.collection.doc('event-1'),
      );
      final subscribedEventIds = <String>[];

      final chats = await EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () => Stream.value([' event-1 ']),
        chatByEventIdStream: (eventId) {
          subscribedEventIds.add(eventId);
          return Stream<EventChatsRecord?>.value(chat);
        },
      ).firstWhere((eventChats) => eventChats.isNotEmpty);

      expect(subscribedEventIds, ['event-1']);
      expect(chats, [chat]);
    });

    test('loads remembered inbox event chat without history event id',
        () async {
      final chat = EventChatsRecord.getDocumentFromData(
        {
          'eventId': 'event-remembered',
          'readAccessUserIds': <String>[],
          'createdAt': DateTime.parse('2026-06-14T10:00:00Z'),
          'updatedAt': DateTime.parse('2026-06-15T10:00:00Z'),
        },
        EventChatsRecord.collection.doc('event-remembered'),
      );
      final subscribedEventIds = <String>[];

      EventGroupChatRepository.rememberInboxEventId(' event-remembered ');

      final chats = await EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () => Stream.value(const <String>[]),
        chatByEventIdStream: (eventId) {
          subscribedEventIds.add(eventId);
          return Stream<EventChatsRecord?>.value(chat);
        },
      ).firstWhere((eventChats) => eventChats.isNotEmpty);

      expect(subscribedEventIds, ['event-remembered']);
      expect(chats, [chat]);
    });

    test('does not fail inbox when event id source fails', () async {
      final chats = await EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () => Stream<List<String>>.error(
          StateError('event history unavailable'),
        ),
        chatByEventIdStream: (_) => const Stream<EventChatsRecord?>.empty(),
      ).first;

      expect(chats, isEmpty);
    });

    test('uses document snapshot cursor after createdAt and document id order',
        () {
      final chatRef = EventChatsRecord.collection.doc('event-1');
      final markerCreatedAt = DateTime.parse('2026-06-14T10:00:00Z');
      final marker = _FakeDocumentSnapshot(
        reference: EventChatMessagesRecord.createDoc(
          chatRef,
          id: 'same-time-a',
        ),
        id: 'same-time-a',
        data: <Object, Object?>{
          FieldPath.fromString('createdAt'): markerCreatedAt,
          'createdAt': markerCreatedAt,
        },
      );

      final query = EventGroupChatRepository.buildMessagesQuery(
        EventChatMessagesRecord.collection(chatRef),
      ).startAfterDocument(marker);

      expect(query.parameters['orderBy'], [
        [FieldPath.fromString('createdAt'), false],
        [FieldPath.documentId, false],
      ]);
      expect(query.parameters['startAfter'], isNotNull);
      expect(query.parameters['startAfter'], contains('same-time-a'));
    });

    test('delegates paged message loading with stable order and cursor',
        () async {
      Query? capturedCollection;
      RecordBuilder<EventChatMessagesRecord>? capturedRecordBuilder;
      Query Function(Query)? capturedQueryBuilder;
      DocumentSnapshot? capturedNextPageMarker;
      int? capturedPageSize;
      bool? capturedIsStream;
      final marker = _FakeDocumentSnapshot(
        reference: EventChatMessagesRecord.createDoc(
          EventChatsRecord.collection.doc('event-1'),
          id: 'same-time-a',
        ),
      );

      final page = await EventGroupChatRepository.loadMessagesPage(
        eventId: ' event-1 ',
        pageSize: EventGroupChatRepository.maxMessageLimit + 1,
        nextPageMarker: marker,
        pageLoader: (
          collection,
          recordBuilder, {
          queryBuilder,
          nextPageMarker,
          required pageSize,
          required isStream,
        }) async {
          capturedCollection = collection;
          capturedRecordBuilder = recordBuilder;
          capturedQueryBuilder = queryBuilder;
          capturedNextPageMarker = nextPageMarker;
          capturedPageSize = pageSize;
          capturedIsStream = isStream;

          return FFFirestorePage<EventChatMessagesRecord>(
            const [],
            null,
            null,
          );
        },
      );

      expect(
        (capturedCollection as CollectionReference).path,
        'eventChats/event-1/messages',
      );
      expect(capturedRecordBuilder, isNotNull);
      expect(capturedQueryBuilder, isNotNull);
      expect(capturedNextPageMarker, same(marker));
      expect(capturedPageSize, EventGroupChatRepository.maxMessageLimit);
      expect(capturedIsStream, isFalse);
      expect(page.data, isEmpty);

      final delegatedQuery = capturedQueryBuilder!(
        EventChatMessagesRecord.collection(
          EventChatsRecord.collection.doc('event-1'),
        ),
      );
      expect(delegatedQuery.parameters['orderBy'], [
        [FieldPath.fromString('createdAt'), false],
        [FieldPath.documentId, false],
      ]);
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

// Test-only cursor token used to verify that the injected page loader receives
// the exact marker instance. It is never passed to the real Firestore SDK.
// ignore: subtype_of_sealed_class
class _FakeDocumentSnapshot implements DocumentSnapshot<Object?> {
  const _FakeDocumentSnapshot({
    required this.reference,
    this.id = 'cursor',
    Map<Object, Object?> data = const <Object, Object?>{},
  }) : _data = data;

  @override
  final String id;

  @override
  bool get exists => true;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  final DocumentReference<Object?> reference;

  final Map<Object, Object?> _data;

  @override
  Object? data() => _data;

  @override
  Object? get(Object field) {
    if (_data.containsKey(field)) {
      return _data[field];
    }
    if (field is FieldPath && field == FieldPath.documentId) {
      return id;
    }
    if (field is FieldPath) {
      return _data[field.toString()];
    }
    return _data[field];
  }

  @override
  Object? operator [](Object field) => get(field);
}
