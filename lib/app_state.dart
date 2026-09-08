import 'package:flutter/material.dart';
import '/authorization/shared/pending_social_auth_context.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
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

  static const _pendingSocialAuthContextKey = 'ff_pendingSocialAuthContext';

  Future initializePersistedState() async {
    final preferencesFuture = SharedPreferences.getInstance();
    final languagesCatalogFuture = _loadDefaultLanguagesFromAsset();

    prefs = await preferencesFuture;
    await languagesCatalogFuture;
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
      _bumpLanguagesListRevision();
    });
    _safeInit(() {
      _isNativeSpeaker =
          prefs.getBool('ff_isNativeSpeaker') ?? _isNativeSpeaker;
    });
    _safeInit(() {
      final serializedContext = prefs.getString(_pendingSocialAuthContextKey);
      if (serializedContext == null || serializedContext.isEmpty) {
        return;
      }
      _pendingSocialAuthContext =
          PendingSocialAuthContext.maybeFromMap(jsonDecode(serializedContext));
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
  int _languagesListRevision = 0;
  List<LanguageStruct> get languagesList => _languagesList;
  int get languagesListRevision => _languagesListRevision;
  set languagesList(List<LanguageStruct> value) {
    _languagesList = value;
    _bumpLanguagesListRevision();
    prefs.setStringList(
        'ff_languagesList', value.map((x) => x.serialize()).toList());
  }

  void _bumpLanguagesListRevision() {
    _languagesListRevision += 1;
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
        _bumpLanguagesListRevision();
      } else if (_languagesList.isEmpty) {
        _languagesList = List<LanguageStruct>.from(_fallbackLanguagesCatalog);
        _bumpLanguagesListRevision();
      }
    } catch (e) {
      debugPrint('FFAppState: Failed to load language catalog asset: $e');
      if (_languagesList.isEmpty) {
        _languagesList = List<LanguageStruct>.from(_fallbackLanguagesCatalog);
        _bumpLanguagesListRevision();
      }
    }
  }

  void addToLanguagesList(LanguageStruct value) {
    languagesList.add(value);
    _bumpLanguagesListRevision();
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  void removeFromLanguagesList(LanguageStruct value) {
    languagesList.remove(value);
    _bumpLanguagesListRevision();
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  void removeAtIndexFromLanguagesList(int index) {
    languagesList.removeAt(index);
    _bumpLanguagesListRevision();
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  void updateLanguagesListAtIndex(
    int index,
    LanguageStruct Function(LanguageStruct) updateFn,
  ) {
    languagesList[index] = updateFn(_languagesList[index]);
    _bumpLanguagesListRevision();
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  void insertAtIndexInLanguagesList(int index, LanguageStruct value) {
    languagesList.insert(index, value);
    _bumpLanguagesListRevision();
    prefs.setStringList(
        'ff_languagesList', _languagesList.map((x) => x.serialize()).toList());
  }

  bool _isNativeSpeaker = false;
  bool get isNativeSpeaker => _isNativeSpeaker;
  set isNativeSpeaker(bool value) {
    _isNativeSpeaker = value;
    prefs.setBool('ff_isNativeSpeaker', value);
  }

  PendingSocialAuthContext? _pendingSocialAuthContext;
  PendingSocialAuthContext? get pendingSocialAuthContext =>
      _pendingSocialAuthContext;
  set pendingSocialAuthContext(PendingSocialAuthContext? value) {
    _pendingSocialAuthContext = value;
    if (value == null) {
      prefs.remove(_pendingSocialAuthContextKey);
      return;
    }
    prefs.setString(
      _pendingSocialAuthContextKey,
      jsonEncode(value.toSerializableMap()),
    );
  }

  void setPendingSocialAuthContext({
    required String providerId,
    required String sourceScreen,
    required UserRole roleIntent,
    String? authUid,
  }) {
    pendingSocialAuthContext = PendingSocialAuthContext(
      providerId: providerId,
      sourceScreen: sourceScreen,
      roleIntent: roleIntent,
      createdAt: DateTime.now(),
      authUid: authUid,
    );
  }

  void attachPendingSocialAuthUid(String authUid) {
    final currentContext = _pendingSocialAuthContext;
    if (currentContext == null) {
      return;
    }
    pendingSocialAuthContext = currentContext.copyWith(authUid: authUid);
  }

  PendingSocialAuthContext? getValidPendingSocialAuthContext({
    String? currentAuthUid,
    DateTime? now,
  }) {
    final currentContext = _pendingSocialAuthContext;
    if (currentContext == null) {
      return null;
    }
    if (!currentContext.isValidFor(
      currentAuthUid: currentAuthUid,
      now: now,
    )) {
      clearPendingSocialAuthContext();
      return null;
    }
    return currentContext;
  }

  void clearPendingSocialAuthContext() {
    pendingSocialAuthContext = null;
  }
}

void _safeInit(Function() initializeField) {
  try {
    initializeField();
  } catch (_) {}
}
