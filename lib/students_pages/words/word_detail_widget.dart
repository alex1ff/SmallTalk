import '/auth/firebase_auth/auth_util.dart';
import '/backend/api_requests/api_calls.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/shared_pages/design/basic_page_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/user_match_profile.dart';
import 'word_detail_content.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class WordDetailWidget extends StatelessWidget {
  const WordDetailWidget({
    super.key,
    required this.wordRef,
    this.initialWord,
  });

  final DocumentReference wordRef;
  final UserWordsRecord? initialWord;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ExpatlioDesign.background,
      body: StreamBuilder<UserWordsRecord>(
        stream: UserWordsRecord.getDocument(wordRef),
        initialData: initialWord,
        builder: (context, snapshot) {
          final word = snapshot.data;
          if (word == null) {
            return Center(
              child: SizedBox(
                width: 50.0,
                height: 50.0,
                child: SpinKitCircle(
                  color: FlutterFlowTheme.of(context).secondary,
                  size: 50.0,
                ),
              ),
            );
          }

          return Column(
            children: [
              const _WordDetailHeader(),
              Expanded(
                child: _WordDetailBody(word: word),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WordDetailHeader extends StatelessWidget {
  const _WordDetailHeader();

  @override
  Widget build(BuildContext context) {
    return BasicPageHeader(
      title: FFLocalizations.of(context).getVariableText(
        ruText: 'Слово',
        enText: 'Word',
      ),
      onBack: () => Navigator.of(context).pop(),
    );
  }
}

class _WordDetailBody extends StatefulWidget {
  const _WordDetailBody({
    required this.word,
  });

  final UserWordsRecord word;

  @override
  State<_WordDetailBody> createState() => _WordDetailBodyState();
}

class _WordDetailBodyState extends State<_WordDetailBody> {
  List<EntryStruct> _apiEntries = const <EntryStruct>[];
  List<SentenceStruct> _apiExamples = const <SentenceStruct>[];
  int _loadSequence = 0;
  bool _didStartInitialLoad = false;

  WordDetailContent get _content {
    return buildWordDetailContent(
      savedEntries: widget.word.entry.toList(),
      savedExamples: widget.word.sentence.toList(),
      apiEntries: _apiEntries,
      apiExamples: _apiExamples,
    );
  }

  @override
  void didUpdateWidget(covariant _WordDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_sourceWordForLookup(oldWidget.word) ==
        _sourceWordForLookup(widget.word)) {
      return;
    }

    _apiEntries = const <EntryStruct>[];
    _apiExamples = const <SentenceStruct>[];
    unawaited(_loadSupplementalContent());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartInitialLoad) {
      return;
    }

    _didStartInitialLoad = true;
    unawaited(_loadSupplementalContent());
  }

  String _sourceWordForLookup(UserWordsRecord word) {
    final entryText = word.entry.firstOrNull?.text.trim();
    return entryText ?? '';
  }

  String? _savedSourceLanguageCode() {
    for (final sentence in widget.word.sentence) {
      final normalized = _normalizeLanguageCode(sentence.lang);
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return null;
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
      final normalized = _normalizeLanguageCode(code);
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

  String _normalizeLanguageCode(String? code) {
    return (code ?? '').trim().toLowerCase().replaceAll('_', '-');
  }

  Future<void> _loadSupplementalContent() async {
    final sourceWord = _sourceWordForLookup(widget.word);
    if (sourceWord.isEmpty) {
      return;
    }

    final sequence = ++_loadSequence;
    final yandexSourceLanguageCode = _resolvedYandexSourceLanguageCode();
    final yandexTranslationLanguageCode =
        _preferredYandexTranslationLanguageCode(context);
    final tatoebaSourceLanguageCode = _resolvedTatoebaSourceLanguageCode();
    final tatoebaTranslationLanguageCode =
        _preferredTatoebaTranslationLanguageCode(context);

    var apiEntries = const <EntryStruct>[];
    var apiExamples = const <SentenceStruct>[];

    await Future.wait([
      Future(() async {
        try {
          final response = await YandexCall.call(
            text: sourceWord,
            lang: '$yandexSourceLanguageCode-$yandexTranslationLanguageCode',
          );
          apiEntries = _entriesFromYandex(response.jsonBody);
        } catch (_) {}
      }),
      Future(() async {
        try {
          final response = await TatoebaCall.call(
            lang: tatoebaSourceLanguageCode,
            q: sourceWord,
            showTransLang: tatoebaTranslationLanguageCode,
            transLang: tatoebaTranslationLanguageCode,
          );
          apiExamples = _examplesFromTatoeba(response.jsonBody);
        } catch (_) {}
      }),
    ]);

    if (!mounted || sequence != _loadSequence) {
      return;
    }

    setState(() {
      _apiEntries = apiEntries;
      _apiExamples = apiExamples;
    });
  }

  List<EntryStruct> _entriesFromYandex(dynamic jsonBody) {
    if (jsonBody is! Map) {
      return const <EntryStruct>[];
    }

    return YyStruct.maybeFromMap(jsonBody)?.def.toList() ??
        const <EntryStruct>[];
  }

  List<SentenceStruct> _examplesFromTatoeba(dynamic jsonBody) {
    if (jsonBody is! Map) {
      return const <SentenceStruct>[];
    }

    return DataStruct.maybeFromMap(jsonBody)?.data.toList() ??
        const <SentenceStruct>[];
  }

  @override
  Widget build(BuildContext context) {
    final content = _content;
    final examples = content.examples;
    final sourceSynonyms = content.sourceSynonyms;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(20.0, 30.0, 20.0, 40.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  content.sourceText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: FlutterFlowTheme.of(context).bodyMedium.override(
                        fontFamily: 'sf pro display',
                        color: ExpatlioDesign.text,
                        fontSize: 36.0,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w800,
                        lineHeight: 1.0,
                      ),
                ),
              ),
              const SizedBox(width: 16.0),
              const _PronunciationButton(),
            ],
          ),
          if (content.transcription.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
              child: Text(
                content.transcription,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: ExpatlioDesign.muted,
                      fontSize: 20.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          if (sourceSynonyms.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 14.0, 0.0, 0.0),
              child: _SynonymWrap(synonyms: sourceSynonyms),
            ),
          const SizedBox(height: 32.0),
          _InfoCard(
            label: FFLocalizations.of(context).getVariableText(
              ruText: 'ПЕРЕВОД',
              enText: 'TRANSLATION',
            ),
            child: _TranslationDetails(content: content),
          ),
          if (examples.isNotEmpty) ...[
            const SizedBox(height: 32.0),
            Text(
              FFLocalizations.of(context).getVariableText(
                ruText: 'ПРИМЕРЫ',
                enText: 'EXAMPLES',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: ExpatlioDesign.muted,
                    fontSize: 16.0,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
            ),
            const SizedBox(height: 18.0),
            ...examples.map(
              (example) => Padding(
                padding:
                    const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
                child: _ExampleCard(sentence: example),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TranslationDetails extends StatelessWidget {
  const _TranslationDetails({
    required this.content,
  });

  final WordDetailContent content;

  @override
  Widget build(BuildContext context) {
    final groups = content.translationGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.translationText,
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'sf pro display',
                color: ExpatlioDesign.text,
                fontSize: 22.0,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w700,
                lineHeight: 1.2,
              ),
        ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 18.0),
          ...groups.map(
            (group) => Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 14.0),
              child: _TranslationGroupView(group: group),
            ),
          ),
        ],
      ],
    );
  }
}

class _TranslationGroupView extends StatelessWidget {
  const _TranslationGroupView({
    required this.group,
  });

  final WordDetailTranslationGroup group;

  String get _meaningsText {
    final meanings = group.meanings
        .map((meaning) => meaning.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();
    if (meanings.isEmpty) {
      return '';
    }
    return meanings.map((meaning) => '$meaning.').join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final meaningsText = _meaningsText;
    final hasSynonyms = group.synonyms.isNotEmpty;
    final hasMeanings = meaningsText.isNotEmpty;

    if (!hasSynonyms && !hasMeanings) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasSynonyms) _SynonymWrap(synonyms: group.synonyms),
        if (hasMeanings)
          Padding(
            padding: EdgeInsetsDirectional.fromSTEB(
                0.0, hasSynonyms ? 8.0 : 0.0, 0.0, 0.0),
            child: Text(
              meaningsText,
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    fontFamily: 'sf pro display',
                    color: ExpatlioDesign.muted,
                    fontSize: 15.0,
                    letterSpacing: 0.0,
                    fontWeight: FontWeight.w500,
                    lineHeight: 1.25,
                  ),
            ),
          ),
      ],
    );
  }
}

class _SynonymWrap extends StatelessWidget {
  const _SynonymWrap({
    required this.synonyms,
  });

  final List<SynonymStruct> synonyms;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: synonyms
          .map(
            (synonym) => _SynonymChip(synonym: synonym),
          )
          .toList(growable: false),
    );
  }
}

class _SynonymChip extends StatelessWidget {
  const _SynonymChip({
    required this.synonym,
  });

  final SynonymStruct synonym;

  @override
  Widget build(BuildContext context) {
    final gen = synonym.gen.trim();

    return Container(
      constraints: const BoxConstraints(minHeight: 34.0),
      decoration: BoxDecoration(
        color: ExpatlioDesign.mutedSurface,
        borderRadius: BorderRadius.circular(18.0),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(12.0, 7.0, 12.0, 7.0),
      child: RichText(
        textScaler: MediaQuery.of(context).textScaler,
        text: TextSpan(
          children: [
            TextSpan(text: synonym.text),
            if (gen.isNotEmpty) ...[
              const TextSpan(text: '  '),
              TextSpan(
                text: gen,
                style: const TextStyle(
                  color: Color(0xFF727272),
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ],
          style: FlutterFlowTheme.of(context).bodyMedium.override(
                fontFamily: 'sf pro display',
                color: ExpatlioDesign.text,
                fontSize: 15.0,
                letterSpacing: 0.0,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

class _PronunciationButton extends StatelessWidget {
  const _PronunciationButton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46.0,
      height: 46.0,
      decoration: BoxDecoration(
        color: ExpatlioDesign.primary.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.volume_up_rounded,
        color: ExpatlioDesign.primary,
        size: 26.0,
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.label,
    required this.child,
  });

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        borderRadius: BorderRadius.circular(20.0),
        border: Border.all(color: ExpatlioDesign.border),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(18.0, 18.0, 18.0, 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: ExpatlioDesign.muted,
                  fontSize: 14.0,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 18.0),
          child,
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard({
    required this.sentence,
  });

  final SentenceStruct sentence;

  String get _translation {
    return sentence.translations.firstOrNull?.text.trim() ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        borderRadius: BorderRadius.circular(18.0),
        border: Border.all(color: ExpatlioDesign.border),
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(18.0, 18.0, 18.0, 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sentence.text,
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  color: ExpatlioDesign.text,
                  fontSize: 18.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w500,
                  lineHeight: 1.25,
                ),
          ),
          if (_translation.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 12.0, 0.0, 0.0),
              child: Text(
                _translation,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      fontFamily: 'sf pro display',
                      color: ExpatlioDesign.muted,
                      fontSize: 17.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                      lineHeight: 1.25,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
