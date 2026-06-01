import '/auth/firebase_auth/auth_util.dart';
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/components/bottom_sheet_header.dart';
import '/shared_pages/design/expatlio_design.dart';
import '/services/user_match_profile.dart';
import '/students_pages/flashcard/flashcard_content_service.dart';
import '/students_pages/flashcard/flashcard_review_repository.dart';
import '/students_pages/words/word_lookup_service.dart';
import 'dart:async';
import '/flutter_flow/custom_functions.dart' as functions;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:lottie/lottie.dart';
import 'new_word_model.dart';
export 'new_word_model.dart';

class NewWordWidget extends StatefulWidget {
  const NewWordWidget({
    super.key,
    required this.word,
    required this.langCode,
    this.sentence,
    this.contextText,
  });

  final String? word;
  final String? langCode;
  final String? sentence;
  final String? contextText;

  @override
  State<NewWordWidget> createState() => _NewWordWidgetState();
}

class _NewWordWidgetState extends State<NewWordWidget> {
  late NewWordModel _model;
  WordLookupResult? _lookupResult;

  bool get _canManageDictionary =>
      currentUserDocument != null &&
      !canAccessTeacherSurfaces(currentUserDocument);
  bool get _lookupLoaded => _lookupResult != null;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => NewWordModel());

    // On component load action.
    SchedulerBinding.instance.addPostFrameCallback((_) async {
      final yandexSourceLanguageCode = _resolvedYandexSourceLanguageCode();
      final yandexTranslationLanguageCode =
          _preferredYandexTranslationLanguageCode(context);
      final tatoebaSourceLanguageCode = _resolvedTatoebaSourceLanguageCode();
      final tatoebaTranslationLanguageCode =
          _preferredTatoebaTranslationLanguageCode(context);

      _lookupResult = await WordLookupService.resolve(
        word: widget.word ?? '',
        userRef: currentUserReference,
        languageConfig: WordLookupLanguageConfig(
          sourceLanguageCode: widget.langCode,
          yandexSourceLanguageCode: yandexSourceLanguageCode,
          yandexTranslationLanguageCode: yandexTranslationLanguageCode,
          tatoebaSourceLanguageCode: tatoebaSourceLanguageCode,
          tatoebaTranslationLanguageCode: tatoebaTranslationLanguageCode,
        ),
      );

      if (!mounted) {
        return;
      }

      final hasContext =
          _phraseContextText() != null || _conversationSentenceText() != null;
      final collapsedSize = _exampleSentences().isEmpty
          ? (hasContext ? 280.0 : 220.0)
          : (hasContext ? 300.0 : 250.0);
      if (_model.size != collapsedSize) {
        _model.size = collapsedSize;
      }
      safeSetState(() {});
    });
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  List<EntryStruct> _dictionaryEntries() {
    return _lookupResult?.entries ?? const <EntryStruct>[];
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

    return widget.word ?? '';
  }

  String? _normalizedText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  String? _phraseContextText() {
    final contextText = _normalizedText(widget.contextText);
    final selectedText = _normalizedText(widget.word);
    if (contextText == null) {
      return null;
    }
    if (selectedText != null &&
        contextText.toLowerCase() == selectedText.toLowerCase()) {
      return null;
    }
    return contextText;
  }

  String? _conversationSentenceText() {
    return _normalizedText(widget.sentence);
  }

  List<SentenceStruct> _sentencesToSave() {
    final merged = <SentenceStruct>[];
    final seen = <String>{};

    void addSentence(SentenceStruct? sentence) {
      if (sentence == null) return;
      final text = sentence.text.trim();
      if (text.isEmpty) return;
      final language = sentence.lang.trim().toLowerCase();
      final dedupeKey = '$language|${text.toLowerCase()}';
      if (!seen.add(dedupeKey)) {
        return;
      }
      merged.add(sentence);
    }

    for (final sentence in _exampleSentences()) {
      addSentence(sentence);
    }

    final conversationSentenceText = _conversationSentenceText();
    if (conversationSentenceText != null) {
      addSentence(
        SentenceStruct(
          text: conversationSentenceText,
          lang: normalizeWordLookupLanguageCode(widget.langCode),
        ),
      );
    }

    return merged;
  }

  Widget _buildContextCard(BuildContext context) {
    final phraseContext = _phraseContextText();
    final sentenceContext = _conversationSentenceText();
    if (phraseContext == null && sentenceContext == null) {
      return const SizedBox.shrink();
    }

    final labelStyle = FlutterFlowTheme.of(context).bodyMedium.override(
          fontFamily: 'sf pro display',
          color: ExpatlioDesign.muted,
          fontSize: 13.0,
          letterSpacing: 0.0,
          fontWeight: FontWeight.w600,
        );
    final valueStyle = FlutterFlowTheme.of(context).bodyMedium.override(
          fontFamily: 'sf pro display',
          fontSize: 16.0,
          letterSpacing: 0.0,
          fontWeight: FontWeight.w500,
        );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: ExpatlioDesign.card,
        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusExtraLarge),
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 0.8,
        ),
      ),
      padding: const EdgeInsets.symmetric(
          horizontal: ExpatlioDesign.space16, vertical: ExpatlioDesign.space12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Контекст',
            style: FlutterFlowTheme.of(context).bodyMedium.override(
                  fontFamily: 'sf pro display',
                  fontSize: 15.0,
                  letterSpacing: 0.0,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (phraseContext != null) ...[
            const SizedBox(height: ExpatlioDesign.space12),
            Text('Фраза', style: labelStyle),
            const SizedBox(height: ExpatlioDesign.space4),
            Text(phraseContext, style: valueStyle),
          ],
          if (sentenceContext != null) ...[
            const SizedBox(height: ExpatlioDesign.space12),
            Text('Предложение', style: labelStyle),
            const SizedBox(height: ExpatlioDesign.space4),
            Text(
              sentenceContext,
              style: valueStyle.copyWith(height: 1.3),
            ),
          ],
        ],
      ),
    );
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
        widget.langCode,
        'en',
      ],
      fallback: 'en',
    );
  }

  String _resolvedTatoebaSourceLanguageCode() {
    return resolveTatoebaWordLookupLanguageCode(
      <String?>[
        widget.langCode,
        'eng',
      ],
      fallback: 'eng',
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

    return Container(
      width: 50.0,
      height: 50.0,
      decoration: BoxDecoration(),
      child: Align(
        alignment: AlignmentDirectional(0.0, 0.0),
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

  List<SentenceStruct> _exampleSentences() {
    return _lookupResult?.examples ?? const <SentenceStruct>[];
  }

  @override
  Widget build(BuildContext context) {
    final translationLanguageCode =
        _preferredDisplayTranslationLanguageCode(context);
    final exampleSentences = _exampleSentences();
    final hasContext =
        _phraseContextText() != null || _conversationSentenceText() != null;
    final collapsedSize = exampleSentences.isEmpty
        ? (hasContext ? 280.0 : 220.0)
        : (hasContext ? 300.0 : 250.0);

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
        duration: Duration(milliseconds: 200),
        curve: Curves.elasticOut,
        width: double.infinity,
        height: _model.size,
        decoration: ExpatlioDesign.sheetDecoration(
          color: FlutterFlowTheme.of(context).primaryBackground,
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.fromSTEB(
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
                            widget.word,
                            'Слово',
                          ),
                        ),
                        const SizedBox(height: ExpatlioDesign.space16),
                        Flexible(
                          child: ClipRRect(
                            borderRadius: BorderRadius.only(
                              bottomLeft:
                                  Radius.circular(ExpatlioDesign.radiusNone),
                              bottomRight:
                                  Radius.circular(ExpatlioDesign.radiusNone),
                              topLeft:
                                  Radius.circular(ExpatlioDesign.radiusNone),
                              topRight:
                                  Radius.circular(ExpatlioDesign.radiusNone),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                borderRadius: BorderRadius.only(
                                  bottomLeft: Radius.circular(
                                      ExpatlioDesign.radiusNone),
                                  bottomRight: Radius.circular(
                                      ExpatlioDesign.radiusNone),
                                  topLeft: Radius.circular(
                                      ExpatlioDesign.radiusNone),
                                  topRight: Radius.circular(
                                      ExpatlioDesign.radiusNone),
                                ),
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
                                          Padding(
                                            padding:
                                                EdgeInsetsDirectional.fromSTEB(
                                                    ExpatlioDesign.space8,
                                                    ExpatlioDesign.space0,
                                                    ExpatlioDesign.space8,
                                                    ExpatlioDesign.space0),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color:
                                                    FlutterFlowTheme.of(context)
                                                        .primaryBackground,
                                                borderRadius:
                                                    BorderRadius.circular(
                                                        ExpatlioDesign
                                                            .radiusExtraLarge),
                                              ),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                children: [
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    6.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        child:
                                                            _buildLanguageFlag(
                                                          widget.langCode,
                                                          fallbackLabel: '🌐',
                                                        ),
                                                      ),
                                                      Text(
                                                        '${valueOrDefault<String>(
                                                          widget.word,
                                                          '-',
                                                        )} ',
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'sf pro display',
                                                              fontSize: 17.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w600,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                  Divider(
                                                    height: 1.0,
                                                    thickness: 1.0,
                                                    indent: 56.0,
                                                    endIndent: 16.0,
                                                    color: FlutterFlowTheme.of(
                                                            context)
                                                        .alternate,
                                                  ),
                                                  Row(
                                                    mainAxisSize:
                                                        MainAxisSize.max,
                                                    children: [
                                                      Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    6.0,
                                                                    0.0,
                                                                    0.0,
                                                                    0.0),
                                                        child:
                                                            _buildLanguageFlag(
                                                          translationLanguageCode,
                                                          fallbackLabel: '🌐',
                                                        ),
                                                      ),
                                                      Builder(
                                                        builder: (context) {
                                                          if (_lookupLoaded) {
                                                            final translationText =
                                                                _primaryTranslationText();
                                                            return Text(
                                                              translationText
                                                                      .isNotEmpty
                                                                  ? translationText
                                                                  : (widget
                                                                          .word ??
                                                                      ''),
                                                              style: FlutterFlowTheme
                                                                      .of(context)
                                                                  .bodyMedium
                                                                  .override(
                                                                    fontFamily:
                                                                        'sf pro display',
                                                                    fontSize:
                                                                        17.0,
                                                                    letterSpacing:
                                                                        0.0,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                  ),
                                                            );
                                                          } else {
                                                            return Padding(
                                                              padding:
                                                                  EdgeInsetsDirectional
                                                                      .fromSTEB(
                                                                          0.0,
                                                                          0.0,
                                                                          0.0,
                                                                          20.0),
                                                              child:
                                                                  Lottie.asset(
                                                                'assets/jsons/Material_Wave_Loading_Animation.json',
                                                                width: 44.67,
                                                                height: 20.2,
                                                                fit: BoxFit
                                                                    .cover,
                                                                animate: true,
                                                              ),
                                                            );
                                                          }
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          if (_phraseContextText() != null ||
                                              _conversationSentenceText() !=
                                                  null)
                                            Padding(
                                              padding: EdgeInsetsDirectional
                                                  .fromSTEB(
                                                      16.0, 12.0, 16.0, 0.0),
                                              child: _buildContextCard(context),
                                            ),
                                          AnimatedOpacity(
                                            opacity: _lookupLoaded ? 1.0 : 0.0,
                                            duration: 200.0.ms,
                                            curve: Curves.easeInOut,
                                            child: Padding(
                                              padding: EdgeInsets.all(
                                                  ExpatlioDesign.space16),
                                              child: Column(
                                                mainAxisSize: MainAxisSize.max,
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Builder(
                                                    builder: (context) {
                                                      final wwww =
                                                          _dictionaryEntries();

                                                      return ListView.separated(
                                                        padding:
                                                            EdgeInsets.zero,
                                                        primary: false,
                                                        shrinkWrap: true,
                                                        scrollDirection:
                                                            Axis.vertical,
                                                        itemCount: wwww.length,
                                                        separatorBuilder:
                                                            (_, __) => SizedBox(
                                                                height:
                                                                    ExpatlioDesign
                                                                        .space24),
                                                        itemBuilder: (context,
                                                            wwwwIndex) {
                                                          final wwwwItem =
                                                              wwww[wwwwIndex];
                                                          return Column(
                                                            mainAxisSize:
                                                                MainAxisSize
                                                                    .max,
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              RichText(
                                                                textScaler: MediaQuery.of(
                                                                        context)
                                                                    .textScaler,
                                                                text: TextSpan(
                                                                  children: [
                                                                    TextSpan(
                                                                      text: wwwwItem
                                                                          .text,
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            fontFamily:
                                                                                'Cool',
                                                                            fontSize:
                                                                                22.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.normal,
                                                                          ),
                                                                    ),
                                                                    TextSpan(
                                                                      text:
                                                                          ' [${wwwwItem.ts}] ',
                                                                      style:
                                                                          TextStyle(
                                                                        fontFamily:
                                                                            'Cool',
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                        fontWeight:
                                                                            FontWeight.normal,
                                                                        fontSize:
                                                                            22.0,
                                                                      ),
                                                                    ),
                                                                    TextSpan(
                                                                      text: () {
                                                                        if (wwwwItem.pos ==
                                                                            'noun') {
                                                                          return 'сущ';
                                                                        } else if (wwwwItem.pos ==
                                                                            'abjective') {
                                                                          return 'прил';
                                                                        } else if (wwwwItem.pos ==
                                                                            'participle') {
                                                                          return 'прич';
                                                                        } else if (wwwwItem.pos ==
                                                                            'verb') {
                                                                          return 'гл';
                                                                        } else {
                                                                          return ' ';
                                                                        }
                                                                      }(),
                                                                      style:
                                                                          TextStyle(
                                                                        fontFamily:
                                                                            'Cool',
                                                                        color: FlutterFlowTheme.of(context)
                                                                            .secondaryText,
                                                                        fontWeight:
                                                                            FontWeight.normal,
                                                                        fontSize:
                                                                            22.0,
                                                                        fontStyle:
                                                                            FontStyle.italic,
                                                                      ),
                                                                    )
                                                                  ],
                                                                  style: FlutterFlowTheme.of(
                                                                          context)
                                                                      .bodyMedium
                                                                      .override(
                                                                        fontFamily:
                                                                            'Cool',
                                                                        color: Colors
                                                                            .black,
                                                                        fontSize:
                                                                            22.0,
                                                                        letterSpacing:
                                                                            0.0,
                                                                        fontWeight:
                                                                            FontWeight.normal,
                                                                      ),
                                                                ),
                                                              ),
                                                              Builder(
                                                                builder:
                                                                    (context) {
                                                                  final tr = wwwwItem
                                                                      .tr
                                                                      .toList()
                                                                      .take(3)
                                                                      .toList();

                                                                  return ListView
                                                                      .separated(
                                                                    padding:
                                                                        EdgeInsets
                                                                            .zero,
                                                                    primary:
                                                                        false,
                                                                    shrinkWrap:
                                                                        true,
                                                                    scrollDirection:
                                                                        Axis.vertical,
                                                                    itemCount: tr
                                                                        .length,
                                                                    separatorBuilder: (_,
                                                                            __) =>
                                                                        SizedBox(
                                                                            height:
                                                                                ExpatlioDesign.space8),
                                                                    itemBuilder:
                                                                        (context,
                                                                            trIndex) {
                                                                      final trItem =
                                                                          tr[trIndex];
                                                                      return Column(
                                                                        mainAxisSize:
                                                                            MainAxisSize.max,
                                                                        crossAxisAlignment:
                                                                            CrossAxisAlignment.start,
                                                                        children: [
                                                                          Padding(
                                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                                ExpatlioDesign.space0,
                                                                                ExpatlioDesign.space12,
                                                                                ExpatlioDesign.space0,
                                                                                ExpatlioDesign.space0),
                                                                            child:
                                                                                Builder(
                                                                              builder: (context) {
                                                                                final sssss = functions.syn(trItem.gen, trItem.text, trItem.syn.toList())?.toList() ?? [];

                                                                                return Wrap(
                                                                                  spacing: ExpatlioDesign.space4,
                                                                                  runSpacing: ExpatlioDesign.space8,
                                                                                  alignment: WrapAlignment.start,
                                                                                  crossAxisAlignment: WrapCrossAlignment.start,
                                                                                  direction: Axis.horizontal,
                                                                                  runAlignment: WrapAlignment.start,
                                                                                  verticalDirection: VerticalDirection.down,
                                                                                  clipBehavior: Clip.none,
                                                                                  children: List.generate(sssss.length, (sssssIndex) {
                                                                                    final sssssItem = sssss[sssssIndex];
                                                                                    return Container(
                                                                                      height: 35.0,
                                                                                      decoration: BoxDecoration(
                                                                                        color: ExpatlioDesign.card,
                                                                                        borderRadius: BorderRadius.circular(ExpatlioDesign.radiusCapsule),
                                                                                      ),
                                                                                      child: Padding(
                                                                                        padding: EdgeInsetsDirectional.fromSTEB(ExpatlioDesign.space12, ExpatlioDesign.space0, ExpatlioDesign.space12, ExpatlioDesign.space0),
                                                                                        child: Column(
                                                                                          mainAxisSize: MainAxisSize.max,
                                                                                          mainAxisAlignment: MainAxisAlignment.center,
                                                                                          children: [
                                                                                            RichText(
                                                                                              textScaler: MediaQuery.of(context).textScaler,
                                                                                              text: TextSpan(
                                                                                                children: [
                                                                                                  TextSpan(
                                                                                                    text: sssssItem.text,
                                                                                                    style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                          fontFamily: 'sf pro display',
                                                                                                          color: ExpatlioDesign.text,
                                                                                                          fontSize: 15.0,
                                                                                                          letterSpacing: 0.0,
                                                                                                          fontWeight: FontWeight.w500,
                                                                                                        ),
                                                                                                  ),
                                                                                                  TextSpan(
                                                                                                    text: FFLocalizations.of(context).getText(
                                                                                                      'wwfgr0mf' /*   */,
                                                                                                    ),
                                                                                                    style: TextStyle(),
                                                                                                  ),
                                                                                                  TextSpan(
                                                                                                    text: sssssItem.gen,
                                                                                                    style: TextStyle(
                                                                                                      color: Color(0xFF727272),
                                                                                                    ),
                                                                                                  )
                                                                                                ],
                                                                                                style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                                      fontFamily: 'sf pro display',
                                                                                                      fontSize: 16.0,
                                                                                                      letterSpacing: 0.0,
                                                                                                      fontWeight: FontWeight.normal,
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
                                                                            padding: EdgeInsetsDirectional.fromSTEB(
                                                                                ExpatlioDesign.space0,
                                                                                ExpatlioDesign.space8,
                                                                                ExpatlioDesign.space0,
                                                                                ExpatlioDesign.space0),
                                                                            child:
                                                                                Container(
                                                                              height: 17.0,
                                                                              decoration: BoxDecoration(),
                                                                              child: Builder(
                                                                                builder: (context) {
                                                                                  final meanb = trItem.mean.toList();

                                                                                  return ListView.builder(
                                                                                    padding: EdgeInsets.zero,
                                                                                    primary: false,
                                                                                    shrinkWrap: true,
                                                                                    scrollDirection: Axis.horizontal,
                                                                                    itemCount: meanb.length,
                                                                                    itemBuilder: (context, meanbIndex) {
                                                                                      final meanbItem = meanb[meanbIndex];
                                                                                      return Text(
                                                                                        '${meanbItem.text}. ',
                                                                                        style: FlutterFlowTheme.of(context).bodyMedium.override(
                                                                                              fontFamily: 'sf pro display',
                                                                                              color: Color(0xFF727272),
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
                                                  ),
                                                  if (exampleSentences
                                                      .isNotEmpty)
                                                    Padding(
                                                      padding:
                                                          EdgeInsetsDirectional
                                                              .fromSTEB(
                                                                  0.0,
                                                                  16.0,
                                                                  0.0,
                                                                  0.0),
                                                      child: Text(
                                                        FFLocalizations.of(
                                                                context)
                                                            .getText(
                                                          'c1hnqtt4' /* Примеры */,
                                                        ),
                                                        style: FlutterFlowTheme
                                                                .of(context)
                                                            .bodyMedium
                                                            .override(
                                                              fontFamily:
                                                                  'Cool',
                                                              fontSize: 22.0,
                                                              letterSpacing:
                                                                  0.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .normal,
                                                            ),
                                                      ),
                                                    ),
                                                  if (exampleSentences
                                                      .isNotEmpty)
                                                    Container(
                                                      decoration:
                                                          BoxDecoration(),
                                                      child: Padding(
                                                        padding:
                                                            EdgeInsetsDirectional
                                                                .fromSTEB(
                                                                    0.0,
                                                                    12.0,
                                                                    0.0,
                                                                    0.0),
                                                        child:
                                                            ListView.separated(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          primary: false,
                                                          shrinkWrap: true,
                                                          scrollDirection:
                                                              Axis.vertical,
                                                          itemCount:
                                                              exampleSentences
                                                                  .length,
                                                          separatorBuilder: (_,
                                                                  __) =>
                                                              SizedBox(
                                                                  height:
                                                                      ExpatlioDesign
                                                                          .space8),
                                                          itemBuilder: (context,
                                                              sssIndex) {
                                                            final sssItem =
                                                                exampleSentences[
                                                                    sssIndex];
                                                            return Container(
                                                              decoration:
                                                                  BoxDecoration(
                                                                color: FlutterFlowTheme.of(
                                                                        context)
                                                                    .primaryBackground,
                                                                borderRadius:
                                                                    BorderRadius
                                                                        .circular(
                                                                            26.0),
                                                              ),
                                                              child: Padding(
                                                                padding:
                                                                    EdgeInsets
                                                                        .all(
                                                                            16.0),
                                                                child: Column(
                                                                  mainAxisSize:
                                                                      MainAxisSize
                                                                          .min,
                                                                  crossAxisAlignment:
                                                                      CrossAxisAlignment
                                                                          .start,
                                                                  children: [
                                                                    Text(
                                                                      sssItem
                                                                          .text,
                                                                      style: FlutterFlowTheme.of(
                                                                              context)
                                                                          .bodyMedium
                                                                          .override(
                                                                            fontFamily:
                                                                                'sf pro display',
                                                                            color:
                                                                                Colors.black,
                                                                            fontSize:
                                                                                16.0,
                                                                            letterSpacing:
                                                                                0.0,
                                                                            fontWeight:
                                                                                FontWeight.w500,
                                                                          ),
                                                                    ),
                                                                    Padding(
                                                                      padding: EdgeInsetsDirectional.fromSTEB(
                                                                          ExpatlioDesign
                                                                              .space0,
                                                                          ExpatlioDesign
                                                                              .space8,
                                                                          ExpatlioDesign
                                                                              .space0,
                                                                          ExpatlioDesign
                                                                              .space0),
                                                                      child:
                                                                          Text(
                                                                        valueOrDefault<
                                                                            String>(
                                                                          sssItem
                                                                              .translations
                                                                              .firstOrNull
                                                                              ?.text,
                                                                          '-',
                                                                        ),
                                                                        style: FlutterFlowTheme.of(context)
                                                                            .bodyMedium
                                                                            .override(
                                                                              fontFamily: 'sf pro display',
                                                                              color: Color(0xFF727272),
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
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ]
                                            .addToStart(SizedBox(
                                                height: ExpatlioDesign.space16))
                                            .addToEnd(SizedBox(
                                                height:
                                                    ExpatlioDesign.space24)),
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
                      alignment: AlignmentDirectional(1.0, 1.0),
                      child: Padding(
                        padding: EdgeInsetsDirectional.fromSTEB(
                            ExpatlioDesign.space0,
                            ExpatlioDesign.space0,
                            ExpatlioDesign.space8,
                            ExpatlioDesign.space20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 60.0,
                              height: 60.0,
                              decoration: BoxDecoration(
                                color: FlutterFlowTheme.of(context)
                                    .primaryBackground,
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 7.0,
                                    color: Color(0x0D2C2C2C),
                                    offset: Offset(
                                      0.0,
                                      2.0,
                                    ),
                                  )
                                ],
                                shape: BoxShape.circle,
                              ),
                              child: Builder(
                                builder: (context) {
                                  if (_model.size >= 400.0) {
                                    return InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.size = 250.0;
                                        safeSetState(() {});
                                      },
                                      child: Stack(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        children: [
                                          Icon(
                                            FFIcons.kexpand01,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 24.0,
                                          ),
                                        ],
                                      ),
                                    );
                                  } else {
                                    return InkWell(
                                      splashColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      highlightColor: Colors.transparent,
                                      onTap: () async {
                                        _model.size = 750.0;
                                        safeSetState(() {});
                                      },
                                      child: Stack(
                                        alignment:
                                            AlignmentDirectional(0.0, 0.0),
                                        children: [
                                          Icon(
                                            FFIcons.kexpand01,
                                            color: FlutterFlowTheme.of(context)
                                                .primaryText,
                                            size: 24.0,
                                          ),
                                        ],
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                            if (_canManageDictionary)
                              StreamBuilder<List<UserWordsRecord>>(
                                stream: queryUserWordsRecord(
                                  parent: currentUserReference,
                                ),
                                builder: (context, snapshot) {
                                  // Customize what your widget looks like when it's loading.
                                  if (!snapshot.hasData) {
                                    return Center(
                                      child: SizedBox(
                                        width: 50.0,
                                        height: 50.0,
                                        child: SpinKitCircle(
                                          color: FlutterFlowTheme.of(context)
                                              .secondary,
                                          size: 50.0,
                                        ),
                                      ),
                                    );
                                  }
                                  List<UserWordsRecord>
                                      containerUserWordsRecordList =
                                      snapshot.data!;

                                  return Container(
                                    width: 60.0,
                                    height: 60.0,
                                    decoration: BoxDecoration(
                                      color: FlutterFlowTheme.of(context)
                                          .primaryBackground,
                                      boxShadow: [
                                        BoxShadow(
                                          blurRadius: 7.0,
                                          color: Color(0x0D2C2C2C),
                                          offset: Offset(
                                            0.0,
                                            2.0,
                                          ),
                                        )
                                      ],
                                      shape: BoxShape.circle,
                                    ),
                                    child: Builder(
                                      builder: (context) {
                                        final primaryEntryText =
                                            _primaryEntry()?.text;
                                        if (containerUserWordsRecordList
                                            .where((e) =>
                                                e.entry.firstOrNull?.text ==
                                                primaryEntryText)
                                            .toList()
                                            .isNotEmpty) {
                                          return InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () async {
                                              unawaited(
                                                () async {
                                                  final existingWord =
                                                      containerUserWordsRecordList
                                                          .where((e) =>
                                                              e
                                                                  .entry
                                                                  .firstOrNull
                                                                  ?.text ==
                                                              primaryEntryText)
                                                          .toList()
                                                          .firstOrNull;
                                                  if (existingWord == null) {
                                                    return;
                                                  }
                                                  await FlashcardReviewRepository
                                                      .deleteReviewForWord(
                                                    existingWord.reference,
                                                  );
                                                  await existingWord.reference
                                                      .delete();
                                                }(),
                                              );
                                            },
                                            child: Container(
                                              width: double.infinity,
                                              child: Stack(
                                                alignment: AlignmentDirectional(
                                                    0.0, 0.0),
                                                children: [
                                                  Icon(
                                                    FFIcons.kstar012,
                                                    color: ExpatlioDesign.text,
                                                    size: 24.0,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        } else {
                                          return InkWell(
                                            splashColor: Colors.transparent,
                                            focusColor: Colors.transparent,
                                            hoverColor: Colors.transparent,
                                            highlightColor: Colors.transparent,
                                            onTap: () async {
                                              final sentencesToSave =
                                                  _sentencesToSave();
                                              var entriesToSave =
                                                  _dictionaryEntries();
                                              final addedAt =
                                                  getCurrentTimestamp;
                                              var userWordsRecordReference =
                                                  UserWordsRecord.createDoc(
                                                      currentUserReference!);
                                              await userWordsRecordReference
                                                  .set({
                                                ...createUserWordsRecordData(
                                                  addedAt: addedAt,
                                                ),
                                                ...mapToFirestore(
                                                  {
                                                    'entry':
                                                        getEntryListFirestoreData(
                                                      entriesToSave,
                                                    ),
                                                    'Sentence':
                                                        getSentenceListFirestoreData(
                                                      sentencesToSave,
                                                    ),
                                                  },
                                                ),
                                              });
                                              await FlashcardReviewRepository
                                                  .ensureInitialReviewForWord(
                                                wordRef:
                                                    userWordsRecordReference,
                                                addedAt: addedAt,
                                              );
                                              try {
                                                entriesToSave =
                                                    await FlashcardContentService
                                                        .enrichWordWithSourceSynonyms(
                                                  wordRef:
                                                      userWordsRecordReference,
                                                  entries: entriesToSave,
                                                  sourceLanguageCode:
                                                      _resolvedYandexSourceLanguageCode(),
                                                );
                                              } catch (_) {}
                                              _model.erweerw = UserWordsRecord
                                                  .getDocumentFromData({
                                                ...createUserWordsRecordData(
                                                  addedAt: addedAt,
                                                ),
                                                ...mapToFirestore(
                                                  {
                                                    'entry':
                                                        getEntryListFirestoreData(
                                                      entriesToSave,
                                                    ),
                                                    'Sentence':
                                                        getSentenceListFirestoreData(
                                                      sentencesToSave,
                                                    ),
                                                  },
                                                ),
                                              }, userWordsRecordReference);

                                              safeSetState(() {});
                                            },
                                            child: Stack(
                                              alignment: AlignmentDirectional(
                                                  0.0, 0.0),
                                              children: [
                                                Icon(
                                                  FFIcons.kstar01,
                                                  color: ExpatlioDesign.text,
                                                  size: 24.0,
                                                ),
                                              ],
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  );
                                },
                              ),
                          ].divide(SizedBox(height: ExpatlioDesign.space8)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ].divide(SizedBox(width: ExpatlioDesign.space4)),
          ),
        ),
      ),
    );
  }
}
