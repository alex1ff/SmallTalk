import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const nearbyPartnerPreviewPrefsPrefix = 'ff_student_nearby_partner_preview_v2';

String nearbyPartnerPreviewCacheKey({
  required String languageCode,
  required String countryCode,
  String cityKey = '',
  required String partnerLevel,
  String userScope = '',
}) {
  String normalize(String value) => value.trim().toLowerCase();

  return <String>[
    nearbyPartnerPreviewPrefsPrefix,
    Uri.encodeComponent(normalize(userScope)),
    Uri.encodeComponent(normalize(languageCode)),
    Uri.encodeComponent(normalize(countryCode)),
    Uri.encodeComponent(normalize(cityKey)),
    Uri.encodeComponent(normalize(partnerLevel)),
  ].join('|');
}

class NearbyPartnerPreviewEntry {
  const NearbyPartnerPreviewEntry({
    required this.displayName,
    required this.photoUrl,
  });

  final String displayName;
  final String photoUrl;

  Map<String, String> toJson() => <String, String>{
        'displayName': displayName.trim(),
        'photoUrl': photoUrl.trim(),
      };

  static NearbyPartnerPreviewEntry? fromJson(Object? value) {
    if (value is! Map) {
      return null;
    }

    final displayName = value['displayName'];
    final photoUrl = value['photoUrl'];
    if (displayName is! String || photoUrl is! String) {
      return null;
    }

    return NearbyPartnerPreviewEntry(
      displayName: displayName.trim(),
      photoUrl: photoUrl.trim(),
    );
  }
}

class NearbyPartnerPreviewCache {
  const NearbyPartnerPreviewCache(
    this._preferences, {
    this.maxEntries = 6,
  });

  final SharedPreferences _preferences;
  final int maxEntries;

  List<NearbyPartnerPreviewEntry>? read(String key) {
    try {
      final rawValue = _preferences.getString(key);
      if (rawValue == null) {
        return null;
      }

      final decodedValue = jsonDecode(rawValue);
      if (decodedValue is! List) {
        return null;
      }

      final entries = <NearbyPartnerPreviewEntry>[];
      for (final value in decodedValue.take(maxEntries)) {
        final entry = NearbyPartnerPreviewEntry.fromJson(value);
        if (entry == null) {
          return null;
        }
        entries.add(entry);
      }
      return entries;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(
    String key,
    List<NearbyPartnerPreviewEntry> entries,
  ) async {
    final encodedEntries = entries
        .take(maxEntries)
        .map((entry) => entry.toJson())
        .toList(growable: false);
    await _preferences.setString(key, jsonEncode(encodedEntries));
  }
}
