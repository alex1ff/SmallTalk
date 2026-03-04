import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'flutter_flow/flutter_flow_util.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {
    prefs = await SharedPreferences.getInstance();
    await _loadDefaultLanguagesFromAsset();
    _safeInit(() {
      _languagesList = prefs
              .getStringList('ff_languagesList')
              ?.map((x) {
                try {
                  return LanguageStruct.fromSerializableMap(jsonDecode(x));
                } catch (e) {
                  print("Can't decode persisted data type. Error: $e.");
                  return null;
                }
              })
              .withoutNulls
              .toList() ??
          _languagesList;
    });
    _safeInit(() {
      _isNativeSpeaker =
          prefs.getBool('ff_isNativeSpeaker') ?? _isNativeSpeaker;
    });
  }

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  late SharedPreferences prefs;

  String _activeSessionId = '';
  String get activeSessionId => _activeSessionId;
  set activeSessionId(String value) {
    _activeSessionId = value;
  }

  static const String _languagesCatalogAssetPath =
      'assets/jsons/languages_catalog.json';
  static final List<LanguageStruct> _fallbackLanguagesCatalog = [
    LanguageStruct(
      code: 'en',
      alternateCodes: const ['en'],
      nameEn: 'English',
      nameRu: 'Английский',
      model: 'nova-3',
      isPopular: true,
      ss: 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/bx7mblqvphr9/English.png',
    ),
    LanguageStruct(
      code: 'ru',
      alternateCodes: const ['ru'],
      nameEn: 'Russian',
      nameRu: 'Русский',
      model: 'nova-3',
      isPopular: true,
      ss: 'https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/f259oh3qfmmi/Russian.png',
    ),
  ];
  List<LanguageStruct> _languagesList = [];
  List<LanguageStruct> get languagesList => _languagesList;
  set languagesList(List<LanguageStruct> value) {
    _languagesList = value;
    prefs.setStringList(
        'ff_languagesList', value.map((x) => x.serialize()).toList());
  }

  Future<void> _loadDefaultLanguagesFromAsset() async {
    try {
      final rawCatalog =
          await rootBundle.loadString(_languagesCatalogAssetPath);
      final decodedCatalog = jsonDecode(rawCatalog);
      if (decodedCatalog is! List) return;

      final parsedLanguages = decodedCatalog
          .whereType<Map>()
          .map(
              (item) => LanguageStruct.fromMap(Map<String, dynamic>.from(item)))
          .where((language) => language.code.isNotEmpty)
          .toList(growable: false);

      if (parsedLanguages.isNotEmpty) {
        _languagesList = List<LanguageStruct>.from(parsedLanguages);
      } else if (_languagesList.isEmpty) {
        _languagesList = List<LanguageStruct>.from(_fallbackLanguagesCatalog);
      }
    } catch (e) {
      debugPrint('FFAppState: Failed to load language catalog asset: $e');
      if (_languagesList.isEmpty) {
        _languagesList = List<LanguageStruct>.from(_fallbackLanguagesCatalog);
      }
    }
  }

  void addToLanguagesList(LanguageStruct value) {
    languagesList.add(value);
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  void removeFromLanguagesList(LanguageStruct value) {
    languagesList.remove(value);
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromLanguagesList(int index) {
    languagesList.removeAt(index);
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  void updateLanguagesListAtIndex(
    int index,
    LanguageStruct Function(LanguageStruct) updateFn,
  ) {
    languagesList[index] = updateFn(_languagesList[index]);
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInLanguagesList(int index, LanguageStruct value) {
    languagesList.insert(index, value);
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  bool _isNativeSpeaker = false;
  bool get isNativeSpeaker => _isNativeSpeaker;
  set isNativeSpeaker(bool value) {
    _isNativeSpeaker = value;
    prefs.setBool('ff_isNativeSpeaker', value);
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}
