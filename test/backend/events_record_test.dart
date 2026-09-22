import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:small_talk/backend/backend.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    setupFirebaseCoreMocks();
    await Firebase.initializeApp();
  });

  group('EventsRecord', () {
    const rejectedMvpEventStatuses = <String>[
      'draft',
      'past',
      'completed',
      'deleted',
      'archived',
      'cancelled',
      'unknown',
      'rescheduled',
    ];

    test('defines the MVP event status allowlist', () {
      expect(mvpEventStatuses, <String>{'active', 'canceled'});
      expect(isMvpEventStatus('active'), isTrue);
      expect(isMvpEventStatus('canceled'), isTrue);
      for (final status in rejectedMvpEventStatuses) {
        expect(isMvpEventStatus(status), isFalse, reason: status);
      }
      expect(isMvpEventStatus(null), isFalse);
    });

    test('parses the events document contract', () {
      final startsAt = DateTime.parse('2026-06-18T15:00:00Z');
      final createdAt = DateTime.parse('2026-06-14T10:00:00Z');
      final updatedAt = DateTime.parse('2026-06-15T11:30:00Z');
      final reference = EventsRecord.collection.doc('event-1');

      final event = EventsRecord.getDocumentFromData(
        {
          'title': 'Conversation club',
          'description': 'Casual English practice',
          'languageCode': 'en',
          'languageNameEn': 'English',
          'languageNameRu': 'Английский',
          'levelMin': 'B1',
          'levelMax': 'C1',
          'countryCode': 'RU',
          'cityKey': 'moscow',
          'cityNameRu': 'Москва',
          'cityNameEn': 'Moscow',
          'cityDisplayContext': 'Москва, Россия',
          'locationName': 'Starbucks, Arbat 5',
          'locationGeoPoint': const GeoPoint(55.7522, 37.6156),
          'startsAt': startsAt,
          'timeZoneId': 'Europe/Moscow',
          'capacity': 10,
          'participantsCount': 5,
          'organizerId': 'organizer-1',
          'organizerDisplayName': 'Anastasia Ivanova',
          'organizerPhotoUrl': 'https://example.com/avatar.jpg',
          'chatId': 'event-1',
          'status': 'active',
          'createdAt': createdAt,
          'updatedAt': updatedAt,
          'canceledAt': null,
        },
        reference,
      );

      expect(event.reference.path, 'events/event-1');
      expect(event.title, 'Conversation club');
      expect(event.description, 'Casual English practice');
      expect(event.languageCode, 'en');
      expect(event.languageNameEn, 'English');
      expect(event.languageNameRu, 'Английский');
      expect(event.levelMin, 'B1');
      expect(event.levelMax, 'C1');
      expect(event.countryCode, 'RU');
      expect(event.cityKey, 'moscow');
      expect(event.cityNameRu, 'Москва');
      expect(event.cityNameEn, 'Moscow');
      expect(event.cityDisplayContext, 'Москва, Россия');
      expect(event.locationName, 'Starbucks, Arbat 5');
      expect(event.locationGeoPoint, const LatLng(55.7522, 37.6156));
      expect(event.startsAt, startsAt);
      expect(event.timeZoneId, 'Europe/Moscow');
      expect(event.capacity, 10);
      expect(event.participantsCount, 5);
      expect(event.organizerId, 'organizer-1');
      expect(event.organizerDisplayName, 'Anastasia Ivanova');
      expect(event.organizerPhotoUrl, 'https://example.com/avatar.jpg');
      expect(event.chatId, 'event-1');
      expect(event.status, 'active');
      expect(event.createdAt, createdAt);
      expect(event.updatedAt, updatedAt);
      expect(event.canceledAt, isNull);
      expect(event.hasCanceledAt(), isFalse);
    });

    test('keeps nullable organizer photo and location unset', () {
      final event = EventsRecord.getDocumentFromData(
        {
          'title': 'Dinner',
          'description': 'Language practice',
          'languageCode': 'it',
          'languageNameEn': 'Italian',
          'languageNameRu': 'Итальянский',
          'levelMin': 'A1',
          'levelMax': 'B2',
          'countryCode': 'IT',
          'cityKey': 'rome',
          'cityNameRu': 'Рим',
          'cityNameEn': 'Rome',
          'cityDisplayContext': 'Рим, Италия',
          'locationName': 'La Cucina',
          'locationGeoPoint': null,
          'startsAt': DateTime.parse('2026-06-19T16:30:00Z'),
          'timeZoneId': 'Europe/Rome',
          'capacity': 8,
          'participantsCount': 1,
          'organizerId': 'organizer-2',
          'organizerDisplayName': 'Marco Rossi',
          'organizerPhotoUrl': null,
          'chatId': 'event-2',
          'status': 'active',
          'createdAt': DateTime.parse('2026-06-15T10:00:00Z'),
          'updatedAt': DateTime.parse('2026-06-15T10:00:00Z'),
          'canceledAt': null,
        },
        EventsRecord.collection.doc('event-2'),
      );

      expect(event.locationGeoPoint, isNull);
      expect(event.hasLocationGeoPoint(), isFalse);
      expect(event.organizerPhotoUrl, '');
      expect(event.hasOrganizerPhotoUrl(), isFalse);
    });

    test('serializes LatLng for Firestore writes', () {
      final data = createEventsRecordData(
        title: 'Conversation club',
        locationGeoPoint: const LatLng(55.7522, 37.6156),
        status: 'active',
      );

      expect(data['title'], 'Conversation club');
      expect(data['locationGeoPoint'], isA<GeoPoint>());
      expect((data['locationGeoPoint'] as GeoPoint).latitude, 55.7522);
      expect((data['locationGeoPoint'] as GeoPoint).longitude, 37.6156);
      expect(data['status'], 'active');
      expect(data.containsKey('canceledAt'), isFalse);

      final canceledAt = DateTime.parse('2026-06-14T12:00:00Z');
      final canceledData = createEventsRecordData(
        status: 'canceled',
        canceledAt: canceledAt,
      );

      expect(canceledData['status'], 'canceled');
      expect(canceledData['canceledAt'], canceledAt);
    });

    test('rejects non-MVP event statuses before Firestore writes', () {
      for (final status in rejectedMvpEventStatuses) {
        expect(
          () => validateMvpEventStatus(status),
          throwsA(isA<ArgumentError>()),
          reason: status,
        );
        expect(
          () => createEventsRecordData(status: status),
          throwsA(isA<ArgumentError>()),
          reason: status,
        );
      }
    });
  });
}
