import 'dart:collection';

typedef EventListCacheInvalidator = void Function();
typedef EventListCreatedEventSeeder = void Function(
  EventListCreatedEventSeed seed,
);

class EventListCreatedEventSeed {
  const EventListCreatedEventSeed({
    required this.eventId,
    required this.ownerUserId,
    required this.countryCode,
    required this.cityKey,
    required this.title,
    required this.description,
    required this.languageCode,
    required this.levelMin,
    required this.levelMax,
    required this.startsAt,
    required this.timeZoneId,
    required this.organizerDisplayName,
    required this.capacity,
    this.languageNameEn,
    this.languageNameRu,
    this.organizerPhotoUrl,
  });

  final String eventId;
  final String ownerUserId;
  final String countryCode;
  final String cityKey;
  final String title;
  final String description;
  final String languageCode;
  final String? languageNameEn;
  final String? languageNameRu;
  final String levelMin;
  final String levelMax;
  final DateTime startsAt;
  final String timeZoneId;
  final String organizerDisplayName;
  final String? organizerPhotoUrl;
  final int capacity;
}

final class EventListCacheInvalidation {
  const EventListCacheInvalidation._();

  static final LinkedHashSet<EventListCacheInvalidator> _invalidators =
      LinkedHashSet<EventListCacheInvalidator>();
  static final LinkedHashSet<EventListCreatedEventSeeder> _createdEventSeeders =
      LinkedHashSet<EventListCreatedEventSeeder>();

  static void register(EventListCacheInvalidator invalidator) {
    _invalidators.add(invalidator);
  }

  static void unregister(EventListCacheInvalidator invalidator) {
    _invalidators.remove(invalidator);
  }

  static void registerCreatedEventSeeder(EventListCreatedEventSeeder seeder) {
    _createdEventSeeders.add(seeder);
  }

  static void unregisterCreatedEventSeeder(
    EventListCreatedEventSeeder seeder,
  ) {
    _createdEventSeeders.remove(seeder);
  }

  static void invalidate() {
    for (final invalidator in List<EventListCacheInvalidator>.of(
      _invalidators,
    )) {
      invalidator();
    }
  }

  static void seedCreatedEvent(EventListCreatedEventSeed seed) {
    for (final seeder in List<EventListCreatedEventSeeder>.of(
      _createdEventSeeders,
    )) {
      seeder(seed);
    }
  }
}
