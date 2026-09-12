import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('EventParticipantsRecord', () {
    test('parses active participant contract', () {
      final joinedAt = DateTime.parse('2026-06-14T10:00:00Z');
      final updatedAt = DateTime.parse('2026-06-14T10:00:00Z');
      final eventRef = EventsRecord.collection.doc('event-1');
      final participantRef = EventParticipantsRecord.createDoc(
        eventRef,
        id: 'uid-1',
      );

      final participant = EventParticipantsRecord.getDocumentFromData(
        {
          'userId': 'uid-1',
          'displayName': 'Anastasia Ivanova',
          'photoUrl': 'https://example.com/avatar.jpg',
          'role': 'organizer',
          'status': 'active',
          'joinedAt': joinedAt,
          'leftAt': null,
          'createdAt': joinedAt,
          'updatedAt': updatedAt,
        },
        participantRef,
      );

      expect(participant.reference.path, 'events/event-1/participants/uid-1');
      expect(participant.parentReference.path, 'events/event-1');
      expect(participant.userId, 'uid-1');
      expect(participant.displayName, 'Anastasia Ivanova');
      expect(participant.photoUrl, 'https://example.com/avatar.jpg');
      expect(participant.role, 'organizer');
      expect(participant.status, 'active');
      expect(participant.joinedAt, joinedAt);
      expect(participant.leftAt, isNull);
      expect(participant.hasLeftAt(), isFalse);
      expect(participant.createdAt, joinedAt);
      expect(participant.updatedAt, updatedAt);
    });

    test('parses left participant with nullable photo', () {
      final joinedAt = DateTime.parse('2026-06-14T10:00:00Z');
      final leftAt = DateTime.parse('2026-06-15T11:30:00Z');
      final participant = EventParticipantsRecord.getDocumentFromData(
        {
          'userId': 'uid-2',
          'displayName': 'Marco Rossi',
          'photoUrl': null,
          'role': 'participant',
          'status': 'left',
          'joinedAt': joinedAt,
          'leftAt': leftAt,
          'createdAt': joinedAt,
          'updatedAt': leftAt,
        },
        EventParticipantsRecord.createDoc(
          EventsRecord.collection.doc('event-1'),
          id: 'uid-2',
        ),
      );

      expect(participant.userId, 'uid-2');
      expect(participant.photoUrl, '');
      expect(participant.hasPhotoUrl(), isFalse);
      expect(participant.role, 'participant');
      expect(participant.status, 'left');
      expect(participant.leftAt, leftAt);
      expect(participant.hasLeftAt(), isTrue);
      expect(participant.updatedAt, leftAt);
    });

    test('creates participant document paths under event parent', () {
      final eventRef = EventsRecord.collection.doc('event-1');
      final participantCollection =
          EventParticipantsRecord.collection(eventRef);
      final participantRef = EventParticipantsRecord.createDoc(
        eventRef,
        id: 'uid-3',
      );

      expect(participantRef.path, 'events/event-1/participants/uid-3');
      expect(participantCollection, isA<CollectionReference>());
      expect(
        (participantCollection as CollectionReference).path,
        'events/event-1/participants',
      );
    });

    test('serializes non-null participant fields', () {
      final joinedAt = DateTime.parse('2026-06-14T10:00:00Z');
      final data = createEventParticipantsRecordData(
        userId: 'uid-4',
        displayName: 'Olga',
        role: 'participant',
        status: 'active',
        joinedAt: joinedAt,
        leftAt: null,
        createdAt: joinedAt,
        updatedAt: joinedAt,
      );

      expect(data['userId'], 'uid-4');
      expect(data['displayName'], 'Olga');
      expect(data['role'], 'participant');
      expect(data['status'], 'active');
      expect(data['joinedAt'], joinedAt);
      expect(data['createdAt'], joinedAt);
      expect(data['updatedAt'], joinedAt);
      expect(data.containsKey('photoUrl'), isFalse);
      expect(data.containsKey('leftAt'), isFalse);
    });
  });
}
