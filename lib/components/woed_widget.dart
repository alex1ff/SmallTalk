import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/custom_functions.dart' as functions;
import '/flutter_flow/flutter_flow_icon_button.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/user_match_profile.dart';
import '/students_pages/flashcard/flashcard_content_service.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import '/students_pages/words/word_lookup_service.dart';
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
  WordLookupResult? _lookupResult;

  bool get _canManageDictionary =>
      currentUserDocument != null &&
      !canAccessTeacherSurfaces(currentUserDocument) &&
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

      _lookupResult = await WordLookupService.resolve(
        word: sourceWord,
        userRef: currentUserReference,
        savedContents: [
          if (widget.word != null)
            WordLookupSavedContent.fromRecord(widget.word!),
        ],
        languageConfig: WordLookupLanguageConfig(
          sourceLanguageCode: _savedSourceLanguageCode(),
          yandexSourceLanguageCode: yandexSourceLanguageCode,
          yandexTranslationLanguageCode: yandexTranslationLanguageCode,
          tatoebaSourceLanguageCode: tatoebaSourceLanguageCode,
          tatoebaTranslationLanguageCode: tatoebaTranslationLanguageCode,
        ),
      );

      if (!mounted) {
        return;
      }

      _syncCollapsedSize();
      safeSetState(() {});
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

  List<EntryStruct> _dictionaryEntries() {
    return _lookupResult?.entries ?? _savedEntries();
  }

  List<SentenceStruct> _displaySentences() {
    return _lookupResult?.examples ?? _savedSentences();
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

    if (canAccessTeacherSurfaces(currentUser)) {
      roleBasedLanguageCode = currentUser?.nativeLanguageNS.code;
    } else if (currentUser != null) {
      roleBasedLanguageCode =
          currentUser.preferences.preferredNativeLanguage.code;
    }

    final fallbackCodes = <String?>[
      roleBasedLanguageCode,
      currentUser?.nativeLanguageNS.code,
      currentUser?.preferences.preferredNativeLanguage.code,
    ];

    for (final code in fallbackCodes) {
      final normalized = normalizeWordLookupLanguageCode(code);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }

  String? _savedSourceLanguageCode() {
    for (final sentence in _savedSentences()) {
      final normalized = normalizeWordLookupLanguageCode(sentence.lang);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
  }

  String _preferredTatoebaTranslationLanguageCode(BuildContext context) {
    return resolveTatoebaWordLookupLanguageCode(
      <String?>[
        _preferredProfileLanguageCode(),
        FFLocalizations.of(context).languageCode,
        'eng',
      ],
      fallback: 'eng',
    );
  }

  String _preferredYandexTranslationLanguageCode(BuildContext context) {
    return resolveYandexWordLookupLanguageCode(
      <String?>[
        _preferredProfileLanguageCode(),
        FFLocalizations.of(context).languageCode,
        'en',
      ],
      fallback: 'en',
    );
  }

  String _resolvedYandexSourceLanguageCode() {
    return resolveYandexWordLookupLanguageCode(
      <String?>[
        _savedSourceLanguageCode(),
        'en',
      ],
      fallback: 'en',
    );
  }

  String _resolvedTatoebaSourceLanguageCode() {
    return resolveTatoebaWordLookupLanguageCode(
      <String?>[
        _savedSourceLanguageCode(),
        'eng',
      ],
      fallback: 'eng',
    );
  }

  String _resolvedDisplaySourceLanguageCode() {
    return resolveNormalizedWordLookupLanguageCode(
      <String?>[
        _savedSourceLanguageCode(),
        'en',
      ],
      fallback: 'en',
    );
  }

  String _preferredDisplayTranslationLanguageCode(BuildContext context) {
    return resolveNormalizedWordLookupLanguageCode(
      <String?>[
        _preferredProfileLanguageCode(),
        FFLocalizations.of(context).languageCode,
        'en',
      ],
      fallback: 'en',
    );
  }

  Widget _buildLanguageFlag(String? code, {required String fallbackLabel}) {
    final language = findWordLookupLanguageByCode(
      languages: FFAppState().languagesList,
      code: code,
    );
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
                        fontSize: 17.0,
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
                      fontSize: 17.0,
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

    var entriesToSave = _dictionaryEntries();
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
    try {
      entriesToSave =
          await FlashcardContentService.enrichWordWithSourceSynonyms(
        wordRef: userWordsRecordReference,
        entries: entriesToSave,
        sourceLanguageCode: _resolvedYandexSourceLanguageCode(),
      );
    } catch (_) {}

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
      padding: const EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space8,
          ExpatlioDesign.space0, ExpatlioDesign.space8, ExpatlioDesign.space0),
      child: Container(
        decoration: BoxDecoration(
          color: ExpatlioDesign.card,
          borderRadius: BorderRadius.circular(ExpatlioDesign.radiusLarge),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space8,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0),
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
                  padding: const EdgeInsetsDirectional.fromSTEB(
                      ExpatlioDesign.space8,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0,
                      ExpatlioDesign.space0),
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
          separatorBuilder: (_, __) =>
              const SizedBox(height: ExpatlioDesign.space24),
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
                              fontSize: 22.0,
                              letterSpacing: 0.0,
                              fontWeight: FontWeight.normal,
                            ),
                      ),
                      TextSpan(
                        text: ' [${entryItem.ts}] ',
                        style: TextStyle(
                          fontFamily: 'Cool',
                          color: ExpatlioDesign.muted,
                          fontWeight: FontWeight.normal,
                          fontSize: 22.0,
                        ),
                      ),
                      TextSpan(
                        text: _partOfSpeechLabel(entryItem.pos),
                        style: TextStyle(
                          fontFamily: 'Cool',
                          color: ExpatlioDesign.muted,
                          fontWeight: FontWeight.normal,
                          fontSize: 22.0,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                          fontFamily: 'Cool',
                          color: ExpatlioDesign.text,
                          fontSize: 22.0,
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
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: ExpatlioDesign.space8),
                      itemBuilder: (context, translationIndex) {
                        final translationItem = translations[translationIndex];

                        return Column(
                          mainAxisSize: MainAxisSize.max,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsetsDirectional.fromSTEB(
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space12,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0,
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
                                    spacing: ExpatlioDesign.space4,
                                    runSpacing: ExpatlioDesign.space8,
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
                                          borderRadius: BorderRadius.circular(
                                              ExpatlioDesign.radiusCapsule),
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
                                                            color:
                                                                ExpatlioDesign
                                                                    .text,
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
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space8,
                                ExpatlioDesign.space0,
                                ExpatlioDesign.space0,
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
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space16,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: Text(
            FFLocalizations.of(context).getText(
              '7118sl5m' /* Примеры */,
            ),
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'Cool',
                  fontSize: 22.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.normal,
                ),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space12,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
          child: ListView.separated(
            padding: EdgeInsets.zero,
            primary: false,
            shrinkWrap: true,
            scrollDirection: Axis.vertical,
            itemCount: sentences.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: ExpatlioDesign.space8),
            itemBuilder: (context, sentenceIndex) {
              final sentenceItem = sentences[sentenceIndex];

              return Container(
                decoration: BoxDecoration(
                  color: ExpatlioDesign.card,
                  borderRadius:
                      BorderRadius.circular(ExpatlioDesign.radiusLarge),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(ExpatlioDesign.space16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sentenceItem.text,
                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                              fontFamily: 'sf pro display',
                              color: ExpatlioDesign.text,
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
                            ExpatlioDesign.space0,
                            ExpatlioDesign.space8,
                            ExpatlioDesign.space0,
                            ExpatlioDesign.space0,
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
        decoration: ExpatlioDesign.sheetDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0,
              ExpatlioDesign.space0),
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
                        BottomSheetHeader(
                          title: valueOrDefault<String>(
                            widget.word?.entry.firstOrNull?.text,
                            'Слово',
                          ),
                        ),
                        const SizedBox(height: ExpatlioDesign.space16),
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
                                              padding: const EdgeInsets.all(
                                                  ExpatlioDesign.space16),
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
                                              const SizedBox(
                                                  height:
                                                      ExpatlioDesign.space24),
                                            )
                                            .addToEnd(
                                              const SizedBox(
                                                  height:
                                                      ExpatlioDesign.space32),
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
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space0,
                          ExpatlioDesign.space8,
                          ExpatlioDesign.space20,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_canManageDictionary)
                              FlutterFlowIconButton(
                                borderRadius: ExpatlioDesign.radiusCapsule,
                                buttonSize: 60.0,
                                fillColor: Colors.white,
                                icon: Icon(
                                  _isSaved
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border,
                                  color: ExpatlioDesign.text,
                                  size: 20.0,
                                ),
                                onPressed: _toggleDictionaryWord,
                              ),
                          ].divide(
                              const SizedBox(height: ExpatlioDesign.space8)),
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
