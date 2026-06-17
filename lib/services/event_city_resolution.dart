import '/backend/backend.dart';
import 'event_city_catalog.dart';

enum EventCityResolutionStatus {
  resolved,
  missingProfileCity,
  staleCatalogVersion,
  invalidIdentity,
  unknownCatalogCity,
}

class EventCityResolutionResult {
  const EventCityResolutionResult._({
    required this.status,
    this.city,
  });

  final EventCityResolutionStatus status;
  final EventCity? city;

  bool get hasResolvedCity =>
      status == EventCityResolutionStatus.resolved && city != null;
}

EventCityResolutionResult resolveSelectedEventCityFromUserProfile({
  required UsersRecord? user,
  required EventCityCatalog catalog,
}) {
  return resolveSelectedEventCityFromProfileCity(
    profileCity:
        user != null && user.hasProfileCity() ? user.profileCity : null,
    catalog: catalog,
  );
}

EventCityResolutionResult resolveSelectedEventCityFromProfileCity({
  required ProfileCityStruct? profileCity,
  required EventCityCatalog catalog,
}) {
  if (profileCity == null ||
      !profileCity.hasCountryCode() ||
      !profileCity.hasCityKey() ||
      profileCity.countryCode.trim().isEmpty ||
      profileCity.cityKey.trim().isEmpty) {
    return const EventCityResolutionResult._(
      status: EventCityResolutionStatus.missingProfileCity,
    );
  }

  if (!profileCity.hasCatalogVersion() ||
      profileCity.catalogVersion.trim() != catalog.catalogVersion) {
    return const EventCityResolutionResult._(
      status: EventCityResolutionStatus.staleCatalogVersion,
    );
  }

  final identity = normalizeEventCityIdentity(
    profileCity.countryCode,
    profileCity.cityKey,
  );
  if (identity == null) {
    return const EventCityResolutionResult._(
      status: EventCityResolutionStatus.invalidIdentity,
    );
  }

  final city = catalog.resolve(identity.countryCode, identity.cityKey);
  if (city == null) {
    return const EventCityResolutionResult._(
      status: EventCityResolutionStatus.unknownCatalogCity,
    );
  }

  return EventCityResolutionResult._(
    status: EventCityResolutionStatus.resolved,
    city: city,
  );
}
