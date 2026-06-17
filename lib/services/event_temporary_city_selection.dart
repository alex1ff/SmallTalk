import 'event_city_catalog.dart';
import 'event_city_chip_source.dart';
import 'event_city_selection_source.dart';
import 'event_selected_city_state.dart';

/// Handles non-profile Events city choices.
///
/// This service returns an in-memory selected-city input and may update the
/// local recent-city store. It must not persist `users.profileCity`; explicit
/// profile persistence belongs to ProfileCitySaveService.
class EventTemporaryCitySelectionService {
  const EventTemporaryCitySelectionService({
    required EventCityChipSource chipSource,
  }) : _chipSource = chipSource;

  final EventCityChipSource _chipSource;

  Future<EventSelectedCityInput> selectCity({
    required EventCity city,
    required EventCitySelectionSource source,
  }) async {
    if (source == EventCitySelectionSource.profile) {
      throw ArgumentError.value(
        source,
        'source',
        'Temporary Events city selection cannot use profile source.',
      );
    }

    await _chipSource.recordSelection(city: city);
    return EventSelectedCityInput(
      countryCode: city.countryCode,
      cityKey: city.cityKey,
      source: source,
    );
  }
}
