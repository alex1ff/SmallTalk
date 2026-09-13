import 'dart:async';

import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_group_chat_repository.dart';
import 'package:small_talk/services/ux_session_cache_lifecycle.dart';

EventInboxEventIdsLoadState _eventIdsState(
  String ownerUid,
  Iterable<String> eventIds, {
  bool isReady = true,
  bool isAuthoritative = true,
}) =>
    EventInboxEventIdsLoadState(
      ownerUid: ownerUid,
      eventIds: eventIds,
      isReady: isReady,
      isAuthoritative: isAuthoritative,
    );

const Object _defaultCreatedAt = Object();

EventParticipantsRecord _participantRecord({
  String? photoUrl = 'https://image.test/a',
  String eventId = 'event-1',
  String documentId = 'uid-1',
  String userId = 'uid-1',
  String role = 'participant',
  String status = 'active',
  DateTime? leftAt,
}) =>
    EventParticipantsRecord.getDocumentFromData(
      <String, dynamic>{
        'userId': userId,
        'displayName': 'Trusted Name',
        'photoUrl': photoUrl,
        'role': role,
        'status': status,
        'joinedAt': DateTime.utc(2026, 1, 1),
        'leftAt': leftAt,
        'createdAt': DateTime.utc(2026, 1, 1),
        'updatedAt': DateTime.utc(2026, 1, 1),
      },
      EventParticipantsRecord.createDoc(
        EventsRecord.collection.doc(eventId),
        id: documentId,
      ),
    );

Map<String, dynamic> _messageData({
  String senderId = 'uid-1',
  String senderDisplayName = 'Trusted Name',
  String? senderPhotoUrl,
  String text = 'hello',
  Object? createdAt = _defaultCreatedAt,
  Object? deletedAt,
}) =>
    <String, dynamic>{
      'senderId': senderId,
      'senderDisplayName': senderDisplayName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'createdAt': identical(createdAt, _defaultCreatedAt)
          ? DateTime.utc(2026, 1, 1)
          : createdAt,
      'deletedAt': deletedAt,
    };

EventChatMessagesRecord _messageRecord({required String messageId}) =>
    EventChatMessagesRecord.getDocumentFromData(
      _messageData(),
      EventChatMessagesRecord.createDoc(
        EventChatsRecord.collection.doc('event-1'),
        id: messageId,
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('EventGroupChatRepository', () {
    setUp(() {
      UxSessionCacheLifecycle.debugResetForTesting();
      EventGroupChatRepository.resetRememberedInboxEventIdsForTesting();
    });

    tearDown(() {
      EventGroupChatRepository.resetRememberedInboxEventIdsForTesting();
      UxSessionCacheLifecycle.debugResetForTesting();
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

      final states = await EventGroupChatRepository.watchChatAccessState(
        eventId: ' event-1 ',
        ownerUid: 'uid-1',
        chatStream: (chatRef) {
          capturedChatRef = chatRef;
          return Stream<EventChatsRecord?>.value(chat);
        },
      ).toList();

      expect(capturedChatRef?.path, 'eventChats/event-1');
      expect(states, hasLength(1));
      expect(states.single.chat?.reference.path, 'eventChats/event-1');
      expect(states.single.chat?.eventId, 'event-1');
      expect(states.single.isAuthoritative, isTrue);
      expect(states.single.accessGranted, isTrue);
    });

    test('access metadata requires server confirmation for the owner', () {
      final chat = EventChatsRecord.getDocumentFromData(
        <String, dynamic>{
          'eventId': 'event-1',
          'readAccessUserIds': <String>['uid-1'],
        },
        EventChatsRecord.collection.doc('event-1'),
      );

      final cached = resolveEventChatAccessSnapshot(
        ownerUid: 'uid-1',
        chat: chat,
        isFromCache: true,
        hasPendingWrites: false,
      );
      final pending = resolveEventChatAccessSnapshot(
        ownerUid: 'uid-1',
        chat: chat,
        isFromCache: false,
        hasPendingWrites: true,
      );
      final confirmed = resolveEventChatAccessSnapshot(
        ownerUid: 'uid-1',
        chat: chat,
        isFromCache: false,
        hasPendingWrites: false,
      );
      final denied = resolveEventChatAccessSnapshot(
        ownerUid: 'uid-2',
        chat: chat,
        isFromCache: false,
        hasPendingWrites: false,
      );

      expect(cached.accessGranted, isTrue);
      expect(cached.isAuthoritative, isFalse);
      expect(pending.isAuthoritative, isFalse);
      expect(confirmed.accessGranted, isTrue);
      expect(confirmed.isAuthoritative, isTrue);
      expect(denied.accessGranted, isFalse);
      expect(denied.isAuthoritative, isTrue);
    });

    test('message metadata distinguishes transient and confirmed empty', () {
      final cachedEmpty = resolveEventChatMessagesSnapshot(
        ownerUid: 'uid-1',
        messages: const <EventChatMessagesRecord>[],
        isFromCache: true,
        hasPendingWrites: false,
      );
      final pendingEmpty = resolveEventChatMessagesSnapshot(
        ownerUid: 'uid-1',
        messages: const <EventChatMessagesRecord>[],
        isFromCache: false,
        hasPendingWrites: true,
      );
      final serverEmpty = resolveEventChatMessagesSnapshot(
        ownerUid: 'uid-1',
        messages: const <EventChatMessagesRecord>[],
        isFromCache: false,
        hasPendingWrites: false,
      );

      expect(cachedEmpty.canResolveEmpty, isFalse);
      expect(pendingEmpty.canResolveEmpty, isFalse);
      expect(serverEmpty.canResolveEmpty, isTrue);
      expect(serverEmpty.isAuthoritative, isTrue);
    });

    test('canonicalizes event chat text in callable order', () {
      expect(
        canonicalizeEventChatMessageText(
          '  Cafe\u0301\r\n\r\n\r\nnext\rline  ',
        ),
        'Caf\u00e9\n\nnext\nline',
      );

      expect(
        () => canonicalizeEventChatMessageText(' \r\n\n '),
        throwsA(
          isA<EventChatMessageTextValidationException>().having(
            (error) => error.reason,
            'reason',
            EventChatMessageTextErrorReason.empty,
          ),
        ),
      );
    });

    test('counts message limits by grapheme clusters', () {
      const family = '👩‍👩‍👧‍👧';
      final accepted = List<String>.filled(1000, family).join();
      final rejected = '$accepted$family';

      expect(canonicalizeEventChatMessageText(accepted), accepted);
      expect(
        () => canonicalizeEventChatMessageText(rejected),
        throwsA(
          isA<EventChatMessageTextValidationException>().having(
            (error) => error.reason,
            'reason',
            EventChatMessageTextErrorReason.tooLong,
          ),
        ),
      );
    });

    test('loads own participant in the exact owner and event scope', () async {
      final participant = _participantRecord();
      DocumentReference? subscribedReference;
      String? subscribedOwner;
      String? subscribedEvent;
      final expectedState = resolveEventChatParticipantSnapshot(
        eventId: 'event-1',
        ownerUid: 'uid-1',
        participant: participant,
        rawData: participant.snapshotData,
        isFromCache: false,
        hasPendingWrites: false,
      );

      final state = await EventGroupChatRepository.watchOwnParticipantState(
        eventId: ' event-1 ',
        ownerUid: 'uid-1',
        participantStateStream: (reference, ownerUid, eventId) {
          subscribedReference = reference;
          subscribedOwner = ownerUid;
          subscribedEvent = eventId;
          return Stream<EventChatParticipantLoadState>.value(expectedState);
        },
      ).single;

      expect(subscribedReference?.path, 'events/event-1/participants/uid-1');
      expect(subscribedOwner, 'uid-1');
      expect(subscribedEvent, 'event-1');
      expect(state.isAuthoritative, isTrue);
      expect(state.isActive, isTrue);
      expect(state.directSenderSnapshot?.senderId, 'uid-1');
      expect(state.directSenderSnapshot?.displayName, 'Trusted Name');
      expect(state.directSenderSnapshot?.photoUrl, 'https://image.test/a');
    });

    test('participant sender snapshot preserves missing and null photo', () {
      final participant = _participantRecord(photoUrl: null);
      final missingPhoto = resolveEventChatParticipantSnapshot(
        eventId: 'event-1',
        ownerUid: 'uid-1',
        participant: participant,
        rawData: <String, dynamic>{
          ...participant.snapshotData,
        }..remove('photoUrl'),
        isFromCache: false,
        hasPendingWrites: false,
      );
      final nullPhoto = resolveEventChatParticipantSnapshot(
        eventId: 'event-1',
        ownerUid: 'uid-1',
        participant: participant,
        rawData: <String, dynamic>{
          ...participant.snapshotData,
          'photoUrl': null,
        },
        isFromCache: false,
        hasPendingWrites: false,
      );

      expect(missingPhoto.hasPhotoUrlField, isFalse);
      expect(missingPhoto.directSenderSnapshot?.photoUrl, isNull);
      expect(nullPhoto.hasPhotoUrlField, isTrue);
      expect(nullPhoto.directSenderSnapshot?.photoUrl, isNull);
    });

    test('foreign, left, and invalid-role participants cannot send directly',
        () {
      final blockedParticipants = <EventParticipantsRecord>[
        _participantRecord(eventId: 'event-2'),
        _participantRecord(userId: 'uid-2'),
        _participantRecord(
          status: 'left',
          leftAt: DateTime.utc(2026, 2, 1),
        ),
        _participantRecord(role: 'admin'),
      ];

      for (final participant in blockedParticipants) {
        final state = resolveEventChatParticipantSnapshot(
          eventId: 'event-1',
          ownerUid: 'uid-1',
          participant: participant,
          rawData: participant.snapshotData,
          isFromCache: false,
          hasPendingWrites: false,
        );

        expect(state.isActive, isFalse, reason: '${participant.snapshotData}');
        expect(
          state.directSenderSnapshot,
          isNull,
          reason: '${participant.snapshotData}',
        );
      }
    });

    test('cached and pending participant states are not authoritative', () {
      final participant = _participantRecord();
      for (final metadata in <({bool cache, bool pending})>[
        (cache: true, pending: false),
        (cache: false, pending: true),
        (cache: true, pending: true),
      ]) {
        final state = resolveEventChatParticipantSnapshot(
          eventId: 'event-1',
          ownerUid: 'uid-1',
          participant: participant,
          rawData: participant.snapshotData,
          isFromCache: metadata.cache,
          hasPendingWrites: metadata.pending,
        );

        expect(state.isActive, isTrue);
        expect(state.directSenderSnapshot, isNotNull);
        expect(state.isAuthoritative, isFalse);
      }
    });

    test('malformed participant profile is not direct eligible', () {
      for (final rawData in <Map<String, dynamic>>[
        <String, dynamic>{
          ..._participantRecord().snapshotData,
          'displayName': ' Trusted Name ',
        },
        <String, dynamic>{
          ..._participantRecord().snapshotData,
          'photoUrl': '',
        },
        <String, dynamic>{
          ..._participantRecord().snapshotData,
          'photoUrl': ' https://image.test/a ',
        },
        <String, dynamic>{
          ..._participantRecord().snapshotData,
          'displayName': 'a' * 71,
        },
        <String, dynamic>{
          ..._participantRecord().snapshotData,
          'displayName': 42,
        },
        <String, dynamic>{
          ..._participantRecord().snapshotData,
          'photoUrl': 'p' * 2049,
        },
        <String, dynamic>{
          ..._participantRecord().snapshotData,
          'photoUrl': 42,
        },
      ]) {
        final state = resolveEventChatParticipantSnapshot(
          eventId: 'event-1',
          ownerUid: 'uid-1',
          participant: _participantRecord(),
          rawData: rawData,
          isFromCache: false,
          hasPendingWrites: false,
        );

        expect(state.isActive, isTrue);
        expect(state.directSenderSnapshot, isNull);
      }
    });

    test('direct writer targets UUID and emits exact six-field payload',
        () async {
      DocumentReference? writtenReference;
      Map<String, dynamic>? writtenData;
      await EventGroupChatRepository.createDirectMessage(
        eventId: ' event-1 ',
        clientMessageId: '123e4567-e89b-42d3-a456-426614174000',
        sender: const EventChatDirectSenderSnapshot(
          senderId: 'uid-1',
          displayName: 'Trusted Name',
          photoUrl: null,
        ),
        text: '  Cafe\u0301\r\n\r\n\r\nnext  ',
        writer: (reference, data) async {
          writtenReference = reference;
          writtenData = data;
        },
      );

      expect(
        writtenReference?.path,
        'eventChats/event-1/messages/123e4567-e89b-42d3-a456-426614174000',
      );
      expect(writtenData?.keys.toSet(), <String>{
        'senderId',
        'senderDisplayName',
        'senderPhotoUrl',
        'text',
        'createdAt',
        'deletedAt',
      });
      expect(writtenData?['senderId'], 'uid-1');
      expect(writtenData?['senderDisplayName'], 'Trusted Name');
      expect(writtenData?.containsKey('senderPhotoUrl'), isTrue);
      expect(writtenData?['senderPhotoUrl'], isNull);
      expect(writtenData?['text'], 'Caf\u00e9\n\nnext');
      expect(writtenData?['createdAt'], isA<FieldValue>());
      expect(writtenData?.containsKey('deletedAt'), isTrue);
      expect(writtenData?['deletedAt'], isNull);
    });

    test('direct writer rejects non-lowercase-v4 message ids', () async {
      for (final messageId in <String>[
        '123e4567-e89b-12d3-a456-426614174000',
        '123E4567-E89B-42D3-A456-426614174000',
        ' 123e4567-e89b-42d3-a456-426614174000 ',
      ]) {
        await expectLater(
          EventGroupChatRepository.createDirectMessage(
            eventId: 'event-1',
            clientMessageId: messageId,
            sender: const EventChatDirectSenderSnapshot(
              senderId: 'uid-1',
              displayName: 'Trusted Name',
              photoUrl: null,
            ),
            text: 'hello',
            writer: (_, __) async {},
          ),
          throwsArgumentError,
          reason: 'Expected $messageId to be rejected.',
        );
      }
    });

    test('message state preserves per-document pending metadata', () {
      final pending = _messageRecord(
        messageId: '123e4567-e89b-42d3-a456-426614174000',
      );
      final confirmed = _messageRecord(
        messageId: '223e4567-e89b-42d3-a456-426614174000',
      );

      final state = resolveEventChatMessagesSnapshot(
        ownerUid: 'uid-1',
        messages: <EventChatMessagesRecord>[pending, confirmed],
        isFromCache: false,
        hasPendingWrites: true,
        pendingWriteMessagePaths: <String>[pending.reference.path],
      );

      expect(state.pendingWriteMessagePaths, <String>{pending.reference.path});
      expect(state.hasPendingWriteFor(pending), isTrue);
      expect(state.hasPendingWriteFor(confirmed), isFalse);
      expect(state.isAuthoritative, isFalse);
    });

    test('retry lookup classifies matching and missing server documents',
        () async {
      final observedPaths = <String>[];
      final matching =
          await EventGroupChatRepository.lookupDirectMessageForRetry(
        eventId: 'event-1',
        clientMessageId: '123e4567-e89b-42d3-a456-426614174000',
        senderId: 'uid-1',
        text: ' hello ',
        lookup: (reference) async {
          observedPaths.add(reference.path);
          return EventChatMessageServerSnapshot(
            exists: true,
            data: _messageData(text: 'hello'),
          );
        },
      );
      final missing =
          await EventGroupChatRepository.lookupDirectMessageForRetry(
        eventId: 'event-1',
        clientMessageId: '223e4567-e89b-42d3-a456-426614174000',
        senderId: 'uid-1',
        text: 'hello',
        lookup: (reference) async {
          observedPaths.add(reference.path);
          return const EventChatMessageServerSnapshot.missing();
        },
      );

      expect(matching.isMatching, isTrue);
      expect(missing.isMissing, isTrue);
      expect(observedPaths, <String>[
        'eventChats/event-1/messages/123e4567-e89b-42d3-a456-426614174000',
        'eventChats/event-1/messages/223e4567-e89b-42d3-a456-426614174000',
      ]);
    });

    test('retry lookup fails closed for conflicting server documents',
        () async {
      final conflicts = <Map<String, dynamic>>[
        _messageData(senderId: 'uid-2'),
        _messageData(text: 'different'),
        _messageData(createdAt: null),
        _messageData(createdAt: 'not-a-timestamp'),
        _messageData(deletedAt: DateTime.utc(2026)),
        _messageData(senderDisplayName: ''),
        _messageData(senderDisplayName: ' Untrimmed '),
        _messageData(senderDisplayName: 'a' * 71),
        <String, dynamic>{
          ..._messageData(),
          'senderDisplayName': 42,
        },
        _messageData(senderPhotoUrl: ''),
        _messageData(senderPhotoUrl: ' https://image.test/a '),
        _messageData(senderPhotoUrl: 'p' * 2049),
        <String, dynamic>{..._messageData(), 'senderPhotoUrl': 42},
        <String, dynamic>{..._messageData(), 'extra': true},
        <String, dynamic>{..._messageData()}..remove('senderPhotoUrl'),
      ];

      for (final data in conflicts) {
        final result =
            await EventGroupChatRepository.lookupDirectMessageForRetry(
          eventId: 'event-1',
          clientMessageId: '123e4567-e89b-42d3-a456-426614174000',
          senderId: 'uid-1',
          text: 'hello',
          lookup: (_) async => EventChatMessageServerSnapshot(
            exists: true,
            data: data,
          ),
        );

        expect(result.isConflict, isTrue, reason: '$data');
      }
    });

    test('bounds remembered inbox ids and forgets inaccessible ids', () {
      UxSessionCacheLifecycle.updateAuthenticatedUser('uid-1');
      for (var index = 0; index < 75; index += 1) {
        EventGroupChatRepository.rememberInboxEventId(
          'event-$index',
          ownerUid: 'uid-1',
        );
      }

      final remembered =
          EventGroupChatRepository.rememberedInboxEventIdsForOwner('uid-1');
      expect(remembered, hasLength(EventGroupChatRepository.maxInboxChatCount));
      expect(remembered.first, 'event-25');
      expect(remembered.last, 'event-74');

      EventGroupChatRepository.forgetInboxEventId(
        'event-40',
        ownerUid: 'uid-1',
      );
      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('uid-1'),
        isNot(contains('event-40')),
      );
    });

    test('rejects inbox persistence for another owner reference', () async {
      await expectLater(
        EventGroupChatRepository.persistInboxEventId(
          ownerUid: 'uid-1',
          userReference: UsersRecord.collection.doc('uid-2'),
          eventId: 'event-1',
        ),
        throwsStateError,
      );
    });

    test('persists a bounded inbox and recomputes it on transaction retry',
        () async {
      final attemptEventIds = <List<String>>[
        List<String>.generate(50, (index) => 'event-$index'),
        <String>[
          ...List<String>.generate(49, (index) => 'event-${index + 1}'),
          'event-concurrent',
        ],
      ];
      Map<String, Object?>? committedUpdate;
      var updateCalls = 0;

      await EventGroupChatRepository.persistInboxEventId(
        ownerUid: 'uid-1',
        userReference: UsersRecord.collection.doc('uid-1'),
        eventId: 'event-new',
        transactionRunner: (body) async {
          for (var index = 0; index < attemptEventIds.length; index += 1) {
            Map<String, Object?>? pendingUpdate;
            await body(
              readUser: () async => (
                exists: true,
                data: <String, Object?>{
                  'eventChatInboxEventIds': attemptEventIds[index],
                },
              ),
              updateUser: (data) {
                updateCalls += 1;
                pendingUpdate = Map<String, Object?>.from(data);
              },
            );
            if (index == attemptEventIds.length - 1) {
              committedUpdate = pendingUpdate;
            }
          }
        },
      );

      expect(updateCalls, 2);
      expect(committedUpdate, isNotNull);
      final committedEventIds =
          committedUpdate!['eventChatInboxEventIds']! as List<String>;
      expect(
        committedEventIds,
        hasLength(EventGroupChatRepository.maxInboxChatCount),
      );
      expect(committedEventIds.first, 'event-2');
      expect(committedEventIds, contains('event-concurrent'));
      expect(committedEventIds.last, 'event-new');
      expect(committedEventIds.toSet(), hasLength(committedEventIds.length));
      expect(committedUpdate, contains('hiddenChatKeys'));
    });

    test('stale inbox persistence scope stops before the transaction read',
        () async {
      var currentChecks = 0;
      var readCalls = 0;
      var updateCalls = 0;

      await EventGroupChatRepository.persistInboxEventId(
        ownerUid: 'uid-1',
        userReference: UsersRecord.collection.doc('uid-1'),
        eventId: 'event-new',
        isStillCurrent: () {
          currentChecks += 1;
          return false;
        },
        transactionRunner: (body) => body(
          readUser: () async {
            readCalls += 1;
            return (
              exists: true,
              data: const <String, Object?>{},
            );
          },
          updateUser: (_) => updateCalls += 1,
        ),
      );

      expect(currentChecks, 1);
      expect(readCalls, 0);
      expect(updateCalls, 0);
    });

    test('inbox persistence scope expiring after read prevents the update',
        () async {
      var currentChecks = 0;
      var readCalls = 0;
      var updateCalls = 0;

      await EventGroupChatRepository.persistInboxEventId(
        ownerUid: 'uid-1',
        userReference: UsersRecord.collection.doc('uid-1'),
        eventId: 'event-new',
        isStillCurrent: () {
          currentChecks += 1;
          return currentChecks == 1;
        },
        transactionRunner: (body) => body(
          readUser: () async {
            readCalls += 1;
            return (
              exists: true,
              data: const <String, Object?>{
                'eventChatInboxEventIds': <String>['event-old'],
              },
            );
          },
          updateUser: (_) => updateCalls += 1,
        ),
      );

      expect(currentChecks, 2);
      expect(readCalls, 1);
      expect(updateCalls, 0);
    });

    test('bounded inbox ids give later sources recency priority', () {
      final historyIds = List<String>.generate(50, (index) => 'event-$index');
      final savedIds = <String>[
        ...List<String>.generate(49, (index) => 'saved-$index'),
        'event-0',
      ];

      final bounded = EventGroupChatRepository.boundedInboxEventIds(
        <String>[...historyIds, ...savedIds],
      );

      expect(bounded, hasLength(EventGroupChatRepository.maxInboxChatCount));
      expect(bounded.last, 'event-0');
      expect(bounded, containsAll(savedIds));
    });

    test('permission denial forgets and reports an inaccessible inbox id',
        () async {
      UxSessionCacheLifecycle.updateAuthenticatedUser('uid-1');
      EventGroupChatRepository.rememberInboxEventId(
        'event-denied',
        ownerUid: 'uid-1',
      );
      final inaccessibleIds = <String>[];

      final chats = await EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () => Stream.value(
          _eventIdsState('uid-1', const <String>['event-denied']),
        ),
        chatAccessStateStream: (_, __) => Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        onInaccessibleEventId: inaccessibleIds.add,
      ).first;

      expect(chats, isEmpty);
      expect(inaccessibleIds, const <String>['event-denied']);
      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('uid-1'),
        isNot(contains('event-denied')),
      );
    });

    test('stale owner denial cannot mutate inbox memory or cleanup callback',
        () async {
      UxSessionCacheLifecycle.updateAuthenticatedUser('uid-1');
      EventGroupChatRepository.rememberInboxEventId(
        'event-denied',
        ownerUid: 'uid-1',
      );
      final inaccessibleIds = <String>[];

      final chats = await EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () => Stream.value(
          _eventIdsState('uid-1', const <String>['event-denied']),
        ),
        chatAccessStateStream: (_, __) => Stream.error(
          FirebaseException(
            plugin: 'cloud_firestore',
            code: 'permission-denied',
          ),
        ),
        canMutateOwner: (_) => false,
        onInaccessibleEventId: inaccessibleIds.add,
      ).first;

      expect(chats, isEmpty);
      expect(inaccessibleIds, isEmpty);
      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('uid-1'),
        contains('event-denied'),
      );
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
        eventIdsStream: () =>
            Stream.value(_eventIdsState('uid-1', [' event-1 '])),
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

      EventGroupChatRepository.rememberInboxEventId(
        ' event-remembered ',
        ownerUid: 'uid-1',
      );

      final chats = await EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () =>
            Stream.value(_eventIdsState('uid-1', const <String>[])),
        chatByEventIdStream: (eventId) {
          subscribedEventIds.add(eventId);
          return Stream<EventChatsRecord?>.value(chat);
        },
      ).firstWhere((eventChats) => eventChats.isNotEmpty);

      expect(subscribedEventIds, ['event-remembered']);
      expect(chats, [chat]);
    });

    test('clears remembered inbox event ids on account change', () async {
      UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
      EventGroupChatRepository.rememberInboxEventId(
        'event-from-a',
        ownerUid: 'user-a',
      );
      final emissions = <EventInboxEventIdsLoadState>[];
      final subscription =
          EventGroupChatRepository.watchRememberedInboxEventIds(
        ownerUid: 'user-a',
      ).listen(emissions.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
        ['event-from-a'],
      );

      UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');
      await pumpEventQueue();

      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
        isEmpty,
      );
      expect(emissions.map((state) => state.eventIds), [
        ['event-from-a'],
        <String>[],
      ]);
      expect(emissions.every((state) => state.isAuthoritative), isTrue);
    });

    test('clears remembered inbox event ids on logout', () async {
      UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
      EventGroupChatRepository.rememberInboxEventId(
        'event-from-a',
        ownerUid: 'user-a',
      );
      final emissions = <EventInboxEventIdsLoadState>[];
      final subscription =
          EventGroupChatRepository.watchRememberedInboxEventIds(
        ownerUid: 'user-a',
      ).listen(emissions.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      UxSessionCacheLifecycle.updateAuthenticatedUser(null);
      await pumpEventQueue();

      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
        isEmpty,
      );
      expect(emissions.map((state) => state.eventIds), [
        ['event-from-a'],
        <String>[],
      ]);
    });

    test('keeps remembered event ids isolated by owner', () async {
      EventGroupChatRepository.rememberInboxEventId(
        'event-from-a',
        ownerUid: 'user-a',
      );
      final ownerBEmissions = <EventInboxEventIdsLoadState>[];
      final subscription =
          EventGroupChatRepository.watchRememberedInboxEventIds(
        ownerUid: 'user-b',
      ).listen(ownerBEmissions.add);
      addTearDown(subscription.cancel);
      await pumpEventQueue();

      EventGroupChatRepository.rememberInboxEventId(
        'late-event-from-a',
        ownerUid: 'user-a',
      );
      await pumpEventQueue();

      expect(
        ownerBEmissions.map((state) => state.eventIds),
        [<String>[]],
      );
      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
        ['event-from-a', 'late-event-from-a'],
      );
      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-b'),
        isEmpty,
      );
    });

    test('late previous-owner remember after lifecycle clear is rejected',
        () async {
      UxSessionCacheLifecycle.updateAuthenticatedUser('user-a');
      EventGroupChatRepository.rememberInboxEventId(
        'event-from-a',
        ownerUid: 'user-a',
      );
      UxSessionCacheLifecycle.updateAuthenticatedUser('user-b');

      EventGroupChatRepository.rememberInboxEventId(
        'late-event-from-a',
        ownerUid: 'user-a',
      );
      final subscribedEventIds = <String>[];
      final ownerBChats = await EventGroupChatRepository.watchInboxChats(
        currentUid: 'user-b',
        eventIdsStream: () =>
            Stream.value(_eventIdsState('user-b', const <String>[])),
        chatByEventIdStream: (eventId) {
          subscribedEventIds.add(eventId);
          return const Stream<EventChatsRecord?>.empty();
        },
      ).first;

      expect(ownerBChats, isEmpty);
      expect(subscribedEventIds, isEmpty);
      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-b'),
        isEmpty,
      );
      expect(
        EventGroupChatRepository.rememberedInboxEventIdsForOwner('user-a'),
        isEmpty,
      );
    });

    test('propagates a cold event id source error without false empty',
        () async {
      final stream = EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () => Stream<EventInboxEventIdsLoadState>.error(
          StateError('event history unavailable'),
        ),
        chatByEventIdStream: (_) => const Stream<EventChatsRecord?>.empty(),
      );

      await expectLater(stream, emitsError(isA<StateError>()));
    });

    test('caps per-id inbox listeners to the bounded saved-id window',
        () async {
      final subscribedEventIds = <String>[];
      final savedIds = List<String>.generate(75, (index) => 'event-$index');

      final chats = await EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () =>
            Stream.value(_eventIdsState('uid-1', const <String>[])),
        rememberedEventIdsStream: () =>
            Stream.value(_eventIdsState('uid-1', savedIds)),
        chatByEventIdStream: (eventId) {
          subscribedEventIds.add(eventId);
          return Stream<EventChatsRecord?>.value(null);
        },
      ).first;

      expect(chats, isEmpty);
      expect(
        subscribedEventIds,
        hasLength(EventGroupChatRepository.maxInboxChatCount),
      );
      expect(subscribedEventIds.first, 'event-25');
      expect(subscribedEventIds.last, 'event-74');
    });

    test(
        'production id/chat aggregation emits non-empty partial data but '
        'waits for every id source before empty', () async {
      final historyEventIds = StreamController<EventInboxEventIdsLoadState>();
      final savedEventIds = StreamController<EventInboxEventIdsLoadState>();
      final chat = StreamController<EventChatsRecord?>();
      addTearDown(historyEventIds.close);
      addTearDown(savedEventIds.close);
      addTearDown(chat.close);
      final eventChat = EventChatsRecord.getDocumentFromData(
        {
          'eventId': 'event-partial',
          'readAccessUserIds': <String>['uid-1'],
          'updatedAt': DateTime.parse('2026-06-15T10:00:00Z'),
        },
        EventChatsRecord.collection.doc('event-partial'),
      );
      final emissions = <List<EventChatsRecord>>[];
      final errors = <Object>[];
      final subscription = EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () => historyEventIds.stream,
        rememberedEventIdsStream: () => savedEventIds.stream,
        chatByEventIdStream: (_) => chat.stream,
      ).listen(emissions.add, onError: errors.add);
      addTearDown(subscription.cancel);

      await pumpEventQueue();
      expect(emissions, isEmpty);

      historyEventIds.add(
        _eventIdsState('uid-1', ['event-partial']),
      );
      await pumpEventQueue();
      expect(emissions, isEmpty);

      chat.add(eventChat);
      await pumpEventQueue();
      expect(emissions, [
        <EventChatsRecord>[eventChat]
      ]);

      chat.add(null);
      await pumpEventQueue();
      expect(emissions, [
        <EventChatsRecord>[eventChat]
      ]);

      savedEventIds.add(_eventIdsState('uid-1', const <String>[]));
      await pumpEventQueue();
      expect(emissions, [
        <EventChatsRecord>[eventChat],
        <EventChatsRecord>[]
      ]);
      expect(errors, isEmpty);
    });

    for (final blockedGate in <String>[
      'read-access',
      'history-ids',
      'saved-ids',
    ]) {
      test('inbox authority waits for $blockedGate independently', () async {
        final readAccessChats = StreamController<EventChatInboxLoadState>();
        final historyEventIds = StreamController<EventInboxEventIdsLoadState>();
        final savedEventIds = StreamController<EventInboxEventIdsLoadState>();
        final chat = StreamController<EventChatsRecord?>();
        addTearDown(readAccessChats.close);
        addTearDown(historyEventIds.close);
        addTearDown(savedEventIds.close);
        addTearDown(chat.close);
        final eventChat = EventChatsRecord.getDocumentFromData(
          <String, dynamic>{
            'eventId': 'event-authority-$blockedGate',
            'readAccessUserIds': <String>['uid-1'],
            'updatedAt': DateTime.parse('2026-06-15T10:00:00Z'),
          },
          EventChatsRecord.collection.doc('event-authority-$blockedGate'),
        );
        final emissions = <EventChatInboxLoadState>[];
        final subscription = EventGroupChatRepository.watchInboxChatsState(
          currentUid: 'uid-1',
          chatsStateStream: () => readAccessChats.stream,
          eventIdsStream: () => historyEventIds.stream,
          rememberedEventIdsStream: () => savedEventIds.stream,
          chatByEventIdStream: (_) => chat.stream,
        ).listen(emissions.add);
        addTearDown(subscription.cancel);

        readAccessChats.add(
          EventChatInboxLoadState(
            ownerUid: 'uid-1',
            chats: <EventChatsRecord>[eventChat],
            isAuthoritative: blockedGate != 'read-access',
          ),
        );
        historyEventIds.add(
          _eventIdsState(
            'uid-1',
            <String>[eventChat.eventId],
            isReady: blockedGate != 'history-ids',
            isAuthoritative: blockedGate != 'history-ids',
          ),
        );
        savedEventIds.add(
          _eventIdsState(
            'uid-1',
            const <String>[],
            isReady: blockedGate != 'saved-ids',
            isAuthoritative: blockedGate != 'saved-ids',
          ),
        );
        await pumpEventQueue();
        chat.add(eventChat);
        await pumpEventQueue();

        expect(emissions, isNotEmpty);
        expect(emissions.last.ownerUid, 'uid-1');
        expect(emissions.last.chats, <EventChatsRecord>[eventChat]);
        expect(emissions.last.isAuthoritative, isFalse);
        final partialRow = emissions.last.chats.single;

        switch (blockedGate) {
          case 'read-access':
            readAccessChats.add(
              EventChatInboxLoadState(
                ownerUid: 'uid-1',
                chats: <EventChatsRecord>[eventChat],
                isAuthoritative: true,
              ),
            );
          case 'history-ids':
            historyEventIds.add(
              _eventIdsState(
                'uid-1',
                <String>[eventChat.eventId],
              ),
            );
          case 'saved-ids':
            savedEventIds.add(
              _eventIdsState('uid-1', const <String>[]),
            );
        }
        await pumpEventQueue();

        expect(emissions.last.chats, <EventChatsRecord>[eventChat]);
        expect(emissions.last.chats.single, same(partialRow));
        expect(emissions.last.isAuthoritative, isTrue);
      });
    }

    test('cached and pending saved ids stay partial until server authority',
        () async {
      final historyEventIds = StreamController<EventInboxEventIdsLoadState>();
      final savedEventIds = StreamController<EventInboxEventIdsLoadState>();
      final chat = StreamController<EventChatsRecord?>();
      addTearDown(historyEventIds.close);
      addTearDown(savedEventIds.close);
      addTearDown(chat.close);
      final eventChat = EventChatsRecord.getDocumentFromData(
        <String, dynamic>{
          'eventId': 'event-saved',
          'readAccessUserIds': <String>['uid-1'],
          'updatedAt': DateTime.parse('2026-06-15T10:00:00Z'),
        },
        EventChatsRecord.collection.doc('event-saved'),
      );
      final emissions = <EventChatInboxLoadState>[];
      final subscription = EventGroupChatRepository.watchInboxChatsState(
        currentUid: 'uid-1',
        eventIdsStream: () => historyEventIds.stream,
        rememberedEventIdsStream: () => savedEventIds.stream,
        chatByEventIdStream: (_) => chat.stream,
      ).listen(emissions.add);
      addTearDown(subscription.cancel);

      historyEventIds.add(_eventIdsState('uid-1', const <String>[]));
      savedEventIds.add(
        _eventIdsState(
          'uid-1',
          const <String>['event-saved'],
          isAuthoritative: false,
        ),
      );
      await pumpEventQueue();
      chat.add(eventChat);
      await pumpEventQueue();

      expect(emissions, isNotEmpty);
      expect(emissions.last.chats, <EventChatsRecord>[eventChat]);
      expect(emissions.every((state) => !state.isAuthoritative), isTrue);

      savedEventIds.add(
        _eventIdsState(
          'uid-1',
          const <String>['event-saved'],
          isAuthoritative: false,
        ),
      );
      await pumpEventQueue();
      expect(emissions.last.isAuthoritative, isFalse);

      savedEventIds.add(
        _eventIdsState('uid-1', const <String>['event-saved']),
      );
      await pumpEventQueue();
      expect(emissions.last.chats, <EventChatsRecord>[eventChat]);
      expect(emissions.last.isAuthoritative, isTrue);

      savedEventIds.add(_eventIdsState('uid-1', const <String>[]));
      await pumpEventQueue();
      expect(emissions.last.chats, isEmpty);
      expect(emissions.last.isAuthoritative, isTrue);
    });

    test('propagates cold chat metadata error without false empty', () async {
      final stream = EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        eventIdsStream: () =>
            Stream.value(_eventIdsState('uid-1', ['event-1'])),
        chatByEventIdStream: (_) => Stream<EventChatsRecord?>.error(
          StateError('chat metadata unavailable'),
        ),
      );

      await expectLater(stream, emitsError(isA<StateError>()));
    });

    test('combined read-access source emits non-empty data immediately',
        () async {
      final historyEventIds = StreamController<EventInboxEventIdsLoadState>();
      addTearDown(historyEventIds.close);
      final eventChat = EventChatsRecord.getDocumentFromData(
        {
          'eventId': 'event-direct',
          'readAccessUserIds': <String>['uid-1'],
          'updatedAt': DateTime.parse('2026-06-15T10:00:00Z'),
        },
        EventChatsRecord.collection.doc('event-direct'),
      );
      final stream = EventGroupChatRepository.watchInboxChats(
        currentUid: 'uid-1',
        chatsStream: () => Stream.value([eventChat]),
        eventIdsStream: () => historyEventIds.stream,
        chatByEventIdStream: (_) => const Stream<EventChatsRecord?>.empty(),
      );

      expect(await stream.first, [eventChat]);
    });

    test('direct inbox state retains rows through a partial replacement',
        () async {
      EventChatsRecord chat(String id, DateTime updatedAt) =>
          EventChatsRecord.getDocumentFromData(
            <String, dynamic>{'eventId': id, 'updatedAt': updatedAt},
            EventChatsRecord.collection.doc(id),
          );
      final chatA = chat('event-a', DateTime.utc(2026, 7, 1));
      final chatB1 = chat('event-b', DateTime.utc(2026, 7, 1));
      final chatB2 = chat('event-b', DateTime.utc(2026, 7, 2));
      final direct = StreamController<EventChatInboxLoadState>();
      addTearDown(direct.close);
      final emissions = <EventChatInboxLoadState>[];
      final subscription = EventGroupChatRepository.watchInboxChatsState(
        currentUid: 'uid-1',
        chatsStateStream: () => direct.stream,
      ).listen(emissions.add);
      addTearDown(subscription.cancel);

      direct.add(
        EventChatInboxLoadState(
          ownerUid: 'uid-1',
          chats: <EventChatsRecord>[chatA, chatB1],
          isAuthoritative: true,
        ),
      );
      await pumpEventQueue();
      direct.add(
        EventChatInboxLoadState(
          ownerUid: 'uid-1',
          chats: <EventChatsRecord>[chatB2],
          isAuthoritative: false,
        ),
      );
      await pumpEventQueue();

      expect(
        emissions.last.chats.map(EventGroupChatRepository.eventIdForChat),
        ['event-b', 'event-a'],
      );
      expect(emissions.last.chats.first, same(chatB2));
      expect(emissions.last.isAuthoritative, isFalse);

      direct.add(
        EventChatInboxLoadState(
          ownerUid: 'uid-1',
          chats: <EventChatsRecord>[chatB2],
          isAuthoritative: true,
        ),
      );
      await pumpEventQueue();
      expect(
        emissions.last.chats.map(EventGroupChatRepository.eventIdForChat),
        ['event-b'],
      );
      expect(emissions.last.isAuthoritative, isTrue);
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
          () => EventGroupChatRepository.watchChatAccessState(
            eventId: eventId,
            ownerUid: 'uid-1',
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
