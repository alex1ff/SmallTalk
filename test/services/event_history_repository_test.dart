import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/services/event_history_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EventHistoryRepository', () {
    test('loads event history through the trusted callable', () async {
      String? functionName;
      Map<String, dynamic>? payload;

      final result = await EventHistoryRepository.loadEventHistory(
        limit: 50,
        invoker: (calledFunctionName, calledPayload) async {
          functionName = calledFunctionName;
          payload = calledPayload;
          return historyResponse();
        },
      );

      expect(functionName, getEventHistoryFunctionName);
      expect(payload, <String, dynamic>{'limit': 50});
      expect(result.limit, 50);
      expect(result.generatedAt, DateTime.parse('2026-06-16T10:00:00.000Z'));
      expect(result.items, hasLength(2));
      expect(result.items.first.eventId, 'event-1');
      expect(result.items.first.title, 'Conversation club');
      expect(
        result.items.first.startsAt,
        DateTime.parse('2026-06-20T10:00:00.000Z'),
      );
      expect(result.items.first.timeZoneId, 'Europe/Moscow');
      expect(result.items.first.status, 'active');
      expect(result.items.first.participantRole, 'participant');
      expect(result.items.first.participantStatus, 'active');
      expect(result.items.first.isOrganizer, false);
      expect(
        result.items.first.timelineStatus,
        EventHistoryTimelineStatus.upcoming,
      );
      expect(result.items.first.locationName, 'Starbucks, Arbat 5');
      expect(result.items.first.cityNameRu, 'Москва');
      expect(result.items.first.languageNameRu, 'Английский');
      expect(result.items.first.levelMin, 'B1');
      expect(result.items.first.levelMax, 'C1');
      expect(result.items.first.description, 'Meet and practice English.');
      expect(result.items.first.organizerDisplayName, 'Organizer');
      expect(result.items.first.organizerPhotoUrl, 'https://img/organizer');
      expect(result.items.first.participantsCount, 3);
      expect(result.items.first.capacity, 10);
      expect(result.items.last.eventId, 'event-2');
      expect(result.items.last.isOrganizer, true);
      expect(result.items.last.timelineStatus, EventHistoryTimelineStatus.past);
      expect(result.items.last.locationName, isNull);
    });

    test('rejects invalid limit before calling function', () async {
      var calls = 0;

      expect(
        () => normalizeEventHistoryLimit(0),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => normalizeEventHistoryLimit(51),
        throwsA(isA<ArgumentError>()),
      );
      await expectLater(
        EventHistoryRepository.loadEventHistory(
          limit: 0,
          invoker: (_, __) async {
            calls += 1;
            return historyResponse();
          },
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(calls, 0);
    });

    test('rejects malformed callable responses', () async {
      await expectLater(
        EventHistoryRepository.loadEventHistory(
          invoker: (_, __) async => <String, dynamic>{
            'items': <dynamic>[],
            'limit': 20,
            'generatedAt': '2026-06-16T10:00:00Z',
          },
        ),
        throwsA(isA<FormatException>()),
      );

      await expectLater(
        EventHistoryRepository.loadEventHistory(
          invoker: (_, __) async => historyResponse(
            itemOverrides: <String, dynamic>{
              'timelineStatus': 'deleted',
            },
          ),
        ),
        throwsA(isA<FormatException>()),
      );
    });
  });
}

Map<String, dynamic> historyResponse({
  Map<String, dynamic>? itemOverrides,
}) =>
    <String, dynamic>{
      'items': <Map<String, dynamic>>[
        <String, dynamic>{
          'eventId': 'event-1',
          'title': 'Conversation club',
          'startsAt': '2026-06-20T10:00:00.000Z',
          'timeZoneId': 'Europe/Moscow',
          'status': 'active',
          'canceledAt': null,
          'participantRole': 'participant',
          'participantStatus': 'active',
          'joinedAt': '2026-06-10T10:00:00.000Z',
          'leftAt': null,
          'timelineStatus': 'upcoming',
          'locationName': 'Starbucks, Arbat 5',
          'countryCode': 'RU',
          'cityKey': 'moscow',
          'cityNameEn': 'Moscow',
          'cityNameRu': 'Москва',
          'languageCode': 'en',
          'languageNameEn': 'English',
          'languageNameRu': 'Английский',
          'levelMin': 'B1',
          'levelMax': 'C1',
          'description': 'Meet and practice English.',
          'organizerDisplayName': 'Organizer',
          'organizerPhotoUrl': 'https://img/organizer',
          'participantsCount': 3,
          'capacity': 10,
          ...?itemOverrides,
        },
        <String, dynamic>{
          'eventId': 'event-2',
          'title': 'Past organizer event',
          'startsAt': '2026-06-01T10:00:00.000Z',
          'timeZoneId': 'Europe/Moscow',
          'status': 'active',
          'canceledAt': null,
          'participantRole': 'organizer',
          'participantStatus': 'active',
          'joinedAt': '2026-05-20T10:00:00.000Z',
          'leftAt': null,
          'timelineStatus': 'past',
          'locationName': '',
          'countryCode': 'RU',
          'cityKey': 'moscow',
          'cityNameEn': null,
          'cityNameRu': null,
          'languageCode': null,
          'languageNameEn': null,
          'languageNameRu': null,
          'levelMin': null,
          'levelMax': null,
          'description': null,
          'organizerDisplayName': null,
          'organizerPhotoUrl': null,
          'participantsCount': null,
          'capacity': null,
        },
      ],
      'limit': 50,
      'generatedAt': '2026-06-16T10:00:00.000Z',
    };
