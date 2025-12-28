import 'package:flutter/material.dart';
import '/backend/backend.dart';
import '/backend/schema/structs/index.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  List<LanguageStruct> _languagesList = [
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"en\",\"alternateCodes\":\"[\\\"en\\\",\\\"en-US\\\",\\\"en-AU\\\",\\\"en-GB\\\",\\\"en-IN\\\",\\\"en-NZ\\\"]\",\"nameEn\":\"English\",\"nameRu\":\"Английский\",\"flag\":\"🇬🇧\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/bx7mblqvphr9/English.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"ru\",\"alternateCodes\":\"[\\\"ru\\\"]\",\"nameEn\":\"Russian\",\"nameRu\":\"Русский\",\"flag\":\"🇷🇺\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/f259oh3qfmmi/Russian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"es\",\"alternateCodes\":\"[\\\"es\\\",\\\"es-419\\\"]\",\"nameEn\":\"Spanish\",\"nameRu\":\"Испанский\",\"flag\":\"🇪🇸\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/9smnot9vk6ry/Spanish.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"fr\",\"alternateCodes\":\"[\\\"fr\\\",\\\"fr-CA\\\"]\",\"nameEn\":\"French\",\"nameRu\":\"Французский\",\"flag\":\"🇫🇷\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/oz76j90jam1x/French.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"de\",\"alternateCodes\":\"[\\\"de\\\"]\",\"nameEn\":\"German\",\"nameRu\":\"Немецкий\",\"flag\":\"🇩🇪\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/njbzsox59j56/German.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"zh\",\"alternateCodes\":\"[\\\"zh\\\",\\\"zh-CN\\\",\\\"zh-Hans\\\"]\",\"nameEn\":\"Chinese\",\"nameRu\":\"Китайский\",\"flag\":\"🇨🇳\",\"model\":\"nova-2\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/f40gogr7xr0d/Chinese.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"ja\",\"alternateCodes\":\"[\\\"ja\\\"]\",\"nameEn\":\"Japanese\",\"nameRu\":\"Японский\",\"flag\":\"🇯🇵\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/1o12kpy9n9r7/Japanese.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"ko\",\"alternateCodes\":\"[\\\"ko\\\",\\\"ko-KR\\\"]\",\"nameEn\":\"Korean\",\"nameRu\":\"Корейский\",\"flag\":\"🇰🇷\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/bqcz1zwgjd0x/Korean.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"it\",\"alternateCodes\":\"[\\\"it\\\"]\",\"nameEn\":\"Italian\",\"nameRu\":\"Итальянский\",\"flag\":\"🇮🇹\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/n5i74aou7wjm/Italian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"pt\",\"alternateCodes\":\"[\\\"pt\\\",\\\"pt-BR\\\",\\\"pt-PT\\\"]\",\"nameEn\":\"Portuguese\",\"nameRu\":\"Португальский\",\"flag\":\"🇵🇹\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/tjb05o62i51v/Portuguese.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"hi\",\"alternateCodes\":\"[\\\"hi\\\"]\",\"nameEn\":\"Hindi\",\"nameRu\":\"Хинди\",\"flag\":\"🇮🇳\",\"model\":\"nova-3\",\"isPopular\":\"true\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/obngjn0ys31h/Hindi.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"bg\",\"alternateCodes\":\"[\\\"bg\\\"]\",\"nameEn\":\"Bulgarian\",\"nameRu\":\"Болгарский\",\"flag\":\"🇧🇬\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/1ape3tc77hc2/Bulgarian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"cs\",\"alternateCodes\":\"[\\\"cs\\\"]\",\"nameEn\":\"Czech\",\"nameRu\":\"Чешский\",\"flag\":\"🇨🇿\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/u3hoh6xh146j/Czech.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"da\",\"alternateCodes\":\"[\\\"da\\\",\\\"da-DK\\\"]\",\"nameEn\":\"Danish\",\"nameRu\":\"Датский\",\"flag\":\"🇩🇰\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/ow5zbfta8lhk/Danish.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"nl\",\"alternateCodes\":\"[\\\"nl\\\"]\",\"nameEn\":\"Dutch\",\"nameRu\":\"Нидерландский\",\"flag\":\"🇳🇱\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/ovghtttn7f2f/Dutch.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"fi\",\"alternateCodes\":\"[\\\"fi\\\"]\",\"nameEn\":\"Finnish\",\"nameRu\":\"Финский\",\"flag\":\"🇫🇮\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/a86gw7isd6sk/Finnish.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"hu\",\"alternateCodes\":\"[\\\"hu\\\"]\",\"nameEn\":\"Hungarian\",\"nameRu\":\"Венгерский\",\"flag\":\"🇭🇺\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/lwrkyskfy6t0/Hungarian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"id\",\"alternateCodes\":\"[\\\"id\\\"]\",\"nameEn\":\"Indonesian\",\"nameRu\":\"Индонезийский\",\"flag\":\"🇮🇩\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/hshcujnoxmcu/Indonesian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"no\",\"alternateCodes\":\"[\\\"no\\\"]\",\"nameEn\":\"Norwegian\",\"nameRu\":\"Норвежский\",\"flag\":\"🇳🇴\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/plxuky87tgom/Norwegian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"pl\",\"alternateCodes\":\"[\\\"pl\\\"]\",\"nameEn\":\"Polish\",\"nameRu\":\"Польский\",\"flag\":\"🇵🇱\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/e09qn2rmsars/Polish.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"sv\",\"alternateCodes\":\"[\\\"sv\\\",\\\"sv-SE\\\"]\",\"nameEn\":\"Swedish\",\"nameRu\":\"Шведский\",\"flag\":\"🇸🇪\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/38upx9a8d3mn/Swedish.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"tr\",\"alternateCodes\":\"[\\\"tr\\\"]\",\"nameEn\":\"Turkish\",\"nameRu\":\"Турецкий\",\"flag\":\"🇹🇷\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/pbk48pnsgsl0/Turkish.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"uk\",\"alternateCodes\":\"[\\\"uk\\\"]\",\"nameEn\":\"Ukrainian\",\"nameRu\":\"Украинский\",\"flag\":\"🇺🇦\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/l6jsdqqc868t/Ukrainian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"vi\",\"alternateCodes\":\"[\\\"vi\\\"]\",\"nameEn\":\"Vietnamese\",\"nameRu\":\"Вьетнамский\",\"flag\":\"🇻🇳\",\"model\":\"nova-3\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/g8t16hoq9mpa/Vietnamese.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"ca\",\"alternateCodes\":\"[\\\"ca\\\"]\",\"nameEn\":\"Catalan\",\"nameRu\":\"Каталанский\",\"flag\":\"🏴\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/urpp9wsb19fx/Catalan.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"zh-TW\",\"alternateCodes\":\"[\\\"zh-TW\\\",\\\"zh-Hant\\\"]\",\"nameEn\":\"Chinese (Traditional)\",\"nameRu\":\"Китайский (Традиционный)\",\"flag\":\"🇹🇼\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/5kd4pgnk2wcx/Chinese_(Traditional).png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"zh-HK\",\"alternateCodes\":\"[\\\"zh-HK\\\"]\",\"nameEn\":\"Chinese (Cantonese)\",\"nameRu\":\"Китайский (Кантонский)\",\"flag\":\"🇭🇰\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/m5lzi2kczq6o/Chinese_(Cantonese).png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"et\",\"alternateCodes\":\"[\\\"et\\\"]\",\"nameEn\":\"Estonian\",\"nameRu\":\"Эстонский\",\"flag\":\"🇪🇪\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/qnayh1k6f89k/Estonian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"nl-BE\",\"alternateCodes\":\"[\\\"nl-BE\\\"]\",\"nameEn\":\"Flemish\",\"nameRu\":\"Фламандский\",\"flag\":\"🇧🇪\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/xdnhhwi89nd3/Flemish.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"de-CH\",\"alternateCodes\":\"[\\\"de-CH\\\"]\",\"nameEn\":\"German (Switzerland)\",\"nameRu\":\"Немецкий (Швейцария)\",\"flag\":\"🇨🇭\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/89dvrw7zx4sv/German_(Switzerland).png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"el\",\"alternateCodes\":\"[\\\"el\\\"]\",\"nameEn\":\"Greek\",\"nameRu\":\"Греческий\",\"flag\":\"🇬🇷\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/igmzls94rfvw/Greek.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"lv\",\"alternateCodes\":\"[\\\"lv\\\"]\",\"nameEn\":\"Latvian\",\"nameRu\":\"Латышский\",\"flag\":\"🇱🇻\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/qt0q53xbls9d/Latvian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"lt\",\"alternateCodes\":\"[\\\"lt\\\"]\",\"nameEn\":\"Lithuanian\",\"nameRu\":\"Литовский\",\"flag\":\"🇱🇹\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/hp7q9hvbhiuc/Lithuanian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"ms\",\"alternateCodes\":\"[\\\"ms\\\"]\",\"nameEn\":\"Malay\",\"nameRu\":\"Малайский\",\"flag\":\"🇲🇾\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/kede78ypw3bx/Malay.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"ro\",\"alternateCodes\":\"[\\\"ro\\\"]\",\"nameEn\":\"Romanian\",\"nameRu\":\"Румынский\",\"flag\":\"🇷🇴\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/odfph5tqzh8i/Romanian.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"sk\",\"alternateCodes\":\"[\\\"sk\\\"]\",\"nameEn\":\"Slovak\",\"nameRu\":\"Словацкий\",\"flag\":\"🇸🇰\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/rqnzyhp5cui0/Slovak.png\"}')),
    LanguageStruct.fromSerializableMap(jsonDecode(
        '{\"code\":\"th\",\"alternateCodes\":\"[\\\"th\\\",\\\"th-TH\\\"]\",\"nameEn\":\"Thai\",\"nameRu\":\"Тайский\",\"flag\":\"🇹🇭\",\"model\":\"nova-2\",\"isPopular\":\"false\",\"ss\":\"https://storage.googleapis.com/flutterflow-io-6f20.appspot.com/projects/small-talk-p1aiwk/assets/r258glt5p617/Thai.png\"}'))
  ];
  List<LanguageStruct> get languagesList => _languagesList;
  set languagesList(List<LanguageStruct> value) {
    _languagesList = value;
    prefs.setStringList(
        'ff_languagesList', value.map((x) => x.serialize()).toList());
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

Future _safeInitAsync(Function() initializeField) async {
  try {
    await initializeField();
  } catch (_) {}
}
