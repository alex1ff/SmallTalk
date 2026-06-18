import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/flutter_flow/flutter_flow_util.dart';
import 'package:small_talk/services/event_actions_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventActionsRepository', () {
    test('creates an event with the exact callable payload', () async {
      String? functionName;
      Map<String, dynamic>? payload;

      final result = await EventActionsRepository.createEvent(
        createRequestId: ' 550E8400-E29B-41D4-A716-446655440000 ',
        fields: eventFieldsFixture(
          startsAt: DateTime.parse('2026-06-18T15:30:45.123456Z'),
          locationGeoPoint: const LatLng(55.7522, 37.6156),
          levelMin: ' b1 ',
          levelMax: ' c1 ',
          countryCode: ' ru ',
        ),
        invoker: (calledFunctionName, calledPayload) async {
          functionName = calledFunctionName;
          payload = calledPayload;
          return createEventResponse();
        },
      );

      expect(functionName, createEventFunctionName);
      expect(payload, <String, dynamic>{
        'createRequestId': '550e8400-e29b-41d4-a716-446655440000',
        'title': 'Conversation club',
        'description': 'Casual practice',
        'languageCode': 'en',
        'levelMin': 'B1',
        'levelMax': 'C1',
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'locationName': 'Starbucks, Arbat 5',
        'locationGeoPoint': <String, dynamic>{
          'latitude': 55.7522,
          'longitude': 37.6156,
        },
        'startsAt': '2026-06-18T15:30:45.123Z',
        'capacity': 10,
      });
      expect(result.eventId, 'event-1');
      expect(result.createdAt, DateTime.parse('2026-06-14T10:00:00Z'));
      expect(result.dailyCreation.count, 2);
      expect(result.dailyCreation.remaining, 3);
    });

    test('edits an event with the exact callable payload', () async {
      String? functionName;
      Map<String, dynamic>? payload;

      final result = await EventActionsRepository.editEvent(
        eventId: ' event-1 ',
        fields: eventFieldsFixture(locationGeoPoint: null),
        invoker: (calledFunctionName, calledPayload) async {
          functionName = calledFunctionName;
          payload = calledPayload;
          return <String, dynamic>{
            'eventId': 'event-1',
            'updatedAt': '2026-06-14T11:00:00.000Z',
          };
        },
      );

      expect(functionName, editEventFunctionName);
      expect(payload, <String, dynamic>{
        'eventId': 'event-1',
        'title': 'Conversation club',
        'description': 'Casual practice',
        'languageCode': 'en',
        'levelMin': 'B1',
        'levelMax': 'C1',
        'countryCode': 'RU',
        'cityKey': 'moscow',
        'locationName': 'Starbucks, Arbat 5',
        'locationGeoPoint': null,
        'startsAt': '2026-06-18T15:30:45.000Z',
        'capacity': 10,
      });
      expect(result.eventId, 'event-1');
      expect(result.updatedAt, DateTime.parse('2026-06-14T11:00:00Z'));
    });

    test('cancels, joins, and leaves through their callable functions',
        () async {
      final calls = <String, Map<String, dynamic>>{};

      final cancelResult = await EventActionsRepository.cancelEvent(
        eventId: 'event-1',
        invoker: (functionName, payload) async {
          calls[functionName] = payload;
          return <String, dynamic>{
            'eventId': 'event-1',
            'status': 'canceled',
            'canceledAt': '2026-06-14T12:00:00.000Z',
          };
        },
      );
      final joinResult = await EventActionsRepository.joinEvent(
        eventId: 'event-1',
        invoker: (functionName, payload) async {
          calls[functionName] = payload;
          return <String, dynamic>{
            'eventId': 'event-1',
            'participantStatus': 'active',
            'participantsCount': 6,
            'joinedAt': '2026-06-14T12:01:00.000Z',
          };
        },
      );
      final leaveResult = await EventActionsRepository.leaveEvent(
        eventId: ' event-1 ',
        invoker: (functionName, payload) async {
          calls[functionName] = payload;
          return <String, dynamic>{
            'eventId': 'event-1',
            'participantStatus': 'left',
            'participantsCount': 5,
            'leftAt': '2026-06-14T12:02:00.000Z',
          };
        },
      );

      expect(calls, <String, Map<String, dynamic>>{
        cancelEventFunctionName: <String, dynamic>{'eventId': 'event-1'},
        joinEventFunctionName: <String, dynamic>{'eventId': 'event-1'},
        leaveEventFunctionName: <String, dynamic>{'eventId': 'event-1'},
      });
      expect(cancelResult.status, 'canceled');
      expect(cancelResult.canceledAt, DateTime.parse('2026-06-14T12:00:00Z'));
      expect(joinResult.participantStatus, 'active');
      expect(joinResult.participantsCount, 6);
      expect(joinResult.occurredAt, DateTime.parse('2026-06-14T12:01:00Z'));
      expect(leaveResult.participantStatus, 'left');
      expect(leaveResult.participantsCount, 5);
      expect(leaveResult.occurredAt, DateTime.parse('2026-06-14T12:02:00Z'));
    });

    test('sends an event chat message through the trusted callable', () async {
      String? functionName;
      Map<String, dynamic>? payload;

      final result = await EventActionsRepository.sendEventChatMessage(
        eventId: ' event-1 ',
        text: '  Всем привет!  ',
        invoker: (calledFunctionName, calledPayload) async {
          functionName = calledFunctionName;
          payload = calledPayload;
          return <String, dynamic>{
            'messageId': 'message-1',
            'createdAt': '2026-06-14T12:03:00.000Z',
          };
        },
      );

      expect(functionName, sendEventChatMessageFunctionName);
      expect(payload, <String, dynamic>{
        'eventId': 'event-1',
        'text': '  Всем привет!  ',
      });
      expect(result.messageId, 'message-1');
      expect(result.createdAt, DateTime.parse('2026-06-14T12:03:00Z'));
    });

    test('rejects invalid ids and create request ids before calling functions',
        () async {
      var calls = 0;
      Future<Object?> invoker(String _, Map<String, dynamic> __) async {
        calls += 1;
        return createEventResponse();
      }

      await expectLater(
        EventActionsRepository.createEvent(
          createRequestId: 'not-a-uuid',
          fields: eventFieldsFixture(),
          invoker: invoker,
        ),
        throwsA(isA<ArgumentError>()),
      );
      for (final eventId in <String>[
        '',
        ' ',
        '.',
        '..',
        'events/event-1',
        '__reserved__',
        'a' * 1501,
      ]) {
        await expectLater(
          EventActionsRepository.cancelEvent(
            eventId: eventId,
            invoker: invoker,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
      expect(calls, 0);
    });

    test('rejects invalid editable fields before calling functions', () async {
      var calls = 0;
      Future<Object?> invoker(String _, Map<String, dynamic> __) async {
        calls += 1;
        return createEventResponse();
      }

      final invalidFields = <EventEditableFields>[
        eventFieldsFixture(startsAt: DateTime(2026, 6, 18, 15, 30)),
        eventFieldsFixture(startsAt: DateTime.utc(10000, 1, 1)),
        eventFieldsFixture(capacity: 1),
        eventFieldsFixture(capacity: 51),
        eventFieldsFixture(levelMin: 'C1', levelMax: 'B1'),
        eventFieldsFixture(levelMin: 'D1'),
        eventFieldsFixture(countryCode: 'RUS'),
        eventFieldsFixture(cityKey: 'Moscow'),
        eventFieldsFixture(locationGeoPoint: const LatLng(91, 37.6156)),
        eventFieldsFixture(locationGeoPoint: LatLng(double.nan, 37.6156)),
      ];

      for (final fields in invalidFields) {
        await expectLater(
          EventActionsRepository.createEvent(
            createRequestId: '550e8400-e29b-41d4-a716-446655440000',
            fields: fields,
            invoker: invoker,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
      expect(calls, 0);
    });

    test('passes callable errors through unchanged', () async {
      final error = StateError('callable failed');

      await expectLater(
        EventActionsRepository.joinEvent(
          eventId: 'event-1',
          invoker: (_, __) => Future<Object?>.error(error),
        ),
        throwsA(same(error)),
      );
    });

    test('throws on malformed success responses', () async {
      await expectLater(
        EventActionsRepository.cancelEvent(
          eventId: 'event-1',
          invoker: (_, __) async => <String, dynamic>{
            'eventId': 'event-1',
            'status': 'canceled',
          },
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        EventActionsRepository.cancelEvent(
          eventId: 'event-1',
          invoker: (_, __) async => <Object?, Object?>{
            1: 'event-1',
            'status': 'canceled',
            'canceledAt': '2026-06-14T12:00:00.000Z',
          },
        ),
        throwsA(isA<FormatException>()),
      );
      for (final canceledAt in <String>[
        '2026-06-14T12:00:00Z',
        '2026-06-14T12:00:00.000+00:00',
        '2026-06-14T12:00:00.000000Z',
      ]) {
        await expectLater(
          EventActionsRepository.cancelEvent(
            eventId: 'event-1',
            invoker: (_, __) async => <String, dynamic>{
              'eventId': 'event-1',
              'status': 'canceled',
              'canceledAt': canceledAt,
            },
          ),
          throwsA(isA<FormatException>()),
        );
      }
      await expectLater(
        EventActionsRepository.cancelEvent(
          eventId: 'event-1',
          invoker: (_, __) async => <String, dynamic>{
            'eventId': 'event-1',
            'status': 'active',
            'canceledAt': '2026-06-14T12:00:00.000Z',
          },
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        EventActionsRepository.joinEvent(
          eventId: 'event-1',
          invoker: (_, __) async => <String, dynamic>{
            'eventId': 'event-1',
            'participantStatus': 'left',
            'participantsCount': 6,
            'joinedAt': '2026-06-14T12:01:00.000Z',
          },
        ),
        throwsA(isA<FormatException>()),
      );
    });

    test('generates UUID v4 create request ids', () {
      expect(
        normalizeEventCreateRequestId(newEventCreateRequestId()),
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });
  });
}

EventEditableFields eventFieldsFixture({
  DateTime? startsAt,
  LatLng? locationGeoPoint,
  String levelMin = 'B1',
  String levelMax = 'C1',
  String countryCode = 'RU',
  String cityKey = 'moscow',
  int capacity = 10,
}) =>
    EventEditableFields(
      title: 'Conversation club',
      description: 'Casual practice',
      languageCode: 'en',
      levelMin: levelMin,
      levelMax: levelMax,
      countryCode: countryCode,
      cityKey: cityKey,
      locationName: 'Starbucks, Arbat 5',
      locationGeoPoint: locationGeoPoint,
      startsAt: startsAt ?? DateTime.parse('2026-06-18T15:30:45Z'),
      capacity: capacity,
    );

Map<String, dynamic> createEventResponse() => <String, dynamic>{
      'eventId': 'event-1',
      'createdAt': '2026-06-14T10:00:00.000Z',
      'dailyCreation': <String, dynamic>{
        'dayKeyUtc': '2026-06-14',
        'count': 2,
        'remaining': 3,
        'resetAtUtc': '2026-06-15T00:00:00.000Z',
      },
    };
