import '/auth/firebase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/backend/schema/enums/enums.dart';
import '/custom_code/widgets/index.dart' as custom_widgets;
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'woed_model.dart';
export 'woed_model.dart';

class WoedWidget extends StatefulWidget {
  const WoedWidget({
    super.key,
    required this.word,
  });

  final UserWordsRecord? word;

  @override
  State<WoedWidget> createState() => _WoedWidgetState();
}

class _WoedWidgetState extends State<WoedWidget> {
  late WoedModel _model;
  DocumentReference? _savedWordReference;
  bool _isSaved = false;

  bool get _canManageDictionary =>
      currentUserDocument?.role == UserRole.student &&
      currentUserReference != null;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => WoedModel());
    _savedWordReference = widget.word?.reference;
    _isSaved = _savedWordReference != null;

    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final sourceWord = _sourceWord();
      if (sourceWord.isEmpty) {
        _syncCollapsedSize();
        return;
      }

      final yandexSourceLanguageCode = _resolvedYandexSourceLanguageCode();
      final yandexTranslationLanguageCode =
          _preferredYandexTranslationLanguageCode(context);
      final tatoebaSourceLanguageCode = _resolvedTatoebaSourceLanguageCode();
      final tatoebaTranslationLanguageCode =
          _preferredTatoebaTranslationLanguageCode(context);

      await Future.wait([
        Future(() async {
          try {
            _model.worrd = await YandexCall.call(
              text: sourceWord,
              lang: '$yandexSourceLanguageCode-$yandexTranslationLanguageCode',
            );
          } catch (_) {}

          if (mounted) {
            safeSetState(() {});
          }
        }),
        Future(() async {
          try {
            _model.ssss = await TatoebaCall.call(
              lang: tatoebaSourceLanguageCode,
              q: sourceWord,
              showTransLang: tatoebaTranslationLanguageCode,
              transLang: tatoebaTranslationLanguageCode,
            );
          } catch (_) {}

          if (mounted) {
            safeSetState(() {});
          }
        }),
      ]);

      if (!mounted) {
        return;
      }

      _syncCollapsedSize();
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  void _syncCollapsedSize() {
    final collapsedSize = _collapsedSize();
    if (_model.size != collapsedSize) {
      _model.size = collapsedSize;
      safeSetState(() {});
    }
  }

  double _collapsedSize() {
    return _displaySentences().isEmpty ? 220.0 : 250.0;
  }

  List<EntryStruct> _savedEntries() {
    return widget.word?.entry.toList() ?? const <EntryStruct>[];
  }

  List<SentenceStruct> _savedSentences() {
    return widget.word?.sentence.toList() ?? const <SentenceStruct>[];
  }

  String _sourceWord() {
    final text = _savedEntries().firstOrNull?.text.trim();
    return text ?? '';
  }

  YyStruct? _parsedWordResponse() {
    final jsonBody = _model.worrd?.jsonBody;
    if (jsonBody is! Map) {
      return null;
    }

    return YyStruct.maybeFromMap(jsonBody);
  }

  List<EntryStruct> _apiDictionaryEntries() {
    return _parsedWordResponse()?.def.toList() ?? const <EntryStruct>[];
  }

  List<EntryStruct> _dictionaryEntries() {
    final apiEntries = _apiDictionaryEntries();
    if (apiEntries.isNotEmpty) {
      return apiEntries;
    }

    return _savedEntries();
  }

  List<SentenceStruct> _apiExampleSentences() {
    final jsonBody = _model.ssss?.jsonBody;
    if (jsonBody is! Map) {
      return const <SentenceStruct>[];
    }

    return DataStruct.maybeFromMap(jsonBody)?.data.toList() ??
        const <SentenceStruct>[];
  }

  List<SentenceStruct> _displaySentences() {
    final merged = <SentenceStruct>[];
    final indexByKey = <String, int>{};

    void upsertSentence(
      SentenceStruct? sentence, {
      required bool preferNew,
    }) {
      if (sentence == null) {
        return;
      }

      final text = sentence.text.trim();
      if (text.isEmpty) {
        return;
      }

      final language = _normalizeLanguageCode(sentence.lang);
      final dedupeKey = '$language|${text.toLowerCase()}';
      final existingIndex = indexByKey[dedupeKey];

      if (existingIndex != null) {
        if (preferNew) {
          merged[existingIndex] = sentence;
        }
        return;
      }

      indexByKey[dedupeKey] = merged.length;
      merged.add(sentence);
    }

    for (final sentence in _savedSentences()) {
      upsertSentence(sentence, preferNew: false);
    }

    for (final sentence in _apiExampleSentences()) {
      upsertSentence(sentence, preferNew: true);
    }

    return merged;
  }

  EntryStruct? _primaryEntry() {
    return _dictionaryEntries().firstOrNull;
  }

  String _primaryTranslationText() {
    final translationText = _primaryEntry()?.tr.firstOrNull?.text;
    if (translationText != null && translationText.isNotEmpty) {
      return translationText;
    }

    final sourceText = _primaryEntry()?.text;
    if (sourceText != null && sourceText.isNotEmpty) {
      return sourceText;
    }

    return _sourceWord();
  }

  String? _preferredProfileLanguageCode() {
    final currentUser = currentUserDocument;
    String? roleBasedLanguageCode;

    if (currentUser?.role == UserRole.native_speaker) {
      roleBasedLanguageCode = currentUser?.nativeLanguageNS.code;
    } else if (currentUser?.role == UserRole.student) {
      roleBasedLanguageCode =
          currentUser?.preferences.preferredNativeLanguage.code;
    }

    final fallbackCodes = <String?>[
      roleBasedLanguageCode,
      currentUser?.nativeLanguageNS.code,
      currentUser?.preferences.preferredNativeLanguage.code,
    ];

    for (final code in fallbackCodes) {
      final normalized = _normalizeLanguageCode(code);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }

  String? _savedSourceLanguageCode() {
    for (final sentence in _savedSentences()) {
      final normalized = _normalizeLanguageCode(sentence.lang);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }

  String _preferredTatoebaTranslationLanguageCode(BuildContext context) {
    final fallbackCodes = <String?>[
      _preferredProfileLanguageCode(),
      FFLocalizations.of(context).languageCode,
      'eng',
    ];

    for (final code in fallbackCodes) {
      final normalized = TatoebaCall.normalizeLanguageCode(code);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return 'eng';
  }

  String _preferredYandexTranslationLanguageCode(BuildContext context) {
    final fallbackCodes = <String?>[
      _preferredProfileLanguageCode(),
      FFLocalizations.of(context).languageCode,
      'en',
    ];

    for (final code in fallbackCodes) {
      final normalized = YandexCall.normalizeLanguageCode(code);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return 'en';
  }

  String _resolvedYandexSourceLanguageCode() {
    final fallbackCodes = <String?>[
      _savedSourceLanguageCode(),
      'en',
    ];

    for (final code in fallbackCodes) {
      final normalized = YandexCall.normalizeLanguageCode(code);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return 'en';
  }

  String _resolvedTatoebaSourceLanguageCode() {
    final fallbackCodes = <String?>[
      _savedSourceLanguageCode(),
      'eng',
    ];

    for (final code in fallbackCodes) {
      final normalized = TatoebaCall.normalizeLanguageCode(code);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }

    return 'eng';
  }

  String _resolvedDisplaySourceLanguageCode() {
    final fallbackCodes = <String?>[
      _savedSourceLanguageCode(),
      'en',
    ];

    for (final code in fallbackCodes) {
      final normalized = _normalizeLanguageCode(code);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return 'en';
  }

  String _preferredDisplayTranslationLanguageCode(BuildContext context) {
    final fallbackCodes = <String?>[
      _preferredProfileLanguageCode(),
      FFLocalizations.of(context).languageCode,
      'en',
    ];

    for (final code in fallbackCodes) {
      final normalized = _normalizeLanguageCode(code);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return 'en';
  }

  String _normalizeLanguageCode(String? code) {
    return (code ?? '').trim().toLowerCase().replaceAll('_', '-');
  }

  LanguageStruct? _findLanguageByCode(String? code) {
    final normalizedCode = _normalizeLanguageCode(code);
    if (normalizedCode.isEmpty) {
      return null;
    }

    final normalizedBaseCode = normalizedCode.split('-').first;

    for (final language in FFAppState().languagesList) {
      final candidateCodes = <String>[
        language.code,
        ...language.alternateCodes,
      ].map(_normalizeLanguageCode).where((value) => value.isNotEmpty);

      final matches = candidateCodes.any((candidateCode) {
        final candidateBaseCode = candidateCode.split('-').first;
        return candidateCode == normalizedCode ||
            candidateCode == normalizedBaseCode ||
            candidateBaseCode == normalizedCode ||
            candidateBaseCode == normalizedBaseCode;
      });

      if (matches) {
        return language;
      }
    }

    return null;
  }

  Widget _buildLanguageFlag(String? code, {required String fallbackLabel}) {
    final language = _findLanguageByCode(code);
    final imageUrl = language?.ss ?? '';

    return SizedBox(
      width: 50.0,
      height: 50.0,
      child: Align(
        alignment: const AlignmentDirectional(0.0, 0.0),
        child: imageUrl.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: imageUrl,
                width: 28.0,
                height: 28.0,
                fit: BoxFit.contain,
                memCacheWidth: 56,
                memCacheHeight: 56,
                errorWidget: (context, _, __) => Text(
                  fallbackLabel,
                  textAlign: TextAlign.center,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        fontSize: 18.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.normal,
                      ),
                ),
              )
            : Text(
                fallbackLabel,
                textAlign: TextAlign.center,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      fontSize: 18.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.normal,
                    ),
              ),
      ),
    );
  }

  String _partOfSpeechLabel(String pos) {
    switch (pos) {
      case 'noun':
        return 'сущ';
      case 'abjective':
        return 'прил';
      case 'participle':
        return 'прич';
      case 'verb':
        return 'гл';
      default:
        return ' ';
    }
  }

  Future<void> _toggleDictionaryWord() async {
    if (!_canManageDictionary) {
      return;
    }

    if (_isSaved) {
      final savedWordReference = _savedWordReference;
      if (savedWordReference == null) {
        return;
      }

      await FlashcardReviewRepository.deleteReviewForWord(savedWordReference);
      await savedWordReference.delete();
      if (!mounted) {
        return;
      }

      safeSetState(() {
        _savedWordReference = null;
        _isSaved = false;
      });
      return;
    }

    final entriesToSave = _dictionaryEntries();
    if (entriesToSave.isEmpty) {
      return;
    }

    final userReference = currentUserReference;
    if (userReference == null) {
      return;
    }

    final userWordsRecordReference = UserWordsRecord.createDoc(userReference);
    final addedAt = getCurrentTimestamp;
    await userWordsRecordReference.set({
      ...createUserWordsRecordData(
        addedAt: addedAt,
      ),
      ...mapToFirestore(
        {
          'entry': getEntryListFirestoreData(entriesToSave),
          'Sentence': getSentenceListFirestoreData(_displaySentences()),
        },
      ),
    });
    await FlashcardReviewRepository.ensureInitialReviewForWord(
      wordRef: userWordsRecordReference,
      addedAt: addedAt,
    );

    if (!mounted) {
      return;
    }

    safeSetState(() {
      _savedWordReference = userWordsRecordReference;
      _isSaved = true;
    });
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String sourceLanguageCode,
    required String translationLanguageCode,
  }) {
    final translationText = _primaryTranslationText();

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 6.0, 0.0),
      child: Container(
        decoration: BoxDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
          borderRadius: BorderRadius.circular(26.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 0.0, 0.0),
                  child: _buildLanguageFlag(
                    sourceLanguageCode,
                    fallbackLabel: '🌐',
                  ),
                ),
                Text(
                  valueOrDefault<String>(
                    _sourceWord(),
                    '-',
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        fontSize: 17.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            Divider(
              height: 1.0,
              thickness: 1.0,
              indent: 56.0,
              endIndent: 16.0,
              color: FlutterFlowTheme.of(context).alternate,
            ),
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(6.0, 0.0, 0.0, 0.0),
                  child: _buildLanguageFlag(
                    translationLanguageCode,
                    fallbackLabel: '🌐',
                  ),
                ),
                Text(
                  valueOrDefault<String>(
                    translationText,
                    '-',
                  ),
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        fontSize: 17.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefinitionsSection(BuildContext context) {
    final entries = _dictionaryEntries();
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Builder(
      builder: (context) {
        return ListView.separated(
          padding: EdgeInsets.zero,
          primary: false,
          shrinkWrap: true,
          scrollDirection: Axis.vertical,
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 24.0),
          itemBuilder: (context, entryIndex) {
            final entryItem = entries[entryIndex];

            return Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  textScaler: MediaQuery.of(context).textScaler,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: entryItem.text,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'Cool',
                              fontSize: 21.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                      TextSpan(
                        text: ' [${entryItem.ts}] ',
                        style: TextStyle(
                          fontFamily: 'Cool',
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontWeight: FontWeight.normal,
                          fontSize: 21.0,
                        ),
                      ),
                      TextSpan(
                        text: _partOfSpeechLabel(entryItem.pos),
                        style: TextStyle(
                          fontFamily: 'Cool',
                          color: FlutterFlowTheme.of(context).secondaryText,
                          fontWeight: FontWeight.normal,
                          fontSize: 21.0,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Cool',
                          color: Colors.black,
                          fontSize: 21.0,
                          letterSpacing: 0.0,
                          fontWeight: FontWeight.normal,
                        ),
                  ),
                ),
                Builder(
                  builder: (context) {
                    final translations = entryItem.tr.toList().take(3).toList();

                    return ListView.separated(
                      padding: EdgeInsets.zero,
                      primary: false,
                      shrinkWrap: true,
                      scrollDirection: Axis.vertical,
                      itemCount: translations.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8.0),
                      itemBuilder: (context, translationIndex) {
                        final translationItem = translations[translationIndex];

                        return Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0,
                                12.0,
                                0.0,
                                0.0,
                              ),
                              child: Builder(
                                builder: (context) {
                                  final synonyms = functions
                                          .syn(
                                            translationItem.gen,
                                            translationItem.text,
                                            translationItem.syn.toList(),
                                          )
                                          ?.toList() ??
                                      [];

                                  return Wrap(
                                    spacing: 4.0,
                                    runSpacing: 8.0,
                                    alignment: WrapAlignment.start,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.start,
                                    children: List.generate(synonyms.length,
                                        (synonymIndex) {
                                      final synonymItem =
                                          synonyms[synonymIndex];

                                      return Container(
                                        height: 35.0,
                                        decoration: BoxDecoration(
                                          color: FlutterFlowTheme.of(context)
                                              .primaryBackground,
                                          borderRadius:
                                              BorderRadius.circular(50.0),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsetsDirectional
                                              .fromSTEB(
                                            12.0,
                                            0.0,
                                            12.0,
                                            0.0,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              RichText(
                                                textScaler:
                                                    MediaQuery.of(context)
                                                        .textScaler,
                                                text: TextSpan(
                                                  children: [
                                                    TextSpan(
                                                      text: synonymItem.text,
                                                      style: FlutterFlowTheme
                                                              .of(context)
                                                          .bodyMedium
                                                          .override(
                                                            fontFamily:
                                                                'sf pro display',
                                                            color: Colors.black,
                                                            fontSize: 15.0,
                                                            letterSpacing: 0.0,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                    ),
                                                    TextSpan(
                                                      text: FFLocalizations.of(
                                                              context)
                                                          .getText(
                                                        'lpzroxlx' /*   */,
                                                      ),
                                                      style: const TextStyle(),
                                                    ),
                                                    TextSpan(
                                                      text: synonymItem.gen,
                                                      style: const TextStyle(
                                                        color:
                                                            Color(0xFF727272),
                                                      ),
                                                    ),
                                                  ],
                                                  style: FlutterFlowTheme.of(
                                                          context)
                                                      .bodyMedium
                                                      .override(
                                                        fontFamily:
                                                            'sf pro display',
                                                        fontSize: 16.0,
                                                        letterSpacing: 0.0,
                                                        fontWeight:
                                                            FontWeight.normal,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  );
                                },
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                0.0,
                                6.0,
                                0.0,
                                0.0,
                              ),
                              child: SizedBox(
                                height: 17.0,
                                child: Builder(
                                  builder: (context) {
                                    final meanings =
                                        translationItem.mean.toList();

                                    return ListView.builder(
                                      padding: EdgeInsets.zero,
                                      primary: false,
                                      shrinkWrap: true,
                                      scrollDirection: Axis.horizontal,
                                      itemCount: meanings.length,
                                      itemBuilder: (context, meaningIndex) {
                                        final meaningItem =
                                            meanings[meaningIndex];

                                        return Text(
                                          '${meaningItem.text}. ',
                                          style: FlutterFlowTheme.of(context)
                                              .bodyMedium
                                              .override(
                                                fontFamily: 'sf pro display',
                                                color: const Color(0xFF727272),
                                                fontSize: 15.0,
                                                letterSpacing: 0.0,
                                              ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildExamplesSection(BuildContext context) {
    final sentences = _displaySentences();
    if (sentences.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0.0, 16.0, 0.0, 0.0),
          child: Text(
            FFLocalizations.of(context).getText(
              '7118sl5m' /* Примеры */,
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Cool',
                  fontSize: 21.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.normal,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            primary: false,
            shrinkWrap: true,
            scrollDirection: Axis.vertical,
            itemCount: sentences.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8.0),
            itemBuilder: (context, sentenceIndex) {
              final sentenceItem = sentences[sentenceIndex];

              return Container(
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryBackground,
                  borderRadius: BorderRadius.circular(26.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sentenceItem.text,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: Colors.black,
                              fontSize: 16.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      if (sentenceItem.translations.firstOrNull?.text != null &&
                          sentenceItem
                              .translations.firstOrNull!.text.isNotEmpty)
                        Padding(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            0.0,
                            6.0,
                            0.0,
                            0.0,
                          ),
                          child: Text(
                            sentenceItem.translations.firstOrNull!.text,
                            style: FlutterFlowTheme.of(context)
                                .bodyMedium
                                .override(
                                  fontFamily: 'sf pro display',
                                  color: const Color(0xFF727272),
                                  fontSize: 16.0,
                                  letterSpacing: 0.0,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final sourceLanguageCode = _resolvedDisplaySourceLanguageCode();
    final translationLanguageCode =
        _preferredDisplayTranslationLanguageCode(context);
    final collapsedSize = _collapsedSize();

    return GestureDetector(
      onVerticalDragEnd: (details) async {
        if (_model.size <= 400.0) {
          _model.size = collapsedSize;
          safeSetState(() {});
        } else if (_model.size <= 200.0) {
          Navigator.pop(context);
        } else {
          _model.size = 750.0;
          safeSetState(() {});
        }
      },
      onVerticalDragUpdate: (details) async {
        if (_model.size <= 200.0) {
          Navigator.pop(context);
        } else {
          _model.size = _model.size - details.delta.dy;
          safeSetState(() {});
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.elasticOut,
        width: double.infinity,
        height: _model.size,
        decoration: const BoxDecoration(),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(0.0, 40.0, 0.0, 0.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 16.0,
                          child: custom_widgets.NotchedClipper(
                            width: double.infinity,
                            height: 16.0,
                          ),
                        ),
                        Flexible(
                          child: ClipRRect(
                            borderRadius: BorderRadius.zero,
                            child: Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 0.5,
                                ),
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          _buildSummaryCard(
                                            context,
                                            sourceLanguageCode:
                                                sourceLanguageCode,
                                            translationLanguageCode:
                                                translationLanguageCode,
                                          ),
                                          AnimatedOpacity(
                                            opacity:
                                                _dictionaryEntries().isNotEmpty
                                                    ? 1.0
                                                    : 0.0,
                                            duration: 200.0.ms,
                                            curve: Curves.easeInOut,
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  _buildDefinitionsSection(
                                                    context,
                                                  ),
                                                  _buildExamplesSection(
                                                    context,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ]
                                            .addToStart(
                                              const SizedBox(height: 24.0),
                                            )
                                            .addToEnd(
                                              const SizedBox(height: 35.0),
                                            ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: const AlignmentDirectional(1.0, 1.0),
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          0.0,
                          0.0,
                          6.0,
                          20.0,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_canManageDictionary)
                              FlutterFlowIconButton(
                                borderRadius: 70.0,
                                buttonSize: 60.0,
                                fillColor: Colors.white,
                                icon: Icon(
                                  _isSaved
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border,
                                  color:
                                      FlutterFlowTheme.of(context).primaryText,
                                  size: 20.0,
                                ),
                                onPressed: _toggleDictionaryWord,
                              ),
                            FlutterFlowIconButton(
                              borderRadius: 70.0,
                              buttonSize: 60.0,
                              fillColor: Colors.white,
                              icon: Icon(
                                Icons.close_sharp,
                                color: FlutterFlowTheme.of(context).error,
                                size: 20.0,
                              ),
                              onPressed: () async {
                                Navigator.pop(context);
                              },
                            ),
                          ].divide(const SizedBox(height: 6.0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
