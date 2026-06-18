import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';
import 'package:small_talk/services/event_detail_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('EventDetailRepository', () {
    test('normalizes event id and subscribes to the event document', () async {
      DocumentReference? capturedEventRef;

      final events = await EventDetailRepository.watchEventDetail(
        eventId: ' event-1 ',
        snapshotStream: (eventRef) {
          capturedEventRef = eventRef;
          return Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: eventObjectRef('event-1'),
              data: eventDetailData(title: 'Conversation club'),
            ),
          );
        },
      ).toList();

      expect(capturedEventRef?.path, 'events/event-1');
      expect(events, hasLength(1));
      expect(events.single?.reference.path, 'events/event-1');
      expect(events.single?.title, 'Conversation club');
    });

    test('emits null when the event document is missing or deleted', () async {
      final events = await EventDetailRepository.watchEventDetail(
        eventId: 'event-1',
        snapshotStream: (_) => Stream<DocumentSnapshot>.fromIterable([
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            data: eventDetailData(title: 'Conversation club'),
          ),
          _FakeEventDocumentSnapshot(
            reference: eventObjectRef('event-1'),
            exists: false,
          ),
        ]),
      ).toList();

      expect(events, hasLength(2));
      expect(events.first?.title, 'Conversation club');
      expect(events.last, isNull);
    });

    test('rejects invalid event ids before subscribing', () {
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
          () => EventDetailRepository.watchEventDetail(
            eventId: eventId,
            snapshotStream: (_) {
              streamCalls += 1;
              return const Stream<DocumentSnapshot>.empty();
            },
          ),
          throwsA(isA<ArgumentError>()),
          reason: 'Expected "$eventId" to be rejected.',
        );
        expect(streamCalls, 0);
      }
    });

    test('passes detail stream errors through', () async {
      final error = StateError('detail stream failed');

      await expectLater(
        EventDetailRepository.watchEventDetail(
          eventId: 'event-1',
          snapshotStream: (_) => Stream<DocumentSnapshot>.error(error),
        ),
        emitsError(same(error)),
      );
    });

    test('watches the current user participant document', () async {
      DocumentReference? capturedParticipantRef;

      final participants =
          await EventDetailRepository.watchCurrentUserParticipant(
        eventId: ' event-1 ',
        userId: ' uid-1 ',
        snapshotStream: (participantRef) {
          capturedParticipantRef = participantRef;
          return Stream<DocumentSnapshot>.value(
            _FakeEventDocumentSnapshot(
              reference: participantObjectRef('event-1', 'uid-1'),
              data: participantData(
                userId: 'uid-1',
                status: 'active',
              ),
            ),
          );
        },
      ).toList();

      expect(capturedParticipantRef?.path, 'events/event-1/participants/uid-1');
      expect(participants, hasLength(1));
      expect(participants.single?.reference.path,
          'events/event-1/participants/uid-1');
      expect(participants.single?.userId, 'uid-1');
      expect(participants.single?.status, 'active');
    });

    test('emits null when the current user participant document is missing',
        () async {
      final participants =
          await EventDetailRepository.watchCurrentUserParticipant(
        eventId: 'event-1',
        userId: 'uid-1',
        snapshotStream: (_) => Stream<DocumentSnapshot>.value(
          _FakeEventDocumentSnapshot(
            reference: participantObjectRef('event-1', 'uid-1'),
            exists: false,
          ),
        ),
      ).toList();

      expect(participants, <EventParticipantsRecord?>[null]);
    });
  });
}

Map<String, dynamic> eventDetailData({
  required String title,
  String status = 'active',
}) =>
    <String, dynamic>{
      'title': title,
      'description': 'Casual practice',
      'languageCode': 'en',
      'levelMin': 'B1',
      'levelMax': 'C1',
      'status': status,
    };

DocumentReference<Object?> eventObjectRef(String eventId) =>
    FirebaseFirestore.instance.doc('events/$eventId').withConverter<Object?>(
          fromFirestore: (snapshot, _) => snapshot.data(),
          toFirestore: (value, _) {
            if (value is Map<String, Object?>) {
              return value;
            }
            return const <String, Object?>{};
          },
        );

DocumentReference<Object?> participantObjectRef(
        String eventId, String userId) =>
    FirebaseFirestore.instance
        .doc('events/$eventId/participants/$userId')
        .withConverter<Object?>(
          fromFirestore: (snapshot, _) => snapshot.data(),
          toFirestore: (value, _) {
            if (value is Map<String, Object?>) {
              return value;
            }
            return const <String, Object?>{};
          },
        );

Map<String, dynamic> participantData({
  required String userId,
  required String status,
}) =>
    <String, dynamic>{
      'userId': userId,
      'displayName': 'Participant',
      'role': 'participant',
      'status': status,
    };

// ignore: subtype_of_sealed_class
class _FakeEventDocumentSnapshot implements DocumentSnapshot<Object?> {
  _FakeEventDocumentSnapshot({
    required this.reference,
    this.exists = true,
    Map<String, dynamic>? data,
  }) : _data = data;

  final Map<String, dynamic>? _data;

  @override
  final bool exists;

  @override
  final DocumentReference<Object?> reference;

  @override
  String get id => reference.id;

  @override
  SnapshotMetadata get metadata => throw UnimplementedError();

  @override
  Object? data() => _data;

  @override
  Object? get(Object field) => _data?[field];

  @override
  Object? operator [](Object field) => get(field);
}
