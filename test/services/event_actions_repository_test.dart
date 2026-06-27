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

    test('accepts create validation boundary fields before calling function',
        () async {
      final calls = <Map<String, dynamic>>[];
      Future<Object?> invoker(
          String functionName, Map<String, dynamic> payload) async {
        expect(functionName, createEventFunctionName);
        calls.add(payload);
        return createEventResponse();
      }

      final validCases = <({
        String name,
        EventEditableFields fields,
        int expectedCapacity,
        Map<String, dynamic>? expectedGeo,
      })>[
        (
          name: 'minimum capacity',
          fields: eventFieldsFixture(capacity: 2),
          expectedCapacity: 2,
          expectedGeo: null,
        ),
        (
          name: 'maximum capacity',
          fields: eventFieldsFixture(capacity: 50),
          expectedCapacity: 50,
          expectedGeo: null,
        ),
        (
          name: 'nullable geo',
          fields: eventFieldsFixture(locationGeoPoint: null),
          expectedCapacity: 10,
          expectedGeo: null,
        ),
        (
          name: 'southwest geo boundary',
          fields: eventFieldsFixture(
            locationGeoPoint: const LatLng(-90, -180),
          ),
          expectedCapacity: 10,
          expectedGeo: <String, dynamic>{
            'latitude': -90.0,
            'longitude': -180.0,
          },
        ),
        (
          name: 'northeast geo boundary',
          fields: eventFieldsFixture(
            locationGeoPoint: const LatLng(90, 180),
          ),
          expectedCapacity: 10,
          expectedGeo: <String, dynamic>{
            'latitude': 90.0,
            'longitude': 180.0,
          },
        ),
      ];

      for (final currentCase in validCases) {
        await EventActionsRepository.createEvent(
          createRequestId: '550e8400-e29b-41d4-a716-446655440000',
          fields: currentCase.fields,
          invoker: invoker,
        );

        final payload = calls.removeLast();
        expect(
          payload['capacity'],
          currentCase.expectedCapacity,
          reason: currentCase.name,
        );
        expect(
          payload['locationGeoPoint'],
          currentCase.expectedGeo,
          reason: currentCase.name,
        );
      }
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

    test('loads event chat access state through the trusted callable',
        () async {
      final calls = <String, Map<String, dynamic>>{};

      final activeResult = await EventActionsRepository.getEventChatAccessState(
        eventId: ' event-1 ',
        invoker: (functionName, payload) async {
          calls['active'] = <String, dynamic>{
            'functionName': functionName,
            'payload': payload,
          };
          return <String, dynamic>{
            'eventId': 'event-1',
            'status': 'active',
            'readOnly': false,
          };
        },
      );
      final canceledResult =
          await EventActionsRepository.getEventChatAccessState(
        eventId: 'event-1',
        invoker: (functionName, payload) async {
          calls['canceled'] = <String, dynamic>{
            'functionName': functionName,
            'payload': payload,
          };
          return <String, dynamic>{
            'eventId': 'event-1',
            'status': 'canceled',
            'readOnly': true,
          };
        },
      );

      expect(calls, <String, Map<String, dynamic>>{
        'active': <String, dynamic>{
          'functionName': getEventChatAccessStateFunctionName,
          'payload': <String, dynamic>{'eventId': 'event-1'},
        },
        'canceled': <String, dynamic>{
          'functionName': getEventChatAccessStateFunctionName,
          'payload': <String, dynamic>{'eventId': 'event-1'},
        },
      });
      expect(activeResult.status, 'active');
      expect(activeResult.readOnly, false);
      expect(canceledResult.status, 'canceled');
      expect(canceledResult.readOnly, true);
    });

    test('reports an event through the trusted callable', () async {
      String? functionName;
      Map<String, dynamic>? payload;

      final result = await EventActionsRepository.reportEvent(
        eventId: ' event-1 ',
        reasonCode: ' UNSAFE ',
        details: '  Небезопасное место встречи  ',
        invoker: (calledFunctionName, calledPayload) async {
          functionName = calledFunctionName;
          payload = calledPayload;
          return <String, dynamic>{
            'eventId': 'event-1',
            'reportId': 'report-1',
            'status': 'submitted',
            'reportedAt': '2026-06-16T10:00:00.000Z',
          };
        },
      );

      expect(functionName, reportEventFunctionName);
      expect(payload, <String, dynamic>{
        'eventId': 'event-1',
        'reasonCode': 'unsafe',
        'details': 'Небезопасное место встречи',
      });
      expect(result.eventId, 'event-1');
      expect(result.reportId, 'report-1');
      expect(result.status, 'submitted');
      expect(result.alreadySubmitted, isFalse);
      expect(result.reportedAt, DateTime.parse('2026-06-16T10:00:00Z'));
    });

    test('reports duplicate events idempotently without empty details',
        () async {
      String? functionName;
      Map<String, dynamic>? payload;

      final result = await EventActionsRepository.reportEvent(
        eventId: 'event-1',
        reasonCode: 'spam',
        details: '   ',
        invoker: (calledFunctionName, calledPayload) async {
          functionName = calledFunctionName;
          payload = calledPayload;
          return <String, dynamic>{
            'eventId': 'event-1',
            'reportId': 'report-1',
            'status': 'already_submitted',
            'reportedAt': '2026-06-16T10:00:00.000Z',
          };
        },
      );

      expect(functionName, reportEventFunctionName);
      expect(payload, <String, dynamic>{
        'eventId': 'event-1',
        'reasonCode': 'spam',
      });
      expect(result.alreadySubmitted, isTrue);
    });

    test('reports an event chat message through the trusted callable',
        () async {
      String? functionName;
      Map<String, dynamic>? payload;

      final result = await EventActionsRepository.reportEventChatMessage(
        eventId: ' event-1 ',
        messageId: ' message-1 ',
        reasonCode: ' OFFENSIVE ',
        details: '  Оскорбительное сообщение  ',
        invoker: (calledFunctionName, calledPayload) async {
          functionName = calledFunctionName;
          payload = calledPayload;
          return <String, dynamic>{
            'eventId': 'event-1',
            'messageId': 'message-1',
            'reportId': 'report-1',
            'status': 'submitted',
            'reportedAt': '2026-06-16T10:00:00.000Z',
          };
        },
      );

      expect(functionName, reportEventChatMessageFunctionName);
      expect(payload, <String, dynamic>{
        'eventId': 'event-1',
        'messageId': 'message-1',
        'reasonCode': 'offensive',
        'details': 'Оскорбительное сообщение',
      });
      expect(result.eventId, 'event-1');
      expect(result.messageId, 'message-1');
      expect(result.reportId, 'report-1');
      expect(result.status, 'submitted');
      expect(result.alreadySubmitted, isFalse);
      expect(result.reportedAt, DateTime.parse('2026-06-16T10:00:00Z'));
    });

    test('reports duplicate event chat messages idempotently', () async {
      final result = await EventActionsRepository.reportEventChatMessage(
        eventId: 'event-1',
        messageId: 'message-1',
        reasonCode: 'spam',
        details: '   ',
        invoker: (calledFunctionName, calledPayload) async {
          expect(calledFunctionName, reportEventChatMessageFunctionName);
          expect(calledPayload, <String, dynamic>{
            'eventId': 'event-1',
            'messageId': 'message-1',
            'reasonCode': 'spam',
          });
          return <String, dynamic>{
            'eventId': 'event-1',
            'messageId': 'message-1',
            'reportId': 'report-1',
            'status': 'already_submitted',
            'reportedAt': '2026-06-16T10:00:00.000Z',
          };
        },
      );

      expect(result.alreadySubmitted, isTrue);
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
      for (final reasonCode in <String>['', 'harassment', 'unsafe/event']) {
        await expectLater(
          EventActionsRepository.reportEvent(
            eventId: 'event-1',
            reasonCode: reasonCode,
            invoker: invoker,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
      for (final messageId in <String>['', ' ', 'messages/message-1']) {
        await expectLater(
          EventActionsRepository.reportEventChatMessage(
            eventId: 'event-1',
            messageId: messageId,
            reasonCode: 'spam',
            invoker: invoker,
          ),
          throwsA(isA<ArgumentError>()),
        );
      }
      await expectLater(
        EventActionsRepository.reportEvent(
          eventId: 'event-1',
          reasonCode: 'spam',
          details: 'a' * 501,
          invoker: invoker,
        ),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        EventActionsRepository.reportEventChatMessage(
          eventId: 'event-1',
          messageId: 'message-1',
          reasonCode: 'other',
          details: 'a' * 501,
          invoker: invoker,
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(calls, 0);
    });

    test('rejects invalid editable fields before calling functions', () async {
      var calls = 0;
      Future<Object?> invoker(String _, Map<String, dynamic> __) async {
        calls += 1;
        return createEventResponse();
      }

      final invalidFields = <({String name, EventEditableFields fields})>[
        (
          name: 'non-UTC startsAt',
          fields: eventFieldsFixture(startsAt: DateTime(2026, 6, 18, 15, 30)),
        ),
        (
          name: 'five-digit startsAt year',
          fields: eventFieldsFixture(startsAt: DateTime.utc(10000, 1, 1)),
        ),
        (
          name: 'capacity below minimum',
          fields: eventFieldsFixture(capacity: 1),
        ),
        (
          name: 'capacity above maximum',
          fields: eventFieldsFixture(capacity: 51),
        ),
        (
          name: 'reversed level range',
          fields: eventFieldsFixture(levelMin: 'C1', levelMax: 'B1'),
        ),
        (name: 'unknown level', fields: eventFieldsFixture(levelMin: 'D1')),
        (
          name: 'invalid country code',
          fields: eventFieldsFixture(countryCode: 'RUS'),
        ),
        (
          name: 'invalid city key',
          fields: eventFieldsFixture(cityKey: 'Moscow'),
        ),
        (
          name: 'latitude above range',
          fields:
              eventFieldsFixture(locationGeoPoint: const LatLng(91, 37.6156)),
        ),
        (
          name: 'longitude below range',
          fields:
              eventFieldsFixture(locationGeoPoint: const LatLng(55.7522, -181)),
        ),
        (
          name: 'longitude above range',
          fields:
              eventFieldsFixture(locationGeoPoint: const LatLng(55.7522, 181)),
        ),
        (
          name: 'NaN latitude',
          fields:
              eventFieldsFixture(locationGeoPoint: LatLng(double.nan, 37.6156)),
        ),
        (
          name: 'infinite longitude',
          fields: eventFieldsFixture(
            locationGeoPoint: LatLng(55.7522, double.infinity),
          ),
        ),
      ];

      for (final currentCase in invalidFields) {
        await expectLater(
          EventActionsRepository.createEvent(
            createRequestId: '550e8400-e29b-41d4-a716-446655440000',
            fields: currentCase.fields,
            invoker: invoker,
          ),
          throwsA(isA<ArgumentError>()),
          reason: currentCase.name,
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

    test('throws on malformed create success responses', () async {
      final malformedResponses = <({String name, Object? response})>[
        (
          name: 'missing eventId',
          response: <String, dynamic>{
            'createdAt': '2026-06-14T10:00:00.000Z',
            'dailyCreation': dailyCreationResponse(),
          },
        ),
        (
          name: 'empty eventId',
          response: createEventResponse(eventId: ''),
        ),
        (
          name: 'non-millis createdAt',
          response: createEventResponse(createdAt: '2026-06-14T10:00:00Z'),
        ),
        (
          name: 'missing dailyCreation',
          response: <String, dynamic>{
            'eventId': 'event-1',
            'createdAt': '2026-06-14T10:00:00.000Z',
          },
        ),
        (
          name: 'non-map dailyCreation',
          response: createEventResponse(dailyCreation: 'invalid'),
        ),
        (
          name: 'non-int daily count',
          response: createEventResponse(
            dailyCreation: dailyCreationResponse(count: '2'),
          ),
        ),
        (
          name: 'non-int daily remaining',
          response: createEventResponse(
            dailyCreation: dailyCreationResponse(remaining: '3'),
          ),
        ),
        (
          name: 'bad daily reset timestamp',
          response: createEventResponse(
            dailyCreation: dailyCreationResponse(
              resetAtUtc: '2026-06-15T00:00:00Z',
            ),
          ),
        ),
      ];

      for (final currentCase in malformedResponses) {
        await expectLater(
          EventActionsRepository.createEvent(
            createRequestId: '550e8400-e29b-41d4-a716-446655440000',
            fields: eventFieldsFixture(),
            invoker: (_, __) async => currentCase.response,
          ),
          throwsA(isA<FormatException>()),
          reason: currentCase.name,
        );
      }
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
      await expectLater(
        EventActionsRepository.getEventChatAccessState(
          eventId: 'event-1',
          invoker: (_, __) async => <String, dynamic>{
            'eventId': 'event-1',
            'status': 'deleted',
            'readOnly': true,
          },
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        EventActionsRepository.getEventChatAccessState(
          eventId: 'event-1',
          invoker: (_, __) async => <String, dynamic>{
            'eventId': 'event-1',
            'status': 'canceled',
            'readOnly': 'yes',
          },
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        EventActionsRepository.reportEvent(
          eventId: 'event-1',
          reasonCode: 'spam',
          invoker: (_, __) async => <String, dynamic>{
            'eventId': 'event-1',
            'reportId': 'report-1',
            'status': 'open',
            'reportedAt': '2026-06-16T10:00:00.000Z',
          },
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        EventActionsRepository.reportEvent(
          eventId: 'event-1',
          reasonCode: 'spam',
          invoker: (_, __) async => <String, dynamic>{
            'eventId': 'event-1',
            'reportId': 'report-1',
            'status': 'submitted',
            'reportedAt': '2026-06-16T10:00:00Z',
          },
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        EventActionsRepository.reportEventChatMessage(
          eventId: 'event-1',
          messageId: 'message-1',
          reasonCode: 'spam',
          invoker: (_, __) async => <String, dynamic>{
            'eventId': 'event-1',
            'messageId': 'message-1',
            'reportId': 'report-1',
            'status': 'open',
            'reportedAt': '2026-06-16T10:00:00.000Z',
          },
        ),
        throwsA(isA<FormatException>()),
      );
      await expectLater(
        EventActionsRepository.reportEventChatMessage(
          eventId: 'event-1',
          messageId: 'message-1',
          reasonCode: 'spam',
          invoker: (_, __) async => <String, dynamic>{
            'eventId': 'event-1',
            'messageId': 'message-1',
            'reportId': 'report-1',
            'status': 'submitted',
            'reportedAt': '2026-06-16T10:00:00Z',
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

const _defaultDailyCreationSentinel = Object();

Map<String, dynamic> createEventResponse({
  Object? eventId = 'event-1',
  Object? createdAt = '2026-06-14T10:00:00.000Z',
  Object? dailyCreation = _defaultDailyCreationSentinel,
}) =>
    <String, dynamic>{
      'eventId': eventId,
      'createdAt': createdAt,
      'dailyCreation': identical(dailyCreation, _defaultDailyCreationSentinel)
          ? dailyCreationResponse()
          : dailyCreation,
    };

Map<String, dynamic> dailyCreationResponse({
  Object? dayKeyUtc = '2026-06-14',
  Object? count = 2,
  Object? remaining = 3,
  Object? resetAtUtc = '2026-06-15T00:00:00.000Z',
}) =>
    <String, dynamic>{
      'dayKeyUtc': dayKeyUtc,
      'count': count,
      'remaining': remaining,
      'resetAtUtc': resetAtUtc,
    };
