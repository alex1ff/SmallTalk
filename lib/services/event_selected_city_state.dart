import '/backend/backend.dart';
import 'event_city_catalog.dart';
import 'event_city_resolution.dart';
import 'event_city_selection_source.dart';

/// Session-only city selection for Events browsing.
///
/// Persisting a profile city must go through ProfileCitySaveService.
class EventSelectedCityInput {
  const EventSelectedCityInput({
    required this.countryCode,
    required this.cityKey,
    required this.source,
  });

  final String countryCode;
  final String cityKey;
  final EventCitySelectionSource source;
}

class EventSelectedCity {
  const EventSelectedCity({
    required this.city,
    required this.source,
  });

  final EventCity city;
  final EventCitySelectionSource source;

  Map<String, String> get analyticsPayload => <String, String>{
        'countryCode': city.countryCode,
        'cityKey': city.cityKey,
        'citySource': source.analyticsValue,
      };
}

class EventSelectedCityState {
  const EventSelectedCityState({
    required this.profileStatus,
    required this.countryCodeHint,
    this.selected,
  });

  final EventCityResolutionStatus profileStatus;
  final String? countryCodeHint;
  final EventSelectedCity? selected;

  bool get canLoadEvents => selected != null;
  bool get needsCitySelection => selected == null;
  bool get selectedFromProfile =>
      selected?.source == EventCitySelectionSource.profile;
  bool get selectedTemporarily => selected != null && !selectedFromProfile;
}

EventSelectedCityState resolveEventSelectedCityState({
  required UsersRecord? user,
  required EventCityCatalog catalog,
  EventSelectedCityInput? temporarySelection,
}) {
  final profileResult = resolveSelectedEventCityFromUserProfile(
    user: user,
    catalog: catalog,
  );
  final countryCodeHint = resolveEventCityCountryCodeHintFromUserProfile(
    user: user,
  );
  final temporaryCity = _resolveTemporarySelectedCity(
    temporarySelection,
    catalog,
  );

  if (temporaryCity != null) {
    return EventSelectedCityState(
      profileStatus: profileResult.status,
      countryCodeHint: countryCodeHint,
      selected: temporaryCity,
    );
  }

  final profileCity = profileResult.city;
  if (profileResult.status == EventCityResolutionStatus.resolved &&
      profileCity != null) {
    return EventSelectedCityState(
      profileStatus: profileResult.status,
      countryCodeHint: countryCodeHint,
      selected: EventSelectedCity(
        city: profileCity,
        source: EventCitySelectionSource.profile,
      ),
    );
  }

  return EventSelectedCityState(
    profileStatus: profileResult.status,
    countryCodeHint: countryCodeHint,
  );
}

EventSelectedCity? _resolveTemporarySelectedCity(
  EventSelectedCityInput? input,
  EventCityCatalog catalog,
) {
  if (input == null || input.source == EventCitySelectionSource.profile) {
    return null;
  }
  final city = catalog.resolve(input.countryCode, input.cityKey);
  if (city == null) {
    return null;
  }
  return EventSelectedCity(
    city: city,
    source: input.source,
  );
}
