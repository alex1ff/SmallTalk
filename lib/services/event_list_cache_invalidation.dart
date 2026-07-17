import 'dart:collection';

typedef EventListCacheInvalidator = void Function();

final class EventListCacheInvalidation {
  const EventListCacheInvalidation._();

  static final LinkedHashSet<EventListCacheInvalidator> _invalidators =
      LinkedHashSet<EventListCacheInvalidator>();

  static void register(EventListCacheInvalidator invalidator) {
    _invalidators.add(invalidator);
  }

  static void unregister(EventListCacheInvalidator invalidator) {
    _invalidators.remove(invalidator);
  }

  static void invalidate() {
    for (final invalidator in List<EventListCacheInvalidator>.of(
      _invalidators,
    )) {
      invalidator();
    }
  }
}
